# Browsers role
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    firefox
    ungoogled-chromium
    microsoft-edge
    floorp-bin
    ladybird
  ];
  programs.firefox = {
    enable = true;
    nativeMessagingHosts.packages = [
      pkgs.tridactyl-native
    ];
  };
}
