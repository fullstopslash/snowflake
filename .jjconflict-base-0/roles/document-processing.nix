# Document processing role for wiki Makefile
{pkgs, ...}: {
  # Document processing packages for wiki Makefile
  environment.systemPackages = with pkgs; [
    # Pandoc - Universal document converter
    pandoc

    # Poppler tools - PDF utilities (pdfinfo, pdftoppm, etc.)
    poppler_utils

    # Typst a LaTeX alternative
    typst
    typstwriter
    typstyle
    typstfmt
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
}
