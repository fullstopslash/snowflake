{
  description = "Multi-host NixOS configuration with modular roles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hardware.url = "github:nixos/nixos-hardware";
    # Role-specific inputs
    mcphub-nvim.url = "github:ravitemer/mcphub.nvim";
    mcp-hub.url = "github:ravitemer/mcp-hub";
    nix-ai-tools.url = "github:numtide/nix-ai-tools";
    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Fix Dolphin OpenURI behavior via overlay
    # dolphin-overlay = {
    #   url = "github:rumboon/dolphin-overlay";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
  };

  outputs = {
    self,
    nixpkgs,
    ...
  } @ inputs: let
    # System configuration
    system = "x86_64-linux";
    # Centralized NixOS state version
    stateVersion = "25.05";

    # Dynamically discover all hosts from the hosts/ directory
    hostsDir = self + "/hosts";
    hostEntries = builtins.readDir hostsDir;

    # Filter for actual host directories (must be a directory and contain default.nix), skip template
    hosts = builtins.filter (
      name: let
        entry = hostEntries.${name};
        sub = builtins.readDir "${hostsDir}/${name}";
      in
        entry == "directory" && name != "template" && builtins.hasAttr "default.nix" sub
    ) (builtins.attrNames hostEntries);

    # Helper function to create host configuration
    mkHost = hostname:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {inherit inputs self;};
        modules = [
          # Expose a stable package set under `pkgs.stable` for easy use in roles
          {
            nixpkgs.overlays = [
              (_: _prev: {
                stable = import inputs.nixpkgs-stable {
                  inherit system;
                  config = {allowUnfree = true;};
                };
              })
              # inputs.dolphin-overlay.overlays.default
            ];
          }
          # Host-specific configuration
          ./hosts/${hostname}/default.nix

          # Dynamic hostname setting
          {networking.hostName = hostname;}

          # Centralize stateVersion for all hosts
          {system.stateVersion = stateVersion;}

          # Note: Do not define system.build.installTest here to avoid conflicts
          # with nixos-anywhere --vm-test which also defines this option.
        ];
      };

    # Generate configurations for all discovered hosts
    hostConfigurations = nixpkgs.lib.genAttrs hosts mkHost;

    # deploy-rs nodes for each host (root profile)
    deployNodes = nixpkgs.lib.genAttrs hosts (
      hostname: {
        inherit hostname;
        profiles.system = {
          user = "root";
          path = inputs.deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.${hostname};
        };
      }
    );
  in {
    # NixOS configurations
    nixosConfigurations = hostConfigurations;

    # deploy-rs configuration
    deploy = {nodes = deployNodes;};

    # CI checks for deploy-rs
    checks.${system} = inputs.deploy-rs.lib.${system}.deployChecks self.deploy;

    # ISO build outputs
    packages = {
      "${system}" = {
        iso-installer = inputs.nixos-generators.nixosGenerate {
          inherit system;
          format = "iso";
          modules = [
            ./iso/installer.nix
            # Centralize stateVersion for the installer ISO
            {system.stateVersion = stateVersion;}
          ];
        };
      };
    };
  };
}
