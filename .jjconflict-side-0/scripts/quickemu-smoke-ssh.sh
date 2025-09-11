#!/usr/bin/env sh
set -eu

HOST="127.0.0.1"
PORT="2222"

printf "%s\n" "Waiting for sshd to listen on $HOST:$PORT ..."
i=0
while :; do
  if command -v nc >/dev/null 2>&1 && nc -z "$HOST" "$PORT" 2>/dev/null; then
    break
  fi
  i=$((i+1))
  if [ "$i" -gt 120 ]; then
    printf "%s\n" "Timeout waiting for sshd port"
    exit 1
  fi
  sleep 2
done

printf "%s\n" "Boot smoke test passed: sshd is listening on $HOST:$PORT"

