#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["bashlex==0.18"]
# ///
# ABOUTME: PreToolUse Bash hook denying docker run/exec/create/compose run|exec
# ABOUTME: that would run a container as root: requires an explicit non-root numeric --user.

import json
import os
import re
import sys

import bashlex
import bashlex.errors

HOOK_EVENT = "PreToolUse"

# docker global options that take a value (from `docker --help`), skipped to
# reach the subcommand (`docker -c ctx run …`, `docker -H tcp://h run …`).
DOCKER_GLOBAL_VALUE_FLAGS = {
    "-H", "--host", "-l", "--log-level", "--config", "-c", "--context",
    "--tlscacert", "--tlscert", "--tlskey",
}
# `docker compose` (v2) + standalone `docker-compose` (v1) global value-flags,
# skipped to reach the run/exec subcommand. Superset of both CLIs; over-inclusion
# only ever consumes a token (deny direction), so covering v1's connection flags
# (-H/--host/--tls*/--log-level) here is safe.
COMPOSE_GLOBAL_VALUE_FLAGS = {
    "--ansi", "--env-file", "-f", "--file", "--parallel", "-p",
    "--project-name", "--profile", "--progress", "--project-directory",
    "-H", "--host", "--log-level", "--tlscacert", "--tlscert", "--tlskey",
}

# Per-subcommand value-taking flags, from `docker <sub> --help` (docker 29.6.2).
# Long: kept complete for the current CLI -- a *missing* value-flag whose value
# is written `--user=X` could be misread as docker's own --user (false-allow), so
# completeness matters, not just the safe early-stop direction.
# Short: MUST be complete -- a missing short value-flag could misread an attached
# value as `-u` (e.g. `-eu1000` -> `-e u1000`, not `-u 1000`).
_RUN_VALUE_LONG = {
    "--add-host", "--annotation", "--attach", "--blkio-weight",
    "--blkio-weight-device", "--cap-add", "--cap-drop", "--cgroupns",
    "--cgroup-parent", "--cidfile", "--cpu-period", "--cpu-quota",
    "--cpu-rt-period", "--cpu-rt-runtime", "--cpus", "--cpuset-cpus",
    "--cpuset-mems", "--cpu-shares", "--detach-keys", "--device",
    "--device-cgroup-rule", "--device-read-bps", "--device-read-iops",
    "--device-write-bps", "--device-write-iops", "--dns", "--dns-option",
    "--dns-search", "--domainname", "--entrypoint", "--env", "--env-file",
    "--expose", "--gpus", "--group-add", "--health-cmd", "--health-interval",
    "--health-retries", "--health-start-interval", "--health-start-period",
    "--health-timeout", "--hostname", "--ip", "--ip6", "--ipc", "--isolation",
    "--label", "--label-file", "--link", "--link-local-ip", "--log-driver",
    "--log-opt", "--mac-address", "--memory", "--memory-reservation",
    "--memory-swap", "--memory-swappiness", "--mount", "--name", "--network",
    "--network-alias", "--oom-score-adj", "--pid", "--pids-limit", "--platform",
    "--publish", "--pull", "--restart", "--runtime", "--security-opt",
    "--shm-size", "--stop-signal", "--stop-timeout", "--storage-opt", "--sysctl",
    "--tmpfs", "--ulimit", "--user", "--userns", "--uts", "--volume",
    "--volume-driver", "--volumes-from", "--workdir",
}
_RUN_VALUE_SHORT = set("acehlmpuvw")
_EXEC_VALUE_LONG = {"--detach-keys", "--env", "--env-file", "--user", "--workdir"}
_EXEC_VALUE_SHORT = set("euw")
_COMPOSE_RUN_VALUE_LONG = {
    "--cap-add", "--cap-drop", "--env", "--entrypoint", "--env-from-file",
    "--label", "--name", "--publish", "--pull", "--user", "--volume", "--workdir",
}
_COMPOSE_RUN_VALUE_SHORT = set("elpuvw")
_COMPOSE_EXEC_VALUE_LONG = {"--env", "--index", "--user", "--workdir"}
_COMPOSE_EXEC_VALUE_SHORT = set("euw")

