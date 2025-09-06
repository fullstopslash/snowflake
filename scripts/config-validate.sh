#!/usr/bin/env sh
set -eu

# scripts/config-validate.sh HOSTNAME
# Runs formatter, linters, flake check, and evaluates the host build attr

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT="$SCRIPT_DIR/.."
cd "$REPO_ROOT"

RAW_HOST="${1:-malphas}"
# Support both "host=malphas" and "malphas"
HOSTNAME="${RAW_HOST#host=}"

printf "%s\n" "[validate] Formatting Nix files (alejandra)"
alejandra .

printf "%s\n" "[validate] Running statix and deadnix"
statix check
deadnix

printf "%s\n" "[validate] nix flake check"
nix flake check

printf "%s\n" "[validate] Evaluating host drvPath: .#nixosConfigurations.%s.config.system.build.toplevel" "$HOSTNAME"
nix eval \
  ".#nixosConfigurations.${HOSTNAME}.config.system.build.toplevel.drvPath"

printf "%s\n" "[validate] Done."
