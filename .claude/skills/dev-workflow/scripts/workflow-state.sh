#!/usr/bin/env bash
# ABOUTME: Trivial scaffold+read helper for the manual-aid dev-workflow.
# ABOUTME: Deliberately NOT a state machine — the routers are human-driven checklists.

set -uo pipefail

usage() { echo "usage: workflow-state.sh {init | tickets [feature-slug]}" >&2; }

# Scaffold the tracker: intake (requests/) is separate from execution (tickets/<feature>/).
# Fails closed on error.
cmd_init() {
    if ! mkdir -p docs/specs docs/decisions tickets requests 2>/dev/null; then
        echo "workflow: failed to create tracker dirs (unwritable root or a path collides with a file)" >&2
        return 1
    fi
    echo "workflow: scaffolded docs/specs/, docs/decisions/, tickets/, requests/"
}

# List one feature's execution tickets (tickets/<slug>/*.md) + a done/total count.
# With no slug: default to the sole feature dir, or error naming the choices; 0/0 if none.
# Intake (requests/) is never counted.
cmd_tickets() {
    local slug="${1:-}"
    if [[ -z "$slug" ]]; then
        local dirs=() d
        shopt -s nullglob
        for d in tickets/*/; do dirs+=("${d%/}"); done
        shopt -u nullglob
        if [[ ${#dirs[@]} -eq 0 ]]; then
            printf '0/0 done\n'; return 0
        elif [[ ${#dirs[@]} -eq 1 ]]; then
            slug="$(basename "${dirs[0]}")"
        else
            echo "workflow: multiple feature dirs — pass one:" >&2
            for d in "${dirs[@]}"; do echo "  $(basename "$d")" >&2; done
            return 1
        fi
    fi

    local dir="tickets/$slug"
    if [[ ! -d "$dir" ]]; then
        echo "workflow: no such feature dir: tickets/$slug" >&2
        return 1
    fi

    local total=0 done=0 f st
    shopt -s nullglob
    for f in "$dir"/*.md; do
        st="$(sed -n 's/^\*\*Status:\*\*[[:space:]]*//p' "$f" | head -n1)"
        [[ -z "$st" ]] && st="(none)"
        total=$((total + 1))
        [[ "$st" == done ]] && done=$((done + 1))
        printf '%s\t%s\n' "$(basename "$f")" "$st"
    done
    shopt -u nullglob
    printf '%d/%d done\n' "$done" "$total"
}

cmd="${1:-}"
case "$cmd" in
    init)    cmd_init ;;
    tickets) shift; cmd_tickets "$@" ;;
    -h|--help|help) usage ;;
    *)       echo "workflow: unknown command '${cmd}'" >&2; usage; exit 1 ;;
esac
