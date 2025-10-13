#!/usr/bin/env bash
# Stop the griefling test VM

if [ ! -f "./griefling-test.pid" ]; then
    echo "No griefling VM running (no PID file found)"
    exit 1
fi

PID=$(cat ./griefling-test.pid)
if ps -p "$PID" > /dev/null 2>&1; then
    echo "Stopping griefling VM (PID: $PID)..."
    kill "$PID"
    sleep 2
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "Force killing VM..."
        kill -9 "$PID"
    fi
    rm -f ./griefling-test.pid
    echo "VM stopped"
else
    echo "VM is not running (stale PID file)"
    rm -f ./griefling-test.pid
fi
