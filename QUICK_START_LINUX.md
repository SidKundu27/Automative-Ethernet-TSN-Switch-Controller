# Quick Start Guide - Linux Environment

Since you have `iverilog` (Icarus Verilog) and `xvlog` (Xilinx Vivado) available on your Linux system, here's how to get started:

# Quick Start Guide - Linux Environment

Since you have `xvlog` (Xilinx Vivado) available on your Linux system, here's how to get started:

## Option 1: Direct Compilation Test (Recommended)

```bash
cd scripts
chmod +x direct_compile_test.sh
./direct_compile_test.sh
```

This script:
- Checks all RTL files exist
- Runs `xvlog -f rtl_files.f` 
- Provides clear success/failure feedback
- Works around script detection issues

## Option 2: Using the Test Script

```bash
cd scripts
chmod +x test_linux_compile.sh
./test_linux_compile.sh
```

This will test file paths and attempt Vivado compilation.

## Option 3: Manual Compilation with Vivado

```bash
cd scripts
mkdir -p work
cd work

# Create file list with correct paths
cat > rtl_files.f << EOF
../../rtl/mac/automotive_eth_mac.v
../../rtl/ptp/ptp_sync_engine.v
../../rtl/tsn/tsn_traffic_shaper.v
../../rtl/switch/switching_matrix.v
../../rtl/top/automotive_tsn_switch_top.v
EOF

# Verify files exist
echo "Checking RTL files..."
for file in $(cat rtl_files.f); do
    if [ -f "$file" ]; then
        echo "✓ Found: $file"
    else
        echo "✗ Missing: $file"
    fi
done

# Source Vivado environment (adjust path as needed)
source /tools/Xilinx/Vivado/2023.1/settings64.sh

# Compile with Vivado
xvlog -f rtl_files.f
```

## Recent Fixes Applied

The compilation errors you encountered have been fixed:

✅ **TSN Traffic Shaper Syntax Issues:**
- Converted SystemVerilog array ports to packed vectors
- Fixed `for (integer ...)` declarations (moved to module scope)
- Removed `wire` declarations inside `always` blocks
- Added proper array packing/unpacking logic

✅ **File Path Issues:**
- Updated file lists to use correct relative paths (`../../rtl/...`)
- Fixed include path handling for Vivado compilation

## Key Differences Between Simulators

### Icarus Verilog (iverilog)
- **Pros:** Free, open-source, widely available, good SystemVerilog support
- **Cons:** Some advanced SystemVerilog features may not be supported
- **Output:** Generates `.vvp` files, run with `vvp filename.vvp`
- **Flags:** Use `-g2012` for SystemVerilog 2012 support

### Vivado Simulator (xvlog/xsim)  
- **Pros:** Professional-grade, excellent SystemVerilog support, timing-accurate
- **Cons:** Requires Vivado installation, larger footprint
- **Output:** Uses compiled libraries, run with `xsim`

## File Structure After Compilation

```
scripts/work/
├── rtl_files.f          # RTL file list (auto-generated)
├── tb_files.f           # Testbench file list (auto-generated)
├── *.vvp                # Icarus compiled files
└── automotive_test_results.log  # Test results
```

## What to Expect

1. **Compilation:** Should complete without errors if all RTL files are present
2. **Simulation:** Will run testbenches and show results
3. **Logs:** Check `automotive_test_results.log` for detailed test results
4. **Waveforms:** Icarus can generate VCD files for waveform viewing

## Troubleshooting Your Linux Environment

If you get errors:

1. **Check simulator availability:**
   ```bash
   which iverilog
   which xvlog
   ```

2. **Check SystemVerilog support:**
   ```bash
   iverilog -V  # Should show version info
   ```

3. **If simulators are in unusual locations:**
   Edit the `run_simulation.sh` script and modify the detection function.

4. **Permission issues:**
   ```bash
   chmod +x run_simulation.sh
   ```

The automotive TSN switch RTL is designed to be portable across simulators, so either Icarus Verilog or Vivado should work fine for development and verification.
