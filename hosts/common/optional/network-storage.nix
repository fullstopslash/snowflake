# Network storage optional module
#
# Enables NFS mounts for LAN storage access from waterbug.lan:
# - /storage - Main storage pool
# - /mnt/apps - Applications and shared software
#
# Uses systemd automount to avoid boot delays when storage server is unavailable.
#
# Import this module in your host configuration to enable network storage.
{ ... }:
{
  services.networkStorage.enable = true;
}
