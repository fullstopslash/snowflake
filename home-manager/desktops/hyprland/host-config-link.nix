# Hyprland Host Config Management
#
# Deploys host-specific Hyprland config and creates the local.conf symlink
# based on the current hostname.
#
# Usage: Import this module in hosts that use chezmoi-managed Hyprland configs
# but need host-specific settings deployed via Nix.
{
  config,
  lib,
  ...
}:
let
  hostname = config.identity.hostName;
  hostConfigDir = ./host-configs;
  mainConfigFile = "${hostConfigDir}/hyprland.conf";
  commonConfigFile = "${hostConfigDir}/common.conf";
  hostConfigFile = "${hostConfigDir}/${hostname}.conf";

  # Check if configs exist
  hasMainConfig = builtins.pathExists mainConfigFile;
  hasCommonConfig = builtins.pathExists commonConfigFile;
  hasHostConfig = builtins.pathExists hostConfigFile;
in
{
  # Deploy hyprland configs: main entry point, common, and host-specific
  home.activation.hyprlandHostConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    HYPR_DIR="$HOME/.config/hypr"
    HYPR_CONF_DIR="$HYPR_DIR/conf.d"

    # Ensure directories exist
    run mkdir -p "$HYPR_CONF_DIR"

    ${lib.optionalString hasMainConfig ''
      # Deploy main hyprland.conf entry point
      run install -Dm644 "${mainConfigFile}" "$HYPR_DIR/hyprland.conf"
      verboseEcho "Hyprland: Deployed hyprland.conf"
    ''}

    ${lib.optionalString hasCommonConfig ''
      # Deploy common config (shared across all hosts)
      run install -Dm644 "${commonConfigFile}" "$HYPR_CONF_DIR/common.conf"
      verboseEcho "Hyprland: Deployed common.conf"
    ''}

    ${lib.optionalString hasHostConfig ''
      # Deploy the host-specific config
      run install -Dm644 "${hostConfigFile}" "$HYPR_CONF_DIR/${hostname}.conf"

      # Create/update the local.conf symlink
      run ln -sf "${hostname}.conf" "$HYPR_CONF_DIR/local.conf"

      verboseEcho "Hyprland: Deployed ${hostname}.conf and linked to local.conf"
    ''}

    ${lib.optionalString (!hasHostConfig) ''
      verboseEcho "Hyprland: No host-specific config found for ${hostname}"
      verboseEcho "Hyprland: Create ${hostConfigDir}/${hostname}.conf if needed"
    ''}
  '';
}
