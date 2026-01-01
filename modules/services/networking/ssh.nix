# SSH client configuration module
#
# Configures the system-wide SSH client including:
# - SSH agent with askpass integration
# - Known hosts for GitHub, GitLab, and private infrastructure
# - SSH key deployment from SOPS
#
# Note: This module is NixOS-only (programs.ssh doesn't exist on Darwin)
#
# Usage: modules.services.networking = [ "ssh" ]
{
  inputs,
  config,
  lib,
  pkgs,
  cfg,
  ...
}:
let
  sopsFolder = builtins.toString inputs.nix-secrets + "/sops";
in
{
  description = "SSH client configuration";

  options = {
    deployUserKey = lib.mkOption {
      type = lib.types.bool;
      default = !config.myModules.services.security.yubikey.enable or false;
      description = "Deploy user SSH key from SOPS (disabled for Yubikey hosts)";
    };
    workMode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable work-specific SSH configuration and known hosts";
    };
  };

  config = lib.mkIf pkgs.stdenv.isLinux {
    # Deploy SSH key from SOPS for non-Yubikey hosts
    # The key is symlinked to ~/.ssh/id_ed25519 by chezmoi dotfiles
    sops.secrets = lib.mkIf (cfg.deployUserKey && (config.sops.defaultSopsFile or null) != null) {
      "keys/ssh/ed25519" = {
        sopsFile = "${sopsFolder}/shared.yaml";
        owner = config.identity.primaryUsername;
        mode = "0400";
      };
    };
    programs.ssh = {
      startAgent = true;
      enableAskPassword = true;
      askPassword = lib.mkForce "${pkgs.kdePackages.ksshaskpass.out}/bin/ksshaskpass";

      knownHostsFiles = [
        (pkgs.writeText "custom_known_hosts" ''
          gitlab.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfuCHKVTjquxvt6CM6tdG4SLp1Btn/nOeHHE5UOzRdf
          github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
          github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=
          gitlab.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBFSMqzJeV9rUzU4kWitGjeR4PWSa29SPqJ1fVkhtj3Hw9xjLVXVYrU9QlYWrOLXBpQ6KWjbjTDTdDkoohFzgbEY=
          github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
        '')
      ]
      ++
        lib.optional
          ((config.modules.apps.desktop or [ ]) != [ ] || (config.modules.apps.window-managers or [ ]) != [ ])
          (
            pkgs.writeText "custom_private_known_hosts" inputs.nix-secrets.networking.ssh.knownHostsFileContents
          )
      ++ lib.optional cfg.workMode (
        pkgs.writeText "custom_work_known_hosts" inputs.nix-secrets.work.ssh.knownHostsFileContents
      );
    };
  };
}
