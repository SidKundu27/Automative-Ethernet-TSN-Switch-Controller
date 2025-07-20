# System Architecture - Automotive TSN Switch Controller

## Overview

This document describes the architecture of the 4-port Automotive Ethernet TSN (Time-Sensitive Networking) Switch Controller designed for safety-critical automotive applications. The system implements IEEE 802.1 TSN standards with automotive-specific enhancements.

## System-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Automotive TSN Switch Controller             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │    Port 0   │    │    Port 1   │    │    Port 2   │         │
│  │ ADAS Camera │    │ Brake Ctrl  │    │Infotainment │         │
│  │             │    │             │    │             │         │
│  │ Priority: 6 │    │ Priority: 7 │    │ Priority: 1 │         │
│  │ 1518B@8kHz  │    │  64B@800Hz  │    │ 512B@100Hz  │         │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
│         │                   │                   │              │
│         └───────────────────┼───────────────────┼──────────┐   │
│                             │                   │          │   │
│  ┌─────────────┐            │                   │          │   │
│  │    Port 3   │            │                   │          │   │
│  │ Diagnostics │            │                   │          │   │
│  │             │            │                   │          │   │
│  │ Priority: 0 │            │                   │          │   │
│  │ 256B@8Hz    │            │                   │          │   │
│  └─────────────┘            │                   │          │   │
│         │                   │                   │          │   │
│         └───────────────────┼───────────────────┼──────────┘   │
│                             │                   │              │
│    ┌────────────────────────▼───────────────────▼─────────┐    │
│    │              Switching Matrix                        │    │
│    │         Cut-Through + Store-Forward                  │    │
│    │           < 500ns Port-to-Port Latency              │    │
│    └────────────────────────┬───────────────────┬─────────┘    │
│                             │                   │              │
│    ┌────────────────────────▼───────────────────▼─────────┐    │
│    │              TSN Traffic Shaper                      │    │
│    │    IEEE 802.1Qbv + IEEE 802.1Qav + Guard Bands     │    │
│    └────────────────────────┬───────────────────┬─────────┘    │
│                             │                   │              │
│    ┌────────────────────────▼───────────────────▼─────────┐    │
│    │              PTP Sync Engine                         │    │
│    │         IEEE 802.1AS Time Synchronization           │    │
│    │              < 1μs Accuracy                         │    │
│    └─────────────────────────────────────────────────────┘    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Key Components

### 1. Ethernet MAC Controllers (4x)

**Purpose**: Interface with external PHY chips, handle frame parsing and generation

**Key Features**:
- GMII/RGMII interface support
- IEEE 802.3 Ethernet frame processing
- VLAN tag parsing (IEEE 802.1Q)
- Hardware timestamping for TSN
- Automotive-grade error detection

**Performance Targets**:
- 1 Gbps per port (4 Gbps aggregate)
- Frame parsing latency < 100ns
- Zero packet loss under normal operation

### 2. PTP Synchronization Engine

**Purpose**: Provide network-wide time synchronization per IEEE 802.1AS

**Key Features**:
- Hardware-based timestamp generation
- Best Master Clock Algorithm (BMCA)
- Automotive environment compensation (temperature/voltage)
- Master/Slave operation modes
- Sub-microsecond accuracy

**Performance Targets**:
- Synchronization accuracy < 1μs
- Clock stability ±50 ppm over automotive temperature range
- Convergence time < 10 seconds

### 3. TSN Traffic Shaping Engine

**Purpose**: Implement deterministic traffic scheduling per IEEE 802.1Qbv/Qav

**Key Features**:
- Gate Control Lists (GCL) for time-aware shaping
- Credit-Based Shaping (CBS) for bandwidth management
- 8 traffic classes with strict priority
- Guard band implementation
- Frame preemption support (IEEE 802.1Qbu)

**Performance Targets**:
- Gate timing precision < 100ns
- Support for 1ms base cycle time
- Zero jitter for safety-critical traffic

### 4. Switching Matrix

**Purpose**: Make forwarding decisions and route frames between ports

**Key Features**:
- Cut-through forwarding for minimum latency
- MAC address learning and aging
- VLAN-aware switching
- Broadcast/multicast handling
- Automotive security features

**Performance Targets**:
- Port-to-port latency < 500ns (cut-through)
- MAC table capacity: 1024 entries
- Line-rate forwarding on all ports

## Automotive-Specific Features

### Safety and Security

1. **MAC Address Filtering**
   - Configurable allowed MAC address ranges
   - Protection against unauthorized devices

2. **VLAN Isolation**
   - Strict VLAN membership enforcement
   - Prevention of cross-domain communication

3. **Error Detection and Reporting**
   - Comprehensive error counters
   - Real-time diagnostics capability

### Environmental Robustness

1. **Temperature Compensation**
   - Crystal oscillator compensation (-40°C to +125°C)
   - Adaptive PTP frequency adjustment

2. **Power Management**
   - Wake-on-LAN support for vehicle power states
   - Per-port power control

