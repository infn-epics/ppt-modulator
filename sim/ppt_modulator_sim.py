#!/usr/bin/env python3
"""
TCP simulator for the Puls-Plasmatechnik IF-MOD2128C modulator, for testing
the ppt-modulator IOC without real hardware.

Implements the wire protocol from docs/tcpip-interface-description_IF-MOD2128C_Rev2-1.pdf:
- Pushes an unsolicited 86-byte status packet once per --interval seconds.
- Accepts the IOC's 32-bit command register writes (4 bytes, + optional
  trailing FF FF which is ignored).
- Byte order matches the IOC's decoder exactly: analog fields are big-endian
  (getWord in pptDecode.c), interlock/status bitfields are little-endian
  (getWordL in pptDecode.c) -- these differ, by design, in the real protocol.
- Only one client is accepted at a time, matching the real device.

Usage:
    python3 ppt_modulator_sim.py --port 2000
Then point a test IOC's drvAsynIPPortConfigure at this host:port instead of
the real modulator.
"""

import argparse
import math
import random
import socket
import struct
import threading
import time

PACKET_LEN = 86


def be16(value):
    return struct.pack(">H", int(round(value)) & 0xFFFF)


def le16(value):
    return struct.pack("<H", int(value) & 0xFFFF)


class Subsystem:
    """ON/OFF + preheat-timer state for one controlled unit."""

    def __init__(self, preheat_seconds=0):
        self.on = False
        self.preheat_total = preheat_seconds
        self.preheat_remaining = 0.0
        self.ready = False

    def turn_on(self):
        self.on = True
        self.preheat_remaining = float(self.preheat_total)
        self.ready = self.preheat_total == 0

    def turn_off(self):
        self.on = False
        self.ready = False
        self.preheat_remaining = 0.0

    def tick(self, dt):
        if self.on and self.preheat_remaining > 0:
            self.preheat_remaining = max(0.0, self.preheat_remaining - dt)
            if self.preheat_remaining == 0:
                self.ready = True

    @property
    def _preheat_display_total(self):
        # Ceiling, not truncation: a real countdown holds "1" for the whole
        # final second rather than dropping straight to "0" the instant
        # remaining time dips below 1.0.
        return math.ceil(self.preheat_remaining)

    @property
    def preheat_min(self):
        return self._preheat_display_total // 60

    @property
    def preheat_sec(self):
        return self._preheat_display_total % 60