VALUE_FLAGS = {
    "run": (_RUN_VALUE_LONG, _RUN_VALUE_SHORT),
    "create": (_RUN_VALUE_LONG, _RUN_VALUE_SHORT),
    "exec": (_EXEC_VALUE_LONG, _EXEC_VALUE_SHORT),
    "compose-run": (_COMPOSE_RUN_VALUE_LONG, _COMPOSE_RUN_VALUE_SHORT),
    "compose-exec": (_COMPOSE_EXEC_VALUE_LONG, _COMPOSE_EXEC_VALUE_SHORT),
}
GUARDED_SUBCOMMANDS = {"run", "exec", "create"}

# --user values that resolve to the invoking user (accepted only when that user
# is not root -- see user_is_nonroot).
INVOKER_UID_TOKENS = {"$(id -u)", "$UID", "${UID}"}

PRESENT_NO_VALUE = object()  # sentinel: --user/-u present but value unreadable

# Fallback recogniser for parse failures: a docker/docker-compose token in
# *command position* (start, or after a shell separator, past any env-assignment
# prefix). Deliberately does NOT match `docker` inside a quoted string argument
# (e.g. `echo "docker`), to honour "never block a non-docker Bash call".
_DOCKER_CMD_POSITION = re.compile(
    r"(?:^|[;&|(]|&&|\|\|)\s*(?:[A-Za-z_]\w*=\S*\s+)*(?:docker|docker-compose)(?:\s|$)"
)

DENY_ROOT = (
    "This docker command would run the container as root: it has no explicit "
    "non-root --user in docker's own options. Re-run as yourself with "
    "`--user $(id -u):$(id -g)`, or pass `--user <uid>` with a non-zero NUMERIC "
    "uid (a username is not accepted -- a name can map to uid 0). If it "
    "genuinely needs root, do NOT run it -- print the exact command for the user "
    "to run manually."
)


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


def iter_command_nodes(node):
    """Yield every `command` node anywhere in the AST — inside lists, pipelines,
    compound bodies, subshells, command substitutions, and redirect targets
    (incl. process substitutions attached via `redirects`)."""
    if getattr(node, "kind", None) == "command":
        yield node
    for attr in ("parts", "list", "command", "output", "input", "redirects"):
        child = getattr(node, attr, None)
        if child is None:
            continue
        if isinstance(child, list):
            for c in child:
                if hasattr(c, "kind"):
                    yield from iter_command_nodes(c)
        elif hasattr(child, "kind"):
            yield from iter_command_nodes(child)


def command_words(cmd_node) -> list[str]:
    """Literal word texts of a simple command; an env-assignment prefix
    (`DOCKER_HOST=…`) is a bashlex `assignment` part, not a word, so it drops out."""
    return [word_text(p) for p in cmd_node.parts if getattr(p, "kind", None) == "word"]


def _skip_value_flags(tokens: list[str], value_flags: set[str]) -> int:
    """Index of the first non-option token, skipping option flags — a value-taking
    flag with no `=` consumes the following token too."""
    i, n = 0, len(tokens)
    while i < n and tokens[i].startswith("-") and tokens[i] != "-":
        if tokens[i] in value_flags and "=" not in tokens[i] and i + 1 < n:
            i += 2
        else:
            i += 1
    return i


def docker_invocation(words: list[str]):
    """If `words` is a guarded docker invocation, return (kind, args) where kind
    is 'run'|'exec'|'create'|'compose-run'|'compose-exec' and args are the tokens
    after the subcommand keyword. Else None."""
    if not words:
        return None
    head = words[0]
    if head == "docker":
        i = 1 + _skip_value_flags(words[1:], DOCKER_GLOBAL_VALUE_FLAGS)
        if i >= len(words):
            return None
        sub = words[i]
        if sub in GUARDED_SUBCOMMANDS:
            return (sub, words[i + 1:])
        if sub == "container" and i + 1 < len(words) and words[i + 1] in GUARDED_SUBCOMMANDS:
            return (words[i + 1], words[i + 2:])
        if sub == "compose":
            return _compose_sub(words[i + 1:])
        return None
    if head == "docker-compose":
        return _compose_sub(words[1:])
    return None


