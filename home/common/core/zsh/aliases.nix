{
  # Overrides those provided by OMZ libs, plugins, and themes.
  # For a full list of active aliases, run `alias`.

  #-------------Bat related------------
  cat = "bat --paging=never";
  diff = "batdiff";
  rg = "batgrep";
  man = "batman";

  #------------Navigation------------
  clr = "clear";
  rst = "reset";
  doc = "cd $HOME/documents";
  scripts = "cd $HOME/scripts";
  ts = "cd $HOME/.talon/user/fidget";
  src = "cd $HOME/src";
  edu = "cd $HOME/src/edu";
  wiki = "cd $HOME/sync/obsidian-vault-01/wiki";
  uc = "cd $HOME/src/unmoved-centre";
  l = "eza -lah";
  la = "eza -lah";
  ll = "eza -lh";
  ls = "eza";
  lsa = "eza -lah";

  #------------Nix config navigation------------
  # Primary config directories (nh uses ~/nix-config via NH_FLAKE)
  cnc = "cd $HOME/nix-config";
  cns = "cd $HOME/nix-secrets";
  # Secondary nix repos
  cnh = "cd $HOME/src/nix/nixos-hardware";
  cnp = "cd $HOME/src/nix/nixpkgs";

  #-----------Nix commands----------------
  nfc = "nix flake check";
  ne = "nix instantiate --eval";
  nb = "nix build";
  ns = "nix shell";

  #-------------justfiles---------------
  jr = "just rebuild";
  jrt = "just rebuild-trace";
  jl = "just --list";
  jc = "$just check";
  jct = "$just check-trace";

  #-------------Neovim---------------
  e = "nvim";
  vi = "nvim";
  vim = "nvim";

  #-------------SSH---------------
  ssh = "TERM=xterm ssh";

  #-------------rmtrash---------------
  # Path to real rm and rmdir in coreutils. This is so we can not use rmtrash for big files
  rrm = "/run/current-system/sw/bin/rm";
  rrmdir = "/run/current-system/sw/bin/rmdir";
  rm = "rmtrash";
  rmdir = "rmdirtrash";

  #-------------Git Goodness-------------
  # just reference `$ alias` and use the defaults, they're good.
}
