#!/usr/bin/env python3
# ABOUTME: Test suite for .claude/hooks/block-git-add-all.py — pipes synthetic
# ABOUTME: PreToolUse JSON in and asserts deny/allow/fail-open. Run: python3 tests/test_*.py.

import json
import subprocess
import sys
from pathlib import Path

HOOK = Path(__file__).resolve().parent.parent / ".claude" / "hooks" / "block-git-add-all.py"
CWD = str(Path(__file__).resolve().parent.parent)


def run_raw(stdin: str) -> tuple[int, str]:
    result = subprocess.run(
        [str(HOOK)], input=stdin, capture_output=True, text=True, cwd=CWD
    )
    return result.returncode, result.stdout


def run(cmd: str, tool: str = "Bash") -> tuple[int, str]:
    payload: dict = {"tool_name": tool, "cwd": CWD}
    if tool == "Bash":
        payload["tool_input"] = {"command": cmd}
    else:
        payload["tool_input"] = {"file_path": "/tmp/x"}
    return run_raw(json.dumps(payload))


def is_deny(out: str) -> bool:
    if not out:
        return False
    try:
        data = json.loads(out)
    except json.JSONDecodeError:
        return False
    return data.get("hookSpecificOutput", {}).get("permissionDecision") == "deny"


DENY_CASES = [
    ("git add -A",              "git add -A"),
    ("git add --all",           "git add --all"),
    ("git add .",               "git add ."),
    ("git add ./",              "git add ./"),
    ("git add *",               "git add *"),
    ("git add -Av cluster",     "git add -Av"),
    ("git add -vA cluster",     "git add -vA"),
    ("git -C sub add -A",       f"git -C {CWD}/.claude add -A"),
    ("git --git-dir= add -A",   f"git --git-dir={CWD}/.git add -A"),
    ("bulk after a path",       "git add src/ -A"),
    ("compound && git add .",   "git status && git add ."),
    ("no-space && bypass",      "git add .&&echo ok"),
    ("no-space ; bypass",       "git add -A;git status"),
]

ALLOW_CASES = [
    ("git add explicit file",   "git add file.py"),
    ("git add two files",       "git add a.py b.py"),
    ("git add a directory",     "git add src/"),
    ("git add glob subset",     "git add *.py"),
    ("git add -u update",       "git add -u"),
    ("git add --update",        "git add --update"),
    ("git add -p patch",        "git add -p"),
    ("git add a variable",      "git add $FOO"),
    ("git add -u .",            "git add -u ."),
    ("git add --update .",      "git add --update ."),
    ("git add -u ./",           "git add -u ./"),
    ("git add -p .",            "git add -p ."),
    ("git add -i .",            "git add -i ."),
    ("git add -n .",            "git add -n ."),
    ("git add --dry-run .",     "git add --dry-run ."),
    ("git status",              "git status"),
    ("not a git command",       "ls -A"),
    ("git commit",              "git commit -m x"),
]


def main() -> int:
    failures = []
    for name, cmd in DENY_CASES:
        rc, out = run(cmd)
        if not is_deny(out):
            failures.append(f"EXPECTED DENY but allowed: {name!r} -> {cmd!r}")
        if rc != 0:
            failures.append(f"nonzero exit {rc} on deny case {name!r}")
    for name, cmd in ALLOW_CASES:
        rc, out = run(cmd)
        if is_deny(out):
            failures.append(f"EXPECTED ALLOW but denied: {name!r} -> {cmd!r}")
        if rc != 0:
            failures.append(f"nonzero exit {rc} on allow case {name!r}")

    # fail-open: exit 0, no deny, regardless of garbage input
    rc, out = run_raw("not json at all")
    if is_deny(out) or rc != 0:
        failures.append(f"malformed JSON not fail-open: rc={rc} out={out!r}")
    rc, out = run('git add "')  # unterminated quote -> bashlex ParsingError
    if is_deny(out) or rc != 0:
        failures.append(f"unterminated quote not fail-open: rc={rc} out={out!r}")
    rc, out = run("irrelevant", tool="Edit")
    if is_deny(out) or rc != 0:
        failures.append(f"non-Bash payload not allowed: rc={rc} out={out!r}")

    if failures:
        print(f"FAIL ({len(failures)}):")
        for f in failures:
            print(f"  {f}")
        return 1
    total = len(DENY_CASES) + len(ALLOW_CASES) + 3
    print(f"ok: {total} cases passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
