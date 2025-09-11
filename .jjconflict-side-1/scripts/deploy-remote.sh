#!/usr/bin/env sh
set -eu

if [ "$#" -lt 2 ]; then
  printf "%s\n" "Usage: $0 <user@host> <hostname> [--disk <disk>] [--flake <flakeRef>] [--push-age-key] [--age-key <path>]" 1>&2
  exit 1
fi

TARGET="$1"; shift
HOSTNAME="$1"; shift
DISK="/dev/sda"
FLAKE_REF=".#$HOSTNAME"
PUSH_AGE_KEY=false
AGE_KEY_PATH=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --disk)
      DISK="$2"; shift 2 ;;
    --flake)
      FLAKE_REF="$2"; shift 2 ;;
    --push-age-key)
      PUSH_AGE_KEY=true; shift 1 ;;
    --age-key)
      AGE_KEY_PATH="$2"; shift 2 ;;
    *) printf "%s\n" "Unknown arg: $1" 1>&2; exit 1 ;;
  esac
done

printf "%s\n" "Deploying $FLAKE_REF to $TARGET (disk: $DISK)"

# Stage optional bootstrap age key for sops-nix
EXTRA_ARG=""
TMPDIR_STAGE=""
if [ "$PUSH_AGE_KEY" = true ]; then
  # Determine source key: explicit path, or user's default, or generate transient
  SRC_KEY=""
  if [ -n "$AGE_KEY_PATH" ] && [ -f "$AGE_KEY_PATH" ]; then
    SRC_KEY="$AGE_KEY_PATH"
  elif [ -f "$HOME/.config/sops/age/keys.txt" ]; then
    SRC_KEY="$HOME/.config/sops/age/keys.txt"
  fi

  TMPDIR_STAGE=$(mktemp -d 2>/dev/null || mktemp -d -t na_stage)
  mkdir -p "$TMPDIR_STAGE/var/lib/sops-nix"

  if [ -n "$SRC_KEY" ]; then
    cp "$SRC_KEY" "$TMPDIR_STAGE/var/lib/sops-nix/key.txt"
  else
    # Generate a fresh bootstrap key
    age-keygen -o "$TMPDIR_STAGE/var/lib/sops-nix/key.txt"
  fi
  chmod 600 "$TMPDIR_STAGE/var/lib/sops-nix/key.txt"
  EXTRA_ARG="--extra-files $TMPDIR_STAGE"
fi

# Ensure nixos-anywhere is available
if ! command -v nixos-anywhere >/dev/null 2>&1; then
  nix run github:nix-community/nixos-anywhere -- --help >/dev/null 2>&1 || true
fi

nix run github:nix-community/nixos-anywhere -- --flake "$FLAKE_REF" --copy-host-keys $EXTRA_ARG "$TARGET" --disk "$DISK"

# Cleanup staging dir
if [ -n "$TMPDIR_STAGE" ] && [ -d "$TMPDIR_STAGE" ]; then
  rm -rf "$TMPDIR_STAGE"
fi

