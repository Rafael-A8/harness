# Changelog

All notable changes to **dev-harness** are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/) and the project uses [Semantic Versioning](https://semver.org/).

## [0.5.0] — 2026-10-21

### Added
- **`RALPH_MODEL`** — model for the implementation session (claude and codex). Without it the session inherits the CLI default, which may be the most expensive model.

### Fixed
- **Session limit detection** (`ralph.sh`): the claude *session* limit ("You've hit your session limit · resets 7:10pm") didn't match `usage limit reached`, so it was treated as a code failure and burned the phase's fix cycles. Now also matches `hit your session limit` and the engine JSON's `"api_error_status":429` (key + value, so a bare `429` in test output is still ignored). A human reset time (`resets 7:10pm`) is parsed into the wait epoch instead of falling back to 30-minute naps.
- **Read-only verifier** now uses `--tools "Read,Glob,Grep"` instead of `--allowedTools`. With `--dangerously-skip-permissions`, `--allowedTools` only auto-approves and restricts nothing — the verifier ran Bash, fired tests against the test DB and failed the phase with a deadlock it caused itself.
- **Gate 3 parser** strips leading markdown (`**`, `_`, `#`, `>`, `-`) before matching `TASK n: DONE|INCOMPLETE`. Bolded answers were ignored and the phase burned a cycle with the work already done.

### Changed
- Implementation prompt: the agent no longer runs the full suite (that is gate 2, run by ralph after the session). It runs only the phase's tests, filtered and in the **foreground** — never tests in the background, which outlive the session and deadlock the test DB against gate 2.

## [0.4.0] — 2026-07-11

### Added
- **`build-guard.sh`** hook (PreToolUse/Bash, **on by default**) — blocks JS dev-servers/builds (`npm/yarn/pnpm/bun run dev|build|start|serve|watch|preview`, `vite`, `webpack`, `next|nuxt dev|build`, `ng serve|build`) that hang the session or dump huge output and burn tokens. Suggests running via `!<command>`. Disable with `DEV_HARNESS_BUILD_GUARD=0`.
- README **Hooks** section documenting both hooks and their toggles.

### Changed
- **`sail-guard.sh` is now opt-in** (`DEV_HARNESS_SAIL_GUARD=1` to enable), default **off**. A plain Laravel app ships `vendor/bin/sail` even when run on the host (Laragon, `php artisan` directly), so on-by-default wrongly blocked those projects.

## [0.3.0] — 2026-07-11

### Added
- **`/dev-harness:implement`** — interactive per-phase executor. Implements a phased plan (`PHASES.md` / `project-phases.md`) one phase at a time **in-session**, pausing at a human checkpoint before committing each phase. The in-the-loop counterpart to the autonomous `scripts/ralph.sh`, sharing the same phase contract and one-commit-per-phase discipline.
- **`TUTORIAL.md`** — Obsidian-friendly guide: installing on another dev's machine (private repo via SSH), the commands with everyday-usage examples, and the `ralph.sh` executor.
- `CHANGELOG.md` and a release/versioning flow (annotated `vX.Y.Z` tags).

### Changed
- **Database schema conventions** (`init:database-schema`):
  - Enums/categorical fields are now stored as `integer` (preferred) or `string` columns handled by an **application-level enum** — the lookup-table-per-enum rule was removed.
  - Foreign-key guidance points only at real relationships, never at categorical values.
  - File uploads are stored as a `string`/`text` **reference** (the file lives in storage, never in the DB).
  - JSON payloads are stored as `longtext` (portable, app-parsed) instead of a DB-native `json`/`jsonb` type.
- `init:project-phases` wording aligned to the enum-column convention.

## [0.2.0] — 2026-07-11

### Changed
- Rebranded to **dev-harness** (marketplace `alvarino-harness`); updated author/owner metadata and internal command namespaces.

[0.5.0]: https://github.com/Rafael-A8/harness/releases/tag/v0.5.0
[0.4.0]: https://github.com/Rafael-A8/harness/releases/tag/v0.4.0
[0.3.0]: https://github.com/Rafael-A8/harness/releases/tag/v0.3.0
[0.2.0]: https://github.com/Rafael-A8/harness/releases/tag/v0.2.0
