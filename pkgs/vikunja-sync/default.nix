{
  pkgs,
  lib,
  ...
}:
let
  syncallPkg = pkgs.callPackage ../syncall/default.nix {};

  # Shared Python module for vikunja-sync suite
  vikunjaCommonModule = pkgs.writeTextFile {
    name = "vikunja_common.py";
    text = builtins.readFile ./vikunja_common.py;
    destination = "/lib/python/vikunja_common.py";
  };

  # Python script for correlation repair (no flake8 checking)
  correlateScript = pkgs.writers.writePython3Bin "vikunja-sync-correlate" {
    libraries = with pkgs.python3Packages; [caldav pyyaml vobject];
    flakeIgnore = ["E501" "E265" "F541"];
  } (builtins.readFile ./correlate.py);

  # Python script for label/tag sync (Vikunja labels -> TW tags)
  labelSyncScript = pkgs.writers.writePython3Bin "vikunja-sync-labels" {
    flakeIgnore = ["E501" "E265"];
  } (builtins.readFile ./label-sync.py);

  # Direct-write sync script (instant webhook/hook handling)
  # Target latency: <100ms vs ~2000ms for full sync
  directSyncScript = pkgs.writers.writePython3Bin "vikunja-direct" {
    flakeIgnore = ["E501" "E265" "W503"];
  } (builtins.readFile ./vikunja-direct.py);

  # Retry queue processor script
  retryScript = pkgs.writers.writePython3Bin "vikunja-sync-retry" {
    flakeIgnore = ["E501" "E265"];
  } (builtins.readFile ./vikunja-sync-retry.py);

  # Main vikunja-sync shell script (for reconciliation/full sync)
  mainScript = pkgs.writeShellApplication {
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
  };
in
# Wrap Python scripts to add PYTHONPATH for vikunja_common module
pkgs.runCommand "vikunja-sync" {
  nativeBuildInputs = [ pkgs.makeWrapper ];
  meta = {
    description = "Bidirectional Taskwarrior <-> Vikunja sync with instant direct-write mode";
    mainProgram = "vikunja-sync";
  };
} ''
  mkdir -p $out/bin $out/lib/python

  # Copy shared module
  cp ${vikunjaCommonModule}/lib/python/vikunja_common.py $out/lib/python/

  # Link main script (shell, no wrapping needed)
  ln -s ${mainScript}/bin/vikunja-sync $out/bin/vikunja-sync

  # Wrap Python scripts with PYTHONPATH
  makeWrapper ${directSyncScript}/bin/vikunja-direct $out/bin/vikunja-direct \
    --prefix PYTHONPATH : "$out/lib/python"

  makeWrapper ${retryScript}/bin/vikunja-sync-retry $out/bin/vikunja-sync-retry \
    --prefix PYTHONPATH : "$out/lib/python"

  makeWrapper ${correlateScript}/bin/vikunja-sync-correlate $out/bin/vikunja-sync-correlate \
    --prefix PYTHONPATH : "$out/lib/python"

  makeWrapper ${labelSyncScript}/bin/vikunja-sync-labels $out/bin/vikunja-sync-labels \
    --prefix PYTHONPATH : "$out/lib/python"
''
