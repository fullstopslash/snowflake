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
  sopsFolder = builtins.toString inputs.nix-secrets + "/sops";

  # List of yubikey public keys for the primary user
  pubKeys = lib.filesystem.listFilesRecursive (
    lib.custom.relativeToRoot "modules/users/${config.identity.primaryUsername}/keys/"
  );
  # IMPORTANT: primary user keys are used for authorized_keys to all users. Change below if
  # you don't want this!
  primaryUserPubKeys = lib.lists.forEach pubKeys (key: builtins.readFile key);

  # Check if system is minimal (no desktop or window managers)
  isMinimal =
    (config.modules.apps.desktop or [ ]) == [ ] && (config.modules.apps.window-managers or [ ]) == [ ];
in
{
  # Import all non-root users
  users = {
    users =
      (lib.mergeAttrsList
        # FIXME: For isMinimal we can likely just filter out primaryUsername only?
        (
          map (user: {
            "${user}" =
              let
                # Only reference SOPS secret if secrets exist and not minimal
                hasSecrets = config.sops.secrets != { };
                sopsHashedPasswordFile =
                  if hasSecrets && !isMinimal then config.sops.secrets."passwords/${user}".path else null;
                platformPath = lib.custom.relativeToRoot "modules/users/${user}/${platform}.nix";
              in
              {
                name = user;
                shell = pkgs.zsh; # Default Shell
                # IMPORTANT: Gives yubikey-based ssh access of primary user to all other users! Change if needed
                openssh.authorizedKeys.keys = primaryUserPubKeys;
                home = if isDarwin then "/Users/${user}" else "/home/${user}";
                # Decrypt password to /run/secrets-for-users/ so it can be used to create the user
                hashedPasswordFile = sopsHashedPasswordFile; # Blank if sops isn't working
              }
              # Add in platform-specific user values if they exist
              // lib.optionalAttrs (lib.pathExists platformPath) (
                import platformPath {
                  inherit config lib;
                }
              );
          }) config.identity.users
        )
      )
      // {
        root = {
          shell = pkgs.zsh;
          hashedPasswordFile = config.users.users.${config.identity.primaryUsername}.hashedPasswordFile;
          hashedPassword = lib.mkForce config.users.users.${config.identity.primaryUsername}.hashedPassword;
          # root's ssh key are mainly used for remote deployment
          openssh.authorizedKeys.keys =
            config.users.users.${config.identity.primaryUsername}.openssh.authorizedKeys.keys;
        };
      };
  }
  //
    # Extra platform-specific options
    lib.optionalAttrs (!isDarwin) {
      mutableUsers = false; # Required for password to be set via sops during system activation!
    };

  # SOPS secrets for user passwords (when SOPS is configured)
  # Passwords are needed for both minimal and non-minimal hosts
  sops.secrets = lib.mkIf ((config.sops.defaultSopsFile or null) != null) (
    lib.mergeAttrsList (
      map (user: {
        "passwords/${user}" = {
          sopsFile = "${sopsFolder}/shared.yaml";
          neededForUsers = true;
        };
      }) config.identity.users
    )
  );
}
