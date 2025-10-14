#!/usr/bin/env bash
# Stop a QEMU test VM
# Usage: ./stop-vm.sh <hostname>

HOSTNAME="${1:-griefling}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PID_FILE="$REPO_ROOT/quickemu/${HOSTNAME}-test.pid"

if [ ! -f "$PID_FILE" ]; then
    echo "No $HOSTNAME VM running (no PID file found)"
    exit 1
fi

PID=$(cat "$PID_FILE")
if ps -p "$PID" > /dev/null 2>&1; then
    echo "Stopping $HOSTNAME VM (PID: $PID)..."
    kill "$PID"
    sleep 2
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "Force killing VM..."
        kill -9 "$PID"
    fi
    rm -f "$PID_FILE"
    echo "✅ VM stopped"
else
    echo "VM is not running (stale PID file)"
    rm -f "$PID_FILE"
fi
