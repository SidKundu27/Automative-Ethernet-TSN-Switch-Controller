# Troubleshooting Guide

## Common Issues and Solutions

### 1. Simulator Not Found Error

**Error:** `vlib: command not found` or `The term 'vlib' is not recognized...`

**Cause:** Required simulator is not installed or not in the system PATH.

**Solutions:**

#### Linux Environment (Restricted Installation)
If you're on a Linux system where you can't install software:

1. **Check available simulators:**
   ```bash
   which iverilog  # Icarus Verilog (most common)
   which xvlog     # Xilinx Vivado Simulator
   which vlog      # ModelSim/QuestaSim
   ```

2. **Use auto-detection:**
   ```bash
   cd scripts
   ./run_simulation.sh compile  # Auto-detects available simulator
   ```

3. **Force specific simulator:**
   ```bash
   # Edit run_simulation.sh and change:
   SIMULATOR="icarus"    # for Icarus Verilog
   SIMULATOR="vivado"    # for Vivado
   ```

#### Available Simulators on Linux:

**Icarus Verilog (iverilog):**
- Usually pre-installed on many Linux systems
- Free and open-source
- Good SystemVerilog 2012 support
- Command: `iverilog -g2012`

**Xilinx Vivado Simulator (xvlog/xsim):**
- Available if Vivado is installed
- Professional-grade simulator
- Excellent SystemVerilog support

#### Windows Environment
1. **Install ModelSim/QuestaSim:**
   - Download Intel ModelSim-Altera Edition (free) or QuestaSim
   - Install following the vendor instructions
   - Add the installation `bin` directory to your system PATH
   - Example path: `C:\intelFPGA\20.1\modelsim_ase\win32aloem`

2. **Use Vivado Simulator instead:**
   ```powershell
   .\run_simulation.ps1 compile -Simulator vivado
   ```

3. **File list generation only:**
   ```powershell
   .\run_simulation.ps1 compile  # Creates file lists without compilation
   ```

### 2. PATH Configuration

#### Windows
**To add ModelSim to PATH:**
1. Open System Properties → Advanced → Environment Variables
2. Edit the `PATH` variable (User or System)
3. Add the ModelSim bin directory (e.g., `C:\intelFPGA\20.1\modelsim_ase\win32aloem`)
4. Restart PowerShell/Command Prompt
5. Test with: `vlog -version`

#### Linux
**To add simulator to PATH (if needed):**
1. Edit your shell profile (~/.bashrc, ~/.zshrc):
   ```bash
   # Add to ~/.bashrc
   export PATH="/path/to/simulator/bin:$PATH"
   ```
2. Reload: `source ~/.bashrc`
3. Test with: `iverilog -V` or `xvlog -version`

**Common simulator locations on Linux:**
- Icarus Verilog: Usually in `/usr/bin/iverilog`
- Vivado: `/tools/Xilinx/Vivado/2023.1/bin/xvlog`
- ModelSim: `/opt/modelsim/bin/vlog`

### 3. PowerShell Execution Policy

**Error:** `Execution of scripts is disabled on this system`

**Solution:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Or run with bypass:
```powershell
powershell -ExecutionPolicy Bypass -File "run_simulation.ps1" help
```

### 4. Missing RTL Files

**Error:** File not found errors during compilation

**Check:**
1. Verify all RTL files exist in the `rtl/` directory
2. Check file paths in the generated `.f` files
3. Ensure proper directory structure

### 5. Vivado Environment Setup

**For Vivado Simulator:**
1. Install Xilinx Vivado (Webpack edition is free)
2. Source the Vivado environment:
   ```bash
   # Windows
   . C:\Xilinx\Vivado\2023.1\settings64.ps1
   
   # Linux
   source /tools/Xilinx/Vivado/2023.1/settings64.sh
   ```
3. Run with Vivado simulator:
   ```bash
   # Linux
   ./run_simulation.sh compile
   
   # Windows
   .\run_simulation.ps1 compile -Simulator vivado
   ```

### 6. Icarus Verilog Specific Issues

**Installation on Linux (if not available):**
```bash
# Ubuntu/Debian
sudo apt-get install iverilog

# CentOS/RHEL
sudo yum install iverilog

# From source (if package manager restricted)
# Contact your system administrator
```

**Common Icarus Verilog Issues:**
1. **SystemVerilog 2012 support:** Use `-g2012` flag
2. **Include paths:** Use `-I` for include directories
3. **Output files:** `.vvp` files are compiled output
4. **Running simulation:** Use `vvp filename.vvp`

**Example manual compilation with Icarus:**
```bash
cd scripts/work
iverilog -g2012 -I../rtl -f rtl_files.f ../testbench/unit/tb_automotive_eth_mac.v -o test.vvp
vvp test.vvp
```

## Alternative Approaches

### 1. Manual Compilation

If automated scripts fail, you can manually compile:

**Icarus Verilog:**
```bash
cd scripts/work
# Compile RTL only
iverilog -g2012 -I../rtl -f rtl_files.f -o rtl.vvp

# Compile with testbench
iverilog -g2012 -I../rtl -I../testbench -f rtl_files.f ../testbench/unit/tb_automotive_eth_mac.v -o test.vvp

# Run simulation
vvp test.vvp
```

**ModelSim:**
```bash
cd scripts/work
vlib work
vlog -f rtl_files.f
vlog -f tb_files.f
```

**Vivado:**
```bash
cd scripts/work
xvlog -f rtl_files.f
xvlog -f tb_files.f
```

### 2. Using Only File Lists

The scripts generate proper file lists even without simulators:
- `scripts/work/rtl_files.f` - RTL compilation order
- `scripts/work/tb_files.f` - Testbench files

These can be imported into any HDL simulator or synthesis tool.

### 3. FPGA Vendor Tools

**Vivado Project:**
1. Create new RTL project in Vivado
2. Add files from `rtl_files.f`
3. Set `automotive_tsn_switch_top.v` as top module

**Quartus Project:**
1. Create new project in Quartus
2. Add files from `rtl_files.f`
3. Set `automotive_tsn_switch_top` as top entity

## Getting Help

1. **Script Help:**
   ```powershell
   .\run_simulation.ps1 help
   ```

2. **Available Actions:**
   - `compile` - File list generation and compilation check
   - `clean` - Clean work directory
   - `help` - Show detailed help

3. **Simulator Detection:**
   The script automatically detects available simulators and provides
   installation instructions if none are found.

## Project Status

With the current fixes:
- ✅ Scripts handle missing simulators gracefully
- ✅ Proper error messages and installation guidance
- ✅ File list generation works without simulators
- ✅ Cross-platform support (PowerShell + Bash + Batch)
- ✅ Comprehensive documentation

The project is ready for development with or without simulation tools installed.
