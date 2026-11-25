# shellcheck shell=bash
# ui.sh - output + prompts. Works when the script is piped from curl by
# reading answers from /dev/tty instead of stdin.

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
  C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
  C_CYAN=$'\033[36m'
else
  C_RESET=""; C_BOLD=""; C_DIM=""
  C_RED=""; C_GREEN=""; C_YELLOW=""; C_CYAN=""
fi
# Used by the scripts that source this file.
export C_CYAN

BIBBY_TTY=""
if [ -r /dev/tty ] && [ -w /dev/tty ]; then
  BIBBY_TTY=/dev/tty
fi

ui_interactive() {
  [ "${BIBBY_ASSUME_YES:-0}" = "1" ] && return 1
  [ -n "$BIBBY_TTY" ] && return 0
  return 1
}

banner() {
  printf '%s\n' ""
  printf '%s\n' "${C_BOLD}  bibby-latex${C_RESET}  ${C_DIM}v${BIBBY_VERSION}${C_RESET}"
  printf '%s\n' "${C_DIM}  LaTeX that just works. Local, VS Code, Colab, Kaggle.${C_RESET}"
  printf '%s\n' ""
}

step()  { printf '\n%s\n' "${C_BOLD}==>${C_RESET} ${C_BOLD}$*${C_RESET}"; }
say()   { printf '    %s\n' "$*"; }
ok()    { printf '    %s %s\n' "${C_GREEN}ok${C_RESET}" "$*"; }
skip()  { printf '    %s %s\n' "${C_DIM}--${C_RESET}" "${C_DIM}$*${C_RESET}"; }
warn()  { printf '    %s %s\n' "${C_YELLOW}warn${C_RESET}" "$*" >&2; }
err()   { printf '    %s %s\n' "${C_RED}fail${C_RESET}" "$*" >&2; }
die()   { err "$*"; exit 1; }

hr() { printf '%s\n' "${C_DIM}    ----------------------------------------------------------${C_RESET}"; }

# ask_yes_no "Question" default(y|n) -> returns 0 for yes
ask_yes_no() {
  local q="$1" def="${2:-y}" ans hint
  if ! ui_interactive; then
    [ "$def" = "y" ]
    return $?
  fi
  if [ "$def" = "y" ]; then hint="[Y/n]"; else hint="[y/N]"; fi
  while true; do
    printf '    %s %s ' "$q" "${C_DIM}$hint${C_RESET}" > "$BIBBY_TTY"
    IFS= read -r ans < "$BIBBY_TTY" || ans=""
    ans="${ans:-$def}"
    case "$ans" in
      [yY]|[yY][eE][sS]) return 0 ;;
      [nN]|[nN][oO])     return 1 ;;
      *) printf '    %s\n' "${C_YELLOW}answer y or n${C_RESET}" > "$BIBBY_TTY" ;;
    esac
  done
}

# ask_choice "Question" default_index label1 label2 ... -> echoes 1-based index
ask_choice() {
  local q="$1" def="$2"; shift 2
  local opts=("$@") i ans
  if ! ui_interactive; then
    printf '%s' "$def"
    return 0
  fi
  printf '\n    %s\n' "${C_BOLD}$q${C_RESET}" > "$BIBBY_TTY"
  for i in "${!opts[@]}"; do
    printf '      %s) %s\n' "$((i+1))" "${opts[$i]}" > "$BIBBY_TTY"
  done
  while true; do
    printf '    choice %s ' "${C_DIM}[$def]${C_RESET}" > "$BIBBY_TTY"
    IFS= read -r ans < "$BIBBY_TTY" || ans=""
    ans="${ans:-$def}"
    case "$ans" in
      ''|*[!0-9]*) ;;
      *) if [ "$ans" -ge 1 ] && [ "$ans" -le "${#opts[@]}" ]; then printf '%s' "$ans"; return 0; fi ;;
    esac
    printf '    %s\n' "${C_YELLOW}pick 1-${#opts[@]}${C_RESET}" > "$BIBBY_TTY"
  done
}

# ask_text "Question" "default" -> echoes answer
ask_text() {
  local q="$1" def="${2:-}" ans
  if ! ui_interactive; then printf '%s' "$def"; return 0; fi
  printf '    %s %s ' "$q" "${C_DIM}[$def]${C_RESET}" > "$BIBBY_TTY"
  IFS= read -r ans < "$BIBBY_TTY" || ans=""
  printf '%s' "${ans:-$def}"
}

# run <description> <command...> - quiet unless it fails or BIBBY_VERBOSE=1
run() {
  local desc="$1"; shift
  if [ "${BIBBY_VERBOSE:-0}" = "1" ]; then
    printf '    %s %s\n' "${C_DIM}\$${C_RESET}" "${C_DIM}$*${C_RESET}"
    "$@" && { ok "$desc"; return 0; } || { err "$desc"; return 1; }
  fi
  local log; log="$(mktemp)"
  printf '    %s %s' "${C_DIM}..${C_RESET}" "$desc"
  if "$@" >"$log" 2>&1; then
    printf '\r    %s %s  \n' "${C_GREEN}ok${C_RESET}" "$desc"
    rm -f "$log"; return 0
  else
    printf '\r    %s %s  \n' "${C_RED}fail${C_RESET}" "$desc"
    printf '%s\n' "${C_DIM}$(tail -n 25 "$log" | sed 's/^/      /')${C_RESET}" >&2
    rm -f "$log"
    return 1
  fi
}
