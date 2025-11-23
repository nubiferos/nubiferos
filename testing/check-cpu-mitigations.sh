#!/bin/bash
# Check CPU security vulnerability mitigations

echo "=========================================="
echo "CPU Security Mitigation Status"
echo "=========================================="
echo ""

echo "1. CPU Information:"
echo "-------------------"
lscpu | grep -E "Model name|Vendor ID|CPU family|Model:|Stepping"
echo ""

echo "2. Vulnerability Status:"
echo "------------------------"
if [ -d /sys/devices/system/cpu/vulnerabilities ]; then
    for vuln in /sys/devices/system/cpu/vulnerabilities/*; do
        name=$(basename "$vuln")
        status=$(cat "$vuln")
        
        # Color code the output
        if echo "$status" | grep -qi "not affected"; then
            echo "✓ $name: $status"
        elif echo "$status" | grep -qi "vulnerable"; then
            echo "✗ $name: $status"
        elif echo "$status" | grep -qi "mitigation"; then
            echo "⚠ $name: $status"
        else
            echo "  $name: $status"
        fi
    done
else
    echo "Vulnerability information not available"
fi

echo ""
echo "3. Active Kernel Parameters:"
echo "----------------------------"
cat /proc/cmdline | tr ' ' '\n' | grep -E "retbleed|mitigation|spectre|mds|tsx|noibrs|noibpb"
if [ $? -ne 0 ]; then
    echo "(No specific mitigation parameters set - using defaults)"
fi

echo ""
echo "4. Detailed RETBleed Status:"
echo "----------------------------"
if [ -f /sys/devices/system/cpu/vulnerabilities/retbleed ]; then
    cat /sys/devices/system/cpu/vulnerabilities/retbleed
else
    echo "RETBleed status not available"
fi

echo ""
echo "5. Spectre v2 Status:"
echo "---------------------"
if [ -f /sys/devices/system/cpu/vulnerabilities/spectre_v2 ]; then
    cat /sys/devices/system/cpu/vulnerabilities/spectre_v2
else
    echo "Spectre v2 status not available"
fi

echo ""
echo "6. Boot Messages (RETBleed related):"
echo "-------------------------------------"
dmesg | grep -i retbleed | head -10
if [ $? -ne 0 ]; then
    echo "(No RETBleed messages in dmesg)"
fi

echo ""
echo "7. Recommendations:"
echo "-------------------"

# Check if RETBleed is vulnerable
if [ -f /sys/devices/system/cpu/vulnerabilities/retbleed ]; then
    retbleed_status=$(cat /sys/devices/system/cpu/vulnerabilities/retbleed)
    
    if echo "$retbleed_status" | grep -qi "vulnerable"; then
        echo "⚠️  Your CPU is vulnerable to RETBleed attacks"
        echo ""
        echo "Options:"
        echo "  1. Accept the risk (recommended for most users)"
        echo "     - Performance: Best"
        echo "     - Security: Partial (Spectre v2 still mitigated)"
        echo ""
        echo "  2. Enable full mitigation (recommended for high-security)"
        echo "     - Add 'retbleed=auto' to kernel parameters"
        echo "     - Performance: 15-30% reduction"
        echo "     - Security: Full protection"
        echo ""
        echo "See docs/CPU_SECURITY_MITIGATIONS.md for details"
    elif echo "$retbleed_status" | grep -qi "not affected"; then
        echo "✓ Your CPU is not affected by RETBleed"
    elif echo "$retbleed_status" | grep -qi "mitigation"; then
        echo "✓ RETBleed mitigation is active"
    fi
fi

echo ""
echo "=========================================="
echo ""
echo "For more information:"
echo "  - docs/CPU_SECURITY_MITIGATIONS.md"
echo "  - https://www.kernel.org/doc/html/latest/admin-guide/hw-vuln/"
echo ""
