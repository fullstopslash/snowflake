# Voice assistant role
{ pkgs, ... }:
{
  services = {
    wyoming.satellite = {
      enable = true;
      vad.enable = false;
      name = "Sattelite";
      user = "rain";
      extraArgs = [
        "--wake-word-name=ok_nabu"
        "--wake-uri=tcp://127.0.0.1:10400"
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
      preloadModels = [ "ok_nabu" ];
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
}