3. **Fault Tolerance**
   - Graceful degradation under stress
   - Automatic recovery mechanisms

## Traffic Classes and Priorities

| Class | Priority | Application | Latency Req | Bandwidth |
|-------|----------|-------------|-------------|-----------|
| 7 | Highest | Brake-by-Wire | < 500ns | 1 Mbps |
| 6 | High | ADAS Camera | < 2ms | 800 Mbps |
| 5 | Medium-High | Audio/Video | < 10ms | 100 Mbps |
| 4 | Medium | Vehicle Control | < 50ms | 10 Mbps |
| 3 | Medium-Low | Body Control | < 100ms | 5 Mbps |
| 2 | Low | Comfort | < 500ms | 2 Mbps |
| 1 | Lower | Infotainment | Best Effort | 50 Mbps |
| 0 | Lowest | Diagnostics | Best Effort | 1 Mbps |

## Timing Architecture

### Clock Domains

1. **Primary Clock (125 MHz)**
   - System processing and control
   - Gigabit Ethernet operation

2. **High-Speed Clock (200 MHz)**
   - Critical path optimization
   - Precision timing measurements

3. **Slow Clock (25 MHz)**
   - Configuration interface
   - Power management

### Synchronization Requirements

1. **PTP Time Base**
   - 64-bit nanosecond counter
   - Hardware acceleration for timestamp insertion
   - Frequency adjustment capability

2. **TSN Gate Timing**
   - Nanosecond-precision gate control
   - Programmable cycle times (1ms - 1s)
   - Guard band enforcement

## Memory Architecture

### On-Chip Memory

1. **Frame Buffers**
   - 512 entries per port (cut-through/store-forward)
   - Dual-port RAM for simultaneous read/write

2. **MAC Address Table**
   - 1024 entries with hash lookup
   - Aging timer implementation

3. **VLAN Table**
   - 256 VLAN entries
   - Port membership and tagging rules

### External Memory (Optional)

1. **DDR Interface**
   - Large frame buffering capability
   - Statistics and logging storage

## Interface Specifications

### GMII/RGMII (4x ports)

```verilog
// Per-port GMII interface
input  wire       gmii_rx_clk    // 125 MHz receive clock
input  wire       gmii_rx_dv     // Receive data valid
input  wire       gmii_rx_er     // Receive error
input  wire [7:0] gmii_rxd       // Receive data

output wire       gmii_tx_clk    // 125 MHz transmit clock  
output wire       gmii_tx_en     // Transmit enable
output wire       gmii_tx_er     // Transmit error
output wire [7:0] gmii_txd       // Transmit data
```

### Management Interface

```verilog
// SPI-based configuration interface
input  wire       cfg_clk        // Configuration clock
input  wire       cfg_cs_n       // Chip select (active low)
input  wire       cfg_mosi       // Master out, slave in
output wire       cfg_miso       // Master in, slave out
output wire       cfg_int_n      // Interrupt (active low)
```

### Environmental Sensors

```verilog
// Automotive environment monitoring
input  wire [11:0] temp_sensor   // Temperature ADC input
input  wire [11:0] voltage_sensor // Supply voltage ADC input
```

## Performance Optimization

### Pipeline Architecture

1. **Frame Reception Pipeline**
   - Cycle 1: GMII data capture
   - Cycle 2: Frame parsing (DA/SA extraction)
   - Cycle 3: VLAN/EtherType processing
   - Cycle 4: Forwarding decision
   - Cycle 5: Output port selection

2. **Cut-Through Optimization**
   - Decision after 64 bytes received
   - Parallel processing of header and payload
   - Immediate forwarding start

### Resource Utilization

**Target FPGA**: Xilinx Zynq UltraScale+ or Intel Cyclone V

| Resource | Utilization | Purpose |
|----------|-------------|---------|
| LUTs | ~50,000 | Logic implementation |
| BRAMs | ~100 | Frame and table storage |
| DSPs | ~20 | Timestamp and arithmetic |
| I/O | ~80 | GMII interfaces and control |

## Verification Strategy

### Unit Testing
- Individual module verification
- Protocol compliance testing
- Error injection and recovery

### Integration Testing
- Multi-port traffic scenarios
- TSN synchronization verification
- Performance characterization

### Automotive Testing
- Real-world traffic patterns
- Environmental stress testing
- Safety-critical scenario validation

## Standards Compliance

### IEEE 802.1 TSN Standards
- **IEEE 802.1AS-2020**: Timing and Synchronization
- **IEEE 802.1Qbv-2015**: Enhancements for Scheduled Traffic
- **IEEE 802.1Qav-2009**: Forwarding and Queuing for Time-Sensitive Streams
- **IEEE 802.1Qbu-2016**: Frame Preemption

### Automotive Standards
- **ISO 26262**: Functional Safety (ASIL-D capability)
- **ISO 14229**: Unified Diagnostic Services (UDS)
- **AUTOSAR**: Classic Platform compatibility

This architecture provides a robust foundation for automotive networking applications requiring deterministic communication with safety-critical timing guarantees.