def _compose_sub(rest: list[str]):
    """rest = tokens after `compose` / after `docker-compose`. Skip compose global
    flags; return ('compose-run'|'compose-exec', args) for a run/exec subcommand."""
    i = _skip_value_flags(rest, COMPOSE_GLOBAL_VALUE_FLAGS)
    if i < len(rest):
        if rest[i] == "run":
            return ("compose-run", rest[i + 1:])
        if rest[i] == "exec":
            return ("compose-exec", rest[i + 1:])
    return None


def _scan_short_cluster(tok: str, args: list[str], i: int, short_vf: set[str]):
    """`tok` is a single-dash short cluster (e.g. -itu, -u0, -u=0, -euser). The
    first char that is a short value-flag takes the rest of the token (an optional
    `=` is stripped, matching pflag) or the next token as its value and ends the
    cluster. Return (user_value_or_None, consumed_next_bool); user_value is set
    only when that value-flag is `-u`."""
    n = len(args)
    for j in range(1, len(tok)):
        c = tok[j]
        if c in short_vf:
            val = tok[j + 1:]
            if val.startswith("="):
                val = val[1:]
            if val:
                return (val if c == "u" else None), False
            if i + 1 < n:
                return (args[i + 1] if c == "u" else None), True
            return (PRESENT_NO_VALUE if c == "u" else None), False
    return None, False  # all boolean short flags


def docker_user(kind: str, args: list[str]):
    """docker's effective `--user`/`-u` value in the OPTION region of `args`
    (before the first positional or `--`), last-wins; PRESENT_NO_VALUE if present
    with no readable value; None if absent. A `--user` after the positional
    belongs to the container command and is ignored."""
    long_vf, short_vf = VALUE_FLAGS[kind]
    user = None
    i, n = 0, len(args)
    while i < n:
        a = args[i]
        if a == "--" or not a.startswith("-") or a == "-":
            break  # end of options / first positional
        if a in ("--user", "-u"):
            user, i = (args[i + 1], i + 2) if i + 1 < n else (PRESENT_NO_VALUE, i + 1)
            continue
        if a.startswith("--user="):
            user = a[len("--user="):]
            i += 1
            continue
        if a.startswith("--"):
            flag = a.split("=", 1)[0]
            i += 2 if ("=" not in a and flag in long_vf and i + 1 < n) else 1
            continue
        cap, consumed_next = _scan_short_cluster(a, args, i, short_vf)
        if cap is not None:
            user = cap
        i += 2 if consumed_next else 1
    return user


def user_is_nonroot(value) -> bool:
    """True iff a --user value is a proven non-root user: an invoker token
    ($(id -u)/$UID/${UID}) *when the hook itself is not running as root*, or a
    non-zero decimal uid. Names, 0/00/root, empty, and unresolved values are NOT
    proven non-root."""
    if value is PRESENT_NO_VALUE or value is None:
        return False
    uid = value.split(":", 1)[0]
    if uid in INVOKER_UID_TOKENS:
        return os.getuid() != 0
    return uid.isascii() and uid.isdigit() and int(uid) != 0


def inspect_command(cmd: str) -> None:
    """Parse and walk `cmd`; deny() on any guarded docker command lacking an
    explicit non-root --user."""
    for tree in bashlex.parse(cmd):
        for node in iter_command_nodes(tree):
            info = docker_invocation(command_words(node))
            if info is None:
                continue
            kind, args = info
            if not user_is_nonroot(docker_user(kind, args)):
                deny(DENY_ROOT)


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        return
    if data.get("tool_name") != "Bash":
        return
    cmd = (data.get("tool_input") or {}).get("command", "")
    if not cmd:
        return

    try:
        inspect_command(cmd)
    except bashlex.errors.ParsingError:
        # Couldn't parse to verify: deny only if a docker command sits in command
        # position; never block a non-docker call that merely contains "docker".
        if _DOCKER_CMD_POSITION.search(cmd):
            deny(DENY_ROOT + " (command could not be parsed to verify).")
    except Exception:
        if _DOCKER_CMD_POSITION.search(cmd):
            deny(DENY_ROOT + " (hook error; run manually to verify).")


if __name__ == "__main__":
    main()
