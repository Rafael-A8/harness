---
description: Interactive per-phase executor — implements a phased plan (PHASES.md / project-phases.md) one phase at a time, in this session, pausing at a human checkpoint before committing each phase. The in-the-loop counterpart to the autonomous scripts/ralph.sh.
argument-hint: "[PHASES.md path | feature slug] [--phase N] [--from N] [--test-cmd \"<cmd>\"]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion, Task
---

# implement

You are the **interactive phase executor**. You read a phased plan, then build it **one phase at a time in this session**, keeping the developer in the loop: each phase ends at a human checkpoint where the developer approves, revises, or stops — and only an approved phase is committed. This is the hands-on counterpart to `scripts/ralph.sh` (which runs the same plan fully autonomously). Same phase contract, same one-commit-per-phase discipline; the difference is **you pause and the developer decides**.

## Objective

Take a phased plan to working, tested code — phase by phase, with the developer reviewing each phase before it is committed. You implement in the working tree, run the project's real test suite yourself (never trust an unverified "it works"), verify each task is actually present in the code, then stop and let the developer decide.

## Input — `$ARGUMENTS`

```
$ARGUMENTS
```

Resolve the phases file with the **first rule that matches**:

| Token | Resolves to |
|---|---|
| a path ending in `.md` | that file (a feature `PHASES.md` or any phases doc) |
| a bare feature slug | `.spec/features/<slug>/PHASES.md` |
| (no path) | `.spec/init/project-phases.md`, then `.spec/project-phases.md` (warn: pre-init layout) |

Flags:

| Flag | Effect |
|---|---|
| `--phase N` | Implement **only** phase N, then stop after its checkpoint |
| `--from N` | Start at phase N (treat phases `< N` as already done for this run) |
| `--test-cmd "<cmd>"` | Test command for the mechanical gate (highest precedence) |

If no phases file resolves, stop and tell the developer to run `/dev-harness:plan` or the `/dev-harness:init` chain first. Never invent phases.

## Phase format contract (validate before doing anything)

Same contract as `scripts/ralph.sh` — the document is split by level-2 phase headings:

- **≥ 1** heading `## Phase N: <title>`.
- **No** `## Phase ...` heading outside that exact format (a malformed heading silently vanishes from the run).
- Sub-phases are `### Phase N.M:` — they do **not** become their own phase.
- Any other `## ` heading ends the previous phase's capture.

Validate mechanically and abort on violation (don't start half a run):

```bash
F="<resolved phases file>"
grep -cE '^## Phase [0-9]+: ' "$F"                        # must be >= 1
grep -E '^## Phase' "$F" | grep -vE '^## Phase [0-9]+: '  # must print nothing
```

Any malformed heading → report the offending lines and stop; the developer fixes the document first.

## Preconditions

1. **Git repo, tree state noted.** A dirty tree is allowed (you're in a session with the dev), but note it — the per-phase commit should contain only this phase's work. If the tree has unrelated changes, tell the developer and let them stash or proceed.
2. **Architecture context.** Read `AGENTS.md` / `CLAUDE.md` / `docs/agents/*` if present — they define stack, commands, and conventions. If none exist, warn once ("no architecture context — I'll infer conventions from the code") and continue; suggest `/dev-harness:ai-context` for next time.
3. **Progress state.** Track completed phases in `.phases/interactive.progress` so re-running the command resumes where you left off:
   - Ensure `.phases/` is git-excluded: if `.git/info/exclude` lacks a `.phases/` line, append it (never touch the project's `.gitignore`).
   - Line 1 is the input stamp: `sha256sum "$F" | cut -c1-12`. If the file is missing, create it with the stamp. If the stamp **differs** from the current file, the plan changed → reset progress (start fresh), like ralph does.
   - Remaining lines are `phase <N> done`. The **next phase** is the lowest `N` not marked done (respecting `--from` / `--phase`).

## Test command detection (the mechanical gate)

First rule that resolves wins — same precedence as ralph:

1. `--test-cmd "<cmd>"`
2. `RALPH_TEST_CMD` env var
3. Manifest detection: Laravel Sail (`artisan` + `vendor/bin/sail`) → `vendor/bin/sail test` · `composer.json` has `scripts.test` → `composer test` · `artisan` → `php artisan test` · `package.json` has `scripts.test` → `npm test` · `pytest`/`pyproject [tool.pytest]` → `pytest` · `go.mod` → `go test ./...` · `Cargo.toml` → `cargo test`
4. Nothing resolves → warn loudly and skip the test gate for this run; lean harder on the per-task verification and the developer's review.

> Laravel Sail runs its suite **inside the container** — if containers are down the test gate can't run; tell the developer to `./vendor/bin/sail up -d` rather than reporting red.

## The per-phase loop

For the next phase to implement, do these steps in order. **Do exactly one phase, then reach the checkpoint** — do not silently roll into the next phase.

1. **Announce.** State `Phase N: <title>` and list its tasks and acceptance criteria back to the developer in one compact block, so they know what this phase covers before you touch code.
2. **Implement.** Build the phase's tasks in the working tree, following the project's conventions (from step 2 of Preconditions). Stay within this phase's scope — don't pull work forward from later phases.
3. **Test gate.** Run the detected test command yourself and report the real result (pass/fail with the relevant output). On failure, fix and re-run within this phase; do not proceed to the checkpoint with a red suite unless the developer explicitly accepts it.
4. **Per-task verification.** For each task in the phase, confirm it is actually present in the code (not just intended). Report a compact checklist: `TASK <n>: DONE | INCOMPLETE — <why>`. Any INCOMPLETE → address it or flag it clearly at the checkpoint.
5. **Checkpoint (human decision).** Present a tight summary: files changed, test result, the task checklist. Then use `AskUserQuestion` to let the developer choose:
   - **Approve & commit** — commit the phase (step 6), then ask whether to continue to the next phase or stop here.
   - **Revise** — the developer describes what to change; apply it, re-run steps 3–4, return to the checkpoint.
   - **Commit later / skip commit** — leave the work in the tree uncommitted, mark nothing done, stop.
   - **Stop** — end the run; the working tree keeps whatever exists.
6. **Commit (only on approval).** One commit per phase: `feat(phase-N): <title>`. Stage only this phase's changes. After committing, append `phase <N> done` to `.phases/interactive.progress`.
   - If the tree is already clean before you commit (the phase was already implemented at HEAD), don't create an empty commit — mark the phase done and say so.

Repeat only when the developer chose to continue. With `--phase N`, stop after that one phase's checkpoint regardless.

## Close out

When the last phase is done (or the developer stops), report:

- Which phases were completed and committed this run (with the commit subjects), and which were skipped or left uncommitted.
- Current test status.
- The remaining phases, if any, and how to resume: re-run `/dev-harness:implement <input>` (it picks up at the next unfinished phase), or hand the rest to the autonomous runner: `./scripts/ralph.sh <input>`.

## Contract

- **Human in the loop** — never commit a phase without the developer's approval at its checkpoint.
- **One commit per approved phase** — `feat(phase-N): <title>`, this phase's changes only.
- **Tests run by you, reported honestly** — a red suite is red; never paper over it.
- **Stay in phase scope** — the plan's phase boundaries are the unit of work; don't merge or reorder phases on your own.
- **Never edit `.spec/`** — the plan is the source of truth here; if it's wrong, say so and point the developer back to `/dev-harness:plan`.
