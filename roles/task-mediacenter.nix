# Mediacenter role - media consumption environment (composable task role)
#
# Can be combined with any hardware role: roles.desktop + roles.mediacenter
# Adds media modules to existing selection
#
# This is a task-based role, not mutually exclusive with hardware roles.
{ config, lib, ... }:
let
  cfg = config.roles;
in
{
  config = lib.mkIf cfg.mediacenter {
    # ========================================
    # MODULE SELECTIONS (additive)
    # ========================================
    modules = {
      apps = lib.mkDefault [ "media" ];
      audio = lib.mkDefault [ "pipewire" "easyeffects" ];
    };
  };
}
