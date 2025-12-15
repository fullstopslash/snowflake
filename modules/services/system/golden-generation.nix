# Golden boot generation management
# Automatically pins stable generations as "golden" and protects from GC
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.services.system.goldenGeneration;
  stateDir = "/var/lib/golden-generation";

  # Script to pin current generation as golden
  pinGoldenScript = pkgs.writeShellScript "pin-golden-generation" ''
    set -euo pipefail

    # Get current generation number
    current=$(readlink /nix/var/nix/profiles/system | grep -oP 'system-\K[0-9]+')

    # Create state directory
    mkdir -p ${stateDir}

    # Save golden generation number
    echo "$current" > ${stateDir}/golden-generation-number

    # Add GC root to protect from deletion
    ln -sfn /nix/var/nix/profiles/system-$current-link \
      /nix/var/nix/gcroots/auto/golden-generation

    echo "Golden generation pinned: $current"
  '';

  # Script to show current golden generation
  showGoldenScript = pkgs.writeShellScript "show-golden-generation" ''
    if [ -f ${stateDir}/golden-generation-number ]; then
      golden=$(cat ${stateDir}/golden-generation-number)
      echo "Golden Generation: $golden"

      if [ -L /nix/var/nix/gcroots/auto/golden-generation ]; then
        echo "GC Protection: Active"
      else
        echo "GC Protection: Missing (run pin-golden to restore)"
      fi
    else
      echo "No golden generation pinned yet"
      exit 1
    fi
  '';

in
{
  options.myModules.services.system.goldenGeneration = {
    enable = lib.mkEnableOption "Golden generation management";

    autoPin = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Automatically pin generation after stable uptime";
    };

    autoPinDelay = lib.mkOption {
      type = lib.types.str;
      default = "24h";
      description = "Delay before auto-pinning (systemd time format)";
    };
  };

  config = lib.mkIf cfg.enable {
    # Auto-pin timer and service
    systemd.timers.golden-auto-pin = lib.mkIf cfg.autoPin {
      description = "Auto-pin golden generation after stable uptime";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = cfg.autoPinDelay;
        Unit = "golden-auto-pin.service";
      };
    };

    systemd.services.golden-auto-pin = lib.mkIf cfg.autoPin {
      description = "Auto-pin current generation as golden";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pinGoldenScript}";
      };
    };

    # Add commands to system packages
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "pin-golden" ''
        exec ${pinGoldenScript} "$@"
      '')
      (pkgs.writeShellScriptBin "show-golden" ''
        exec ${showGoldenScript} "$@"
      '')
    ];

    # Create state directory
    systemd.tmpfiles.rules = [
      "d ${stateDir} 0755 root root -"
    ];
  };
}
