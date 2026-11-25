# shellcheck shell=bash
# cloud.sh - Colab / Kaggle / remote notebook setup.

COLAB_ONE_LINER='!curl -fsSL https://raw.githubusercontent.com/BibbyAI/Bibby-LaTeX-CLI/main/cloud/bibby_cloud.py | python3 - --profile standard'

copy_clipboard() {
  local text="$1"
  if   has pbcopy;  then printf '%s' "$text" | pbcopy && return 0
  elif has wl-copy; then printf '%s' "$text" | wl-copy && return 0
  elif has xclip;   then printf '%s' "$text" | xclip -selection clipboard && return 0
  elif has clip.exe; then printf '%s' "$text" | clip.exe && return 0
  fi
  return 1
}

setup_cloud() {
  local dir="${1:-$PWD}"
  step "Cloud notebooks (Colab / Kaggle)"

  mkdir -p "$dir"
  cp "$BIBBY_ROOT/cloud/bibby_cloud.py"    "$dir/bibby_cloud.py"    2>/dev/null || true
  cp "$BIBBY_ROOT/cloud/colab_bibby.ipynb" "$dir/colab_bibby.ipynb" 2>/dev/null || true
  cp "$BIBBY_ROOT/cloud/kaggle_bibby.ipynb" "$dir/kaggle_bibby.ipynb" 2>/dev/null || true
  ok "wrote bibby_cloud.py, colab_bibby.ipynb, kaggle_bibby.ipynb to $dir"

  hr
  say "${C_BOLD}Paste this as the first cell of any Colab or Kaggle notebook:${C_RESET}"
  printf '\n      %s\n\n' "${C_CYAN}${COLAB_ONE_LINER}${C_RESET}"
  say "then compile with:"
  printf '      %s\n\n' "${C_CYAN}!latexmk -pdf -interaction=nonstopmode main.tex${C_RESET}"

  if copy_clipboard "$COLAB_ONE_LINER"; then
    ok "copied the one-liner to your clipboard"
  fi
}
