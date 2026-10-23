# Common brief for every builder agent — "Nocna Zmiana" (Godot 4.7.2 boomer shooter, Floor I)

Project root (main checkout, branch `pietro-1` = integration branch): `D:\ClaudeCode\Doomer Shooter`.
You work ONLY in your own worktree (path given in your task). Never touch other worktrees or anything outside the project folder.

## Hard rules (owner's, non-negotiable)
1. **Windows and sound.** By default: NO windows, NO sound — only `--headless` Godot, `blender -b`, scripts. The controller tells you when NIGHT MODE is on (the owner is away): then windowed runs are allowed ONLY through the PC-wide lock — `bash tools/agents/with_window.sh <windowed command>` (one window on the whole PC at a time; keep each run < 10 min, batch your views). Audio ALWAYS stays muted (never `SOUND=1`). Look at your screenshots with the Read tool. Anything you could not check goes to your plan doc's "Do sprawdzenia w oknie" list.
2. Nothing goes to GitHub. Commit locally only. Never push. Git author/email are configured repo-locally — don't change git config.
3. Installs only on drive D:, free/open-source only; no downloads without the controller's explicit OK. At most ONE Blender process at a time, no Cycles renders.
4. Don't spawn sub-agents. Commit messages in English, plan docs in Polish (match existing docs). End commit messages with your Co-Authored-By trailer.
5. `tools/godot` in a worktree is a junction to the main Godot — never delete it or `git clean -x` it.
6. When you finish (or are stopped), make sure no Godot/Blender/Python process you started is left running (`TaskStop` does not kill them — use `taskkill /T /PID ...` on your own processes only).

## How the project works
- Tests: `bash tools/run_tests.sh` (all, ~2900, headless, `--fixed-fps 60`) or `--filter=a,b`. A run fails on any test failure OR any engine `ERROR` line/leak.
  With many agents running, run the full suite SINGLE-PROCESS (RAM: 64 GB shared, each Godot test process peaks ~3 GB). Only when the controller says the PC is quiet may you use `-j 2`…`-j 6` (`--parallel`).
- TDD: failing test first, then code; one commit per task; keep the suite green.
- Plans: `docs/superpowers/plans/*.md`. Spec: `docs/Nocna-Zmiana-specyfikacja.md`. Backlog: `docs/backlog-pietro1.md`.
- After room/opening changes rerun `bash tools/bake_shell_cache.sh`.
- Shared files many branches touch (`locale/strings.csv`, `tests/test_runner.gd`, `src/game/floor1/floor_game.gd`, zone files, `guardian_scenario.gd`, `floor1_art.gd`, `export_presets.cfg`): small additive edits so merges are clean unions.
- Edit `.gd` files with the Edit tool (Python text-mode writes turn LF into CRLF).
- Before your final full suite: `git merge pietro-1` (it moves), conflicts as unions.

## Quality bar
Steam-quality, readable telegraphs (>= 0.6 s), beatable by a human, no horde, no softlocks, no placeholders. Keep "Stan prac / co dalej" in your plan doc current (it's the hand-off if you are stopped).

## Report
Short: status (DONE / DONE_WITH_CONCERNS / BLOCKED / NEEDS_CONTEXT), branch + last commit, full-suite counts, what's left, "Do sprawdzenia w oknie", concerns.
