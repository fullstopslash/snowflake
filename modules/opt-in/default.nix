# Registry of opt-in modules that hosts can explicitly import
# Returns an attrset of paths to role modules
{
  # AI and Development Tools
  ai-tools = ../../roles/ai-tools.nix;
  development = ../../roles/development.nix;
  neovim = ../../roles/neovim.nix;

  # Desktop Environments
  desktop = ../../roles/desktop.nix;
  hyprland = ../../roles/hyprland.nix;
  plasma = ../../roles/plasma.nix;
  niri = ../../roles/niri.nix;
  greetd = ../../roles/greetd.nix;
  flatpak = ../../roles/flatpak.nix;
  waybar = ../../roles/waybar.nix;

  # Gaming and Media
  gaming = ../../roles/gaming.nix;
  media = ../../roles/media.nix;
  obs = ../../roles/obs.nix;
  audio-tuning = ../../roles/audio-tuning.nix;

  # Networking
  networking = ../../roles/networking.nix;
  tailscale = ../../roles/tailscale.nix;
  vpn = ../../roles/vpn.nix;
  sinkzone = ../../roles/sinkzone.nix;
  network-storage = ../../roles/network-storage.nix;
  syncthing = ../../roles/syncthing.nix;

  # System Tools
  containers = ../../roles/containers.nix;
  quickemu = ../../roles/quickemu.nix;
  ollama = ../../roles/ollama.nix;

  # CLI and Shell
  cli-tools = ../../roles/cli-tools.nix;
  shell = ../../roles/shell.nix;
  atuin = ../../roles/atuin.nix;

  # Utilities
  bitwarden-automation = ../../roles/bitwarden-automation.nix;
  document-processing = ../../roles/document-processing.nix;
  secrets = ../../roles/secrets.nix;
  fonts = ../../roles/fonts.nix;
  stylix = ../../roles/stylix.nix;

  # Specialized
  rust-packages = ../../roles/rust-packages.nix;
  latex = ../../roles/latex.nix;
  crush = ../../roles/crush.nix;
  moondeck-buddy = ../../roles/moondeck-buddy.nix;
  voice-assistant = ../../roles/voice-assistant.nix;
}
