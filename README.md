# PPT Modulator EPICS IOC

EPICS IOC for PPT (Pulse Power Technology) Modulator using StreamDevice over TCP/IP.

## Overview

This IOC communicates with a PPT modulator that sends **86 bytes of binary data** over **TCP port 2000**. The data contains voltage, current, temperature, flow, timer, status, and interlock information from the modulator.

## Features
- StreamDevice protocol for binary TCP/IP communication
- Complete database template with all modulator parameters
- Example startup script (`st.cmd`) configured for 192.168.197.111:2000
- **Phoebus BOB display** for real-time monitoring
- Comprehensive documentation

## Quick Start

### 1. Build the IOC
```bash
cd /Users/andreamichelotti/progetti/ppt-modulator
make clean
make
```

### 2. Configure Device IP
Edit `iocBoot/iocppt/st.cmd` and set your modulator IP address:
```bash
drvAsynIPPortConfigure("PPT1", "192.168.197.111:2000", 0, 0, 0)
```

### 3. Run the IOC
```bash
cd iocBoot/iocppt
./st.cmd
```

### 4. Open Phoebus Display
```bash
phoebus.sh ppt-modulator.bob
```

## Documentation

- **[README_IOC.md](README_IOC.md)** - Detailed IOC documentation
- **[README_PHOEBUS.md](README_PHOEBUS.md)** - Phoebus display guide
- **[FIXES.md](FIXES.md)** - Issues found and fixed
- **[docs/tcpip-interface-description_IF-MOD2128C_Rev2-1.pdf](docs/)** - Protocol specification

