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
        obs-vkcapture
        wlrobs
        waveform
        obs-vaapi
        obs-tuna
        obs-teleport
        input-overlay
      ];
    })
  ];

  # OBS kernel module (build only the kernel module, skip userspace utils)
  boot = {
    extraModulePackages = with config.boot.kernelPackages; [
      (v4l2loopback.overrideAttrs (_old: {
        phases = ["unpackPhase" "patchPhase" "buildPhase" "installPhase"];
        buildPhase = ''
          runHook preBuild
          make -C ${config.boot.kernelPackages.kernel.dev}/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/build M=$PWD modules
          runHook postBuild
        '';
        installPhase = ''
          runHook preInstall
          mkdir -p $out/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/updates
          cp -v v4l2loopback.ko $out/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/updates/
          runHook postInstall
        '';
      }))
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
