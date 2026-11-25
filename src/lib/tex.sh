# shellcheck shell=bash
# tex.sh - installing the TeX distribution itself.

TINYTEX_INSTALLER="https://yihui.org/tinytex/install-bin-unix.sh"

ensure_prereqs() {
  local missing=()
  has curl || has wget || missing+=("curl")
  has perl || missing+=("perl")
  has fc-cache || { [ "$BIBBY_OS" != "macos" ] && missing+=("fontconfig"); }

  [ "${#missing[@]}" -eq 0 ] && { skip "prerequisites already present"; return 0; }

  say "installing prerequisites: ${missing[*]}"
  case "$BIBBY_DISTRO" in
    debian) sys_install "${missing[@]}" ;;
    fedora) sys_install "${missing[@]}" ;;
    arch)   sys_install "${missing[@]}" ;;
    suse|alpine) sys_install "${missing[@]}" ;;
    macos)  has brew && sys_install "${missing[@]}" || warn "install Homebrew or Xcode CLT for: ${missing[*]}" ;;
    *) warn "install manually: ${missing[*]}" ;;
  esac
}

install_tinytex() {
  step "Installing TinyTeX"
  if [ -d "$HOME/.TinyTeX" ] || [ -d "$HOME/Library/TinyTeX" ]; then
    skip "TinyTeX already present"
  else
    if has curl; then
      run "download + install TinyTeX" bash -c "curl -fsSL '$TINYTEX_INSTALLER' | sh" || return 1
    else
      run "download + install TinyTeX" bash -c "wget -qO- '$TINYTEX_INSTALLER' | sh" || return 1
    fi
  fi
  detect_tex || { err "TinyTeX installed but pdflatex not found"; return 1; }
  export PATH="$BIBBY_TEX_BIN:$PATH"
  ok "TeX binaries at $BIBBY_TEX_BIN"
}

install_mactex() {
  step "Installing MacTeX (no GUI apps)"
  if ! has brew; then
    warn "Homebrew not found, falling back to TinyTeX"
    install_tinytex
    return $?
  fi
  run "brew install --cask mactex-no-gui" brew install --cask mactex-no-gui || return 1
  export PATH="/Library/TeX/texbin:$PATH"
  detect_tex
}

install_system_texlive() {
  local profile="$1" pkgs
  step "Installing TeX Live from the system package manager"
  pkgs="$(system_tex_packages "$profile")" || { warn "no system packages known for $BIBBY_DISTRO"; return 1; }
  say "packages: $pkgs"
  # shellcheck disable=SC2086
  run "install $BIBBY_DISTRO TeX Live" sys_install $pkgs || return 1
  detect_tex
}

tlmgr_bin() {
  if has tlmgr; then command -v tlmgr; return 0; fi
  [ -n "$BIBBY_TEX_BIN" ] && [ -x "$BIBBY_TEX_BIN/tlmgr" ] && { printf '%s' "$BIBBY_TEX_BIN/tlmgr"; return 0; }
  return 1
}

# Only safe on TinyTeX / a user-owned TeX Live. On a distro TeX Live the
# package manager owns the tree, so we do not touch it.
install_tex_packages() {
  local profile="$1" tlmgr pkgs
  tlmgr="$(tlmgr_bin)" || { skip "tlmgr unavailable, skipping package set"; return 0; }

  if [ "$BIBBY_TEX_KIND" = "texlive" ] && [ "${BIBBY_TEX_BIN#/usr}" != "$BIBBY_TEX_BIN" ]; then
    skip "distro-managed TeX Live, package set handled by the system packages"
    return 0
  fi

  step "Installing the $profile package set"
  pkgs="$(profile_packages "$profile")"

  run "tlmgr update --self" "$tlmgr" update --self || warn "tlmgr self-update failed, continuing"

  local failed=()
  local total=0 done=0
  # shellcheck disable=SC2086
  set -- $pkgs
  total=$#
  for p in "$@"; do
    done=$((done+1))
    printf '\r    %s installing packages %s/%s  %-28s' "${C_DIM}..${C_RESET}" "$done" "$total" "$p"
    if ! "$tlmgr" install "$p" >/dev/null 2>&1; then failed+=("$p"); fi
  done
  printf '\r%-72s\r' ""

  if [ "${#failed[@]}" -eq 0 ]; then
    ok "$total packages installed"
  else
    ok "$((total - ${#failed[@]}))/$total packages installed"
    warn "not available in this distribution: ${failed[*]}"
  fi

  # Let latex pull anything still missing, without a prompt.
  "$tlmgr" option autobackup 0 >/dev/null 2>&1 || true
}

ensure_path() {
  local bin="$BIBBY_TEX_BIN" rc line
  [ -z "$bin" ] && return 0
  case ":$PATH:" in *":$bin:"*) ;; *) export PATH="$bin:$PATH" ;; esac

  rc="$(shell_rc)"
  mkdir -p "$(dirname "$rc")"
  touch "$rc"

  if grep -q "bibby-latex: TeX PATH" "$rc" 2>/dev/null; then
    skip "PATH already configured in $(basename "$rc")"
    return 0
  fi

  if [ "${rc##*/}" = "config.fish" ]; then
    line="# bibby-latex: TeX PATH
fish_add_path $bin"
  else
    line="# bibby-latex: TeX PATH
export PATH=\"$bin:\$PATH\""
  fi
  printf '\n%s\n' "$line" >> "$rc"
  ok "added TeX to PATH in $rc"
  # Read by bibby-latex.sh after this file is sourced.
  export BIBBY_PATH_CHANGED=1
}

# Make `latexmk` usable even if the distro skipped it.
ensure_latexmk() {
  has latexmk && { skip "latexmk present"; return 0; }
  local tlmgr; tlmgr="$(tlmgr_bin)" || return 1
  run "install latexmk" "$tlmgr" install latexmk
}
