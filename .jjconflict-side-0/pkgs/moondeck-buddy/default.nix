{
  lib,
  stdenv,
  fetchFromGitHub,
  nix-update-script,
  kdePackages,
  cmake,
  ninja,
  qt6,
  procps,
  xorg,
  steam,
  useNixSteam ? true,
}: let
  inherit (kdePackages) qtbase wrapQtAppsHook;
  qtEnv = with qt6;
    env "qt-env-custom-${qtbase.version}" [
      qthttpserver
      qtwebsockets
    ];
in
  stdenv.mkDerivation (finalAttrs: {
    pname = "moondeck-buddy";
    version = "1.8.0";

    src = fetchFromGitHub {
      owner = "FrogTheFrog";
      repo = "moondeck-buddy";
      tag = "v${finalAttrs.version}";
      fetchSubmodules = true;
      hash = "sha256-US39rGTUzIeH2cgX3XJ5CYv6ZQ6IbuMZDWrwzMg6b24=";
    };

    buildInputs = [
      procps
      xorg.libXrandr
      qtbase
      qtEnv
    ];

    nativeBuildInputs = [
      cmake
      ninja
      wrapQtAppsHook
    ];

    postPatch = lib.optionalString useNixSteam ''
      # Replace any hardcoded /usr/bin/steam references if present; do not fail if files changed
      if grep -R "/usr/bin/steam" -n . >/dev/null 2>&1; then
        grep -Rl "/usr/bin/steam" . | while read -r f; do
          substituteInPlace "$f" --replace /usr/bin/steam ${lib.getExe steam} || true
        done
      fi
    '';

    passthru.updateScript = nix-update-script {};

    meta = {
      mainProgram = "MoonDeckBuddy";
      description = "Helper to work with moonlight on a steamdeck";
      homepage = "https://github.com/FrogTheFrog/moondeck-buddy";
      changelog = "https://github.com/FrogTheFrog/moondeck-buddy/releases/tag/v${finalAttrs.version}";
      license = lib.licenses.lgpl3Only;
      maintainers = with lib.maintainers; [redxtech];
      platforms = lib.platforms.linux;
    };
  })
