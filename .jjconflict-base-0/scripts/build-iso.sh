#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/.."

printf "%s\n" "Building ISO: .#iso-installer"
nix build .#iso-installer

ISO_PATH=$(readlink -f ./result/iso/*.iso 2>/dev/null || true)
if [ -n "$ISO_PATH" ]; then
  printf "%s\n" "Built ISO: $ISO_PATH"
else
  printf "%s\n" "ISO build completed, symlink ./result created. Inspect ./result for outputs." 1>&2
fi

