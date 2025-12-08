{ pkgs, ... }:
{
  environment.variables = {
    ENABLE_HDR_WSI = "1";
  };

  # programs.gamescope = {
  #   package = pkgs.gamescope-wsi;
  #   /*
  #   env = {
  #     ENABLE_GAMESCOPE_WSI = "1";
  #     DXVK_HDR = "1";
  #     DISABLE_HDR_WSI = "1";
  #     MANGOHUD = "1";
  #   };
  #   */
  #   /*
  #   args = [
  #     "-f"
  #     "-F fsr"
  #     "-h 2160"
  #     "--force-grab-cursor"
  #     "--adaptive-sync"
  #     "--hdr-enabled"
  #     "--hdr-debug-force-output"
  #     "--hdr-itm-enable"
  #     "--steam"
  #   ];
  #   */
  # };

  # Provide the Vulkan HDR layer for native KWin apps
  environment.systemPackages = [
    (pkgs.vulkan-hdr-layer-kwin6 or (pkgs.callPackage ./VK_hdr_layer.nix { }))
  ];

  nixpkgs.overlays = [
    (_: prev: {
      gamescope-wsi = prev.gamescope-wsi.override { enableExecutable = true; };
    })
  ];
}
