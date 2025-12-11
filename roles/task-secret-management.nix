# Secret management role - Bitwarden automation and related tooling
#
# Enables: Bitwarden CLI automation with OAuth + libsecret integration
# Use: roles.secretManagement = true;
#
# This is a task-based role, composable with any hardware role.
{ config, lib, ... }:
let
  cfg = config.roles;
in
{
  options.roles.secretManagement = lib.mkEnableOption "secret management (Bitwarden automation)";

  config = lib.mkIf cfg.secretManagement {
    # Enable Bitwarden automation with sensible defaults
    roles.bitwardenAutomation = {
      enable = true;
      enableAutoLogin = lib.mkDefault true;
      syncInterval = lib.mkDefault 30;
    };
  };
}
