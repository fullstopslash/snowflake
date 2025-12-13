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
    # These add to whatever the hardware role sets
    modules.development = [
      "latex"
      "document-processing"
      "containers"
      "tools"
    ];
  };
}
