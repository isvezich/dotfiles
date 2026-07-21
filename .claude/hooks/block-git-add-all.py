#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["bashlex"]
# ///
# ABOUTME: PreToolUse Bash hook denying bulk `git add` (-A/--all/./ ./ /*) that
# ABOUTME: sweeps untracked scratch/litter into the index; nudge to stage paths.

import json
import sys

import bashlex
import bashlex.errors

HOOK_EVENT = "PreToolUse"
BULK_PATHSPECS = {".", "./", "*"}
BULK_LONG_FLAGS = {"--all"}
GIT_GLOBAL_VALUE_FLAGS = {"-c", "-C", "--git-dir", "--work-tree"}
SAFE_MODE_FLAGS = {"-u", "--update", "-p", "--patch", "-i", "--interactive", "-n", "--dry-run"}


def deny(reason: str) -> None:
    json.dump(
        {
            "hookSpecificOutput": {
                "hookEventName": HOOK_EVENT,
                "permissionDecision": "deny",
                "permissionDecisionReason": reason,
            }
        },
        sys.stdout,
    )
    sys.exit(0)


def word_text(word_node) -> str:
    return getattr(word_node, "word", "") or ""


def iter_simple_commands(node):
    """Yield each top-level `command` node. Commands inside pipelines, compound
    statements (for/while/if/case), and substitutions are skipped -- bulk adds
    there are not the accidental case this nudge targets."""
    kind = node.kind
    if kind == "command":
        yield node
        return
    if kind == "list":
        for part in node.parts:
            if part.kind == "operator":
                continue
            yield from iter_simple_commands(part)


def command_words(cmd_node) -> list[str]:
    """Literal word texts of a simple command. Returns [] for an assignment/
    env-prefixed command (`FOO=bar git ...`) -- the prefix may matter and the
    hook can't tell, so it stays out."""
    words: list[str] = []
    for part in cmd_node.parts:
        if part.kind == "assignment":
            return []
        if part.kind == "word":
            words.append(word_text(part))
    return words


def is_bulk_add_arg(tok: str) -> bool:
    """A bulk-add form: -A, --all, ., ./, *, or -A inside a short-flag cluster
    (e.g. -Av / -vA). `-A` is the only git-add short flag that uses the letter
    A, so 'cluster contains A' is exactly 'cluster contains --all' -- -u/-p/-n/-N
    never match."""
    if tok in BULK_PATHSPECS or tok in BULK_LONG_FLAGS:
        return True
    if tok.startswith("-") and not tok.startswith("--") and "A" in tok[1:]:
        return True
    return False


def bulk_git_add_arg(words: list[str]) -> str | None:
    """If `words` is a `git ... add ...` invocation carrying a bulk form, return
    the offending literal arg, else None. Skips git global options to reach the
    subcommand."""
    if not words or words[0] != "git":
        return None
    i = 1
    n = len(words)
    while i < n:
        t = words[i]
        if t in GIT_GLOBAL_VALUE_FLAGS and i + 1 < n:
            i += 2
        elif t.startswith("-"):
            i += 1
        else:
            break
    if i >= n or words[i] != "add":
        return None
    rest = words[i + 1:]
    # Modes that cannot accidentally sweep untracked files: -u/--update stages
    # tracked files only; -p/--patch and -i/--interactive select interactively;
    # -n/--dry-run stages nothing. When one is present a bulk `.`/`*` pathspec
    # is not an accidental litter sweep, so don't flag it.
    if any(a in SAFE_MODE_FLAGS for a in rest):
        return None
    for t in rest:
        if is_bulk_add_arg(t):
            return t
    return None


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    if data.get("tool_name") != "Bash":
        sys.exit(0)

    cmd = (data.get("tool_input") or {}).get("command", "")
    if not cmd:
        sys.exit(0)

    try:
        trees = bashlex.parse(cmd)
    except bashlex.errors.ParsingError:
        # Unparseable bash (unbalanced quotes, bare heredoc): fail open.
        sys.exit(0)

    for tree in trees:
        for cmd_node in iter_simple_commands(tree):
            offending = bulk_git_add_arg(command_words(cmd_node))
            if offending is not None:
                deny(
                    f"`git add {offending}` sweeps every matching file into the "
                    "index, including untracked scratch and litter. Stage the "
                    "specific paths you mean instead: `git add path/to/file ...`. "
                    "Run `git status` to see what's there."
                )

    sys.exit(0)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        # Fail open: quality-of-life hook, not a security boundary. A crash
        # must not block the user's Bash call.
        sys.exit(0)
