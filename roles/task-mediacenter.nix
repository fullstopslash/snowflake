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
  # Media imports
  imports = [
    ../modules/apps/media
    ../modules/services/audio
  ];

  # Mediacenter-specific config (only when role is enabled)
  config = lib.mkIf cfg.mediacenter {
    # Enable audio by default for media playback
    # (pipewire/pulseaudio handled by modules/services/audio)

    # Media consumption optimizations could go here
    # e.g., hardware video acceleration, codec support, etc.
  };
}
