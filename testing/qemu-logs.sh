#!/bin/bash
# QEMU Log Viewer - View and share QEMU logs

show_help() {
    cat << EOF
QEMU Log Viewer

Usage: $0 [command]

Commands:
    list            List all available log files
    latest          Show the most recent log file
    view [file]     View a specific log file
    tail [file]     Follow a log file in real-time
    errors [file]   Show only errors from a log file
    share [file]    Prepare log for sharing (last 200 lines)
    clean           Remove old log files (keep last 5)
    help            Show this help message

Examples:
    $0 list                              # List all logs
    $0 latest                            # View most recent log
    $0 view logs/qemu/boot_20231123.log  # View specific log
    $0 errors                            # Show errors from latest log
    $0 share                             # Prepare latest log for sharing

Log locations:
    - QEMU boot logs: logs/qemu/boot_*.log
    - VNC serial logs: /tmp/qemu-serial.log

EOF
}

list_logs() {
    echo "=========================================="
    echo "Available QEMU Logs"
    echo "=========================================="
    echo ""
    
    local found=0
    
    # Check /tmp for qemu-boot logs
    if ls /tmp/qemu-boot_*.log >/dev/null 2>&1; then
        echo "Boot logs (/tmp/):"
        ls -lh /tmp/qemu-boot_*.log 2>/dev/null | awk '{print "  " $9 " (" $5 ", " $6 " " $7 ")"}'
        echo ""
        found=1
    fi
    
    # Check logs/qemu
    if [ -d logs/qemu ] && [ "$(ls -A logs/qemu 2>/dev/null)" ]; then
        echo "Boot logs (logs/qemu/):"
        ls -lh logs/qemu/*.log 2>/dev/null | awk '{print "  " $9 " (" $5 ", " $6 " " $7 ")"}'
        echo ""
        found=1
    fi
    
    # Check VNC serial log
    if [ -f /tmp/qemu-serial.log ]; then
        echo "VNC serial log:"
        ls -lh /tmp/qemu-serial.log | awk '{print "  " $9 " (" $5 ", " $6 " " $7 ")"}'
        echo ""
        found=1
    fi
    
    if [ $found -eq 0 ]; then
        echo "No QEMU logs found"
        echo ""
        echo "Run QEMU with logging first:"
        echo "  ./testing/qemu-with-logging.sh iso/NubiferOS-1.0-amd64.iso"
        echo ""
    fi
}

get_latest_log() {
    local latest=""
    
    # Check /tmp for qemu-boot logs first
    latest=$(ls -t /tmp/qemu-boot_*.log 2>/dev/null | head -1)
    
    # Fall back to logs/qemu if exists
    if [ -z "$latest" ] && [ -d logs/qemu ]; then
        latest=$(ls -t logs/qemu/*.log 2>/dev/null | head -1)
    fi
    
    # Fall back to /tmp/qemu-serial.log (VNC logs)
    if [ -z "$latest" ] && [ -f /tmp/qemu-serial.log ]; then
        latest="/tmp/qemu-serial.log"
    fi
    
    echo "$latest"
}

view_log() {
    local logfile="${1:-$(get_latest_log)}"
    
    if [ -z "$logfile" ]; then
        echo "No log files found"
        echo "Run QEMU with logging first:"
        echo "  ./testing/qemu-with-logging.sh"
        return 1
    fi
    
    if [ ! -f "$logfile" ]; then
        echo "Log file not found: $logfile"
        return 1
    fi
    
    echo "=========================================="
    echo "Log: $logfile"
    echo "=========================================="
    echo ""
    cat "$logfile"
}

tail_log() {
    local logfile="${1:-$(get_latest_log)}"
    
    if [ -z "$logfile" ]; then
        echo "No log files found"
        return 1
    fi
    
    if [ ! -f "$logfile" ]; then
        echo "Log file not found: $logfile"
        return 1
    fi
    
    echo "Following log: $logfile"
    echo "Press Ctrl+C to stop"
    echo ""
    tail -f "$logfile"
}

show_errors() {
    local logfile="${1:-$(get_latest_log)}"
    
    if [ -z "$logfile" ]; then
        echo "No log files found"
        return 1
    fi
    
    if [ ! -f "$logfile" ]; then
        echo "Log file not found: $logfile"
        return 1
    fi
    
    echo "=========================================="
    echo "Errors in: $logfile"
    echo "=========================================="
    echo ""
    
    if grep -i "error\|fail\|fatal\|panic" "$logfile" > /dev/null 2>&1; then
        grep -i "error\|fail\|fatal\|panic" "$logfile"
    else
        echo "No errors found"
    fi
}

share_log() {
    local logfile="${1:-$(get_latest_log)}"
    
    if [ -z "$logfile" ]; then
        echo "No log files found"
        return 1
    fi
    
    if [ ! -f "$logfile" ]; then
        echo "Log file not found: $logfile"
        return 1
    fi
    
    echo "=========================================="
    echo "Log excerpt for sharing: $logfile"
    echo "=========================================="
    echo ""
    echo "Last 200 lines:"
    echo ""
    tail -n 200 "$logfile"
    echo ""
    echo "=========================================="
    echo "End of log excerpt"
    echo "=========================================="
}

clean_logs() {
    if [ ! -d logs/qemu ]; then
        echo "No logs directory found"
        return
    fi
    
    local count=$(ls logs/qemu/*.log 2>/dev/null | wc -l)
    
    if [ "$count" -le 5 ]; then
        echo "Only $count log files found, keeping all"
        return
    fi
    
    echo "Found $count log files, keeping 5 most recent..."
    
    ls -t logs/qemu/*.log | tail -n +6 | while read file; do
        echo "  Removing: $file"
        rm "$file"
    done
    
    echo "Done"
}

# Main command handling
case "${1:-latest}" in
    list|ls)
        list_logs
        ;;
    latest)
        view_log
        ;;
    view)
        view_log "$2"
        ;;
    tail|follow)
        tail_log "$2"
        ;;
    errors|err)
        show_errors "$2"
        ;;
    share)
        share_log "$2"
        ;;
    clean)
        clean_logs
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
