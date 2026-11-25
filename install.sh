#!/usr/bin/env bash
# bibby-latex bootstrap
#
#   curl -fsSL https://raw.githubusercontent.com/trybibby/bibby-latex/main/install.sh | bash
#
# Flags can be passed through after `-s --`:
#
#   curl -fsSL https://raw.githubusercontent.com/trybibby/bibby-latex/main/install.sh | bash -s -- --yes --profile=standard
#
set -euo pipefail

BIBBY_REPO="${BIBBY_REPO:-trybibby/bibby-latex}"
BIBBY_REF="${BIBBY_REF:-main}"
BIBBY_HOME="${BIBBY_HOME:-$HOME/.bibby-latex}"

# If the libs sit next to this script we are in a checkout / extracted zip.
_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P 2>/dev/null || echo "")"

if [ -n "$_self_dir" ] && [ -f "$_self_dir/src/bibby-latex.sh" ]; then
  exec bash "$_self_dir/src/bibby-latex.sh" "$@"
fi

# Remote install: fetch the tarball, run from a stable location.
command -v curl >/dev/null 2>&1 || { echo "bibby-latex: curl is required" >&2; exit 1; }
command -v tar  >/dev/null 2>&1 || { echo "bibby-latex: tar is required"  >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

url="https://codeload.github.com/${BIBBY_REPO}/tar.gz/${BIBBY_REF}"
echo "bibby-latex: fetching ${BIBBY_REPO}@${BIBBY_REF}"
curl -fsSL "$url" | tar -xz -C "$tmp" --strip-components=1

mkdir -p "$BIBBY_HOME"
rm -rf "$BIBBY_HOME/src" "$BIBBY_HOME/templates" "$BIBBY_HOME/cloud" "$BIBBY_HOME/windows"
cp -R "$tmp/src" "$tmp/templates" "$tmp/cloud" "$tmp/windows" "$BIBBY_HOME/" 2>/dev/null || true
chmod +x "$BIBBY_HOME/src/bibby-latex.sh"

exec bash "$BIBBY_HOME/src/bibby-latex.sh" "$@"
