# OBS role
{
  config,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    # stable.obs-cmd
    obs-studio
    # stable.obs-do
    # OBS with plugins
    (pkgs.stable.wrapOBS {
      plugins = with pkgs.obs-studio-plugins; [
        wlrobs
        obs-backgroundremoval
        obs-pipewire-audio-capture
        wlrobs
        waveform
        obs-gstreamer
        obs-vaapi
        obs-vkcapture
        obs-tuna
        obs-teleport
        input-overlay
      ];
    })
  ];

  # OBS kernel module for virtual camera
  boot = {
    extraModulePackages = with config.boot.kernelPackages; [
      v4l2loopback
    ];

    kernelParams = ["video4linux"];
    kernelModules = [
      "v4l2loopback"
    ];
    # Load v4l2loopback module on-demand when OBS starts
    extraModprobeConfig = ''
      options v4l2loopback devices=1 video_nr=1 card_label="OBS Cam" exclusive_caps=1
    '';
  };
}
