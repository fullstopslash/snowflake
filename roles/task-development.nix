# Development role - development environment (composable task role)
#
# Can be combined with any hardware role: roles.laptop + roles.development
# Adds development modules to existing selection
#
# This is a task-based role, not mutually exclusive with hardware roles.
{ config, lib, ... }:
let
  cfg = config.roles;
in
{
  config = lib.mkIf cfg.development {
    # ========================================
    # MODULE SELECTIONS (additive)
    # ========================================
    # These add to whatever the hardware role sets
    modules.development = lib.mkDefault [ "latex" "document-processing" "containers" "tools" ];
  };
}
