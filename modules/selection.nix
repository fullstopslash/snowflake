# Unified Module Selection System
#
# This module provides list-based selection for modules, enabling:
# - LSP autocompletion via lib.types.enum
# - Unified syntax for roles and hosts
# - Automatic translation to myModules.*.enable flags
#
# Usage:
#   modules.desktop = [ "hyprland" "wayland" ];
#   modules.apps = [ "media" "gaming" ];
#   modules.development = [ "latex" "containers" ];
#
# Roles set defaults with lib.mkDefault, hosts can override.
#
{ config, lib, ... }:
let
  cfg = config.modules;

  # Helper to check if a module is selected
  isSelected = category: name: builtins.elem name cfg.${category};

  # ========================================
  # AVAILABLE MODULE ENUMS
  # ========================================
  # These define what values are valid for each selection category.
  # LSP will autocomplete these values.

  desktopModules = [
    "plasma"
    "hyprland"
    "niri"
    "wayland"
    "common"
    "waybar"
  ];

  displayManagerModules = [
    "ly"
    "greetd"
  ];

  # App categories (top-level myModules.apps.*)
  appModules = [
    "media"
    "gaming"
    "comms"
    "productivity"
    "browsers"
    "editors"
  ];

  # CLI tools (myModules.apps.cli.*)
  cliModules = [
    "shell"
    "tools"
    "zellij"
  ];

  # Development tools (myModules.apps.development.* and myModules.services.development.*)
  developmentModules = [
    "latex"
    "document-processing"
    "tools"
    "containers"
    "neovim"
    "rust"
  ];

  # Services (various myModules.services.*)
  serviceModules = [
    "atuin"
    "syncthing"
    "tailscale"
    "flatpak"
    "openssh"
    "ssh"
    "ollama"
    "clamav"
    "auto-upgrade"
  ];

  # Audio services (myModules.services.audio.*)
  audioModules = [
    "pipewire"
    "easyeffects"
    "tools"
  ];

  # AI tools (myModules.apps.ai.* and myModules.services.ai.*)
  aiModules = [
    "ollama"
    "crush"
    "voice-assistant"
  ];

  # Security tools (myModules.apps.security.*)
  securityModules = [
    "secrets"
    "clamav"
    "yubikey"
    "bitwarden"
  ];

