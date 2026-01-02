{
  description = "Minimal NixOS configuration for bootstrapping systems";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    disko.url = "github:nix-community/disko"; # Declarative partitioning and formatting
    nix-secrets = {
      url = "git+https://github.com/fullstopslash/snowflake-secrets.git?ref=main&shallow=1";
      inputs = { };
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      ...
    }@inputs:
    let
      inherit (self) outputs;

      minimalSpecialArgs = {
        inherit inputs outputs;
        lib = nixpkgs.lib.extend (self: super: { custom = import ../lib { inherit (nixpkgs) lib; }; });
        isDarwin = false;
      };

      # Auto-discover hosts from ../hosts/ directory
      hostsList = builtins.filter (name: name != "TEMPLATE.nix" && name != "template" && name != "iso") (
        builtins.attrNames (builtins.readDir ../hosts)
      );

      # Read host config to extract disk configuration
      mkInstallerConfig =
        hostname:
        let
          hostPath = ../hosts/${hostname};
          # Import host config to read disks settings
          hostConfig = import hostPath { lib = nixpkgs.lib; };

          # Extract disk config
          disks =
            hostConfig.disks or {
              enable = true;
              layout = "btrfs";
              device = "/dev/vda";
              withSwap = false;
              swapSize = "0";
            };

          # Extract architecture from host config or default to x86_64-linux
          architecture = hostConfig.host.architecture or "x86_64-linux";

          # Map layout to disk spec path
          diskSpecPath =
            if disks.layout == "btrfs-luks-impermanence" then
              ../modules/disks/btrfs-luks-impermanence-disk.nix
            else if disks.layout == "btrfs-impermanence" then
              ../modules/disks/btrfs-impermanence-disk.nix
            else
              ../modules/disks/btrfs-disk.nix;

          # Convert withSwap to boolean if needed
          withSwap = if builtins.isBool disks.withSwap then disks.withSwap else (disks.withSwap or false);

          # Extract swap size, default to 0
          swapSize = builtins.toString (disks.swapSize or "0");
        in
        nixpkgs.lib.nixosSystem {
          system = architecture;
          specialArgs = minimalSpecialArgs;
          modules = [
            inputs.disko.nixosModules.disko
            diskSpecPath
            {
              _module.args = {
                disk = disks.device;
                inherit withSwap swapSize;
              };
            }
            ./minimal-configuration.nix
            ../hosts/${hostname}/hardware-configuration.nix
            {
              networking.hostName = hostname;
              # Override username for minimal install
              host.primaryUsername = "${toString inputs.nix-secrets.user}";
              host.username = "${toString inputs.nix-secrets.user}";
            }
          ];
        };
    in
    {
      nixosConfigurations = builtins.listToAttrs (
        map (host: {
          name = host;
          value = mkInstallerConfig host;
        }) hostsList
      );
    };
}