class ModulatorState:
    def __init__(self, preheat_short=1.0, preheat_long=10.0):
        # Real datasheet timings (Thy/Klys preheat minutes, HVPS 15s) are far
        # too slow for interactive testing of the autoOnSequence/autoOffSequence
        # state machine, so every subsystem here settles much faster. But the
        # subsystems whose preheat/ready state actually GATES the next step in
        # pptAutoSeq.st -- Thy (gates HVPS via autoOn_waitPreheat), Klys100
        # (gates Focus), HVPS (gates ChargePFN) -- use preheat_long so that
        # gating is actually observable rather than resolving instantly.
        self.thy = Subsystem(preheat_seconds=preheat_long)
        self.klys80 = Subsystem(preheat_seconds=preheat_short)
        self.klys100 = Subsystem(preheat_seconds=preheat_long)
        self.focus = Subsystem(preheat_seconds=preheat_short)
        self.premag = Subsystem(preheat_seconds=preheat_short)
        self.hvps = Subsystem(preheat_seconds=preheat_long)
        self.chargepfn = Subsystem(preheat_seconds=preheat_short)

        # Ordered per autoOnSequence in pptAutoSeq.st: Thy -> Klys80 -> Klys100
        # -> Focus -> Premag -> HVPS -> ChargePFN. Each stage depends on every
        # earlier one, so turning an earlier stage OFF cascades forward.
        self._sequence = [
            (0x01, self.thy), (0x02, self.klys80), (0x04, self.klys100),
            (0x08, self.focus), (0x10, self.premag), (0x20, self.hvps),
            (0x40, self.chargepfn),
        ]

        self.hv_setpoint_raw = 0  # 0..500, raw units = kV * 10
        self.hv_actual_raw = 0.0
        self.local_remote = 1  # 1 = remote

        self.prev_cmd_word = 0
        self.lock = threading.Lock()

    def apply_command(self, cmd_word, hv_bits):
        with self.lock:
            prev = self.prev_cmd_word

            # ON bits (0-6): rising edge only
            for bit, sub in self._sequence:
                if (cmd_word & bit) and not (prev & bit):
                    sub.turn_on()

            # OFF bits (8-14): level-triggered, and cascades forward -- turning
            # an earlier stage off takes every later stage down with it, since
            # each stage depends on the ones before it.
            for i, (bit, sub) in enumerate(self._sequence):
                if cmd_word & (bit << 8):
                    for _, later_sub in self._sequence[i:]:
                        later_sub.turn_off()

            self.prev_cmd_word = cmd_word
            self.hv_setpoint_raw = hv_bits & 0xFFFF

    def tick(self, dt):
        with self.lock:
            for sub in (self.thy, self.klys80, self.klys100, self.focus,
                        self.premag, self.hvps, self.chargepfn):
                sub.tick(dt)

            target = self.hv_setpoint_raw if self.hvps.on else 0
            rate = 40.0 * dt  # raw units/sec, ~4 kV/sec ramp
            if self.hv_actual_raw < target:
                self.hv_actual_raw = min(target, self.hv_actual_raw + rate)
            elif self.hv_actual_raw > target:
                self.hv_actual_raw = max(target, self.hv_actual_raw - rate)

    def build_packet(self):
        with self.lock:
            buf = bytearray(PACKET_LEN)

            def analog(offset, value):
                buf[offset:offset + 2] = be16(value)

            def status(offset, value):
                buf[offset:offset + 2] = le16(value)

            # Thyratron (bytes 0-13)
            thy_heater_v = 75 if self.thy.on else 0       # 7.5 V *10
            thy_reservoir_v = 68 if self.thy.on else 0    # 6.8 V *10
            analog(0, thy_heater_v)
            analog(2, thy_reservoir_v)
            analog(4, (thy_heater_v + thy_reservoir_v) * 0.6)  # total current *10
            analog(6, self.thy.preheat_min)
            analog(8, self.thy.preheat_sec)
            status(10, 0)  # no interlocks simulated
            status(12, (1 if self.thy.ready else 0)
                       | (2 if self.thy.on else 0)
                       | (4 if self.thy.on and not self.thy.ready else 0))

            # Klystron (bytes 14-35)
            klys_on = self.klys80.on or self.klys100.on
            analog(14, 235 if klys_on else 0)
            analog(16, 3 if klys_on else 0)
            analog(18, 32 + (2 if klys_on else 0) + random.uniform(-0.3, 0.3))
            analog(20, 34 + (3 if klys_on else 0) + random.uniform(-0.3, 0.3))
            analog(22, 52 + random.uniform(-1, 1))  # L/min *10
            analog(24, 50 if self.klys100.ready else (5 if klys_on else 0))
            analog(26, 36 + (2 if klys_on else 0) + random.uniform(-0.5, 0.5))
            analog(28, self.klys100.preheat_min)
            analog(30, self.klys100.preheat_sec)
            status(32, 0)
            status(34, (1 if (self.klys80.ready or self.klys100.ready) else 0)
                       | (2 if klys_on else 0)
                       | (4 if self.klys100.on and not self.klys100.ready else 0)
                       | (8 if self.klys80.ready else 0)
                       | (16 if self.klys100.ready else 0))

            # Focus (bytes 36-51)
            focus_v = 1100 if self.focus.on else 0  # 110.0 V *10
            focus_i = 400 if self.focus.on else 0   # 40.0 A *10
            for off in (36, 40, 44):
                analog(off, focus_v)
            for off in (38, 42, 46):
                analog(off, focus_i)
            status(48, 0)
            status(50, (1 if self.focus.ready else 0) | (2 if self.focus.on else 0))

            # Premagnetisation (bytes 52-59)
            analog(52, 500 if self.premag.on else 0)  # 50.0 V *10
            analog(54, 150 if self.premag.on else 0)  # 15.0 A *10
            status(56, 0)
            status(58, (1 if self.premag.ready else 0) | (2 if self.premag.on else 0))

            # Vacuum(ext)/Interlocks(ext)/EOLC (bytes 60-67) - no faults simulated
            status(60, 0)
            status(62, 0)
            status(64, 0)
            analog(66, 0)  # EOLC counter

            # HVPS (bytes 68-79)
            analog(68, self.hv_actual_raw)
            analog(70, 250 + random.uniform(-2, 2))  # water temp, 25.0 C *10
            status(72, 0)
            status(74, (1 if self.hvps.on else 0)
                       | (2 if self.hvps.ready else 0)
                       | (4 if self.chargepfn.ready and self.hvps.ready else 0))
            status(76, 0)
            status(78, self.local_remote & 0x1)

            return bytes(buf)


