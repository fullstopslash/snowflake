# Development role - development environment (composable task role)
#
# Can be combined with any hardware role: roles.laptop + roles.development
# Adds development modules to existing selection
#
# This is a task-based role, not mutually exclusive with hardware roles.
{ config, lib, ... }:
{
  config = lib.mkIf (builtins.elem "development" config.roles) {
    # ========================================
    # MODULE SELECTIONS (additive)
    # ========================================
    # Paths mirror filesystem: modules/<top>/<category> = [ "<module>" ]
    modules = {
      apps = {
        development = [
          "latex"
          "document-processing"
          "tools"
        ];
      };
      services = {
        development = [ "containers" ];
      };
    };
  };
}
