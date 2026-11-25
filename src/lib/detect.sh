# shellcheck shell=bash
# detect.sh - platform, package manager, existing TeX and editors.

has() { command -v "$1" >/dev/null 2>&1; }

detect_os() {
  case "$(uname -s)" in
    Darwin) BIBBY_OS="macos" ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then BIBBY_OS="wsl"; else BIBBY_OS="linux"; fi
      ;;
    MINGW*|MSYS*|CYGWIN*) BIBBY_OS="windows" ;;
    *) BIBBY_OS="unknown" ;;
  esac
  BIBBY_ARCH="$(uname -m)"
  export BIBBY_OS BIBBY_ARCH
}

detect_distro() {
  BIBBY_DISTRO="unknown"; BIBBY_DISTRO_NAME="unknown"
  if [ "$BIBBY_OS" = "macos" ]; then
    BIBBY_DISTRO="macos"; BIBBY_DISTRO_NAME="macOS $(sw_vers -productVersion 2>/dev/null || echo '')"
  elif [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    BIBBY_DISTRO_NAME="${PRETTY_NAME:-$ID}"
    case "${ID_LIKE:-$ID}" in
      *debian*|*ubuntu*) BIBBY_DISTRO="debian" ;;
      *fedora*|*rhel*|*centos*) BIBBY_DISTRO="fedora" ;;
      *arch*) BIBBY_DISTRO="arch" ;;
      *suse*) BIBBY_DISTRO="suse" ;;
      *alpine*) BIBBY_DISTRO="alpine" ;;
      *) case "$ID" in
           debian|ubuntu|pop|linuxmint|elementary) BIBBY_DISTRO="debian" ;;
           fedora|rhel|centos|rocky|almalinux) BIBBY_DISTRO="fedora" ;;
           arch|manjaro|endeavouros) BIBBY_DISTRO="arch" ;;
           opensuse*|sles) BIBBY_DISTRO="suse" ;;
           alpine) BIBBY_DISTRO="alpine" ;;
         esac ;;
    esac
  fi
  export BIBBY_DISTRO BIBBY_DISTRO_NAME
}

detect_sudo() {
  BIBBY_SUDO=""
  if [ "$(id -u)" -ne 0 ]; then
    if has sudo; then BIBBY_SUDO="sudo"; elif has doas; then BIBBY_SUDO="doas"; fi
  fi
  export BIBBY_SUDO
}

# system package install, best effort
sys_install() {
  local pkgs=("$@")
  case "$BIBBY_DISTRO" in
    macos)  has brew && brew install "${pkgs[@]}" ;;
    debian) $BIBBY_SUDO apt-get update -qq && DEBIAN_FRONTEND=noninteractive $BIBBY_SUDO apt-get install -y "${pkgs[@]}" ;;
    fedora) $BIBBY_SUDO dnf install -y "${pkgs[@]}" ;;
    arch)   $BIBBY_SUDO pacman -Sy --noconfirm --needed "${pkgs[@]}" ;;
    suse)   $BIBBY_SUDO zypper --non-interactive install "${pkgs[@]}" ;;
    alpine) $BIBBY_SUDO apk add --no-cache "${pkgs[@]}" ;;
    *) return 1 ;;
  esac
}

# Finds a TeX installation even when PATH has not been reloaded yet.
detect_tex() {
  BIBBY_TEX_KIND="none"; BIBBY_TEX_BIN=""; BIBBY_TEX_VERSION=""

  local candidates=()
  has pdflatex && candidates+=("$(command -v pdflatex)")
  for p in \
    "$HOME/.TinyTeX/bin"/*/pdflatex \
    "$HOME/Library/TinyTeX/bin"/*/pdflatex \
    /Library/TeX/texbin/pdflatex \
    /usr/local/texlive/*/bin/*/pdflatex \
    /opt/texlive/*/bin/*/pdflatex \
    /usr/bin/pdflatex
  do
    [ -x "$p" ] && candidates+=("$p")
  done

  [ "${#candidates[@]}" -eq 0 ] && return 1

  BIBBY_TEX_BIN="$(dirname "${candidates[0]}")"
  BIBBY_TEX_VERSION="$("${candidates[0]}" --version 2>/dev/null | head -n1)"

  case "$BIBBY_TEX_BIN" in
    *TinyTeX*) BIBBY_TEX_KIND="tinytex" ;;
    */Library/TeX/*) BIBBY_TEX_KIND="mactex" ;;
    *) case "$BIBBY_TEX_VERSION" in
         *MiKTeX*) BIBBY_TEX_KIND="miktex" ;;
         *) BIBBY_TEX_KIND="texlive" ;;
       esac ;;
  esac
  export BIBBY_TEX_KIND BIBBY_TEX_BIN BIBBY_TEX_VERSION
  return 0
}

detect_editor() {
  BIBBY_CODE_CLI=""
  for c in code code-insiders cursor windsurf codium vscodium; do
    if has "$c"; then BIBBY_CODE_CLI="$c"; break; fi
  done
  # macOS app bundle without the shell command on PATH
  if [ -z "$BIBBY_CODE_CLI" ] && [ "$BIBBY_OS" = "macos" ]; then
    local b="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
    [ -x "$b" ] && BIBBY_CODE_CLI="$b"
  fi
  export BIBBY_CODE_CLI
}

vscode_user_dir() {
  case "$BIBBY_OS" in
    macos) printf '%s' "$HOME/Library/Application Support/Code/User" ;;
    windows) printf '%s' "${APPDATA:-$HOME/AppData/Roaming}/Code/User" ;;
    *) printf '%s' "${XDG_CONFIG_HOME:-$HOME/.config}/Code/User" ;;
  esac
}

shell_rc() {
  case "$(basename "${SHELL:-/bin/bash}")" in
    zsh)  printf '%s' "$HOME/.zshrc" ;;
    fish) printf '%s' "$HOME/.config/fish/config.fish" ;;
    *)    if [ -f "$HOME/.bash_profile" ] && [ "$BIBBY_OS" = "macos" ]; then
            printf '%s' "$HOME/.bash_profile"
          else
            printf '%s' "$HOME/.bashrc"
          fi ;;
  esac
}
