#!/usr/bin/env bash
# ABOUTME: Tests for dev-workflow/scripts/workflow-state.sh (v2 state machine).
# ABOUTME: Throwaway git repos; ledger redirected via WORKFLOW_STATE_DIR. No external deps.

set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.claude/skills/dev-workflow/scripts" && pwd)/workflow-state.sh"

pass=0; fail=0
check() { local d="$1" e="$2" a="$3"; if [[ "$a" == "$e" ]]; then pass=$((pass+1)); else
    fail=$((fail+1)); printf 'FAIL: %s\n  expected: %q\n  actual:   %q\n' "$d" "$e" "$a"; fi; }
check_contains() { local d="$1" n="$2" h="$3"; if [[ "$h" == *"$n"* ]]; then pass=$((pass+1)); else
    fail=$((fail+1)); printf 'FAIL: %s\n  want-contains: %q\n  actual: %q\n' "$d" "$n" "$h"; fi; }

# A throwaway git repo. Prints its path.
new_repo() {
    local d; d="$(mktemp -d)"
    ( cd "$d" && git init -q && git config user.email t@t && git config user.name t &&
      printf 'a\n' > f && git add f && git commit -qm c1 )
    printf '%s' "$d"
}
# run the helper in repo $1 with the ledger redirected to a temp state dir $2
wf() { ( cd "$1" && WORKFLOW_STATE_DIR="$2" bash "$SCRIPT" "${@:3}" ); }

# ── init: creates ledger (in the state dir) + inbox/ + features/ ─────────────
proj="$(new_repo)"; sd="$(mktemp -d)"
wf "$proj" "$sd" init >/dev/null 2>&1
check "init: ledger created in state dir"  "yes" "$([[ -f "$sd/state.yaml" ]] && echo yes || echo no)"
check "init: tickets/inbox created"        "yes" "$([[ -d "$proj/tickets/inbox" ]] && echo yes || echo no)"
check "init: tickets/features created"     "yes" "$([[ -d "$proj/tickets/features" ]] && echo yes || echo no)"
check_contains "init: ledger starts idle"  "status: idle" "$(cat "$sd/state.yaml")"
rm -rf "$proj" "$sd"

# default ledger location is the git-common-dir (WORKFLOW_STATE_DIR unset)
proj="$(new_repo)"
( cd "$proj" && bash "$SCRIPT" init >/dev/null 2>&1 )
gcd="$( cd "$proj" && git rev-parse --git-common-dir )"
check "init: default ledger under git-common-dir" "yes" "$([[ -f "$proj/$gcd/dev-workflow/state.yaml" || -f "$gcd/dev-workflow/state.yaml" ]] && echo yes || echo no)"
rm -rf "$proj"

# init fails closed when a scaffold path collides with a file
proj="$(new_repo)"; sd="$(mktemp -d)"
: > "$proj/tickets"   # 'tickets' is a file -> mkdir tickets/inbox must fail
wf "$proj" "$sd" init >/dev/null 2>&1
check "init: fails closed on collision" "1" "$?"
rm -rf "$proj" "$sd"

# ── show ────────────────────────────────────────────────────────────────────
proj="$(new_repo)"; sd="$(mktemp -d)"; wf "$proj" "$sd" init >/dev/null 2>&1
check_contains "show: prints ledger" "status:" "$(wf "$proj" "$sd" show 2>/dev/null)"
rm -rf "$proj" "$sd"
proj="$(new_repo)"; sd="$(mktemp -d)"
wf "$proj" "$sd" show >/dev/null 2>&1
check "show: errors when absent" "1" "$?"
rm -rf "$proj" "$sd"

# ── set-status: legal transitions succeed, illegal are rejected ──────────────
proj="$(new_repo)"; sd="$(mktemp -d)"; wf "$proj" "$sd" init >/dev/null 2>&1
wf "$proj" "$sd" set-status triaging >/dev/null 2>&1
check "set-status: idle->triaging ok" "0" "$?"
check_contains "set-status: persisted" "status: triaging" "$(cat "$sd/state.yaml")"
wf "$proj" "$sd" set-status working >/dev/null 2>&1   # illegal from triaging
check "set-status: illegal transition rejected" "1" "$?"
check_contains "set-status: status unchanged after illegal" "status: triaging" "$(cat "$sd/state.yaml")"
# a full legal path
for s in designing spec-approved ready-to-work working shipping idle; do
    wf "$proj" "$sd" set-status "$s" >/dev/null 2>&1 || { echo "FAIL: legal set-status $s rejected"; fail=$((fail+1)); }
done
check "set-status: walked the legal path to idle" "status: idle" "$(grep '^status:' "$sd/state.yaml")"
rm -rf "$proj" "$sd"

