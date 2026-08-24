#!/usr/bin/env bash
# ABOUTME: Durable-state helper for the local-only dev workflow (triage/feature/work/ship).
# ABOUTME: Scaffolds the local tracker layout and reads state; the agent owns .ai/workflow.yaml's contents.

set -uo pipefail

usage() {
    cat >&2 <<'EOF'
usage: workflow-state.sh <command>

Run from a project root. Commands:
  init      Create the local-tracker layout (docs/specs, docs/decisions,
            tickets, .ai) and a starter .ai/workflow.yaml if absent. Idempotent:
            never overwrites an existing state file.
  show      Print .ai/workflow.yaml. Exits non-zero if it does not exist.
  tickets   List tickets/*.md as "<file>\t<status>" (status parsed from the
            "**Status:**" line, else "unknown"), then a "<done>/<total> done"
            summary. "done" counts tickets whose status is exactly "done".

All ticket and spec tracking is LOCAL files only — never GitHub Issues, Jira,
or any remote tracker.
EOF
}

STATE_FILE=".ai/workflow.yaml"

cmd_init() {
    mkdir -p docs/specs docs/decisions tickets .ai
    if [[ -f "$STATE_FILE" ]]; then
        printf 'workflow: %s already exists, left untouched\n' "$STATE_FILE"
        return 0
    fi
    cat > "$STATE_FILE" <<'EOF'
# ABOUTME: Durable state for this project's dev workflow — the recovery map.
# ABOUTME: After compaction, trust this file and `git log` over conversation memory.

# The feature currently in flight (slug), or null when idle.
feature: null
# Path to the approved spec under docs/specs/, or null.
spec: null
# Git branch / worktree the feature is being built on, or null.
branch: null
# idle | triaging | designing | working | shipping
status: idle
# The ticket under tickets/ currently being executed, or null.
current_ticket: null
# Free-form notes for the next session to pick up.
notes: null
EOF
    printf 'workflow: initialized local tracker and %s\n' "$STATE_FILE"
}

cmd_show() {
    if [[ ! -f "$STATE_FILE" ]]; then
        printf 'workflow: no %s here — run `workflow-state.sh init` first\n' "$STATE_FILE" >&2
        return 1
    fi
    cat "$STATE_FILE"
}

cmd_tickets() {
    local total=0 done=0 f status
    shopt -s nullglob
    for f in tickets/*.md; do
        total=$((total + 1))
        status="$(sed -n 's/^\*\*Status:\*\*[[:space:]]*//p' "$f" | head -n1)"
        status="${status%"${status##*[![:space:]]}"}"   # rstrip
        [[ -z "$status" ]] && status="unknown"
        [[ "$status" == "done" ]] && done=$((done + 1))
        printf '%s\t%s\n' "$(basename "$f")" "$status"
    done
    shopt -u nullglob
    printf '%d/%d done\n' "$done" "$total"
}

main() {
    local cmd="${1:-}"
    case "$cmd" in
        init)    cmd_init ;;
        show)    cmd_show ;;
        tickets) cmd_tickets ;;
        -h|--help|help) usage ;;
        *)       usage; return 1 ;;
    esac
}

main "$@"