in
{
  # ========================================
  # SELECTION OPTIONS
  # ========================================

  options.modules = {
    desktop = lib.mkOption {
      type = lib.types.listOf (lib.types.enum desktopModules);
      default = [ ];
      description = "Desktop environments and window managers to enable";
      example = [ "hyprland" "wayland" ];
    };

    displayManager = lib.mkOption {
      type = lib.types.listOf (lib.types.enum displayManagerModules);
      default = [ ];
      description = "Display managers to enable";
      example = [ "ly" ];
    };

    apps = lib.mkOption {
      type = lib.types.listOf (lib.types.enum appModules);
      default = [ ];
      description = "Application categories to enable";
      example = [ "media" "gaming" "browsers" ];
    };

    cli = lib.mkOption {
      type = lib.types.listOf (lib.types.enum cliModules);
      default = [ ];
      description = "CLI tools and shell configuration to enable";
      example = [ "shell" "tools" ];
    };

    development = lib.mkOption {
      type = lib.types.listOf (lib.types.enum developmentModules);
      default = [ ];
      description = "Development tools to enable";
      example = [ "latex" "containers" ];
    };

    services = lib.mkOption {
      type = lib.types.listOf (lib.types.enum serviceModules);
      default = [ ];
      description = "System services to enable";
      example = [ "atuin" "syncthing" "tailscale" ];
    };

    audio = lib.mkOption {
      type = lib.types.listOf (lib.types.enum audioModules);
      default = [ ];
      description = "Audio services and tools to enable";
      example = [ "pipewire" "easyeffects" ];
    };

    ai = lib.mkOption {
      type = lib.types.listOf (lib.types.enum aiModules);
      default = [ ];
      description = "AI tools and services to enable";
      example = [ "ollama" ];
    };

    security = lib.mkOption {
      type = lib.types.listOf (lib.types.enum securityModules);
      default = [ ];
      description = "Security tools to enable";
      example = [ "secrets" "yubikey" ];
    };
  };

  # ========================================
  # TRANSLATION LAYER
  # ========================================
  # Converts list selections to myModules.*.enable flags

  config = {
    # Desktop modules -> myModules.desktop.*
    myModules.desktop.plasma.enable = lib.mkIf (isSelected "desktop" "plasma") true;
    myModules.desktop.hyprland.enable = lib.mkIf (isSelected "desktop" "hyprland") true;
    myModules.desktop.niri.enable = lib.mkIf (isSelected "desktop" "niri") true;
    myModules.desktop.wayland.enable = lib.mkIf (isSelected "desktop" "wayland") true;
    myModules.desktop.common.enable = lib.mkIf (isSelected "desktop" "common") true;

    # Display managers -> myModules.displayManager.*
    myModules.displayManager.ly.enable = lib.mkIf (isSelected "displayManager" "ly") true;
    myModules.displayManager.greetd.enable = lib.mkIf (isSelected "displayManager" "greetd") true;

    # App categories -> myModules.apps.*
    myModules.apps.media.enable = lib.mkIf (isSelected "apps" "media") true;
    myModules.apps.gaming.enable = lib.mkIf (isSelected "apps" "gaming") true;
    myModules.apps.comms.enable = lib.mkIf (isSelected "apps" "comms") true;
    myModules.apps.productivity.enable = lib.mkIf (isSelected "apps" "productivity") true;

    # CLI tools -> myModules.apps.cli.*
    myModules.apps.cli.shell.enable = lib.mkIf (isSelected "cli" "shell") true;
    myModules.apps.cli.tools.enable = lib.mkIf (isSelected "cli" "tools") true;
    myModules.apps.cli.zellij.enable = lib.mkIf (isSelected "cli" "zellij") true;

    # Development -> myModules.apps.development.* and myModules.services.development.*
    myModules.apps.development.latex.enable = lib.mkIf (isSelected "development" "latex") true;
    myModules.apps.development.documentProcessing.enable = lib.mkIf (isSelected "development" "document-processing") true;
    myModules.apps.development.tools.enable = lib.mkIf (isSelected "development" "tools") true;
    myModules.services.development.containers.enable = lib.mkIf (isSelected "development" "containers") true;

    # Services -> myModules.services.*
    myModules.services.atuin.enable = lib.mkIf (isSelected "services" "atuin") true;
    myModules.services.syncthing.enable = lib.mkIf (isSelected "services" "syncthing") true;
    myModules.services.tailscale.enable = lib.mkIf (isSelected "services" "tailscale") true;
    myModules.services.flatpak.enable = lib.mkIf (isSelected "services" "flatpak") true;
    myModules.networking.openssh.enable = lib.mkIf (isSelected "services" "openssh") true;
    myModules.networking.ssh.enable = lib.mkIf (isSelected "services" "ssh") true;
    myModules.services.autoUpgrade.enable = lib.mkIf (isSelected "services" "auto-upgrade") true;
    myModules.services.security.clamav.enable = lib.mkIf (isSelected "services" "clamav") true;

    # Audio -> myModules.services.audio.*
    myModules.services.audio.pipewire.enable = lib.mkIf (isSelected "audio" "pipewire") true;
    myModules.services.audio.easyeffects.enable = lib.mkIf (isSelected "audio" "easyeffects") true;
    myModules.services.audio.tools.enable = lib.mkIf (isSelected "audio" "tools") true;

    # AI -> myModules.services.ai.* and myModules.apps.ai.*
    myModules.services.ai.ollama.enable = lib.mkIf (isSelected "ai" "ollama") true;
    myModules.apps.ai.crush.enable = lib.mkIf (isSelected "ai" "crush") true;
    myModules.apps.ai.voiceAssistant.enable = lib.mkIf (isSelected "ai" "voice-assistant") true;

    # Security -> myModules.apps.security.* and myModules.services.security.*
    myModules.apps.security.secrets.enable = lib.mkIf (isSelected "security" "secrets") true;
  };
}
