# Secrets role
{pkgs, ...}: {
  # Secrets packages
  environment.systemPackages = with pkgs; [
    # Secrets management
    age
    age-plugin-yubikey
    sops
    gopass
    pass
    gnupg
    ssh-to-age
    rbw
    bitwarden-cli
    bitwarden-desktop
    # bws
  ];
}
