---
name: git-management
description: Use during agent development in Git repositories, including implementation, debugging, refactoring, test-driven edits, automatic checkpoint commits, isolated worktree harnesses, experimental and verified branches, safe promotion of validated changes, status and diff review, committing, pushing, and protecting user-owned dirty worktrees.
---

# Git Management

Use this skill as a Git harness for agent-driven development. The harness separates the user's checkout from the agent's workspace, commits exploratory work automatically, and promotes only validated changes to a clean branch.

For small, low-risk tasks in a clean checkout, direct edits may be faster. Use the harness when the task is exploratory, risky, validation-heavy, likely to touch several files, or when the user checkout is dirty and must be protected.

When the user asks to place a branch or repository under git-management, start a harness and record the resulting management setup in project-level memory. If the user explicitly asks to create a new user branch as the managed baseline, create that user-owned branch first and start the harness from it. Otherwise, use the current branch and current `HEAD` as the managed baseline; do not create a new user branch implicitly.

## Ownership model

- User checkout: the original working tree where the user invoked the task. Pre-existing dirty changes are user-owned. Do not modify, stage, commit, stash, reset, or clean them unless the user explicitly requests it.
- Experimental worktree: `codex/exp/<task-id>` checked out under `$HOME/.git-worktrees/<repo-hash>/<task-id>` by default. All changes in this worktree are agent-owned and may be checkpointed automatically.
- Verified worktree: `codex/verified/<task-id>` checked out under `$HOME/.git-worktrees/<repo-hash>/<task-id>-verified` by default. It contains only validated final changes promoted from the experimental branch.

Prefer this ownership boundary over guessing whether individual files were created by the user or a prior agent.

## Branch and worktree model

- Experimental branch: `codex/exp/<task-id>`.
- Verified branch: `codex/verified/<task-id>`.
- Base branch: the current user checkout branch at harness start, unless the user explicitly requested creating a new user-owned baseline branch.
- Base commit: the user checkout `HEAD` at harness start.
- Default worktree root: `$HOME/.git-worktrees/<repo-hash>/`. Override with `CODEX_GIT_WORKTREE_ROOT` when needed, but keep it under `$HOME/.git-worktrees/`.
- Metadata file: `.codex/git-harness.json` inside the experimental worktree.

Start from the current branch and `HEAD` by default. Only create a new user-owned baseline branch when the user explicitly requests a new branch or gives a new baseline branch name. If the user checkout has dirty changes, report that they are excluded from the harness unless the user explicitly asks to include them.

## User baseline branch policy

- Default: use the current branch as the user-owned baseline branch for the harness.
- Explicit new baseline: if the user asks to create a new user branch for management, create it from the current `HEAD`, switch to it if needed, and then start the harness from that branch.
- Do not create baseline branches speculatively based on task type alone.
- Keep user-owned baseline branches free of agent-owned exploratory edits unless the user explicitly asks to edit or commit there.
- Record the baseline branch name, base commit, experimental branch, verified branch, worktree path, validation state, and resume commands after every successful harness setup or adoption.

## Project memory record

Every time a repository, branch, or newly created user baseline branch is explicitly placed under git-management, write or refresh a local project-level memory record so future conversations in the same checkout can resume correctly. This record is part of the management setup, not an optional extra prompt.

Preferred record locations inside the user checkout:

- `AGENTS.md`: concise project-level instructions that future agents are likely to read first.
- `.codex/git-management.md`: detailed local git-management index for all currently managed branches, including branch names, base commit, worktree paths, checkpoint commit, validation status, and resume commands.

If `research-record` is available and the setup affects research direction, reproducibility, or handoff state, also add a concise handoff or change record under `docs/logs/` and refresh `docs/logs/START_HERE.md` according to that skill.

Memory record rules:

- Create missing `AGENTS.md` or `.codex/git-management.md` when starting or adopting a git-management harness. Do not create them for routine Git operations that do not place a branch or repository under git-management.
- If these files already exist, update only the git-management section; preserve unrelated project instructions.
- `.codex/git-management.md` must list all current git-management harnesses known for this repository, not only the most recent harness. When adding or adopting a harness, update the matching entry if the task id, experimental branch, or worktree path already exists; otherwise append a new managed-branch entry.
- Each managed-branch entry should include task id, user baseline branch, base commit, experimental branch, experimental worktree, verified branch target, verified worktree target, latest checkpoint when known, validation status, last updated time when known, and resume commands.
- `AGENTS.md` should stay concise: include the active/default management entry, point to `.codex/git-management.md`, and avoid duplicating the full managed-branch index.
- Treat project-level memory files as local by default. Ensure `AGENTS.md` and `.codex/` are ignored by `.gitignore` before reporting setup complete unless the user explicitly asks to version these memory files.
- Do not put secrets, tokens, transient process IDs, or full command logs in memory files.
- Do not commit memory files unless the user explicitly asks. If the user wants the memory to travel with the branch, remove or override the ignore rule intentionally and then commit.

