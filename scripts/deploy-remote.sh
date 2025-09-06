#!/usr/bin/env sh
set -eu

if [ "$#" -lt 2 ]; then
  printf "%s\n" "Usage: $0 <user@host> <hostname> [--disk <disk>] [--flake <flakeRef>]" 1>&2
  exit 1
fi

TARGET="$1"; shift
HOSTNAME="$1"; shift
DISK="/dev/sda"
FLAKE_REF=".#$HOSTNAME"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --disk)
      DISK="$2"; shift 2 ;;
    --flake)
      FLAKE_REF="$2"; shift 2 ;;
    *) printf "%s\n" "Unknown arg: $1" 1>&2; exit 1 ;;
  esac
done

printf "%s\n" "Deploying $FLAKE_REF to $TARGET (disk: $DISK)"

# Ensure nixos-anywhere is available
if ! command -v nixos-anywhere >/dev/null 2>&1; then
  nix run github:nix-community/nixos-anywhere -- --help >/dev/null 2>&1 || true
fi

nix run github:nix-community/nixos-anywhere -- --flake "$FLAKE_REF" "$TARGET" --disk "$DISK"

