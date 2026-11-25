# shellcheck shell=bash
# vscode.sh - extensions + settings, without clobbering what the user has.

VSCODE_EXTENSIONS_CORE="james-yu.latex-workshop"
VSCODE_EXTENSIONS_EXTRA="valentjn.vscode-ltex streetsidesoftware.code-spell-checker tecosaur.latex-utilities"
VSCODE_EXTENSIONS_BIBBY="trybibby.bibby-latex"

install_vscode_extensions() {
  local extras="${1:-0}" bibby="${2:-1}" list
  step "Setting up VS Code"

  if [ -z "$BIBBY_CODE_CLI" ]; then
    warn "no 'code' command found"
    say "VS Code > Command Palette > 'Shell Command: Install code command in PATH', then re-run:"
    say "  bibby-latex --vscode-only"
    return 1
  fi

  list="$VSCODE_EXTENSIONS_CORE"
  [ "$bibby" = "1" ] && list="$list $VSCODE_EXTENSIONS_BIBBY"
  [ "$extras" = "1" ] && list="$list $VSCODE_EXTENSIONS_EXTRA"

  local e
  for e in $list; do
    if "$BIBBY_CODE_CLI" --list-extensions 2>/dev/null | grep -qix "$e"; then
      skip "$e already installed"
    else
      run "install $e" "$BIBBY_CODE_CLI" --install-extension "$e" --force || warn "could not install $e"
    fi
  done
}

# Merge our recommended settings into the user's settings.json. Existing keys win
# unless --force-settings was passed.
write_vscode_settings() {
  local force="${1:-0}"
  local dir file tmpl
  dir="$(vscode_user_dir)"
  file="$dir/settings.json"
  tmpl="$BIBBY_ROOT/templates/settings.json"

  [ -f "$tmpl" ] || { warn "settings template missing"; return 1; }
  mkdir -p "$dir"
  [ -f "$file" ] || printf '{}\n' > "$file"

  if ! has python3; then
    warn "python3 not found, skipping settings merge"
    say "copy the recommended settings yourself from $tmpl"
    return 1
  fi

  cp "$file" "$file.bibby-backup" 2>/dev/null || true

  if python3 "$BIBBY_ROOT/src/lib/merge_settings.py" "$file" "$tmpl" "$force"; then
    ok "merged LaTeX settings into $file"
    say "backup at $file.bibby-backup"
  else
    warn "settings merge failed, your settings.json is untouched"
    return 1
  fi
}

# Drop a workspace scaffold in the current directory.
scaffold_project() {
  local dir="${1:-.}"
  step "Scaffolding a LaTeX project in $dir"
  mkdir -p "$dir/.vscode"
  [ -f "$dir/main.tex" ]   || cp "$BIBBY_ROOT/templates/main.tex" "$dir/main.tex"
  [ -f "$dir/.latexmkrc" ] || cp "$BIBBY_ROOT/templates/latexmkrc" "$dir/.latexmkrc"
  [ -f "$dir/.gitignore" ] || cp "$BIBBY_ROOT/templates/gitignore" "$dir/.gitignore"
  [ -f "$dir/.vscode/settings.json" ] || cp "$BIBBY_ROOT/templates/settings.json" "$dir/.vscode/settings.json"
  ok "main.tex, .latexmkrc, .gitignore, .vscode/settings.json"
}
