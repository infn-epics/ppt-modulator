# PPT Modulator EPICS IOC

EPICS IOC for PPT (Pulse Power Technology) Modulator using StreamDevice over TCP/IP.

## Overview

This IOC communicates with a PPT modulator that sends **86 bytes of binary data** over **TCP port 2000**. The data contains voltage, current, temperature, flow, timer, status, and interlock information from the modulator.

## ✨ Optimized Architecture

This IOC uses an **optimized single-read architecture**:
- 📥 **1 TCP read** per scan cycle (not 43)
- 🎯 **Perfect data consistency** - all values from same snapshot
- ⚡ **97% less network traffic**
- 🚀 **Reduced device load** - minimal CPU impact
- 📊 All data extraction happens in EPICS, not on network

## Features
- **Optimized StreamDevice** protocol for binary TCP/IP communication
- **Single-read architecture** - reads all 86 bytes at once
- Complete database template with all modulator parameters
- Example startup script (`st.cmd`) configured for 192.168.197.111:2000
- **Phoebus BOB display** for real-time monitoring
- **Raw data access** for debugging and analysis
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

- **[OPTIMIZATION.md](OPTIMIZATION.md)** - ⭐ Architecture & optimization details
- **[MIGRATION.md](MIGRATION.md)** - Migration guide from old version
- **[README_IOC.md](README_IOC.md)** - Detailed IOC documentation
- **[README_PHOEBUS.md](README_PHOEBUS.md)** - Phoebus display guide
- **[FIXES.md](FIXES.md)** - Issues found and fixed
- **[docs/tcpip-interface-description_IF-MOD2128C_Rev2-1.pdf](docs/)** - Protocol specification

## Performance

| Metric | Value |
|--------|-------|
| TCP reads per second | **1** (was 43) |
| Network efficiency | **97.7% improvement** |
| Data consistency | **Perfect** (single snapshot) |
| Update rate | 1 Hz (1 second) |
| Raw data access | ✅ Available |

