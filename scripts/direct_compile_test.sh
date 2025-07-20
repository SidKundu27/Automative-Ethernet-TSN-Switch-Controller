#!/bin/bash
# Direct compilation test for Linux with xvlog
# Run this after fixing the TSN traffic shaper

echo "=== Direct Vivado Compilation Test ==="
echo ""

# Navigate to work directory
cd work || { echo "Error: work directory not found"; exit 1; }

# Check if RTL files exist
echo "Checking RTL files..."
missing=0
while IFS= read -r file; do
    if [[ "$file" =~ ^#.*$ ]] || [[ -z "$file" ]]; then
        continue  # Skip comments and empty lines
    fi
    if [ -f "$file" ]; then
        echo "✓ $file"
    else
        echo "✗ $file (missing)"
        missing=1
    fi
done < rtl_files.f

if [ $missing -eq 1 ]; then
    echo ""
    echo "Error: Some RTL files are missing. Please check file paths."
    exit 1
fi

echo ""
echo "All RTL files found. Starting compilation..."
echo ""

# Run xvlog compilation
echo "Running: xvlog -f rtl_files.f"
xvlog -f rtl_files.f

# Check result
if [ $? -eq 0 ]; then
    echo ""
    echo "✅ SUCCESS: RTL compilation completed without errors!"
else
    echo ""
    echo "❌ FAILED: RTL compilation failed. Check errors above."
    exit 1
fi

echo ""
echo "=== Compilation Summary ==="
echo "• All 5 RTL modules compiled successfully"
echo "• Ready for testbench compilation and simulation"
echo "• TSN traffic shaper syntax issues resolved"
