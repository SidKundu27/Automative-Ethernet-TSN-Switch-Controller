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

### Phase 1: Foundation (Weeks 1-2) ✅
- [x] Project setup and documentation
- [x] Ethernet MAC implementation
- [x] Basic packet processing
- [x] FIFO management

### Phase 2: TSN Core Features (Weeks 3-4)
- [ ] IEEE 802.1AS time synchronization
- [ ] IEEE 802.1Qbv Time-Aware Shaper
- [ ] IEEE 802.1Qav Credit-Based Shaper
- [ ] Priority queue management

### Phase 3: Advanced Features (Weeks 5-6)
- [ ] Frame preemption (IEEE 802.1Qbu)
- [ ] Security features
- [ ] Automotive diagnostics
- [ ] Wake-on-LAN support

### Phase 4: Optimization & Verification (Weeks 7-8)
- [ ] Timing closure optimization
- [ ] FPGA implementation
- [ ] Performance verification
- [ ] Automotive test scenarios

### Phase 5: Documentation & Demo (Weeks 9-10)
- [ ] Complete documentation
- [ ] Timing analysis reports
- [ ] Demo video creation
- [ ] Final verification reports

## Getting Started

1. **Prerequisites:**
   - Xilinx Vivado or Intel Quartus
   - ModelSim or QuestaSim
   - SystemVerilog knowledge
   - Understanding of Ethernet and TSN protocols

2. **Build Instructions:**
   ```bash
   # Clone repository
   git clone <repository-url>
   cd Automative-Ethernet-TSN-Switch-Controller
   
   # Run simulation
   cd scripts
   ./run_simulation.sh
   
   # Synthesize for FPGA
   ./synthesize.sh
   ```

3. **Key Documentation:**
   - [Architecture Overview](docs/architecture/system_architecture.md)
   - [Timing Requirements](docs/timing/timing_specification.md)
   - [Verification Plan](docs/verification/verification_plan.md)

## Contact

This project demonstrates advanced RTL design skills for automotive networking applications, specifically targeting opportunities in companies like NXP Semiconductors working on next-generation automotive Ethernet solutions.

---

**Note:** This project is designed to showcase expertise in automotive networking, TSN protocols, and high-performance RTL design for safety-critical applications.
