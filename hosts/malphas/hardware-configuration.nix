# Hardware configuration for malphus
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Optimized kernel modules - only load essential modules at boot
  boot = {
    initrd = {
      availableKernelModules = [
        "nvme"
        "xhci_pci"
        "ahci"
        "usbhid"
        "uas"
        "sd_mod"
        "dm_mod" # For LVM if needed
      ];
      kernelModules = [
        "amdgpu" # Graphics - needed for display
      ];
    };
    kernelParams = [
      "amdgpu.hdr=1"
      "amdgpu.dc=1"
      "amdgpu.audio=1"
    ];
    kernelModules = [
      "kvm-amd" # Virtualization - only needed when using VMs
      "uinput" # Input - only needed for gaming/input tools
    ];
    # Fix Intel I225-V connection dropouts at 2.5GbE
    # Driver-level settings to prevent link instability
    extraModprobeConfig = ''
      # Interrupt throttling for stability
      options igc InterruptThrottleRate=125
      # Disable EEE (Energy Efficient Ethernet) - causes dropouts at 2.5GbE
      options igc EnableEEE=0
      # Disable flow control at driver level - prevents negotiation issues at 2.5GbE
      options igc FlowControl=0
    '';
    kernel.sysctl = {
      # Optimize module loading
      "kernel.modprobe" = "/run/current-system/sw/bin/modprobe";
    };
    loader.efi.efiSysMountPoint = "/efi";
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/66a48256-3f19-4a43-b8fa-1898f36ce9b0";
      fsType = "ext4";
    };

    "/efi" = {
      device = "/dev/disk/by-uuid/18CA-2A9C";
      fsType = "vfat";
      options = ["fmask=0022" "dmask=0022"];
    };

    "/mnt/homey" = {
      device = "/dev/disk/by-uuid/74a6a511-0876-4108-9615-2392a6a318bb";
      fsType = "btrfs";
    };
  };

  swapDevices = [];

  # Enable DHCP on each ethernet and wireless interface
  networking.useDHCP = lib.mkDefault true;

  # Wake-on-LAN for eno1
  networking.interfaces.eno1.wakeOnLan = {
    enable = true;
  };

  # Fix Intel I225-V 2.5GbE stability using NetworkManager dispatcher (non-blocking)
  # Driver-level settings (EEE, flow control) are already applied via extraModprobeConfig
  # This dispatcher script applies runtime settings when interface comes up
  environment.etc."NetworkManager/dispatcher.d/10-fix-i225v" = {
    mode = "0755";
    text = ''
      #!/usr/bin/env sh
      # Fix Intel I225-V 2.5GbE stability
      # Only run for eno1 interface on up/connect events
      [ "$1" != "eno1" ] && exit 0
      [ "$2" != "up" ] && [ "$2" != "connect" ] && exit 0

      # Disable EEE and flow control, force 2.5GbE
      ${pkgs.ethtool}/bin/ethtool --set-eee "$1" eee off 2>/dev/null || true
      ${pkgs.ethtool}/bin/ethtool -A "$1" rx off tx off 2>/dev/null || true
      ${pkgs.ethtool}/bin/ethtool -s "$1" autoneg off speed 2500 duplex full 2>/dev/null || true
      ${pkgs.ethtool}/bin/ethtool -A "$1" rx off tx off 2>/dev/null || true
    '';
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Hardware configuration
  hardware = {
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    logitech.wireless = {
      enable = true;
      enableGraphical = false; # Disable graphical support for faster boot
    };
    bluetooth = {
      enable = true;
      powerOnBoot = false; # Don't power on at boot for faster startup
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
          Experimental = false; # Disable experimental features
          AutoEnable = false; # Don't auto-enable at boot
          ControllerMode = "dual";
          UserspaceHID = true;
        };
      };
    };
    enableRedistributableFirmware = true;
    firmware = with pkgs; [
      linux-firmware
    ];
  };

  # hardware.amdgpu.amdvlk = {
  #   enable = true;
  #   supportExperimental.enable = true;
  #   support32Bit.enable = true;
  # };

  # environment.variables.AMD_VULKAN_ICD = "RADV";
  services.lact.enable = true;

  # Input groups
  users.groups.uinput = {};
}
