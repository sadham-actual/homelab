#!/usr/bin/env bash
#
# Pre-commit guard: blocks commits containing secrets or identifying strings,
# so nothing sensitive leaks into this PUBLIC repo.
#
# Generic secret patterns are built in (below). Repo-specific literals — the
# real domain, LAN subnet, personal email, etc. — live ONLY in a local,
# untracked file so they never appear in this published script:
#
#     .git/sensitive-patterns.txt   (one regex per line; '#' comments allowed)
#
# Fresh clone setup: create that file and copy this script to
# .git/hooks/pre-commit (chmod +x). See CLAUDE.md "Sensitive-data guard".
#
# If this fires, FIX the content — do not bypass with `git commit --no-verify`.

set -uo pipefail

# Generic secret formats (safe to publish — reveal nothing repo-specific):
generic='-----BEGIN [A-Z ]*PRIVATE KEY|-----BEGIN OPENSSH|AKIA[0-9A-Z]{16}|xox[baprs]-[0-9A-Za-z-]+|ghp_[0-9A-Za-z]{30,}|AIza[0-9A-Za-z_-]{35}'

# Repo-specific literals, kept local-only (never committed):
gitdir=$(git rev-parse --git-dir)
patterns="$generic"
if [ -f "$gitdir/sensitive-patterns.txt" ]; then
  extra=$(grep -vE '^[[:space:]]*(#|$)' "$gitdir/sensitive-patterns.txt" | paste -sd'|' -)
  [ -n "$extra" ] && patterns="$generic|$extra"
fi

fail=0
files=$(git diff --cached --name-only --diff-filter=ACM | grep -v '^scripts/check-sensitive\.sh$' || true)
for f in $files; do
  hits=$(git show ":$f" 2>/dev/null | grep -nEI -e "$patterns" || true)
  if [ -n "$hits" ]; then
    echo "❌ Sensitive string(s) in staged file: $f"
    echo "$hits" | head -5
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  echo ""
  echo "Commit blocked by scripts/check-sensitive.sh (see CLAUDE.md sanitize rules)."
  echo "Fix the flagged content; do not bypass with --no-verify."
  exit 1
fi
exit 0
