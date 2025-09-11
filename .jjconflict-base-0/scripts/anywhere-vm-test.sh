#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/.."

HOSTNAME="${1:-malphas}"

printf "%s\n" "Running nixos-anywhere --vm-test for .#$HOSTNAME (verbose)"
nix run github:nix-community/nixos-anywhere -- --verbose --debug --flake .#"$HOSTNAME" --vm-test

