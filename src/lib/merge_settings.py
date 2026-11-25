#!/usr/bin/env python3
"""Merge the bibby-latex recommended settings into a VS Code settings.json.

Handles JSONC (comments + trailing commas) because VS Code writes it.
Existing user keys win unless force=1.

usage: merge_settings.py <user settings.json> <template.json> <force 0|1>
"""
import json
import re
import sys


def strip_jsonc(text: str) -> str:
    out, i, n = [], 0, len(text)
    in_str = False
    while i < n:
        c = text[i]
        if in_str:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(text[i + 1])
                i += 2
                continue
            if c == '"':
                in_str = False
            i += 1
            continue
        if c == '"':
            in_str = True
            out.append(c)
            i += 1
            continue
        if c == "/" and i + 1 < n and text[i + 1] == "/":
            while i < n and text[i] != "\n":
                i += 1
            continue
        if c == "/" and i + 1 < n and text[i + 1] == "*":
            i += 2
            while i + 1 < n and not (text[i] == "*" and text[i + 1] == "/"):
                i += 1
            i += 2
            continue
        out.append(c)
        i += 1
    cleaned = "".join(out)
    cleaned = re.sub(r",(\s*[}\]])", r"\1", cleaned)
    return cleaned


def load(path: str) -> dict:
    try:
        with open(path, "r", encoding="utf-8") as fh:
            raw = fh.read()
    except FileNotFoundError:
        return {}
    raw = raw.strip()
    if not raw:
        return {}
    try:
        return json.loads(strip_jsonc(raw))
    except json.JSONDecodeError as exc:
        print(f"could not parse {path}: {exc}", file=sys.stderr)
        raise SystemExit(2)


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2
    user_path, tmpl_path = sys.argv[1], sys.argv[2]
    force = len(sys.argv) > 3 and sys.argv[3] == "1"

    user = load(user_path)
    tmpl = load(tmpl_path)

    added = 0
    for key, value in tmpl.items():
        if key not in user or force:
            if user.get(key) != value:
                added += 1
            user[key] = value

    with open(user_path, "w", encoding="utf-8") as fh:
        json.dump(user, fh, indent=2, ensure_ascii=False)
        fh.write("\n")

    print(f"{added} settings written")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
