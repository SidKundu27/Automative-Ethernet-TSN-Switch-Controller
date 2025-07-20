#!/bin/bash
# Simple test script for Linux environment with xvlog
# Use this if the main script has issues

echo "Testing Vivado compilation on Linux..."

# Create work directory
mkdir -p work
cd work

# Create correct file list for Linux
cat > rtl_files.f << EOF
# RTL Files
../../rtl/mac/automotive_eth_mac.v
../../rtl/ptp/ptp_sync_engine.v
../../rtl/tsn/tsn_traffic_shaper.v
../../rtl/switch/switching_matrix.v
../../rtl/top/automotive_tsn_switch_top.v
EOF

# Check if files exist
echo "Checking if RTL files exist..."
for file in $(cat rtl_files.f | grep -v "#"); do
    if [ -f "$file" ]; then
        echo "✓ Found: $file"
    else
        echo "✗ Missing: $file"
    fi
done

# Test xvlog compilation
echo ""
echo "Testing Vivado compilation..."
if command -v xvlog >/dev/null 2>&1; then
    echo "Found xvlog, attempting compilation..."
    xvlog -f rtl_files.f
    echo "Compilation result: $?"
else
    echo "xvlog not found. Make sure Vivado environment is sourced:"
    echo "source /tools/Xilinx/Vivado/2023.1/settings64.sh"
fi

cd ..