# ── tickets --feature: counts only that feature's execution tickets ──────────
proj="$(new_repo)"; sd="$(mktemp -d)"; wf "$proj" "$sd" init >/dev/null 2>&1
mkdir -p "$proj/tickets/features/foo" "$proj/tickets/features/bar" "$proj/tickets/inbox"
printf '**Status:** done\n'            > "$proj/tickets/features/foo/01-a.md"
printf '**Status:** in-progress\n'     > "$proj/tickets/features/foo/02-b.md"
printf '**Status:** wontfix\n'         > "$proj/tickets/inbox/x.md"          # inbox: ignored
printf '**Status:** done\n'            > "$proj/tickets/features/bar/01-c.md" # other feature: ignored
out="$(wf "$proj" "$sd" tickets --feature foo 2>/dev/null)"
check_contains "tickets --feature: lists foo/01 done"        "01-a.md"$'\t'"done" "$out"
check_contains "tickets --feature: counts only foo (1/2)"    "1/2 done" "$out"
rm -rf "$proj" "$sd"

# unknown command -> non-zero
proj="$(new_repo)"; sd="$(mktemp -d)"
wf "$proj" "$sd" bogus >/dev/null 2>&1
check "unknown command: non-zero" "1" "$?"
rm -rf "$proj" "$sd"

# ── Ticket 02: approval pins, check-ready, graph-validate ────────────────────

# helper: a repo mid-feature with committed tickets on a feature branch
feature_repo() {  # -> prints "proj sd slug"
    local proj sd slug=demo; proj="$(new_repo)"; sd="$(mktemp -d)"
    ( cd "$proj" && WORKFLOW_STATE_DIR="$sd" bash "$SCRIPT" init >/dev/null 2>&1
      mkdir -p "tickets/features/$slug"
      printf '**Blocked by:** None\n**Status:** ready-for-agent\n' > "tickets/features/$slug/01-a.md"
      printf '**Blocked by:** 01\n**Status:** ready-for-agent\n'   > "tickets/features/$slug/02-b.md"
      git add -A && git commit -qm tickets )
    printf '%s %s %s' "$proj" "$sd" "$slug"
}

# approve-spec / approve-tickets record pins + transition
read -r proj sd slug <<<"$(feature_repo)"
wf "$proj" "$sd" set-status designing >/dev/null 2>&1
sha=$( cd "$proj" && git rev-parse HEAD )
wf "$proj" "$sd" approve-spec "$sha" >/dev/null 2>&1
check "approve-spec: status spec-approved" "0" "$?"
check_contains "approve-spec: records commit" "spec_commit: $sha" "$(cat "$sd/state.yaml")"
wf "$proj" "$sd" approve-tickets "$sha" "tickets/features/$slug/01-a.md" "tickets/features/$slug/02-b.md" >/dev/null 2>&1
check "approve-tickets: ok" "0" "$?"
check_contains "approve-tickets: status ready-to-work" "status: ready-to-work" "$(cat "$sd/state.yaml")"
# check-ready passes when clean
wf "$proj" "$sd" check-ready >/dev/null 2>&1
check "check-ready: clean passes" "0" "$?"
# digest drift -> fail closed
( cd "$proj" && printf 'DRIFT\n' >> "tickets/features/$slug/01-a.md" )
wf "$proj" "$sd" check-ready >/dev/null 2>&1
check "check-ready: digest drift fails" "1" "$?"
rm -rf "$proj" "$sd"

# check-ready fails when status isn't ready-to-work
read -r proj sd slug <<<"$(feature_repo)"
wf "$proj" "$sd" set-status triaging >/dev/null 2>&1
wf "$proj" "$sd" check-ready >/dev/null 2>&1
check "check-ready: wrong status fails" "1" "$?"
rm -rf "$proj" "$sd"

# graph-validate: clean graph passes; a cycle fails
read -r proj sd slug <<<"$(feature_repo)"
wf "$proj" "$sd" graph-validate "$slug" >/dev/null 2>&1
check "graph-validate: clean passes" "0" "$?"
( cd "$proj" && printf '**Blocked by:** 02\n**Status:** ready-for-agent\n' > "tickets/features/$slug/01-a.md" )  # 01<->02 cycle
wf "$proj" "$sd" graph-validate "$slug" >/dev/null 2>&1
check "graph-validate: cycle fails" "1" "$?"
rm -rf "$proj" "$sd"

# graph-validate: no executable frontier (every ticket blocked) fails
read -r proj sd slug <<<"$(feature_repo)"
( cd "$proj" && printf '**Blocked by:** 02\n**Status:** ready-for-agent\n' > "tickets/features/$slug/01-a.md"
  printf '**Blocked by:** 01\n**Status:** ready-for-agent\n' > "tickets/features/$slug/02-b.md" )
wf "$proj" "$sd" graph-validate "$slug" >/dev/null 2>&1
check "graph-validate: no frontier fails" "1" "$?"
rm -rf "$proj" "$sd"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
