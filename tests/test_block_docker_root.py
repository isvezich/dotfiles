#!/usr/bin/env python3
# ABOUTME: Test suite for .claude/hooks/block-docker-root.py — pipes synthetic
# ABOUTME: PreToolUse JSON in and asserts deny/allow/fail-closed. Run: python3 tests/test_*.py.

import json
import subprocess
import sys
from pathlib import Path

HOOK = Path(__file__).resolve().parent.parent / ".claude" / "hooks" / "block-docker-root.py"
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
    ("run, no user",            "docker run img"),
    ("--user 0",                "docker run --user 0 img"),
    ("--user root",             "docker run --user root img"),
    ("--user 00 (zero)",        "docker run --user 00 img"),
    ("--user 0:0",              "docker run --user 0:0 img"),
    ("--user=0",                "docker run --user=0 img"),
    ("-u0",                     "docker run -u0 img"),
    ("-u 0",                    "docker run -u 0 img"),
    ("-itu0 cluster root",      "docker run -itu0 img"),
    ("username",                "docker run --user svezich img"),
    ("bare --user val=img",     "docker run --user img"),
    ("unclassifiable var",      "docker run --user $SOMEVAR img"),
    ("--userns not user",       "docker run --userns=host img"),
    ("user after image",        "docker run alpine echo --user 1000"),
    ("repeat --user last wins", "docker run --user 1000 --user 0 img"),
    ("-euser is -e not -u",     "docker run -euser img"),
    ("-eu0 is -e not -u",       "docker run -eu0 img"),
    ("-v value not user",       "docker run -v /usr:/x img"),
    ("--pull no user",          "docker run --pull=always img"),
    ("--name no user",          "docker run --name foo img"),
    ("--mount no user",         "docker run --mount type=bind,src=/a,dst=/b img"),
    ("exec, no user",           "docker exec c sh"),
    ("exec -u 0",               "docker exec -u 0 c sh"),
    ("exec -it no user",        "docker exec -it c bash"),
    ("create, no user",         "docker create img"),
    ("container create no usr", "docker container create img"),
    ("compose run no user",     "docker compose run svc"),
    ("docker-compose run",      "docker-compose run svc"),
    ("compose exec --user 0",   "docker compose exec --user 0 svc sh"),
    ("compose exec no user",    "docker compose exec svc sh"),
    ("dc exec -u 0",            "docker-compose exec -u 0 svc sh"),
    ("compose exec -u root",    "docker compose exec -u root svc sh"),
    ("--ip6 no user",           "docker run --ip6 2001:db8::33 img"),
    ("compound && run",         "docker build . && docker run img"),
    ("env prefix stripped",     "DOCKER_HOST=x docker run img"),
    ("global -c then run",      "docker -c prod run img"),
    ("global -H then run",      "docker -H tcp://h:2375 run img"),
    ("parse err docker pos",    'docker run "'),
    ("parse err compound pos",  'pytest && docker run "'),
]

ALLOW_CASES = [
    ("--user 1000",             "docker run --user 1000 img"),
    ("--user 1000:1000",        "docker run --user 1000:1000 img"),
    ("-u 65532",                "docker run -u 65532 img"),
    ("--user=1000",             "docker run --user=1000 img"),
    ("-u65532 attached",        "docker run -u65532 img"),
    ("-u1000:1000",             "docker run -u1000:1000 img"),
    ("-u=1000 (= stripped)",    "docker run -u=1000 img"),
    ("-itu 1000 cluster",       "docker run -itu 1000 img"),
    ("-itu=65532 cluster =",    "docker run -itu=65532 img"),
    ("$(id -u):$(id -g)",       "docker run --user $(id -u):$(id -g) img"),
    ("$UID",                    "docker run --user $UID img"),
    ("${UID}",                  "docker run --user ${UID} img"),
    ("-e then user",            "docker run -e FOO=bar --user 1000 img"),
    ("exec --user 1000",        "docker exec --user 1000 c sh"),
    ("container create --user", "docker container create --user 1000 img"),
    ("compose run --user",      "docker compose run --user 1000 svc"),
    ("compose exec --user",     "docker compose exec --user 1000 svc sh"),
    ("dc exec --user",          "docker-compose exec --user 65532 svc sh"),
    ("compose globals + run",   "docker compose -f x.yml --progress plain run --user 1000 svc"),
    ("global -H + user",        "docker -H tcp://h:2375 run --user 1000 img"),
    ("--name then user",        "docker run --name foo --user 1000 img"),
    ("--mount then user",       "docker run --mount type=bind,src=/a,dst=/b --user 1000 img"),
    ("--ip6 then user",         "docker run --ip6 2001:db8::33 --user 1000 img"),
    ("user then container -u",  "docker run --user 1000 img id -u"),
    ("entrypoint then user",    "docker run --entrypoint /bin/sh --user 65532 img -c echo"),
    # Not guarded -> no deny.
    ("docker ps",               "docker ps"),
    ("docker build",            "docker build -t x ."),
    ("docker images",           "docker images"),
    ("docker logs",             "docker logs c"),
    ("docker start",            "docker start c"),
    ("compose up",              "docker compose up -d"),
    ("not a docker command",    "git status"),
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

    # Never block a non-docker Bash call, even garbage or `docker` inside a string.
    rc, out = run_raw("not json at all")
    if is_deny(out) or rc != 0:
        failures.append(f"malformed JSON not exit-0: rc={rc} out={out!r}")
    rc, out = run('echo "docker run as root')  # non-docker; 'docker' only in a string, unterminated
    if is_deny(out) or rc != 0:
        failures.append(f"docker-in-string false-blocked: rc={rc} out={out!r}")
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
