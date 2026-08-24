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
/triage   → decide what to build        (skip if no inbound queue)
/feature  → design + break down work     approve spec, then approve tickets
/work     → execute all tickets          autonomous — no gate between tickets
/ship     → verify + integrate           choose merge / PR / keep
```

`dev-workflow/` holds the shared reference (`workflow.md`, the single source of
truth) and `scripts/workflow-state.sh`, which scaffolds and reads a project's
**local-only** tracker. All triage/specs/tickets are local files in the project
repo — never GitHub Issues or Jira. Per project, the loop uses `CONTEXT.md`,
`docs/specs/`, `docs/decisions/` (ADRs), `tickets/`, and `.ai/workflow.yaml`
(the durable ledger / recovery map). Run
`workflow-state.sh init` in a project to scaffold that layout. Tests:
`bash tests/dev-workflow/test.sh`.

### Helper scripts: symlink from ~/bin

Scripts under `bin/` are meant to live on `PATH` via `~/bin/`:

```bash
cd "$(git rev-parse --show-toplevel)"
mkdir -p ~/bin

for b in bin/*; do
  ln -sf "$PWD/$b" "$HOME/bin/$(basename "$b")"
done
```

- `codex-review-capture` — wrapper around `codex review` used by the [codex pre-push gate](#optional-codex-pre-push-gate) below. Captures the full transcript to `/tmp/codex-review.*` (owner-only, cleaned on reboot) and prints only the verdict (content after the last `^codex$` marker) to stdout.
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
| [`codex-gate.sh`](#optional-codex-pre-push-gate) (+ `codex-gate-pass.sh`) | PreToolUse `git push`/`gh pr create` + PostToolUse | Block a push/PR until a `codex review` ran on the diff |

(`cleanup-grip.sh`, a `SessionEnd` hook that kills leftover grip servers, belongs to the grip-review skill and is covered with it above.)

### Optional: codex pre-push gate

`bin/codex-review-capture` and the hooks in `.claude/hooks/` together implement a per-project gate that blocks `git push` and `gh pr create` until a `codex review` has run with a recognized mode flag in the same Claude Code session, and re-blocks if the diff has changed since.

Flow:
1. The model runs `codex-review-capture --commit <sha>` (or `--base <branch>`, or `--uncommitted`). The wrapper detects the mode and computes `(BASE, HASH)` for exactly the diff codex sees, *before* invoking codex (so a long-running review can't be raced by working-tree edits). On `rc=0` the wrapper leaves a staged file at `/tmp/codex-gate-staged-${UID}-${repo}-${pid}` and prints `staged=<path>` to stderr.
2. `codex-gate-pass.sh` (PostToolUse, only fires on success) reads the staged path from `tool_response.stderr` and renames the file to a session-keyed sentinel `/tmp/codex-gate-${SESSION_ID}-${repo}`.
3. `codex-gate.sh` (PreToolUse on `git push *` / `gh pr create *`) recomputes `git diff BASE` against the current tree, compares to the stored hash, and either consumes the sentinel and allows the push or exits 2 with a message.

Caveats:
- The hooks are opt-in per project. Each project that wants the gate references the scripts from its own `.claude/settings.local.json`.
- `codex-review-capture --uncommitted` requires a clean untracked state. If untracked files are present, the wrapper fails closed with a stderr message asking you to `git add` them first. This avoids index mutation and keeps the gate's verification logic simple.
- `codex-review-capture` without a mode flag does not write a sentinel — the gate fails closed.
- `--commit X` reviews only commit X's diff. The gate then checks that the working tree at push time produces the same diff vs `X^`, but it does NOT verify that only X is being pushed. For multi-commit branches, prefer `--base <branch>` to review the full unpushed range.

Install the hook scripts once:

```bash
cd "$(git rev-parse --show-toplevel)"
mkdir -p ~/.claude/hooks

for h in codex-gate.sh codex-gate-pass.sh; do
  ln -sf "$PWD/.claude/hooks/$h" "$HOME/.claude/hooks/$h"
done
```

Activate the gate in a project by merging the contents of [`.claude/hooks/settings.local.example.json`](.claude/hooks/settings.local.example.json) into that project's `.claude/settings.local.json`. The example uses each hook entry's `if` field (permission-rule syntax) so the scripts only spawn for the gated commands — no overhead on every Bash call.

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
