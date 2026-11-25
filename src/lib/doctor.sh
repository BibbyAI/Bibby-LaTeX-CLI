# shellcheck shell=bash
# doctor.sh - prove the install actually compiles a document.

DOCTOR_FAILURES=0

check() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    ok "$label"
  else
    err "$label"
    DOCTOR_FAILURES=$((DOCTOR_FAILURES+1))
  fi
}

# check_version <label> <cmd> [required|optional]
check_version() {
  local label="$1" cmd="$2" req="${3:-required}"
  if has "$cmd"; then
    ok "$label  ${C_DIM}$("$cmd" --version 2>/dev/null | head -n1 | cut -c1-60)${C_RESET}"
  elif [ "$req" = "optional" ]; then
    warn "$label  ${C_DIM}not found (optional)${C_RESET}"
  else
    err "$label  ${C_DIM}not found${C_RESET}"
    DOCTOR_FAILURES=$((DOCTOR_FAILURES+1))
  fi
}

doctor_compile_test() {
  local dir out
  dir="$(mktemp -d)"
  cat > "$dir/bibby-test.tex" <<'TEX'
\documentclass[11pt]{article}
\usepackage{amsmath,amssymb,graphicx,hyperref,booktabs,xcolor}
\title{bibby-latex smoke test}
\author{bibby}
\begin{document}
\maketitle
\section{Math}
\begin{equation}
  \mathcal{L}(\theta) = \mathbb{E}_{x\sim p}\left[\log \pi_\theta(x)\right]
\end{equation}
\section{Table}
\begin{tabular}{lr}\toprule Item & Value \\ \midrule Works & Yes \\ \bottomrule\end{tabular}
\end{document}
TEX

  if has latexmk; then
    out="$(cd "$dir" && latexmk -pdf -interaction=nonstopmode -halt-on-error bibby-test.tex 2>&1)"
  else
    out="$(cd "$dir" && pdflatex -interaction=nonstopmode -halt-on-error bibby-test.tex 2>&1)"
  fi

  if [ -f "$dir/bibby-test.pdf" ]; then
    ok "compiled a test document to PDF"
    rm -rf "$dir"
    return 0
  fi

  err "test compile failed"
  printf '%s\n' "${C_DIM}$(printf '%s' "$out" | tail -n 20 | sed 's/^/      /')${C_RESET}" >&2
  DOCTOR_FAILURES=$((DOCTOR_FAILURES+1))
  rm -rf "$dir"
  return 1
}

run_doctor() {
  step "Doctor"
  detect_os; detect_distro; detect_tex >/dev/null 2>&1; detect_editor
  [ -n "$BIBBY_TEX_BIN" ] && export PATH="$BIBBY_TEX_BIN:$PATH"

  say "${C_DIM}system${C_RESET}   $BIBBY_DISTRO_NAME ($BIBBY_OS/$BIBBY_ARCH)"
  say "${C_DIM}tex${C_RESET}      $BIBBY_TEX_KIND ${BIBBY_TEX_BIN:+at $BIBBY_TEX_BIN}"
  say "${C_DIM}editor${C_RESET}   ${BIBBY_CODE_CLI:-none on PATH}"
  hr

  check_version "pdflatex" pdflatex required
  check_version "latexmk " latexmk  required
  check_version "xelatex " xelatex  optional
  check_version "lualatex" lualatex optional
  check_version "biber   " biber    optional
  check_version "bibtex  " bibtex   optional
  check_version "tlmgr   " tlmgr    optional

  if [ -n "$BIBBY_CODE_CLI" ]; then
    if "$BIBBY_CODE_CLI" --list-extensions 2>/dev/null | grep -qix "james-yu.latex-workshop"; then
      ok "VS Code extension: LaTeX Workshop"
    else
      warn "LaTeX Workshop not installed  ${C_DIM}bibby-latex --vscode-only${C_RESET}"
    fi
  fi

  hr
  doctor_compile_test

  hr
  if [ "$DOCTOR_FAILURES" -eq 0 ]; then
    printf '    %s\n\n' "${C_GREEN}everything checks out.${C_RESET}"
    return 0
  fi
  printf '    %s\n' "${C_YELLOW}$DOCTOR_FAILURES check(s) failed.${C_RESET}"
  printf '    %s\n\n' "${C_DIM}try: bibby-latex --profile=standard --yes${C_RESET}"
  return 1
}
