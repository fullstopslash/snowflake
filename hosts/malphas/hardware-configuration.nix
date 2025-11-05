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
    # Fix Intel I225-V connection dropouts
    # Disable problematic features that cause intermittent disconnections
    extraModprobeConfig = ''
      options igc InterruptThrottleRate=125
      options igc EnableEEE=0
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

  # Fix Intel I225-V connection dropouts via ethtool
  # Configure interface settings to prevent intermittent disconnections
  # The I225-V (igc driver) is known to have issues with 2.5GbE autonegotiation
  # and power management causing connection dropouts
  # This service runs after NetworkManager to ensure settings are applied
  # after NetworkManager has configured the interface
  systemd.services.fix-igc-interface = {
    description = "Fix Intel I225-V (igc) interface settings";
    after = [
      "network-online.target"
      "NetworkManager.service"
    ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # Wait for interface to be available and NetworkManager to configure it
      for i in {1..30}; do
        if ${pkgs.iproute2}/bin/ip link show eno1 >/dev/null 2>&1 && \
           ${pkgs.iproute2}/bin/ip link show eno1 | grep -q "state UP"; then
          break
        fi
        sleep 1
      done

      # Small delay to ensure NetworkManager has finished configuring
      sleep 2

      # Ensure EEE is disabled (can cause issues with some switches/routers)
      # EEE (Energy Efficient Ethernet) can cause dropouts with certain hardware
      ${pkgs.ethtool}/bin/ethtool --set-eee eno1 eee off 2>/dev/null || true

      # Configure wake-on-LAN (preserve existing WOL setting)
      ${pkgs.ethtool}/bin/ethtool -s eno1 wol g 2>/dev/null || true
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