## Standard harness workflow

1. Preflight in the user checkout.
   - Identify repo root, active branch, upstream state, `HEAD`, and dirty status.
   - Do not change the user checkout while doing preflight.
   - Decide the baseline branch using the user baseline branch policy: current branch by default, new user branch only on explicit request.
   - Use `scripts/start_harness.sh <task-id>` from this skill when creating the harness.

2. Develop only in the experimental worktree.
   - Move into the `worktree_path` printed by `scripts/start_harness.sh` before editing files.
   - Treat all changes there as agent-owned.
   - Make automatic checkpoint commits after meaningful milestones, before risky refactors, after generated changes, after validation attempts, and at final experimental state.
   - Use `scripts/checkpoint.sh "<message>"` from inside the experimental worktree when possible.

3. Validate before promotion.
   - Run the relevant repository checks or tests when available.
   - Prefer `scripts/validate.sh "<command>"`; it runs the command, records the exit code, timestamp, and validated commit, and checkpoints the validation metadata.
   - Use `scripts/mark_validation.sh <passed|failed|skipped> "<command>"` only for manual overrides when the command was already run outside the harness script.
   - If validation fails, checkpoint the failure state in the experimental branch and report the failing command and summary. Do not promote.
   - If validation is intentionally skipped, report that explicitly. Skipped validation is never eligible for verified promotion.

4. Promote validated work.
   - Use `scripts/promote_verified.sh` from inside the experimental worktree only when validation passed.
   - Promotion creates or reuses `codex/verified/<task-id>` from the original base commit.
   - Promotion applies the final experimental diff as one clean verified commit by default.
   - Do not promote `.codex/git-harness.json` unless the user explicitly wants harness metadata in the deliverable.

5. Report state.
   - Use `scripts/status_harness.sh` for a compact state snapshot instead of running several separate Git and metadata commands.
   - Write or refresh the project memory record for newly managed branches or repositories before the final report.
   - Include base commit, experimental branch, verified branch when created, latest checkpoint commit, validation command and result, and any dirty user checkout changes excluded from the harness.
   - Do not push unless the user explicitly asks.

## Auto-commit policy

- Auto-commit is allowed in `codex/exp/*` branches.
- Auto-commit in `codex/verified/*` is limited to the final promoted commit.
- Auto-commit is not allowed in the user's original checkout unless the user explicitly requests committing that checkout.
- Checkpoint commits stage all changes in the harness worktree after blocking common secret, credential, virtualenv, cache, build, and coverage paths, while excluding local project memory files such as `AGENTS.md` and `.codex/git-management.md`. Harness metadata `.codex/git-harness.json` remains tracked. If the guard blocks an intentional file, add an explicit ignore/rename decision before retrying.
- Checkpoint commit message format: `agent checkpoint: <short milestone>`.
- Verified commit message format: `agent verified: <short task summary>`.

## Safety rules

- Never run destructive Git commands unless the user explicitly requested that exact operation. This includes `git reset --hard`, `git clean`, forced checkout or restore, branch deletion, and force-push.
- Do not use stash as a shortcut in the user checkout. If user dirty changes block the task, ask how to proceed.
- Prefer non-interactive Git commands.
- If a harness branch or worktree already exists, reuse it only when `.codex/git-harness.json` matches the same task id, base commit, expected branch, and expected worktree path.
- Keep harness worktrees under `$HOME/.git-worktrees/`. `CODEX_GIT_WORKTREE_ROOT` overrides outside that root are rejected by the bundled scripts.
- If promotion conflicts, stop and report the conflict files. Do not hard reset, clean, or discard conflict state without explicit user direction.

## Script usage

Bundled scripts live next to this skill:

```text
scripts/start_harness.sh <task-id>
scripts/checkpoint.sh "<message>"
scripts/validate.sh "<command>"
scripts/mark_validation.sh <passed|failed|skipped> "<command>"
scripts/promote_verified.sh [commit-message]
scripts/status_harness.sh
```

Use scripts by absolute path when the skill directory is known. If scripts are unavailable, follow the same behavior manually and keep the same safety rules.
