#!/usr/bin/env bash
# bibby-latex - one command, working LaTeX. Local, VS Code, Colab, Kaggle.
set -uo pipefail

BIBBY_VERSION="1.0.0"
BIBBY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

# shellcheck source=lib/ui.sh
. "$BIBBY_ROOT/src/lib/ui.sh"
# shellcheck source=lib/detect.sh
. "$BIBBY_ROOT/src/lib/detect.sh"
# shellcheck source=lib/profiles.sh
. "$BIBBY_ROOT/src/lib/profiles.sh"
# shellcheck source=lib/tex.sh
. "$BIBBY_ROOT/src/lib/tex.sh"
# shellcheck source=lib/vscode.sh
. "$BIBBY_ROOT/src/lib/vscode.sh"
# shellcheck source=lib/cloud.sh
. "$BIBBY_ROOT/src/lib/cloud.sh"
# shellcheck source=lib/doctor.sh
. "$BIBBY_ROOT/src/lib/doctor.sh"

# ---------------------------------------------------------------- defaults ---
BIBBY_ASSUME_YES=0
BIBBY_VERBOSE=0
BIBBY_PROFILE=""
BIBBY_BACKEND=""          # tinytex | system | mactex
BIBBY_DO_VSCODE=""
BIBBY_DO_EXTRAS=0
BIBBY_DO_CLOUD=""
BIBBY_DO_SCAFFOLD=""
BIBBY_FORCE_SETTINGS=0
BIBBY_MODE="install"      # install | doctor | vscode-only | cloud-only | uninstall
BIBBY_PATH_CHANGED=0

usage() {
  cat <<EOF
${C_BOLD}bibby-latex${C_RESET} v$BIBBY_VERSION

  One command to get LaTeX working: locally, in VS Code, on Colab and Kaggle.

${C_BOLD}usage${C_RESET}
  bibby-latex [options]

${C_BOLD}options${C_RESET}
  -y, --yes                 accept every default, no questions
      --profile=NAME        minimal | standard | full
      --backend=NAME        tinytex | system | mactex
      --no-vscode           skip the VS Code setup
      --extras              also install spell check + grammar extensions
      --cloud               write the Colab/Kaggle notebook setup here
      --scaffold[=DIR]      create main.tex, .latexmkrc, .vscode in DIR
      --force-settings      overwrite conflicting VS Code settings
      --vscode-only         only do the VS Code part
      --cloud-only          only print/write the cloud setup
      --doctor              diagnose an existing install and test-compile
      --uninstall           remove TinyTeX and the PATH entry bibby added
  -v, --verbose             show every command
  -V, --version             print version
  -h, --help                this

${C_BOLD}examples${C_RESET}
  curl -fsSL https://raw.githubusercontent.com/trybibby/bibby-latex/main/install.sh | bash
  curl -fsSL https://raw.githubusercontent.com/trybibby/bibby-latex/main/install.sh | bash -s -- --yes --profile=full
  bibby-latex --doctor
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -y|--yes)          BIBBY_ASSUME_YES=1 ;;
    -v|--verbose)      BIBBY_VERBOSE=1 ;;
    -V|--version)      printf '%s\n' "$BIBBY_VERSION"; exit 0 ;;
    -h|--help)         usage; exit 0 ;;
    --profile=*)       BIBBY_PROFILE="${1#*=}" ;;
    --backend=*)       BIBBY_BACKEND="${1#*=}" ;;
    --no-vscode)       BIBBY_DO_VSCODE=0 ;;
    --extras)          BIBBY_DO_EXTRAS=1 ;;
    --cloud)           BIBBY_DO_CLOUD=1 ;;
    --scaffold)        BIBBY_DO_SCAFFOLD="$PWD" ;;
    --scaffold=*)      BIBBY_DO_SCAFFOLD="${1#*=}" ;;
    --force-settings)  BIBBY_FORCE_SETTINGS=1 ;;
    --vscode-only)     BIBBY_MODE="vscode-only" ;;
    --cloud-only)      BIBBY_MODE="cloud-only" ;;
    --doctor)          BIBBY_MODE="doctor" ;;
    --uninstall)       BIBBY_MODE="uninstall" ;;
    *) err "unknown option: $1"; echo; usage; exit 2 ;;
  esac
  shift
