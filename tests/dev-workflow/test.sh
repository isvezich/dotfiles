#!/usr/bin/env bash
# ABOUTME: Tests for the dev-workflow scaffold+read helper (requests/ intake + per-feature tickets).
# ABOUTME: Throwaway dirs; no external deps; runs under bash 3.2.

set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.claude/skills/dev-workflow/scripts" && pwd)/workflow-state.sh"

pass=0; fail=0
check() { local d="$1" e="$2" a="$3"; if [[ "$a" == "$e" ]]; then pass=$((pass+1)); else
    fail=$((fail+1)); printf 'FAIL: %s\n  expected: %q\n  actual:   %q\n' "$d" "$e" "$a"; fi; }
check_contains() { local d="$1" n="$2" h="$3"; if [[ "$h" == *"$n"* ]]; then pass=$((pass+1)); else
    fail=$((fail+1)); printf 'FAIL: %s\n  want-contains: %q\n  actual: %q\n' "$d" "$n" "$h"; fi; }
check_missing() { local d="$1" n="$2" h="$3"; if [[ "$h" != *"$n"* ]]; then pass=$((pass+1)); else
    fail=$((fail+1)); printf 'FAIL: %s\n  should-not-contain: %q\n  actual: %q\n' "$d" "$n" "$h"; fi; }
newp() { mktemp -d; }

# init scaffolds the tracker incl. a separate requests/ intake dir
p="$(newp)"; ( cd "$p" && bash "$SCRIPT" init >/dev/null 2>&1 )
check "init: docs/specs"     "yes" "$([[ -d "$p/docs/specs" ]] && echo yes || echo no)"
check "init: docs/decisions" "yes" "$([[ -d "$p/docs/decisions" ]] && echo yes || echo no)"
check "init: tickets"        "yes" "$([[ -d "$p/tickets" ]] && echo yes || echo no)"
check "init: requests"       "yes" "$([[ -d "$p/requests" ]] && echo yes || echo no)"
rm -rf "$p"

# init fails closed on a path collision
p="$(newp)"; : > "$p/tickets"
( cd "$p" && bash "$SCRIPT" init >/dev/null 2>&1 )
check "init: fails closed on collision" "1" "$?"
rm -rf "$p"

# tickets <slug>: lists status + done/total for that feature dir only, defaulting a missing status
p="$(newp)"; ( cd "$p" && bash "$SCRIPT" init >/dev/null 2>&1 )
mkdir -p "$p/tickets/feat-a"
printf '# 01\n**Status:** done\n'            > "$p/tickets/feat-a/01-a.md"
printf '# 02\n**Status:** ready-for-agent\n' > "$p/tickets/feat-a/02-b.md"
printf '# 03 (no status)\n'                  > "$p/tickets/feat-a/03-c.md"
out="$( cd "$p" && bash "$SCRIPT" tickets feat-a 2>/dev/null )"
check_contains "tickets: 01 done"     "01-a.md"$'\t'"done" "$out"
check_contains "tickets: 03 (none)"   "03-c.md"$'\t'"(none)" "$out"
check_contains "tickets: 1/3 done"    "1/3 done" "$out"
rm -rf "$p"

# tickets (no arg) defaults to the single feature dir
p="$(newp)"; ( cd "$p" && bash "$SCRIPT" init >/dev/null 2>&1 )
mkdir -p "$p/tickets/only-feat"
printf '**Status:** done\n' > "$p/tickets/only-feat/01.md"
check_contains "tickets: single-dir default" "1/1 done" "$( cd "$p" && bash "$SCRIPT" tickets 2>/dev/null )"
rm -rf "$p"

# tickets (no arg) with multiple feature dirs errors, naming them
p="$(newp)"; ( cd "$p" && bash "$SCRIPT" init >/dev/null 2>&1 )
mkdir -p "$p/tickets/feat-a" "$p/tickets/feat-b"
( cd "$p" && bash "$SCRIPT" tickets >/dev/null 2>&1 )
check "tickets: multi-dir no-arg errors" "1" "$?"
err="$( cd "$p" && bash "$SCRIPT" tickets 2>&1 >/dev/null )"
check_contains "tickets: multi-dir names feat-a" "feat-a" "$err"
check_contains "tickets: multi-dir names feat-b" "feat-b" "$err"
rm -rf "$p"

# tickets (no arg) with no feature dirs -> 0/0
p="$(newp)"; ( cd "$p" && bash "$SCRIPT" init >/dev/null 2>&1 )
check_contains "tickets: no features is 0/0" "0/0 done" "$( cd "$p" && bash "$SCRIPT" tickets 2>/dev/null )"
rm -rf "$p"

# tickets <slug> for a nonexistent feature -> non-zero
p="$(newp)"; ( cd "$p" && bash "$SCRIPT" init >/dev/null 2>&1 )
( cd "$p" && bash "$SCRIPT" tickets ghost >/dev/null 2>&1 )
check "tickets: unknown feature non-zero" "1" "$?"
rm -rf "$p"

# requests/ (intake) is excluded from the execution count
p="$(newp)"; ( cd "$p" && bash "$SCRIPT" init >/dev/null 2>&1 )
mkdir -p "$p/tickets/feat-a"
printf '**Status:** done\n'    > "$p/tickets/feat-a/01.md"
printf '**Status:** wontfix\n' > "$p/requests/99-junk.md"
out="$( cd "$p" && bash "$SCRIPT" tickets feat-a 2>/dev/null )"
check_contains "tickets: excludes requests count" "1/1 done" "$out"
check_missing  "tickets: excludes requests file"  "99-junk.md" "$out"
rm -rf "$p"

# tracker paths anchor at the repo root, not the launch subdirectory
p="$(newp)"; git init -q "$p"; mkdir -p "$p/sub/deeper"
( cd "$p/sub/deeper" && bash "$SCRIPT" init >/dev/null 2>&1 )
check "anchor: root has tickets/"      "yes" "$([[ -d "$p/tickets" ]] && echo yes || echo no)"
check "anchor: subdir has no tickets/" "yes" "$([[ ! -d "$p/sub/deeper/tickets" ]] && echo yes || echo no)"
rm -rf "$p"

# tickets rejects a slug outside the safe grammar (blocks path traversal / option-like values)
p="$(newp)"; ( cd "$p" && bash "$SCRIPT" init >/dev/null 2>&1 )
( cd "$p" && bash "$SCRIPT" tickets "../etc" >/dev/null 2>&1 )
check "slug: rejects traversal"  "1" "$?"
( cd "$p" && bash "$SCRIPT" tickets "a/b" >/dev/null 2>&1 )
check "slug: rejects slash"      "1" "$?"
( cd "$p" && bash "$SCRIPT" tickets "-rf" >/dev/null 2>&1 )
check "slug: rejects option-like" "1" "$?"
rm -rf "$p"

# unknown command -> non-zero
p="$(newp)"; ( cd "$p" && bash "$SCRIPT" bogus >/dev/null 2>&1 )
check "unknown command: non-zero" "1" "$?"
rm -rf "$p"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
