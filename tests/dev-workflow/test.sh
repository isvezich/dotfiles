#!/usr/bin/env bash
# ABOUTME: Tests for dev-workflow/scripts/workflow-state.sh — init, show, tickets.
# ABOUTME: Runs each case in a throwaway project dir; no external deps (no yq/bats).

set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.claude/skills/dev-workflow/scripts" && pwd)/workflow-state.sh"

pass=0
fail=0

check() {
    # check <description> <expected> <actual>
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        printf 'FAIL: %s\n  expected: %q\n  actual:   %q\n' "$desc" "$expected" "$actual"
    fi
}

check_contains() {
    # check_contains <description> <needle> <haystack>
    local desc="$1" needle="$2" haystack="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        printf 'FAIL: %s\n  expected to contain: %q\n  actual: %q\n' "$desc" "$needle" "$haystack"
    fi
}

new_project() {
    local d
    d="$(mktemp -d)"
    printf '%s' "$d"
}

# --- init: creates the local-tracker layout and a starter state file ---
proj="$(new_project)"
( cd "$proj" && bash "$SCRIPT" init >/dev/null 2>&1 )
check "init creates docs/specs"     "yes" "$([[ -d "$proj/docs/specs" ]] && echo yes || echo no)"
check "init creates docs/decisions" "yes" "$([[ -d "$proj/docs/decisions" ]] && echo yes || echo no)"
check "init creates tickets"        "yes" "$([[ -d "$proj/tickets" ]] && echo yes || echo no)"
check "init creates .ai/workflow.yaml" "yes" "$([[ -f "$proj/.ai/workflow.yaml" ]] && echo yes || echo no)"
check_contains "starter state file carries ABOUTME" "ABOUTME:" "$(cat "$proj/.ai/workflow.yaml")"
check_contains "starter state file has status field" "status:" "$(cat "$proj/.ai/workflow.yaml")"
rm -rf "$proj"

# --- init: idempotent, never clobbers an existing state file ---
proj="$(new_project)"
( cd "$proj" && bash "$SCRIPT" init >/dev/null 2>&1 )
printf 'feature: my-sentinel\n' > "$proj/.ai/workflow.yaml"
( cd "$proj" && bash "$SCRIPT" init >/dev/null 2>&1 )
check "second init preserves existing state file" "feature: my-sentinel" "$(cat "$proj/.ai/workflow.yaml")"
rm -rf "$proj"

# --- show: prints the state file; errors when absent ---
proj="$(new_project)"
( cd "$proj" && bash "$SCRIPT" init >/dev/null 2>&1 )
show_out="$( cd "$proj" && bash "$SCRIPT" show 2>/dev/null )"
check_contains "show prints the state file" "status:" "$show_out"
rm -rf "$proj"

proj="$(new_project)"
( cd "$proj" && bash "$SCRIPT" show >/dev/null 2>&1 )
check "show without state file exits non-zero" "1" "$?"
rm -rf "$proj"

# --- tickets: lists each ticket with its parsed status + a done/total summary ---
proj="$(new_project)"
( cd "$proj" && bash "$SCRIPT" init >/dev/null 2>&1 )
cat > "$proj/tickets/01-first.md" <<'EOF'
# 01 — First
**Status:** done
EOF
cat > "$proj/tickets/02-second.md" <<'EOF'
# 02 — Second
**Status:** ready-for-agent
EOF
cat > "$proj/tickets/03-third.md" <<'EOF'
# 03 — Third
(no status line here)
EOF
tickets_out="$( cd "$proj" && bash "$SCRIPT" tickets 2>/dev/null )"
check_contains "tickets lists first with done"        "01-first.md"$'\t'"done" "$tickets_out"
check_contains "tickets lists second as ready"        "02-second.md"$'\t'"ready-for-agent" "$tickets_out"
check_contains "tickets marks missing status unknown" "03-third.md"$'\t'"unknown" "$tickets_out"
check_contains "tickets prints done/total summary"    "1/3 done" "$tickets_out"
rm -rf "$proj"

# --- tickets: empty tracker reports 0/0 ---
proj="$(new_project)"
( cd "$proj" && bash "$SCRIPT" init >/dev/null 2>&1 )
tickets_out="$( cd "$proj" && bash "$SCRIPT" tickets 2>/dev/null )"
check_contains "empty tracker reports 0/0 done" "0/0 done" "$tickets_out"
rm -rf "$proj"

# --- unknown command exits non-zero ---
proj="$(new_project)"
( cd "$proj" && bash "$SCRIPT" bogus >/dev/null 2>&1 )
check "unknown command exits non-zero" "1" "$?"
rm -rf "$proj"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
