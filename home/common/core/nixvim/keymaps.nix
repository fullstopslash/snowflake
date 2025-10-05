{
  programs.nixvim = {
    globals.mapleader = ";";
    #
    # ========== Modes Legend ==========
    #
    #    "n" Normal mode
    #    "i" Insert mode
    #    "v" Visual and Select mode
    #    "s" Select mode
    #    "t" Terminal mode
    #    ""  Normal, visual, select and operator-pending mode
    #    "x" Visual mode only, without select
    #    "o" Operator-pending mode
    #    "!" Insert and command-line mode
    #    "l" Insert, command-line and lang-arg mode
    #    "c" Command-line mode
    keymaps = [
      #
      # ========== Nixvim Config Shortcuts ==========
      #
      {
        mode = [ "n" ];
        key = "<Leader>ve";
        action = "<cmd>e ~/src/nix/nix-config/home/common/core/nixvim/default.nix<CR>";
        options = {
          desc = "Edit nix-config/home/common/core/nixvim/default.nix";
          noremap = true;
        };
      }
      # This is disabled because for some unknown reason nixvim doesn't symlink to .vimrc
      #{
      #  mode = [ "n" ];
      #  key = "<Leader>vr";
      #  action = "<cmd>so $MYVIMRC<CR>";
      #  options = {
      #     desc = "Reload vimrc";
      #     noremap = true;
      #  };
      #}

      #
      # ======== Movement ========
      #
      {
        mode = [ "n" ];
        key = "j";
        action = "gj";
        options = {
          desc = "Move down through wrapped lines";
          noremap = true;
        };
      }
      {
        mode = [ "n" ];
        key = "k";
        action = "gk";
        options = {
          desc = "Move up through wrapped lines";
          noremap = true;
        };
      }
      {
        mode = [ "n" ];
        key = "<C-j>";
        action = "<C-d>";
        options = {
          desc = "Add bind for 1/2 page down";
          noremap = true;
        };
      }
      {
        mode = [ "n" ];
        key = "<C-k>";
        action = "<C-u>";
        options = {
          desc = "Add bind for 1/2 page up";
          noremap = true;
        };
      }
      #      {
      #        mode = [ "n" ];
      #        key = "E";
      #        action = "$";
      #        options = {
      #          desc = "Add bind for move to end of line";
      #          noremap = true;
      #        };
      #      }
      # {
      #   # disable default move to beginning/end of line
      #   mode = ["n"];
      #   key = "$";
      #   action = "<nop>";
      # }
      #

      #
      # ======== Buffer navigation ========
      #
      {
        mode = [ "n" ];
        key = "<Leader>-";
        action = ":b#<CR>";
        options = {
          desc = "Switch to the previous buffer";
          noremap = true;
        };
      }

      #
      # ======== Window navigation ========
      #
      {
        mode = [ "n" ];
        key = "<Leader>h";
        action = "<C-W>h";
        options = {
          desc = "Move the cursor one window left";
          noremap = true;
        };
      }
      {
        mode = [ "n" ];
        key = "<Leader>j";
        action = "<C-W>j";
        options = {
          desc = "Move the cursor window down";
          noremap = true;
        };
      }
      {
        mode = [ "n" ];
        key = "<Leader>k";
        action = "<C-W>k";
        options = {
          desc = "Move the cursor window up";
          noremap = true;
        };
      }
      {
        mode = [ "n" ];
        key = "<Leader>l";
        action = "<C-W>l";
        options = {
          desc = "Move the cursor window right";
          noremap = true;
        };
      }
      #
      # =========== Search=========
      #
      {
        mode = [ "n" ];
        key = "<space><space>";
        action = "<cmd>nohlsearch<CR>";
        options = {
          desc = "Clear search highlighting";
          noremap = true;
        };
      }
      #
      # =========== Editing =========
      #
      {
        mode = [ "n" ];
        key = "<Leader>sr";
        action = ":%s/<C-r><C-w>//g<Left><Left>";
        options = {
          desc = "Substitute the word you are currently on";
          noremap = true;
        };
      }
      #
      # =========== sudo Save =========
      #
      {
        mode = [ "c" ];
        key = "w!!";
        action = "<cmd>w !sudo tee > /dev/null %<CR>";
        options = {
          desc = "Performs `sudo save` on privleged files";
          noremap = true;
        };
      }

      #
      # =========== Undo and Redo =========
      #
      {
        mode = [ "i" ];
        key = ",";
        action = ",<C-g>U";
        options = {
          desc = "Update undo when , operator is used in Insert mode";
          noremap = true;
        };
      }
      {
        mode = [ "i" ];
        key = ".";
        action = ".<C-g>U";
        options = {
          desc = "Update undo when . operator is used in Insert mode";
          noremap = true;
        };
      }
      {
        mode = [ "i" ];
        key = "!";
        action = "!<C-g>U";
        options = {
          desc = "Update undo when ! operator is used in Insert mode";
          noremap = true;
        };
      }
      {
        mode = [ "i" ];
        key = "?";
        action = "?<C-g>U";
        options = {
          desc = "Update undo when ? operator is used in Insert mode";
          noremap = true;
        };
      }
      #
      # ========= Twiggy =============
      #
      {
        mode = [ "n" ];
        key = "<Leader>tw";
        action = ":Twiggy<CR>";
        options = {
          desc = "toggle display twiggy";
          noremap = true;
        };
      }
      #
      # ======== Zen ========
      #
      {
        mode = [ "n" ];
        key = "<Leader>zz";
        action = ":ZenMode<CR>";
        options = {
          desc = "toggle ZenMode";
          noremap = true;
        };
      }
    ];
  };
}
