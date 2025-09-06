#!/usr/bin/env sh

set -e

OUT_DIR="/tmp/boot-report"
mkdir -p "$OUT_DIR"

printf 'Generating systemd-analyze reports in %s\n' "$OUT_DIR"

if command -v systemd-analyze >/dev/null 2>&1; then
  systemd-analyze blame > "$OUT_DIR/blame.txt" || true
  systemd-analyze critical-chain > "$OUT_DIR/critical-chain.txt" || true
  systemd-analyze time > "$OUT_DIR/time.txt" || true
  systemd-analyze plot > "$OUT_DIR/boot.svg" || true
  printf 'Done. Open %s to review.\n' "$OUT_DIR"
else
  printf 'systemd-analyze not found.\n'
fi


