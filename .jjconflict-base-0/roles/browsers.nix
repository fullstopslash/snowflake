# Browsers role
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    firefox
    ungoogled-chromium
    microsoft-edge
    floorp
    ladybird
  ];
  programs.firefox = {
    enable = true;
    nativeMessagingHosts.packages = [
      pkgs.tridactyl-native
    ];
  };
}
