# Automotive Ethernet TSN Switch Controller

## Project Overview

This project implements a **4-port Time-Sensitive Networking (TSN) Ethernet Switch Controller** in Verilog RTL, specifically targeting automotive applications. The design aligns with NXP's focus areas and demonstrates advanced digital logic design skills for automotive networking applications.

## Key Features

- **4-Port Gigabit Ethernet Switch** with GMII/RGMII interfaces
- **IEEE 802.1AS Time Synchronization** (Precision Time Protocol)
- **IEEE 802.1Qbv Time-Aware Shaping** for deterministic latency
- **IEEE 802.1Qav Credit-Based Shaping** for bandwidth management
- **Cut-Through Switching** for ultra-low latency (< 500ns target)
- **Automotive-Grade Design** (-40°C to +125°C operation)
- **Security Features** (MAC filtering, VLAN isolation)

## Technical Specifications

- **Target Performance:** 4 Gbps aggregate throughput (1 Gbps per port)
- **Latency:** < 500ns port-to-port switching delay
- **Time Sync Accuracy:** < 1μs (IEEE 802.1AS)
- **Traffic Classes:** 8 priority levels per port
- **Power Target:** < 2W total consumption
- **FPGA Target:** Xilinx Zynq UltraScale+ / Intel Cyclone V

## Directory Structure

```
├── rtl/                    # Verilog RTL source files
│   ├── mac/               # Ethernet MAC controllers
│   ├── tsn/               # TSN-specific modules
│   ├── switch/            # Switching matrix and forwarding
│   ├── ptp/               # Precision Time Protocol
│   └── top/               # Top-level integration
├── testbench/             # SystemVerilog testbenches
│   ├── unit/              # Unit tests for individual modules
│   ├── integration/       # Integration tests
│   └── automotive/        # Automotive-specific test scenarios
├── synthesis/             # FPGA synthesis scripts and constraints
│   ├── xilinx/            # Xilinx Vivado files
│   └── intel/             # Intel Quartus files
├── docs/                  # Documentation
│   ├── architecture/      # Design architecture documents
│   ├── timing/            # Timing analysis reports
│   └── verification/      # Verification plans and reports
├── scripts/               # Build and simulation scripts
└── demo/                  # Demo applications and videos
```

## Implementation Timeline

### Phase 1: Foundation ✅
- [x] Project setup and documentation
- [x] Ethernet MAC implementation
- [x] PTP synchronization engine
- [x] TSN traffic shaping
- [x] Switching matrix
- [x] System integration
- [x] Comprehensive testbenches

### Phase 2: FPGA Implementation
- [ ] Synthesis optimization
- [ ] Timing constraint implementation
- [ ] Resource utilization optimization
- [ ] Hardware validation platform

### Phase 3: Advanced Features
- [ ] Frame preemption (IEEE 802.1Qbu)
- [ ] Enhanced security features
- [ ] Automotive diagnostics
- [ ] Performance optimization

### Phase 4: Verification & Documentation
- [ ] Automotive compliance testing
- [ ] Timing analysis reports
- [ ] Complete design documentation
- [ ] Demo applications

## Getting Started

1. **Prerequisites:**
   - **FPGA Tools:** Xilinx Vivado or Intel Quartus Prime
   - **Simulator:** ModelSim/QuestaSim or Vivado Simulator
   - **Knowledge:** SystemVerilog, Ethernet protocols, TSN standards

2. **Build Instructions:**
   
   **On Windows (PowerShell):**
   ```powershell
   # Clone repository
   git clone <repository-url>
   cd Automative-Ethernet-TSN-Switch-Controller
   
   # Check simulator availability and run tests
   cd scripts
   .\run_simulation.ps1 help        # Show help and prerequisites
   .\run_simulation.ps1 compile     # Compile only (no simulation)
   .\run_simulation.ps1 all         # Full test suite (requires simulator)
   
   # Alternative: Use batch file wrapper
   .\run_simulation.bat help
   .\run_simulation.bat compile
   
   # Synthesize for FPGA
   .\synthesize.ps1
   ```
   
   **On Linux/macOS (Bash):**
   ```bash
   # Clone repository
   git clone <repository-url>
   cd Automative-Ethernet-TSN-Switch-Controller
   
   # Auto-detect available simulator and compile
   cd scripts
   ./run_simulation.sh compile       # Auto-detects iverilog, xvlog, or vlog
   ./run_simulation.sh all           # Run full test suite
   
   # Force specific simulator
   # Edit run_simulation.sh: SIMULATOR="icarus" or "vivado"
   
   # Synthesize for FPGA
   ./synthesize.sh
   ```

3. **Simulator Setup:**
   - **ModelSim:** Add `<ModelSim_install>/win32aloem` to PATH
   - **Vivado:** Source `settings64.ps1` from Vivado installation
   - **Alternative:** Use file list generation without simulation

4. **Key Documentation:**
   - [Architecture Overview](docs/architecture/system_architecture.md)
   - [Timing Requirements](docs/timing/timing_specification.md)
   - [Project Status](PROJECT_STATUS.md)
   - [Troubleshooting Guide](TROUBLESHOOTING.md)
   - [Linux Quick Start](QUICK_START_LINUX.md)