done

export BIBBY_ASSUME_YES BIBBY_VERBOSE BIBBY_VERSION BIBBY_ROOT

# ------------------------------------------------------------------ modes ---
detect_os
detect_distro
detect_sudo
detect_editor

case "$BIBBY_MODE" in
  doctor)
    banner; run_doctor; exit $? ;;
  vscode-only)
    banner
    detect_tex >/dev/null 2>&1
    install_vscode_extensions "$BIBBY_DO_EXTRAS" 1
    write_vscode_settings "$BIBBY_FORCE_SETTINGS"
    exit 0 ;;
  cloud-only)
    banner; setup_cloud "$PWD"; exit 0 ;;
  uninstall)
    banner
    step "Uninstalling"
    if ask_yes_no "Remove ~/.TinyTeX and the PATH line bibby added?" n; then
      rm -rf "$HOME/.TinyTeX" "$HOME/Library/TinyTeX"
      rc="$(shell_rc)"
      if [ -f "$rc" ]; then
        tmp="$(mktemp)"
        grep -v -e '# bibby-latex: TeX PATH' -e 'TinyTeX/bin' "$rc" > "$tmp" && mv "$tmp" "$rc"
      fi
      ok "removed TinyTeX and cleaned $rc"
      say "VS Code extensions were left alone, remove them from the editor."
    else
      skip "nothing removed"
    fi
    exit 0 ;;
esac

# ---------------------------------------------------------------- install ---
banner

step "Looking around"
say "${C_DIM}system${C_RESET}   $BIBBY_DISTRO_NAME ($BIBBY_OS/$BIBBY_ARCH)"
if detect_tex; then
  say "${C_DIM}tex${C_RESET}      ${C_GREEN}found${C_RESET} $BIBBY_TEX_KIND at $BIBBY_TEX_BIN"
else
  say "${C_DIM}tex${C_RESET}      ${C_YELLOW}none${C_RESET}"
fi
say "${C_DIM}editor${C_RESET}   ${BIBBY_CODE_CLI:-${C_YELLOW}no code command on PATH${C_RESET}}"
[ "$BIBBY_OS" = "windows" ] && die "run windows/install.ps1 in PowerShell instead, or use WSL"

# --- questions ---------------------------------------------------------------
if [ -z "$BIBBY_PROFILE" ]; then
  if [ "$BIBBY_TEX_KIND" != "none" ] && ! ask_yes_no "TeX is already installed. Install/refresh packages anyway?" y; then
    BIBBY_PROFILE="skip"
  else
    idx="$(ask_choice "How much TeX do you want?" 2 \
      "$(profile_label minimal)" \
      "$(profile_label standard)" \
      "$(profile_label full)")"
    case "$idx" in 1) BIBBY_PROFILE="minimal" ;; 3) BIBBY_PROFILE="full" ;; *) BIBBY_PROFILE="standard" ;; esac
  fi
fi

if [ -z "$BIBBY_BACKEND" ] && [ "$BIBBY_PROFILE" != "skip" ]; then
  if [ "$BIBBY_TEX_KIND" != "none" ]; then
    BIBBY_BACKEND="existing"
  elif [ "$BIBBY_OS" = "macos" ]; then
    idx="$(ask_choice "Which TeX distribution?" 1 \
      "TinyTeX      user-level, no sudo, fast, installs packages on demand (recommended)" \
      "MacTeX       full Apple install via Homebrew, several GB")"
    case "$idx" in 2) BIBBY_BACKEND="mactex" ;; *) BIBBY_BACKEND="tinytex" ;; esac
  else
    idx="$(ask_choice "Which TeX distribution?" 1 \
      "TinyTeX      user-level, no sudo, fast, installs packages on demand (recommended)" \
      "System TeX Live   via $BIBBY_DISTRO package manager, needs sudo")"
    case "$idx" in 2) BIBBY_BACKEND="system" ;; *) BIBBY_BACKEND="tinytex" ;; esac
  fi
