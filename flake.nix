{
  description = "fullstopsash's Nix-Config";
  outputs =
    {
      self,
      nixpkgs,
      # nix-darwin,
      ...
    }@inputs:
    let
      inherit (self) outputs;

      #
      # ========= Architectures =========
      #
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # ========== Extend lib with lib.custom ==========
      # NOTE: This approach allows lib.custom to propagate into hm
      # see: https://github.com/nix-community/home-manager/pull/3454
      lib = nixpkgs.lib.extend (self: super: { custom = import ./lib { inherit (nixpkgs) lib; }; });

      #
      # ========= Helper Functions =========
      #
      # Architecture-aware mkHost helper for building NixOS configurations
      # Reads architecture and nixpkgsVariant from host config declaratively
      mkHost =
        hostname:
        let
          hostPath = ./hosts/${hostname};

          # Helper to build the final configuration with proper nixpkgs input
          # We need to evaluate config once to determine which nixpkgs to use
          buildConfig =
            {
              system,
              pkgInput,
              useCustom,
            }:
            let
              # Create custom pkgs if needed
              customPkgs =
                if useCustom then
                  (import pkgInput {
                    inherit system;
                    config = {
                      allowUnfree = true;
                      allowBroken = true;
                    };
                  })
                else
                  null;

              # Use matching lib for the nixpkgs version
              hostLib =
                if useCustom then
                  pkgInput.lib.extend (self: super: { custom = import ./lib { lib = pkgInput.lib; }; })
                else
                  lib;

              isDarwin = lib.hasInfix "darwin" system;
            in
            pkgInput.lib.nixosSystem {
              inherit system;
              specialArgs = {
                inherit inputs outputs isDarwin;
                lib = hostLib;
              };
              modules = [
                # StateVersion must load first (needed by modules/users via roles/common)
                (
                  { config, lib, ... }:
                  {
                    options.stateVersions = {
                      system = lib.mkOption {
                        type = lib.types.str;
                        default = "25.11";
                        description = "NixOS state version (DO NOT CHANGE on existing systems)";
                      };
                      home = lib.mkOption {
                        type = lib.types.str;
                        default = "25.11";
                        description = "Home Manager state version (DO NOT CHANGE on existing environments)";
                      };
                    };

                    config = lib.mkIf (hostname != "iso") {
                      # Use mkDefault for normal hosts (priority 1000), which:
                      # - Overrides NixOS's default stateVersion (priority 1500)
                      # - Can be overridden by host-specific settings with mkForce
                      # ISO is excluded to avoid conflict with installation-cd-base.nix
                      system.stateVersion = lib.mkDefault config.stateVersions.system;
                      warnings = lib.optional (
                        config.stateVersions.system != config.stateVersions.home
                      ) "StateVersion mismatch: system=${config.stateVersions.system} home=${config.stateVersions.home}";
                    };
                  }
                )

                # sops-nix for secrets management
                inputs.sops-nix.nixosModules.sops

                # Role system - must come before host config (skip for ISO which is special)
                (if hostname != "iso" then ./roles else { })

                # Common modules
                ./modules/common

                hostPath

                # Pass custom pkgs for alternate nixpkgs inputs
                (
                  if useCustom then
                    {
                      nixpkgs.pkgs = lib.mkForce customPkgs;
                      nixpkgs.config = lib.mkForce { };
                      nix.registry = lib.mkForce { };
                      nix.nixPath = lib.mkForce [ ];
                    }
                  else
                    { }
                )
              ];
            };

          # Simple evaluation to extract architecture and variant
          # For ISO, use defaults directly without evaluation
          finalArchitecture =
            if hostname == "iso" then
              "x86_64-linux"
            else
              let
                # We import the host file directly to read declared values
                prelimConfig = import hostPath { lib = nixpkgs.lib; };

                # Extract values from roles and host config
                # Roles set defaults via lib.mkDefault, so host can override
                roleConfig =
                  if builtins.hasAttr "roles" prelimConfig && builtins.elem "vm" prelimConfig.roles then
                    {
                      architecture = "x86_64-linux";
                      nixpkgsVariant = "unstable";
                    }
                  else if builtins.hasAttr "roles" prelimConfig && builtins.elem "pi" prelimConfig.roles then
                    {
                      architecture = "aarch64-linux";
                      nixpkgsVariant = "stable";
                    }
                  else
                    {
                      architecture = "x86_64-linux";
                      nixpkgsVariant = "stable";
                    };
              in
              # Host can override in host config
              prelimConfig.host.architecture or roleConfig.architecture;

          finalVariant =
            if hostname == "iso" then
              "stable"
            else
              let
                prelimConfig = import hostPath { lib = nixpkgs.lib; };
                roleConfig =
                  if builtins.hasAttr "roles" prelimConfig && builtins.elem "vm" prelimConfig.roles then
                    {
                      architecture = "x86_64-linux";
                      nixpkgsVariant = "unstable";
                    }
                  else if builtins.hasAttr "roles" prelimConfig && builtins.elem "pi" prelimConfig.roles then
                    {
                      architecture = "aarch64-linux";
                      nixpkgsVariant = "stable";
                    }
                  else
                    {
                      architecture = "x86_64-linux";
                      nixpkgsVariant = "stable";
                    };
              in
              prelimConfig.host.nixpkgsVariant or roleConfig.nixpkgsVariant;

          # Select inputs
          finalPkgInput = if finalVariant == "unstable" then inputs.nixpkgs-unstable else nixpkgs;
          useCustomPkgs = finalVariant != "stable";
        in
        buildConfig {
          system = finalArchitecture;
          pkgInput = finalPkgInput;
          useCustom = useCustomPkgs;
        };
    in
    {
      #
      # ========= Overlays =========
      #
      # Custom modifications/overrides to upstream packages
      overlays = import ./overlays { inherit inputs; };

      #
      # ========= Host Configurations =========
      #
      # Building configurations is available through `just rebuild` or `nixos-rebuild --flake .#hostname`
      # Auto-discover hosts from hosts/ directory and build with mkHost helper
      # Filter out TEMPLATE.nix and template directory
      nixosConfigurations = builtins.listToAttrs (
        map
          (host: {
            name = host;
            value = mkHost host;
          })
          (
            builtins.filter (name: name != "TEMPLATE.nix" && name != "template") (
              builtins.attrNames (builtins.readDir ./hosts)
            )
          )
      );

      # darwinConfigurations = builtins.listToAttrs (
      #   map (host: {
      #     name = host;
      #     value = nix-darwin.lib.darwinSystem {
      #       specialArgs = {
      #         inherit inputs outputs lib;
      #         isDarwin = true;
      #       };
      #       modules = [ ./hosts/darwin/${host} ];
      #     };
      #   }) (builtins.attrNames (builtins.readDir ./hosts/darwin))
      # );

      #
      # ========= Packages =========
      #
      # Expose custom packages

      /*
        NOTE: This is only for exposing packages exterally; ie, `nix build .#packages.x86_64-linux.cd-gitroot`
        For internal use, these packages are added through the default overlay in `overlays/default.nix`
      */

      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          };
        in
        nixpkgs.lib.packagesFromDirectoryRecursive {
          callPackage = nixpkgs.lib.callPackageWith pkgs;
          directory = ./pkgs/common;
        }
      );

      #
      # ========= Formatting =========
      #
      # Nix formatter available through 'nix fmt' https://github.com/NixOS/nixfmt
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);
      # Pre-commit checks
      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        import ./checks.nix { inherit inputs pkgs; }
      );
      #
      # ========= DevShell =========
      #
      # Custom shell for bootstrapping on new hosts, modifying nix-config, and secrets management
      devShells = forAllSystems (
        system:
        import ./shell.nix {
          pkgs = nixpkgs.legacyPackages.${system};
          checks = self.checks.${system};
        }
      );
    };

  inputs = {
    #
    # ========= Official NixOS, Darwin, and HM Package Sources =========
    #
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    # The next two are for pinning to stable vs unstable regardless of what the above is set to
    # This is particularly useful when an upcoming stable release is in beta because you can effectively
    # keep 'nixpkgs-stable' set to stable for critical packages while setting 'nixpkgs' to the beta branch to
    # get a jump start on deprecation changes.
    # See also 'stable-packages' and 'unstable-packages' overlays at 'overlays/default.nix"
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    hardware.url = "github:nixos/nixos-hardware";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager-unstable = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    nixpkgs-darwin.url = "github:nixos/nixpkgs/nixpkgs-25.05-darwin";
    nix-darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    #
    # ========= Utilities =========
    #
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Declarative partitioning and formatting
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Secrets management. See ./docs/secretsmgmt.md
    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Declarative vms using libvirt
    nixvirt = {
      url = "https://flakehub.com/f/AshleyYakeley/NixVirt/*.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # vim4LMFQR!
    nixvim = {
      url = "github:nix-community/nixvim/nixos-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
      #url = "github:nix-community/nixvim";
      #inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    # Pre-commit
    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Theming
    stylix.url = "github:danth/stylix/release-25.05";
    rose-pine-hyprcursor.url = "github:ndom91/rose-pine-hyprcursor";

    # MCP Hub - Model Context Protocol neovim integration
    mcp-hub = {
      url = "github:ravitemer/mcp-hub";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #
    # ========= Personal Repositories =========
    #
    # Private secrets repo.  See ./docs/secretsmgmt.md
    # Authenticate via ssh and use shallow clone
    nix-secrets = {
      url = "git+ssh://git@github.com/fullstopslash/snowflake-secrets.git?ref=simple&shallow=1";
      inputs = { };
    };
    nix-assets = {
      url = "github:emergentmind/nix-assets";
    };
  };
}
