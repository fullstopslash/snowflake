# Syncthing - continuous file synchronization
#
# This is a thin wrapper that enables the syncthing module.
# For configuration details, see modules/services/networking/syncthing.nix
{
  ...
}:
{
  myModules.services.syncthing.enable = true;
}
