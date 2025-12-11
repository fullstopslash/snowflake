# Document processing role for wiki Makefile
{ config, lib, pkgs, ... }:
let
  cfg = config.myModules.apps.development.documentProcessing;
in
{
  options.myModules.apps.development.documentProcessing = {
    enable = lib.mkEnableOption "Document processing tools (pandoc, texlive, typst)";
  };

  config = lib.mkIf cfg.enable {
    # Document processing packages for wiki Makefile
    environment.systemPackages = with pkgs; [
    # Pandoc - Universal document converter
    pandoc

    # Poppler tools - PDF utilities (pdfinfo, pdftoppm, etc.)
    poppler-utils

    # Typst a LaTeX alternative
    typst
    typstwriter
    typstyle
    typst-live
    tinymist

    # Tectonic - Modern LaTeX compiler
    tectonic
    texlive.combined.scheme-full

    # Explicitly include LuaLaTeX math package
    texlivePackages.lualatex-math

    # Additional LuaLaTeX packages
    texlivePackages.luatex
    texlivePackages.luatexbase
    texlivePackages.lualibs

    # Additional commonly used LaTeX packages
    texlivePackages.catchfile
    texlivePackages.inconsolata-nerd-font
    texlivePackages.etoolbox
    texlivePackages.fontspec
    texlivePackages.unicode-math
    texlivePackages.polyglossia

    # SVG support (without emoji package)
    texlivePackages.svg

    # Graphviz - For dot command (SVG generation)
    graphviz

    # YAML processing
    yq-go

    # Pandoc filters
    pandoc-include

    # Image processing for diagrams
    imagemagick
    inkscape

    # PlantUML for UML diagrams
    plantuml

    # Additional text processing
    asciidoctor

    # File watching for automatic rebuilds
    entr

    # Additional utilities
    ghostscript
    qpdf
    pdf2svg
  ];
  };
}