fi

if [ -z "$BIBBY_DO_VSCODE" ]; then
  if ask_yes_no "Set up VS Code (LaTeX Workshop + build-on-save + PDF preview)?" y; then
    BIBBY_DO_VSCODE=1
  else
    BIBBY_DO_VSCODE=0
  fi
fi

if [ "$BIBBY_DO_VSCODE" = "1" ] && [ "$BIBBY_DO_EXTRAS" = "0" ]; then
  ask_yes_no "Also install spell check and grammar extensions?" n && BIBBY_DO_EXTRAS=1
fi

if [ -z "$BIBBY_DO_CLOUD" ]; then
  ask_yes_no "Set up Colab / Kaggle notebooks too?" y && BIBBY_DO_CLOUD=1 || BIBBY_DO_CLOUD=0
fi

if [ -z "$BIBBY_DO_SCAFFOLD" ]; then
  ask_yes_no "Create a starter LaTeX project in $PWD?" n && BIBBY_DO_SCAFFOLD="$PWD"
fi

# --- plan --------------------------------------------------------------------
step "Plan"
say "profile    $BIBBY_PROFILE"
say "backend    $BIBBY_BACKEND"
say "vscode     $([ "$BIBBY_DO_VSCODE" = 1 ] && echo yes || echo no)"
say "cloud      $([ "$BIBBY_DO_CLOUD" = 1 ] && echo yes || echo no)"
say "scaffold   ${BIBBY_DO_SCAFFOLD:-no}"
if ! ask_yes_no "Go?" y; then say "nothing done."; exit 0; fi

START_TS=$(date +%s)

# --- do it -------------------------------------------------------------------
if [ "$BIBBY_PROFILE" != "skip" ]; then
  step "Prerequisites"
  ensure_prereqs

  case "$BIBBY_BACKEND" in
    tinytex)  install_tinytex || die "TinyTeX install failed" ;;
    mactex)   install_mactex  || die "MacTeX install failed" ;;
    system)   install_system_texlive "$BIBBY_PROFILE" || die "system TeX Live install failed" ;;
    existing) skip "using the TeX already installed" ;;
  esac

  detect_tex >/dev/null 2>&1
  ensure_path
  ensure_latexmk
  install_tex_packages "$BIBBY_PROFILE"
fi

if [ "$BIBBY_DO_VSCODE" = "1" ]; then
  install_vscode_extensions "$BIBBY_DO_EXTRAS" 1
  write_vscode_settings "$BIBBY_FORCE_SETTINGS"
fi

[ -n "$BIBBY_DO_SCAFFOLD" ] && scaffold_project "$BIBBY_DO_SCAFFOLD"
[ "$BIBBY_DO_CLOUD" = "1" ] && setup_cloud "$PWD"

# --- verify ------------------------------------------------------------------
run_doctor
DOCTOR_RC=$?

ELAPSED=$(( $(date +%s) - START_TS ))

step "Done in ${ELAPSED}s"
if [ "$BIBBY_PATH_CHANGED" = "1" ]; then
  say "${C_YELLOW}open a new terminal${C_RESET} (or: ${C_CYAN}source $(shell_rc)${C_RESET}) so PATH picks up TeX"
fi
say "compile anything:     ${C_CYAN}latexmk -pdf main.tex${C_RESET}"
say "check the install:    ${C_CYAN}bibby-latex --doctor${C_RESET}"
say "in VS Code:           open a .tex file, hit ${C_CYAN}Ctrl/Cmd+S${C_RESET}, the PDF builds and previews"
printf '\n'

exit $DOCTOR_RC
