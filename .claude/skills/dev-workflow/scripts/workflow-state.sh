#!/usr/bin/env bash
# ABOUTME: Trivial scaffold+read helper for the manual-aid dev-workflow.
# ABOUTME: Deliberately NOT a state machine — the routers are human-driven checklists.

set -uo pipefail

usage() { echo "usage: workflow-state.sh {init | tickets}" >&2; }

# Scaffold the flat local tracker. Fails closed on error.
cmd_init() {
    if ! mkdir -p docs/specs docs/decisions tickets 2>/dev/null; then
        echo "workflow: failed to create tracker dirs (unwritable root or a path collides with a file)" >&2
        return 1
    fi
    echo "workflow: scaffolded docs/specs/, docs/decisions/, tickets/"
}

# List tickets/*.md with their **Status:** line + a done/total count.
cmd_tickets() {
    local total=0 done=0 f st
    shopt -s nullglob
    for f in tickets/*.md; do
        st="$(sed -n 's/^\*\*Status:\*\*[[:space:]]*//p' "$f" | head -n1)"
        [[ -z "$st" ]] && st="(none)"
        total=$((total + 1))
        [[ "$st" == done ]] && done=$((done + 1))
        printf '%s\t%s\n' "$(basename "$f")" "$st"
    done
    shopt -u nullglob
    printf '%d/%d done\n' "$done" "$total"
}

case "${1:-}" in
    init)    cmd_init ;;
    tickets) cmd_tickets ;;
    -h|--help|help) usage ;;
    *)       echo "workflow: unknown command '${1:-}'" >&2; usage; exit 1 ;;
esac
