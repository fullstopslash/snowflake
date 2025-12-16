#!/usr/bin/env bash
set -euo pipefail

HOSTNAME="${1:-}"
if [ -z "$HOSTNAME" ]; then
	echo "Usage: install-host <hostname>"
	echo "Available hosts:"
	# shellcheck disable=SC2010
	ls /etc/nixos-config/hosts/ | grep -v TEMPLATE | grep -v template | grep -v iso
	exit 1
fi

echo "Installing host: $HOSTNAME"
echo "This will:"
echo "  1. Partition and format disks with disko"
echo "  2. Install NixOS configuration"
echo "  3. Reboot (secrets must be bootstrapped after first boot)"
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
	exit 1
fi

nixos-install --flake "/etc/nixos-config#${HOSTNAME}" --no-root-password

echo ""
echo "Installation complete!"
echo "After reboot, run: /path/to/nix-config/scripts/bootstrap-secrets.sh $HOSTNAME"
