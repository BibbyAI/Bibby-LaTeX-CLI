# shellcheck shell=bash
# profiles.sh - what "minimal / standard / full" actually means.

# TinyTeX add-on packages per profile. Installed with tlmgr.
PROFILE_MINIMAL_PKGS="latexmk xcolor geometry hyperref booktabs enumitem"

PROFILE_STANDARD_PKGS="latexmk collection-fontsrecommended collection-latexrecommended \
amsmath amsfonts amscls xcolor geometry hyperref booktabs enumitem caption subcaption \
graphics float microtype titlesec fancyhdr natbib biblatex biber csquotes \
algorithms algorithm2e algorithmicx listings minted fvextra upquote \
siunitx cleveref todonotes pgf pgfplots tikz-cd standalone \
multirow tabularx threeparttable wrapfig lipsum mathtools bm \
import xstring etoolbox environ trimspaces ulem soul"

# Conference / journal classes people actually hit a wall on.
PROFILE_PAPER_PKGS="revtex4-1 revtex acmart ieeetran elsarticle llncs \
achemso apa7 biblatex-apa times txfonts newtx fontawesome5 orcidlink"

profile_packages() {
  case "$1" in
    minimal)  printf '%s' "$PROFILE_MINIMAL_PKGS" ;;
    standard) printf '%s %s' "$PROFILE_MINIMAL_PKGS" "$PROFILE_STANDARD_PKGS" ;;
    full)     printf '%s %s %s' "$PROFILE_MINIMAL_PKGS" "$PROFILE_STANDARD_PKGS" "$PROFILE_PAPER_PKGS" ;;
    *)        printf '%s' "$PROFILE_MINIMAL_PKGS" ;;
  esac
}

profile_label() {
  case "$1" in
    minimal)  printf '%s' "minimal    ~200 MB   TinyTeX + the basics, pulls packages on demand" ;;
    standard) printf '%s' "standard   ~1.2 GB   everything a thesis or paper normally needs (recommended)" ;;
    full)     printf '%s' "full       ~2.5 GB   standard + journal/conference classes (ACM, IEEE, Springer, APA)" ;;
  esac
}

# Debian/Fedora/Arch system package names per profile, for people who insist
# on the distro TeX Live instead of TinyTeX.
system_tex_packages() {
  local profile="$1"
  case "$BIBBY_DISTRO" in
    debian)
      case "$profile" in
        minimal)  printf '%s' "texlive-latex-base texlive-latex-recommended latexmk" ;;
        standard) printf '%s' "texlive-latex-base texlive-latex-recommended texlive-latex-extra texlive-fonts-recommended texlive-science latexmk biber" ;;
        full)     printf '%s' "texlive-full latexmk biber" ;;
      esac ;;
    fedora)
      case "$profile" in
        minimal)  printf '%s' "texlive-scheme-basic latexmk" ;;
        standard) printf '%s' "texlive-scheme-medium latexmk biber" ;;
        full)     printf '%s' "texlive-scheme-full latexmk biber" ;;
      esac ;;
    arch)
      case "$profile" in
        minimal)  printf '%s' "texlive-basic texlive-binextra" ;;
        standard) printf '%s' "texlive-basic texlive-latex texlive-latexrecommended texlive-latexextra texlive-fontsrecommended texlive-binextra texlive-bibtexextra biber" ;;
        full)     printf '%s' "texlive-meta biber" ;;
      esac ;;
    suse)
      printf '%s' "texlive-latex texlive-latexmk biber" ;;
    alpine)
      printf '%s' "texlive texlive-luatex texmf-dist-latexextra" ;;
    *) return 1 ;;
  esac
}
