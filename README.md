# dotfiles

Personal dotfiles, forked from [obra/dotfiles](https://github.com/obra/dotfiles).

## Claude Code install

### Required: install the Superpowers plugin

The [`obra/superpowers`](https://github.com/obra/superpowers) plugin is a hard dependency of this config, not a recommendation. `CLAUDE.md` and the personal skills in this repo assume its skills are loaded — test-driven-development, systematic-debugging, writing-plans, brainstorming, verification-before-completion, and others are referenced directly. Without it, the workflow breaks.

Install it from the official marketplace before anything else:

```
/plugin install superpowers@claude-plugins-official
```

Use the actively maintained version (v5.0.7+). Skills evolve there faster than in any fork.

### Required: plugins the dev-workflow skills depend on

The `triage`/`feature`/`work` routers invoke skills from two more plugins — install both, or those commands fail with unknown-skill errors:

```
/plugin install mattpocock-skills@claude-plugins-official   # grilling, domain-modeling, research, prototype, codebase-design
/plugin marketplace add https://github.netflix.net/corp/gni-skills.git   # gni-skills isn't built in
/plugin install reviewers@gni-skills                        # reviewers:codex (the /work review), + the codex push gate
```

(`mattpocock-skills`' `to-spec`/`to-tickets`/`triage` are user-only, so the routers inline those steps rather than invoking them — but the model-invocable skills above must be present.)

### Personal skills + CLAUDE.md: symlink from this repo

`CLAUDE.md` and the personal skills (`java-style`, `grip-review`,
`e2e-scenario-testing`, and the `triage`/`feature`/`work`/`ship`/`dev-workflow`
set) live in this repo. Install them into `~/.claude/` with symlinks:

```bash
cd "$(git rev-parse --show-toplevel)"
mkdir -p ~/.claude/skills

ln -sf "$PWD/.claude/CLAUDE.md" ~/.claude/CLAUDE.md

for s in java-style grip-review e2e-scenario-testing triage feature work ship dev-workflow; do
  ln -sf "$PWD/.claude/skills/$s" "$HOME/.claude/skills/$s"
done
```

This coexists with the Superpowers plugin skills and any other skill dirs under `~/.claude/skills/`. `e2e-scenario-testing` (merged from upstream) verifies a running app through its real interface via agent-run scenario cards; see [`docs/e2e-scenario-testing.md`](docs/e2e-scenario-testing.md) for when and how to use it. The many other upstream skills under `.claude/skills/` (roborev, obsidian, windows-vm, …) are left unsymlinked and inert.

### Slash commands: symlink the whole dir from this repo

Unlike skills (which must coexist with the Superpowers plugin under `~/.claude/skills/`, so they're symlinked per-skill), the commands dir has no such neighbor — symlink the whole thing, and every command in this repo is wired at once:

```bash
cd "$(git rev-parse --show-toplevel)"
ln -sfn "$PWD/.claude/commands" "$HOME/.claude/commands"
```

- `/par` — dispatches two subagents to review your work adversarially, competing to find the most legitimate issues (disqualified for BS or inflated severity). A lightweight, model-internal mid-task review; complements the heavier `reviewers:codex` / `reviewers:bitbot` completion gate.
- `/story-loop` — drives a repo to a known-good state by cataloguing every capability as `e2e-scenario-testing` cards, then looping test → fix → re-test. Pairs with the `e2e-scenario-testing` skill.

The grip-review skill also needs its SessionEnd hook symlinked:

```bash
mkdir -p ~/.claude/hooks
ln -sf "$PWD/.claude/hooks/cleanup-grip.sh" "$HOME/.claude/hooks/cleanup-grip.sh"
```

Then merge `.claude/settings.grip-review-example.json` into your live `~/.claude/settings.json` (the live file is intentionally not tracked; the example shows the allow rule and the SessionEnd hook entry to add).

#### The dev-workflow skills

`triage`, `feature`, `work`, and `ship` are a four-verb development loop that
combines the Superpowers process spine with Matt Pocock's design skills, wired
to keep the coordinator context lean. They are **thin routers** — they invoke
the tuned upstream skills in order and stop at human gates; they do not
reimplement upstream content.

```
/triage   → decide what to build          (skip if no queue)
/feature  → design + break down            approve spec, then approve tickets
/work     → execute the tickets            autonomous between tickets
/ship     → verify + integrate             choose merge / PR / keep
```

They are **human-driven checklists**, deliberately not a state machine (a robust
state-machine attempt was abandoned as over-engineered — see
[ADR 0001](docs/decisions/0001-dev-workflow-simple.md)). `dev-workflow/` holds the
shared reference (`workflow.md`) and a trivial `scripts/workflow-state.sh` that
only scaffolds and lists (`init`, `tickets`). All triage/specs/tickets are local
files (never GitHub/Jira): flat `tickets/<NN>-<slug>.md` (with a `**Status:**`
line), `docs/specs/`, `docs/decisions/`, `CONTEXT.md`. No ledger, no
commit-pinning, no transactions — the human drives the gates. `/work`'s value is
the dual-model review (Superpowers + `reviewers:codex` + the Fowler smell lens).
Run `workflow-state.sh init` to scaffold. Tests: `bash tests/dev-workflow/test.sh`.

### Helper scripts: symlink from ~/bin

Scripts under `bin/` are meant to live on `PATH` via `~/bin/`:

```bash
cd "$(git rev-parse --show-toplevel)"
mkdir -p ~/bin

for b in bin/*; do
  ln -sf "$PWD/$b" "$HOME/bin/$(basename "$b")"
done
```

- `pyparse` — syntax-checks Python files via `ast.parse`, with no `.pyc` / `__pycache__` litter (unlike `python3 -m py_compile`). `pyparse FILE [FILE ...]`.
- `screen` — compatibility wrapper that maps common GNU `screen` invocations to `tmux`.

### Hooks at a glance

The Claude Code hooks in `.claude/hooks/`. All are opt-in: each is a script you symlink into `~/.claude/hooks/`, plus a checked-in `settings.*-example.json` you merge into your live `settings.json`. Details and install steps are in the sections below.

| Hook | Event — matcher | What it does |
|------|-----------------|--------------|
| [`enforce-subagent-model.py`](#optional-enforce-an-explicit-model-on-every-subagent-dispatch) | PreToolUse — `Agent`/`Task`/`Workflow` | Deny a subagent dispatch with no explicit `model` (except frontmatter-pinned `local-*` agents) |
| [`block-git-dash-c.py`](#optional-bash-behavior-nudge-hooks) | PreToolUse — `Bash(git */cd *)` | Block redundant `git -C` / `cd <cwd> && git …` |
| [`block-git-add-all.py`](#optional-bash-behavior-nudge-hooks) | PreToolUse — `Bash(git *)` | Block bulk `git add -A`/`--all`/`.`/`./`/`*` |
| [`read-write-edit-block.py`](#optional-bash-behavior-nudge-hooks) | PreToolUse — `Bash(cat/head/sed/echo *)` | Nudge single-file `cat`/`head`/`sed`/`echo` to Read/Write/Edit |
| [`block-docker-root.py`](#optional-block-docker-containers-running-as-root) | PreToolUse — `Bash(docker */docker-compose *)` | Deny `docker run`/`exec`/`create`/`compose run`/`compose exec` lacking a non-root `--user` |

(`cleanup-grip.sh`, a `SessionEnd` hook that kills leftover grip servers, belongs to the grip-review skill and is covered with it above. The pre-push review gate is no longer a local hook — it's the `reviewers` plugin's gate, wired globally; see [Pre-push review gate](#optional-pre-push-review-gate-via-the-reviewers-plugin).)

### Optional: pre-push review gate (via the `reviewers` plugin)

Blocks `git push` / `gh pr create` until the diff being pushed has been reviewed. This is the generic gate shipped by the [`reviewers`](https://github.netflix.net/corp/gni-skills) plugin (`review-gate.sh`), not a hand-rolled one — the home-grown `codex-gate.sh`/`codex-review-capture` were retired in favour of it. The plugin's `codex-review-capture.sh` writes a hash-keyed sentinel (`/tmp/review-gate-reviewed-${UID}-${repo}-${diffhash}`) on each successful `codex review` bug-finding pass; the gate hashes the diff being pushed and admits it only when a sentinel matches. Modify the tree and the hash drifts, so the gate re-blocks until you re-review.

Wired **globally** in `~/.claude/settings.json` (every repo, not per-project):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "if": "Bash(git push *) Bash(gh pr create *)",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/review-gate.sh" }
        ]
      }
    ]
  }
}
```

Requirements: `uv`, `python3`, and network on first use (the gate parses bash via `bashlex`; `uv` caches it after). Satisfy the gate with `/reviewers:codex --base <upstream>` for a branch push — **use `--base`, not `--commit HEAD`**: `--commit HEAD` reviews only the tip, so a multi-commit push can send earlier unreviewed commits and still match the sentinel. Only the bug-finding pass writes the sentinel, not the advisory design pass. The `reviewers` plugin must be installed (see the required-plugins section, incl. the `gni-skills` marketplace).

### Optional: bash behavior-nudge hooks

Three PreToolUse hooks that steer Bash invocations toward better-behaved forms — the dedicated Read/Write/Edit tools, cleaner git usage, or explicit staging:

- `block-git-dash-c.py` — denies `git -C/--git-dir/--work-tree <path-in-cwd>` and `cd <cwd> && git ...`. Both defeat Claude Code's auto-allow matcher for read-only git subcommands and force needless permission prompts.
- `read-write-edit-block.py` — denies single-file `cat`/`head`/`sed`/`echo` invocations covered by Read/Write/Edit. Skips pipes, multi-file, sed scripts, echo flags (`-n`/`-e`), and other shapes the dedicated tools can't replicate.
- `block-git-add-all.py` — denies bulk `git add` (`-A`, `--all`, `.`, `./`, `*`) that sweeps untracked scratch/litter into the index. Allows explicit paths, `git add <dir>/`, targeted globs (`*.py`), and `-u`. Parses with bashlex; fail-open.

Install the scripts:

```bash
cd "$(git rev-parse --show-toplevel)"
mkdir -p ~/.claude/hooks

for h in block-git-dash-c.py read-write-edit-block.py block-git-add-all.py; do
  ln -sf "$PWD/.claude/hooks/$h" "$HOME/.claude/hooks/$h"
done
```

Activate per-machine by merging entries from [`.claude/settings.git-dash-C-example.json`](.claude/settings.git-dash-C-example.json), [`.claude/settings.read-write-edit-block-example.json`](.claude/settings.read-write-edit-block-example.json), and [`.claude/settings.block-git-add-all-example.json`](.claude/settings.block-git-add-all-example.json) into `~/.claude/settings.json`. The examples use narrow `if: Bash(<cmd> *)` matchers so the hooks only run for the relevant commands.

### Optional: block docker containers running as root

`block-docker-root.py` is a PreToolUse Bash hook that denies `docker run`, `docker exec`, `docker create`, their `docker container …` aliases, and `docker compose run`/`exec` (and `docker-compose …`) when they lack an explicit **non-root numeric** `--user` — because those default to running the container process as **root** (uid 0), which writes root-owned files into mounted volumes and has broad host-mount access. Allowed: a non-zero numeric uid (`--user 1000`, `--user 65532`) or `--user $(id -u):$(id -g)`. Denied: no `--user`, `--user 0`/`root`, or a username (a name isn't proof of a non-root uid). The deny message steers Claude to `--user $(id -u):$(id -g)` or to hand you the exact command to run manually.

It parses docker's real option grammar with bashlex (per-subcommand value-flag tables, short-flag getopt), so a `--user` belonging to the in-container command isn't mistaken for docker's, and it makes no subprocess calls. Unlike the behavior-nudge hooks it **fails closed**: a parse failure or hook error denies a docker command in command position (but never a non-docker call that merely mentions `docker`).

**This is best-effort accident-prevention, not a security boundary.** Being in the `docker` group already grants host-root via the socket, so a shell hook can't stop a determined caller; it stops the ordinary mistake of running a container as root without thinking. Known gaps (by design): `docker start`/`restart` and `compose up`/`start`/`restart` (no CLI `--user`), invocations that don't begin with the bare command (`DOCKER_HOST=x docker …`, `/usr/bin/docker …`, `env docker …`), shell-expansion injection, non-default daemons, and flag-table drift. See the design spec for the full list.

Install the script:

```bash
cd "$(git rev-parse --show-toplevel)"
mkdir -p ~/.claude/hooks
ln -sf "$PWD/.claude/hooks/block-docker-root.py" "$HOME/.claude/hooks/block-docker-root.py"
```

Activate per-machine by merging [`.claude/settings.block-docker-root-example.json`](.claude/settings.block-docker-root-example.json) into `~/.claude/settings.json`. It uses two `if: Bash(docker *)` / `Bash(docker-compose *)` matchers so the hook only runs for docker commands.

### Optional: enforce an explicit model on every subagent dispatch

`enforce-subagent-model.py` is a PreToolUse hook that denies a subagent dispatch with no explicit `model`, so the choice is never left to silent inheritance of the session model. A dispatch with no `model` inherits the session model (often Opus) even when a mechanical, fully-specified task would run fine on a cheaper tier. The hook makes the choice conscious at dispatch time — any explicit model passes, including `"inherit"` if you genuinely want the session model (with one exception for `local-*` agents, below).

- **`Agent` / `Task`** — denied when `tool_input.model` is absent/falsy. **Exception:** when `subagent_type` starts with `local-`, the rule inverts. Such agents pin a full gateway model id in their frontmatter (a value CC's dispatch `model` enum won't accept), and that frontmatter only takes effect when the dispatch is model-less. So a model-less `local-*` dispatch is *allowed*, and a `local-*` dispatch *with* any `model` param (a tier, or `inherit`) is *denied* — the param would override the frontmatter and silently route the work to the cloud instead of the local gateway model. The hook trusts the `local-` prefix: it can't read frontmatter, so a `local-*` agent that omits `model:` in its own frontmatter would slip through — acceptable because this hook is a routing/cost nudge, not a data-residency guarantee (it fails open).
- **`Workflow`** — the launch is denied when any `agent(` call in the workflow script lacks a top-level `model` option (bare `model:` or quoted `'model':`). The script is read from inline `tool_input.script`, or from `tool_input.scriptPath` (the `.js` file on disk) when the launch points at one — file-launched workflows like deep-research carry their agents only there, and `scriptPath` is what actually runs, so it takes precedence over any stale inline `script`. This is a best-effort static text lint of the JavaScript: string/template-literal contents and `//` / `/* */` comments are blanked first, so an `agent(`/`model:` inside a prompt, description, or comment doesn't fool it, and a `model:` nested in a sibling config, an inline schema, or a nested `agent()` call doesn't satisfy the outer call. Known gaps, because this is a text lint rather than a JS parser: a `name`-launched saved/built-in workflow has no inline or file script to lint (a missed deny); a `model` supplied via a variable or spread isn't recognized as present, so such a call is *wrongly denied*; and regex literals (`/.../`) aren't recognized, so a quote inside one can blank following text — either hiding a call (a missed deny) or blanking a real `model:` option (a wrongful block). The wrongful-block cases are recoverable: write a literal `model:` (e.g. `model: 'haiku'`) at the call site. It enforces *presence* of a model, never *correctness of tier*.

The hook fails open: malformed input or an unexpected shape allows the dispatch — a hook bug must never block work.

Install the script:

```bash
cd "$(git rev-parse --show-toplevel)"
mkdir -p ~/.claude/hooks
ln -sf "$PWD/.claude/hooks/enforce-subagent-model.py" "$HOME/.claude/hooks/enforce-subagent-model.py"
```

Activate per-machine by merging [`.claude/settings.enforce-subagent-model-example.json`](.claude/settings.enforce-subagent-model-example.json) into `~/.claude/settings.json`. It adds `Agent`, `Task`, and `Workflow` matcher entries to `hooks.PreToolUse` (no `if` field — these match the whole tool, not a Bash sub-command).
