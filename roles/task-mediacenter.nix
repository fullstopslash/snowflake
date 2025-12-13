# Mediacenter role - media consumption environment (composable task role)
#
# Can be combined with any hardware role: roles.desktop + roles.mediacenter
# Adds media modules to existing selection
#
# This is a task-based role, not mutually exclusive with hardware roles.
{ config, lib, ... }:
{
  config = lib.mkIf (builtins.elem "mediacenter" config.roles) {
    # ========================================
    # MODULE SELECTIONS (additive)
    # ========================================
    modules = {
      apps = [ "media" ];
      audio = [
        "pipewire"
        "easyeffects"
      ];
    };
  };
}
