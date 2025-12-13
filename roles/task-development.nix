# Development role - development environment (composable task role)
#
# Can be combined with any hardware role: roles.laptop + roles.development
# Enables: Development tools, LSPs, editors, git config
# Sets: hostSpec.isDevelopment = true
#
# This is a task-based role, not mutually exclusive with hardware roles.
{ config, lib, ... }:
let
  cfg = config.roles;
in
{
  # Development-specific config (only when role is enabled)
  config = lib.mkIf cfg.development {
    # Set hostSpec flag for other modules to check
    hostSpec.isDevelopment = lib.mkDefault true;

    # Development packages and environment
    # (Most dev tools come from modules/apps/development and modules/services/development)
  };
}
