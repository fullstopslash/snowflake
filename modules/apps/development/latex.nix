# LaTeX role
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.apps.development.latex;

  latex-fhs = pkgs.buildFHSEnv {
    name = "latex-env";

    targetPkgs =
      pkgs: with pkgs; [
        # Build tools
        gnumake
        gcc

        # TeXLive infrastructure and tools
        perl
        wget
        curl
        gnutar
        gzip
        fontconfig

        # Python for some LaTeX tools
        python3

        # Additional utilities
        which
        file
        ghostscript

        # Optional: Add more tools based on your needs
        git
        vim

        # Optional: minimal texlive base (uncomment if desired)
        # texlive.combined.scheme-infraonly
      ];

    # Set up environment for tlmgr
    profile = ''
      export TEXLIVE_INSTALL_PREFIX=$HOME/texlive
      export PATH="$TEXLIVE_INSTALL_PREFIX/bin/x86_64-linux:$PATH"

      # Create texlive directory if it doesn't exist
      mkdir -p $TEXLIVE_INSTALL_PREFIX

      # Function to install TeXLive if not present
      install_texlive() {
        if [ ! -d "$TEXLIVE_INSTALL_PREFIX/bin" ]; then
          echo "TeXLive not found. Installing..."
          cd /tmp
          wget -q https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz
          tar -xzf install-tl-unx.tar.gz
          cd install-tl-*
          ./install-tl --no-gui --profile=<(echo "selected_scheme scheme-basic")
          echo "TeXLive installed! You can now use tlmgr."
        fi
      }

      echo "LaTeX FHS Environment loaded!"
      echo "Run 'install_texlive' to install TeXLive if not already present"
      echo "TeXLive will be installed to: $TEXLIVE_INSTALL_PREFIX"
    '';

    runScript = "bash";
  };
in
{
  options.myModules.apps.development.latex = {
    enable = lib.mkEnableOption "LaTeX development environment";
  };

  config = lib.mkIf cfg.enable {
    # Make the latex-env command available system-wide
    environment = {
      systemPackages = [ latex-fhs ];
      shellAliases = {
        latex-env = "${latex-fhs}/bin/latex-env";
      };
      etc."latex-env-help".text = ''
        LaTeX FHS Environment Help
        ==========================

        To enter the LaTeX environment: latex-env

        First time setup:
        1. Run: latex-env
        2. Inside the environment: install_texlive
        3. Use tlmgr normally: tlmgr install <package>

        The environment includes:
        - GNU Make
        - GCC compiler
        - Perl, Python3
        - wget, curl, tar, gzip
        - ghostscript
        - fontconfig

        TeXLive will be installed to: $HOME/texlive
      '';
    };
  };
}
