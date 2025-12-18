# Chromium configuration via home-manager programs.chromium
# Package installation via: myModules.apps.browsers.chromium.enable = true
# Both must be enabled for Chromium to work with these settings
{
  programs.chromium = {
    enable = true;
    commandLineArgs = [
      "--no-default-browser-check"
      "--restore-last-session"
    ];
  };
}
