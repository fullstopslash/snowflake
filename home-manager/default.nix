# Home-manager system integration
#
# Configures how home-manager integrates with NixOS/Darwin.
# This sets up:
# - extraSpecialArgs for all home-manager modules
# - User imports (which home-manager modules each user gets)
# - Root user's home-manager configuration
#
# The home-manager module itself is imported in roles/common.nix
{
  inputs,
  pkgs,
  config,
  lib,
  isDarwin,
  ...
}:

let
  platform = if isDarwin then "darwin" else "nixos";
  host = config.host;
  homeStateVersion = config.stateVersions.home;

  fullPathIfExists =
    path:
    let
      fullPath = lib.custom.relativeToRoot path;
    in
    lib.optional (lib.pathExists fullPath) fullPath;
in

lib.mkIf (inputs ? "home-manager") {
  home-manager = {
    # Use global pkgs instead of home-manager's own
    useGlobalPkgs = lib.mkDefault true;
    # Backup file extension for conflicts
    backupFileExtension = lib.mkDefault "bk";

    # Special args passed to all home-manager modules
    extraSpecialArgs = {
      inherit pkgs inputs;
      host = config.host;
    };

    # Configure home-manager for all non-root users
    users =
      (lib.mergeAttrsList (
        map (user: {
          "${user}".imports = lib.flatten [
            # Chezmoi dotfiles management - applies to all non-minimal users
            (lib.optional (!host.isMinimal) (lib.custom.relativeToRoot "home-manager/chezmoi.nix"))
            # User-specific and host-specific home-manager configs
            (lib.optional (!host.isMinimal) (
              map (fullPathIfExists) [
                "home-manager/users/${user}/${host.hostName}.nix"
                "home-manager/users/${user}/common"
                "home-manager/users/${user}/common/${platform}.nix"
              ]
            ))
            # Common values for all users (homeDirectory, username, stateVersion)
            (
              { ... }:
              {
                home = {
                  homeDirectory = if isDarwin then "/Users/${user}" else "/home/${user}";
                  username = "${user}";
                  stateVersion = homeStateVersion;
                };
              }
            )
          ];
        }) config.host.users
      ))
      # Root user configuration
      // {
        root = {
          home.stateVersion = homeStateVersion;
          programs.zsh = {
            enable = true;
            plugins = [
              {
                name = "zsh-powerlevel10k";
                src = "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k";
                file = "powerlevel10k.zsh-theme";
              }
            ];
          };
        };
      };
  };
}
