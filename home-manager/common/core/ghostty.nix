{ ... }:
{
  programs.ghostty = {
    enable = true;
    settings = {
      scrollback-limit = 10000;
      #NOTE(ghostty): not using ghostty for splits or tabs so nearly all default binds conflict Hypr, nvim, or zellij
      keybind = [
        "ctrl+shift+d=inspector:toggle"
        "ctrl+shift+c=copy_to_clipboard"
        "ctrl+shift+v=paste_from_clipboard"
        # Fix fixterm conflict with zsh ^[ character https://github.com/ghostty-org/ghostty/discussions/5071
        "ctrl+left_bracket=text:\\x1b"
        "ctrl+shift+minus=decrease_font_size:1"
        "ctrl+shift+plus=increase_font_size:1"
        "ctrl+shift+0=reset_font_size"
        #
        # ========== UNBIND ==========
        #
        "ctrl+shift+e=unbind" # new_split
        "ctrl+shift+n=unbind" # new_window
        "ctrl+shift+t=unbind" # new_tab
      ];
    };
  };
}