def client_handler(conn, addr, state, interval):
    conn.settimeout(0.5)
    conn.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    stop = threading.Event()

    def sender():
        time.sleep(interval)  # let the client settle before the first push
        next_send = time.monotonic() + interval
        while not stop.is_set():
            try:
                conn.sendall(state.build_packet())
            except OSError:
                return
            next_send += interval
            sleep_for = next_send - time.monotonic()
            if sleep_for > 0:
                time.sleep(sleep_for)
            else:
                next_send = time.monotonic() + interval  # fell behind; resync

    threading.Thread(target=sender, daemon=True).start()

    buf = b""
    while not stop.is_set():
        try:
            data = conn.recv(4096)
        except socket.timeout:
            continue
        except OSError:
            break
        if not data:
            break
        buf += data
        print(f"[SIM] {addr} raw recv: {data.hex()}")
        while len(buf) >= 4:
            # StreamDevice's "%.4r" writes the 32-bit register big-endian on
            # the wire. pptEncodeCmd32 packs command bits in the high 16 bits
            # and HV bits in the low 16 bits, so big-endian transmission puts
            # the command word first on the wire (bytes 0-1), matching the
            # datasheet's Command Packet layout (WORD0=command, WORD2=HV).
            value = struct.unpack_from(">I", buf, 0)[0]
            cmd_word = (value >> 16) & 0xFFFF
            hv_bits = value & 0xFFFF
            print(f"[SIM] {addr} write: cmd=0x{cmd_word:04X} hv=0x{hv_bits:04X} "
                  f"({hv_bits / 10.0:.1f} kV)")
            state.apply_command(cmd_word, hv_bits)
            trailer = len(buf) >= 6 and buf[4:6] == b"\xff\xff"
            buf = buf[6:] if trailer else buf[4:]

    stop.set()
    conn.close()


def ticker(state, dt=0.2):
    while True:
        state.tick(dt)
        time.sleep(dt)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=2000)
    parser.add_argument("--interval", type=float, default=1.0,
                         help="status packet send interval, seconds")
    parser.add_argument("--preheat-short", type=float, default=1.0,
                         help="preheat seconds for contactor-style subsystems "
                              "(Thy, Klys80, Focus, Premag, ChargePFN)")
    parser.add_argument("--preheat-long", type=float, default=10.0,
                         help="preheat seconds for warm-up/charge subsystems "
                              "(Klys100, HVPS)")
    args = parser.parse_args()

    state = ModulatorState(preheat_short=args.preheat_short,
                            preheat_long=args.preheat_long)
    threading.Thread(target=ticker, args=(state,), daemon=True).start()

    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind((args.host, args.port))
    srv.listen(1)
    print(f"[SIM] listening on {args.host}:{args.port}")

    try:
        while True:
            conn, addr = srv.accept()
            print(f"[SIM] client connected: {addr}")
            client_handler(conn, addr, state, args.interval)
            print(f"[SIM] client disconnected: {addr}")
    except KeyboardInterrupt:
        pass
    finally:
        srv.close()


if __name__ == "__main__":
    main()
