# OBS role
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # v4l2loopback 0.15.3 for kernel 6.18 compatibility
  v4l2loopback = config.boot.kernelPackages.v4l2loopback.overrideAttrs (_old: {
    version = "0.15.3";
    src = pkgs.fetchFromGitHub {
      owner = "umlaeute";
      repo = "v4l2loopback";
      rev = "v0.15.3";
      hash = "sha256-KXJgsEJJTr4TG4Ww5HlF42v2F1J+AsHwrllUP1n/7g8=";
    };
  });
in
{
  programs.obs-studio = {
    enable = true;
    enableVirtualCamera = true;
    plugins = with pkgs.obs-studio-plugins; [
      wlrobs
      obs-backgroundremoval
      obs-pipewire-audio-capture
      obs-gstreamer
      obs-vaapi
      obs-vkcapture
      obs-tuna
      obs-teleport
      input-overlay
      waveform
    ];
  };

  # Override v4l2loopback module set by enableVirtualCamera
  boot.extraModulePackages = lib.mkForce [ v4l2loopback ];
}
