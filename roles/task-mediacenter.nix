# Mediacenter role - media consumption environment (composable task role)
#
# Can be combined with any hardware role: roles.desktop + roles.mediacenter
# Enables: Media playback apps, streaming clients, codecs
# Focus: Media consumption, not serving (server role handles serving)
#
# This is a task-based role, not mutually exclusive with hardware roles.
{ config, lib, ... }:
let
  cfg = config.roles;
in
{
  # Mediacenter-specific config (only when role is enabled)
  config = lib.mkIf cfg.mediacenter {
    # Enable media apps
    myModules.apps.media.enable = lib.mkDefault true;

    # Note: Audio is handled by modules/services/audio which is imported globally
    # in roles/common.nix. PipeWire/PulseAudio will be configured automatically.

    # Media consumption optimizations could go here
    # e.g., hardware video acceleration, codec support, etc.
  };
}
