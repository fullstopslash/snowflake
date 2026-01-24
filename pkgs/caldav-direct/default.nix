{
  pkgs,
  lib,
  ...
}:
let
  # Direct CalDAV sync script (instant TW -> CalDAV writes)
  # Target latency: <200ms vs ~2000ms for full sync
  directScript = pkgs.writers.writePython3Bin "caldav-direct" {
    libraries = with pkgs.python3Packages; [caldav icalendar vobject];
    flakeIgnore = ["E501" "E265" "W503"];
  } (builtins.readFile ./caldav-direct.py);
in
pkgs.symlinkJoin {
  name = "caldav-direct";
  paths = [directScript];
  meta = {
    description = "Direct CalDAV sync for Taskwarrior - instant TW -> CalDAV writes";
    mainProgram = "caldav-direct";
  };
}
