#!/usr/bin/env sh
set -eu

# scripts/post-deploy-verify.sh HOST
# Performs basic post-deployment checks on a remote NixOS host via SSH.
# Example:
#   ./scripts/post-deploy-verify.sh root@malphas

if [ "${1:-}" = "" ]; then
  printf "%s\n" "usage: $0 <ssh-host>"
  exit 2
fi

SSH_HOST="$1"
SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=10"

fail() {
  printf "%s\n" "FAIL: $1"
  exit 1
}

pass() {
  printf "%s\n" "PASS: $1"
}

printf "%s\n" "[verify] Connecting to $SSH_HOST"

REMOTE_SCRIPT='set -eu
printf "%s\n" "host: $(hostname)"
printf "%s\n" "nixos-version: $(nixos-version || true)"
printf "%s\n" "kernel: $(uname -sr)"

# core units
systemctl is-active multi-user.target >/dev/null 2>&1 || { echo "multi-user.target inactive"; exit 10; }
systemctl is-active sshd >/dev/null 2>&1 || { echo "sshd inactive"; exit 11; }

# store and generation sanity
mount | grep " on /nix/store " >/dev/null 2>&1 || { echo "/nix/store not mounted"; exit 12; }
current_gen=$(readlink -f /run/current-system || true)
[ -n "$current_gen" ] || { echo "/run/current-system missing"; exit 13; }

# show last 3 system generations to confirm a new one just activated
if [ -x /nix/var/nix/profiles/system/bin/switch-to-configuration ] || [ -e /nix/var/nix/profiles/system ]; then
  nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -n 3 || true
fi

# network sanity (non-fatal)
if command -v ip >/dev/null 2>&1; then
  ip -o -4 addr show | awk "{print \$2, \$4}" || true
fi
'

if ! ssh $SSH_OPTS "$SSH_HOST" "$REMOTE_SCRIPT"; then
  fail "remote verification checks failed"
fi

pass "remote verification checks passed"
