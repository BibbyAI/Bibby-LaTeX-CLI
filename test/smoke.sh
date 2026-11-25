#!/usr/bin/env bash
# Smoke test. Does not install anything: checks that every entry point parses,
# that the non-destructive flags work, and that the templates are valid.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

PASS=0; FAIL=0
t() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then printf 'ok    %s\n' "$name"; PASS=$((PASS+1))
  else printf 'FAIL  %s\n' "$name"; FAIL=$((FAIL+1)); fi
}

for f in install.sh src/bibby-latex.sh src/lib/*.sh test/smoke.sh; do
  t "syntax $f" bash -n "$f"
done

t "python syntax cloud/bibby_cloud.py" python3 -m py_compile cloud/bibby_cloud.py
t "python syntax merge_settings.py"    python3 -m py_compile src/lib/merge_settings.py
t "node syntax bin/bibby-latex.js"     node --check bin/bibby-latex.js

t "--version" bash src/bibby-latex.sh --version
t "--help"    bash src/bibby-latex.sh --help
t "rejects unknown flags" bash -c '! bash src/bibby-latex.sh --definitely-not-a-flag'

t "settings.json is valid json" python3 -c "import json;json.load(open('templates/settings.json'))"
t "package.json is valid json"  python3 -c "import json;json.load(open('package.json'))"
for nb in cloud/*.ipynb; do
  t "notebook $nb" python3 -c "import json,sys;json.load(open(sys.argv[1]))" "$nb"
done

# merge_settings must not lose existing user keys
tmp="$(mktemp -d)"
printf '{\n  // a comment\n  "editor.fontSize": 15,\n}\n' > "$tmp/settings.json"
python3 src/lib/merge_settings.py "$tmp/settings.json" templates/settings.json 0 >/dev/null 2>&1
t "merge keeps existing keys" python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
assert d['editor.fontSize']==15
assert 'latex-workshop.latex.recipes' in d
" "$tmp/settings.json"
rm -rf "$tmp"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
