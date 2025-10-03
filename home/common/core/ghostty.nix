{ ... }:
{
  programs.ghostty = {
    enable = true;
    clearDefaultKeybinds = true;
    settings = {
      scrollback-limit = 10000;
      #NOTE(ghostty): not using ghostty for splits or tabs so nearly all default binds conflict Hypr, nvim, or zellij
      keybind = [
        "ctrl+shift+d=inspector:toggle"
        "ctrl+shift+c=copy_to_clipboard"
        "ctrl+shift+v=paste_from_clipboard"
        # Fix fixterm conflict with zsh ^[ character https://github.com/ghostty-org/ghostty/discussions/5071
        "ctrl+left_bracket=text:\\x1b"
      ];
    };
  };
}
