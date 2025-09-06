#!/usr/bin/env sh

# POSIX helper to partition with Disko and run nixos-install for a host
# Usage:
#   install_host <hostname> [flake_root]
# If flake_root is omitted, this tries the current directory if it contains
# a flake, otherwise falls back to /home/nixos/nix.

set -eu

print_usage() {
  printf '%s\n' "Usage: install_host <hostname> [flake_root]" >&2
}

detect_flake_root() {
  if [ -f "flake.nix" ]; then
    printf '%s' "$(pwd)"
    return 0
  fi
  if [ -d "/home/nixos/nix" ] && [ -f "/home/nixos/nix/flake.nix" ]; then
    printf '%s' "/home/nixos/nix"
    return 0
  fi
  return 1
}

install_host() {
  if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    print_usage
    return 2
  fi

  HOSTNAME=$1
  if [ $# -eq 2 ]; then
    FLAKE_ROOT=$2
  else
    if ! FLAKE_ROOT=$(detect_flake_root); then
      printf '%s\n' "Error: could not detect flake root; pass it explicitly." >&2
      return 2
    fi
  fi

  if [ ! -f "$FLAKE_ROOT/hosts/$HOSTNAME/disko-config.nix" ]; then
    printf '%s\n' "Error: missing $FLAKE_ROOT/hosts/$HOSTNAME/disko-config.nix" >&2
    return 2
  fi

  printf '%s\n' "[1/2] Running Disko for host ${HOSTNAME}..."
  nix run github:nix-community/disko -- \
    --mode disko \
    --mountpoint /mnt \
    "$FLAKE_ROOT/hosts/$HOSTNAME/disko-config.nix"

  printf '%s\n' "[2/2] Running nixos-install for ${HOSTNAME}..."
  nixos-install --no-root-passwd --flake "$FLAKE_ROOT#$HOSTNAME"

  printf '%s\n' "Done. You can now reboot or power off." 
}

# Allow running directly: scripts/install-host.sh vmtest [/path/to/flake]
if [ "${1-}" != """" ]; then
  install_host "$@"
fi


