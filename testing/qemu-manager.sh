#!/bin/bash
# QEMU Process Manager - Find, list, and kill QEMU instances

set -e

show_help() {
    cat << EOF
QEMU Process Manager

Usage: $0 [command]

Commands:
    list, ls        List all running QEMU processes
    kill [PID]      Kill specific QEMU process by PID
    killall         Kill all QEMU processes
    locks           Show files locked by QEMU
    help            Show this help message

Examples:
    $0 list                 # Show all QEMU processes
    $0 kill 12345          # Kill QEMU process with PID 12345
    $0 killall             # Kill all QEMU processes
    $0 locks               # Show what files QEMU has locked

EOF
}

list_qemu() {
    echo "=========================================="
    echo "Running QEMU Processes"
    echo "=========================================="
    
    if pgrep -a qemu-system > /dev/null 2>&1; then
        echo ""
        ps aux | head -1
        ps aux | grep qemu-system | grep -v grep
        echo ""
        echo "To kill a process: $0 kill <PID>"
        echo "To kill all: $0 killall"
    else
        echo ""
        echo "No QEMU processes found"
        echo ""
    fi
}

kill_process() {
    local PID=$1
    
    if [ -z "$PID" ]; then
        echo "Error: Please provide a PID"
        echo "Usage: $0 kill <PID>"
        exit 1
    fi
    
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "Killing QEMU process $PID..."
        kill "$PID" 2>/dev/null || kill -9 "$PID" 2>/dev/null
        sleep 1
        
        if ps -p "$PID" > /dev/null 2>&1; then
            echo "Process still running, force killing..."
            kill -9 "$PID"
        fi
        
        echo "Process $PID terminated"
    else
        echo "Process $PID not found"
    fi
}

killall_qemu() {
    echo "Killing all QEMU processes..."
    
    if pgrep qemu-system > /dev/null 2>&1; then
        pkill qemu-system 2>/dev/null || true
        sleep 1
        
        # Force kill if still running
        if pgrep qemu-system > /dev/null 2>&1; then
            echo "Some processes still running, force killing..."
            pkill -9 qemu-system 2>/dev/null || true
        fi
        
        echo "All QEMU processes terminated"
    else
        echo "No QEMU processes found"
    fi
}

show_locks() {
    echo "=========================================="
    echo "Files Locked by QEMU"
    echo "=========================================="
    echo ""
    
    if pgrep qemu-system > /dev/null 2>&1; then
        for pid in $(pgrep qemu-system); do
            echo "Process $pid:"
            lsof -p "$pid" 2>/dev/null | grep -E "\.iso|\.qcow2|\.img" || echo "  No disk images locked"
            echo ""
        done
    else
        echo "No QEMU processes found"
        echo ""
    fi
}

# Main command handling
case "${1:-list}" in
    list|ls)
        list_qemu
        ;;
    kill)
        kill_process "$2"
        ;;
    killall)
        killall_qemu
        ;;
    locks)
        show_locks
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
