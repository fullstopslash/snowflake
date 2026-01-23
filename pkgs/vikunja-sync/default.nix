{
  pkgs,
  lib,
  ...
}:
let
  syncallPkg = pkgs.callPackage ../syncall/default.nix {};

  # Python script for correlation repair (no flake8 checking)
  correlateScript = pkgs.writers.writePython3Bin "vikunja-sync-correlate" {
    libraries = with pkgs.python3Packages; [caldav pyyaml vobject];
    flakeIgnore = ["E501" "E265" "F541"];
  } (builtins.readFile ./correlate.py);

  # Python script for label/tag sync (Vikunja labels -> TW tags)
  labelSyncScript = pkgs.writers.writePython3Bin "vikunja-sync-labels" {
    flakeIgnore = ["E501" "E265"];
  } (builtins.readFile ./label-sync.py);
in
pkgs.writeShellApplication {
  name = "vikunja-sync";
  runtimeInputs = [
    syncallPkg
    correlateScript
    labelSyncScript
    pkgs.curl
    pkgs.jq
    pkgs.yq-go
    pkgs.sops
    pkgs.taskwarrior3
    pkgs.coreutils
  ];
  text = builtins.readFile ./vikunja-sync.sh;
}
