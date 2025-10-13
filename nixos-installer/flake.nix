{
  description = "Minimal NixOS configuration for bootstrapping systems";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    disko.url = "github:nix-community/disko"; # Declarative partitioning and formatting
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

      # This mkHost is way better: https://github.com/linyinfeng/dotfiles/blob/8785bdb188504cfda3daae9c3f70a6935e35c4df/flake/hosts.nix#L358
      newConfig =
        name: disk: swapSize: useLuks: useImpermanence: username:
        (
          let
            diskSpecPath =
              if useLuks && useImpermanence then
                ../hosts/common/disks/btrfs-luks-impermanence-disk.nix
              else if !useLuks && useImpermanence then
                ../hosts/common/disks/btrfs-impermanence-disk.nix
              else
                ../hosts/common/disks/btrfs-disk.nix;
          in
          nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = minimalSpecialArgs;
            modules = [
              inputs.disko.nixosModules.disko
              diskSpecPath
              {
                _module.args = {
                  inherit disk;
                  withSwap = swapSize > 0;
                  swapSize = builtins.toString swapSize;
                };
              }
              ./minimal-configuration.nix
              ../hosts/nixos/${name}/hardware-configuration.nix

              { 
                networking.hostName = name;
                # Override username for minimal install to ensure correct SSH keys are used
                hostSpec.primaryUsername = username;
                hostSpec.username = username;
              }
            ];
          }
        );
    in
    {
      nixosConfigurations = {
        # host = newConfig "name" "disk" "swapSize" "useLuks" "useImpermanence" "username"
        # Swap size is in GiB
        genoa = newConfig "genoa" "/dev/nvme0n1" 16 true true "ta";
        grief = newConfig "grief" "/dev/vda" 0 false false "ta";
        griefling = newConfig "griefling" "/dev/vda" 0 false false "rain";
        guppy = newConfig "guppy" "/dev/vda" 0 false false "rain";
        gusto = newConfig "gusto" "/dev/nvme0n1" 8 false false "ta";
        malphas = newConfig "malphas" "/dev/vda" 4 false false "ta";

        ghost = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = minimalSpecialArgs;
          modules = [
            inputs.disko.nixosModules.disko
            ../hosts/common/disks/ghost.nix
            ./minimal-configuration.nix
            { 
              networking.hostName = "ghost";
              hostSpec.primaryUsername = "ta";
              hostSpec.username = "ta";
            }
            ../hosts/nixos/ghost/hardware-configuration.nix
          ];
        };
      };
    };
}
