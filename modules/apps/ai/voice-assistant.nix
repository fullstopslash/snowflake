# Voice assistant module (Wyoming integration)
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.apps.ai.voiceAssistant;
  openwakewordCfg = config.services.wyoming.openwakeword;
in
{
  options.myModules.apps.ai.voiceAssistant = {
    enable = lib.mkEnableOption "Wyoming voice assistant";
  };

  config = lib.mkIf cfg.enable {
    services = {
      wyoming.satellite = {
        enable = true;
        vad.enable = false;
        name = "Sattelite";
        user = "rain";
        extraArgs = [
          "--wake-word-name=ok_nabu"
          "--wake-uri=tcp://127.0.0.1:${toString openwakewordCfg.port}"
        ];
        microphone = {
          command = "${pkgs.pipewire}/bin/pw-cat --record --target alsa_input.usb-audio-technica____AT2020_USB-00.iec958-stereo --format=s16 --channels=1 --rate=16000 -";
          autoGain = 5;
          noiseSuppression = 2;
        };
        sounds = {
          awake = "/home/rain/958__anton__groter.wav";
        };
      };
      wyoming.openwakeword = {
        enable = true;
        # preloadModels removed in wyoming-openwakeword 2.0
      };
    };

    # Voice assistant packages
    environment.systemPackages = with pkgs; [
      # Voice assistant tools
      stable.wyoming-satellite
      stable.wyoming-openwakeword
      stable.wyoming-faster-whisper
      stable.wyoming-piper
    ];
  };
}
