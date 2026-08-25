#!/usr/bin/env bash
# ABOUTME: Tests for the trivial dev-workflow scaffold+read helper (no state machine).
# ABOUTME: Throwaway dirs; no external deps.

set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.claude/skills/dev-workflow/scripts" && pwd)/workflow-state.sh"

pass=0; fail=0
check() { local d="$1" e="$2" a="$3"; if [[ "$a" == "$e" ]]; then pass=$((pass+1)); else
    fail=$((fail+1)); printf 'FAIL: %s\n  expected: %q\n  actual:   %q\n' "$d" "$e" "$a"; fi; }
check_contains() { local d="$1" n="$2" h="$3"; if [[ "$h" == *"$n"* ]]; then pass=$((pass+1)); else
    fail=$((fail+1)); printf 'FAIL: %s\n  want-contains: %q\n  actual: %q\n' "$d" "$n" "$h"; fi; }
newp() { mktemp -d; }

# init scaffolds the flat tracker
p="$(newp)"; ( cd "$p" && bash "$SCRIPT" init >/dev/null 2>&1 )
check "init: docs/specs"     "yes" "$([[ -d "$p/docs/specs" ]] && echo yes || echo no)"
check "init: docs/decisions" "yes" "$([[ -d "$p/docs/decisions" ]] && echo yes || echo no)"
check "init: tickets"        "yes" "$([[ -d "$p/tickets" ]] && echo yes || echo no)"
rm -rf "$p"

# init fails closed on a path collision
p="$(newp)"; : > "$p/tickets"
( cd "$p" && bash "$SCRIPT" init >/dev/null 2>&1 )
check "init: fails closed on collision" "1" "$?"
rm -rf "$p"

# tickets lists status + done/total, defaulting a missing status
p="$(newp)"; ( cd "$p" && bash "$SCRIPT" init >/dev/null 2>&1 )
printf '# 01\n**Status:** done\n'            > "$p/tickets/01-a.md"
printf '# 02\n**Status:** ready-for-agent\n' > "$p/tickets/02-b.md"
printf '# 03 (no status)\n'                  > "$p/tickets/03-c.md"
out="$( cd "$p" && bash "$SCRIPT" tickets 2>/dev/null )"
check_contains "tickets: 01 done"        "01-a.md"$'\t'"done" "$out"
check_contains "tickets: 03 (none)"      "03-c.md"$'\t'"(none)" "$out"
check_contains "tickets: 1/3 done"       "1/3 done" "$out"
rm -rf "$p"

# empty tracker -> 0/0
p="$(newp)"; ( cd "$p" && bash "$SCRIPT" init >/dev/null 2>&1 )
check_contains "tickets: empty is 0/0" "0/0 done" "$( cd "$p" && bash "$SCRIPT" tickets 2>/dev/null )"
rm -rf "$p"

# unknown command -> non-zero
p="$(newp)"; ( cd "$p" && bash "$SCRIPT" bogus >/dev/null 2>&1 )
check "unknown command: non-zero" "1" "$?"
rm -rf "$p"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
