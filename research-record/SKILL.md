---
name: research-record
description: Use when recording research work in a repository, including experiment logs, change logs, plans, decisions, observations, and handoff notes. Also use proactively after key experiment, evaluation, analysis, or validation loops complete and change verified state or next actions; for implementation-only work, use proactively only after validation or when it affects research direction, reproducibility, or handoff state. Writes concise timestamped Markdown records under the current repo's docs/logs directory and maintains startup context for future conversations.
---

# Research Record

Use this skill when the user asks to record research progress, experiments, changes, plans, decisions, observations, or handoff context for future conversations.

Also use this skill proactively when a key experiment loop completes, such as after finishing a run, evaluation, analysis pass, or implementation-and-validation cycle that changes the project's verified state or next action. Do not record every routine command; record only moments that would help a future agent resume correctly.

For implementation-only work, record proactively only after validation or when the change affects research direction, reproducibility, or handoff state.

Record when any of these changed: verified result, chosen route, next action, blocker, reproducibility state, or important artifact path. A failed run is record-worthy when it identifies a blocker, invalidates an approach, changes configuration, or determines the next action.

## Default location

Write records to the current repository:

```text
docs/logs/
├── START_HERE.md
├── INDEX.md
├── experiments/
├── changes/
├── plans/
├── decisions/
├── observations/
└── handoffs/
```

Do not write routine research logs outside `docs/logs/` unless the user explicitly requests another location.

Use repo-relative paths for files inside the repository. Use absolute paths only for external datasets, shared storage, system locations, or paths outside the repository.

When locating the repository root:

- Prefer `git rev-parse --show-toplevel` when the current directory is inside a git repository.
- If the directory is not a git repository, use the current working directory and note `Repo: Not a git repository` in the record when relevant.
- In a monorepo, use the user-specified project path when provided; otherwise use the current git root and record paths relative to that root.

## Log file naming

When available, use `scripts/log_meta.py` from this skill directory to get the CST timestamp and ISO weekly filename metadata. If the script is unavailable or fails, compute them manually from CST local time.

```bash
python3 scripts/log_meta.py
```

When writing a record, use the weekly file for that record's type directory:

```text
YYYY-WW-MMDD-MMDD.md
```

Rules:

- Use ISO week-year and ISO week number, for example `2026-W22`.
- Use ISO week-year, not calendar year, for the `YYYY` part.
- The first `MMDD` is the Monday of that ISO week.
- The second `MMDD` is the Sunday of that ISO week.
- Example: `docs/logs/experiments/2026-W22-0525-0531.md`.
- Create a weekly file only for the type being recorded. Do not precreate empty weekly files for unrelated types.

Every record inside a file must also have a timestamp precise to seconds:

```markdown
## 2026-05-26 15:42:08 CST - Record title
```

## Record types

- `experiments/`: experiment setup, runs, results, conclusions, reproducibility hints.
- `changes/`: code, config, data, script, document, or workflow changes.
- `plans/`: research plans, task breakdowns, priorities, acceptance criteria.
- `decisions/`: technical or research-route decisions and tradeoffs.
- `observations/`: data observations, anomalies, reading notes, interim analysis.
- `handoffs/`: compact context for a new conversation or another researcher.

If one note fits multiple types, choose the primary type and mention related types in the body. Do not duplicate the same full note across directories.

Use these precedence rules for ambiguous notes:

- If the note includes an experiment run, evaluation result, metric, model output, or reproducibility setup, choose `experiments/`.
- If the main subject is a code, config, script, data-processing, document, or workflow edit, choose `changes/`.
- If the main subject is future work, task breakdown, priorities, acceptance criteria, or a route to execute, choose `plans/`.
- If the main subject is a technical or research-route choice, rejected alternative, tradeoff, or rationale, choose `decisions/`.
- If the main subject is an observed phenomenon, anomaly, interim analysis, reading note, or data/model behavior without a completed experiment record, choose `observations/`.
- If the purpose is to resume work in a future conversation or transfer context to another person, choose `handoffs/`.
- If classification remains ambiguous after one pass, choose the type that best supports future continuation and proceed.

Every useful record should include the trigger or goal, key paths or commands when applicable, current result or state, and a concrete next action. Mark unknown fields as `Not recorded` instead of guessing.

For verified claims, include the evidence path, command output summary, metric file, commit, job id, or artifact path. Prefer stable artifact paths and concise conclusions over copied content; if an artifact path is temporary or may be deleted, say so.

When code state matters, record the current branch and whether the worktree was dirty, but do not paste full diffs.

Mark volatile state explicitly, for example `Volatile: running job/process; verify before relying on it`.

Use a short record instead of a full template for small updates, quick observations, simple status changes, or lightweight checks that do not need experiment/change/handoff detail.

Do not record:

- Routine command failures unless they reveal an environment, data, config, method, or reproducibility issue.
- Repeated checks that do not change the conclusion, current state, or next action.
- Details that are already recoverable from git history, test output files, or artifacts; record the path and conclusion instead.
- Secrets, tokens, private credentials, or full sensitive environment variables.

## Workflow

Fast path for a normal record:

1. Decide the record type.
2. Compute timestamp and weekly file, preferably with `scripts/log_meta.py`.
3. Skim existing `START_HERE.md` and target weekly file when present.
4. Append one concise record after a quick duplicate check.
5. Refresh only the affected fields in `START_HERE.md`.
6. Add the missing `INDEX.md` weekly link if needed.
7. Report timestamp, record type, title, and touched files.

Use the full workflow below when the repo, record type, duplicate risk, or startup context is unclear.

1. Confirm the repo root and use `<repo>/docs/logs/`.
2. Get the CST timestamp and ISO weekly filename metadata, preferably with `scripts/log_meta.py`.
3. If the script is unavailable or fails, compute the current ISO week, Monday, and Sunday manually from CST local time; derive the weekly filename for the chosen record type.
4. Create missing `docs/logs/` directories, `START_HERE.md`, or `INDEX.md` from the templates when needed.
5. Read `docs/logs/START_HERE.md`, `docs/logs/INDEX.md`, and the target weekly file if they exist.
6. Check recent records in the target weekly file and `START_HERE.md` to avoid duplicating the same event.
7. Append one structured record to the correct type directory.
8. Update only the affected fields in `START_HERE.md`: `Last Updated`, current focus, state, evidence, key paths, up to 5 recent records, open issues, or next actions.
9. Update `INDEX.md` with a link to the weekly file under the relevant type, without copying record bodies.
10. Report the touched files, record type, title, and exact timestamp to the user.

When updating `INDEX.md`, add a weekly link only if it is missing. Do not add links to weekly files that were not created or do not exist.

Ask at most 1-3 concise questions only when missing information would make the record misleading. Otherwise, make a conservative record from available context and mark unknown fields as `Not recorded`.

If unsure which template to use, use the Short template. A valid short record only needs `Note`, `Status`, and `Next`.

For Short records, put evidence in `Status` when the status is verified.

Do not rewrite historical records to change their meaning unless the user explicitly asks. If a later finding corrects an earlier conclusion, append a new record that references the earlier title or timestamp.

When correcting a prior record, title the new entry `Correct <prior title>` or reference the prior timestamp in `Context`.

When recording failures, keep the entry compact: include the symptom, short error summary, affected scope, and next action. Do not paste full stderr or scheduler logs.

## File structure templates

Use this structure for `docs/logs/START_HERE.md`:

```markdown
# Start Here

Last Updated: YYYY-MM-DD HH:MM:SS CST

## Current Focus
Concise statement of the active research or engineering focus.

## Current State
Latest verified state, result, output, or blocker.

## Evidence
Latest verified metric, artifact, job id, commit, or output path.

## Key Paths
- Code:
- Data:
- Outputs:
- Logs:
- Config:

## Recent Records
- [type - YYYY-MM-DD HH:MM:SS - Title](relative/path/to/weekly-file.md)

## Open Issues
- Known uncertainty, blocker, or risk.

## Next Actions
1. Exact next command or action, target path, and expected success signal.
```

Use this structure for `docs/logs/INDEX.md`:

```markdown
# Research Log Index

## Experiments
- [2026-W22-0525-0531](experiments/2026-W22-0525-0531.md)

## Changes
- [2026-W22-0525-0531](changes/2026-W22-0525-0531.md)

## Plans
- [2026-W22-0525-0531](plans/2026-W22-0525-0531.md)

## Decisions
- [2026-W22-0525-0531](decisions/2026-W22-0525-0531.md)

## Observations
- [2026-W22-0525-0531](observations/2026-W22-0525-0531.md)

## Handoffs
- [2026-W22-0525-0531](handoffs/2026-W22-0525-0531.md)
```

Keep `INDEX.md` sorted by type and then by newest weekly file first within each type. Do not include per-record summaries in `INDEX.md`.

Keep all type sections in `INDEX.md` even when a section has no links.

Maintain `START_HERE.md` as a current-state summary, not a full history:

- Rewrite only summary fields affected by the new record, especially when active focus or state changes.
- Keep historical details in weekly logs, not in `START_HERE.md`.
- Keep at most 5 recent records; remove older entries from this section as new ones are added.
- Prefer recent records that affect current state, next actions, blockers, or important artifacts. Do not keep trivial records in `START_HERE.md` just because they are newer.
- Link recent records to the weekly file and include the timestamp in the link text. Do not require heading anchors.
- Use timestamps in `Recent Records` to locate matching headings in linked weekly files.
- Keep `Evidence` to the latest evidence needed to trust the current state; move older evidence to weekly logs.
- Keep `Last Updated` in sync whenever `START_HERE.md` changes.

## Templates

Use optional `Tags:` lines sparingly when they improve searchability, for example `Tags: qwen3-vl, longvideobench, eval`. Prefer stable project, dataset, model, benchmark, or subsystem names.

In conclusions, separate verified facts from assumptions. Do not phrase unverified hypotheses as facts.

### General

```markdown
## YYYY-MM-DD HH:MM:SS CST - Title

Tags: optional, comma-separated, stable identifiers

### Context
Background, goal, or trigger.

### Details
Concrete process, operation, analysis, or content.

### Result
Current result, output, metric, path, or status.

### Conclusion
- Verified:
- Assumed:
- Unknown:

### Next
Actionable next steps.
```

### Short

```markdown
## YYYY-MM-DD HH:MM:SS CST - Title

Tags: optional, comma-separated, stable identifiers

### Note
What happened, with key paths or commands if relevant.

### Status
Verified result, blocker, or unknown.

### Next
Nearest action.
```

### Experiment

```markdown
## YYYY-MM-DD HH:MM:SS CST - Experiment title

Tags: optional, comma-separated, stable identifiers

### Objective
Experiment purpose and hypothesis.

### Setup
- Code:
- Data:
- Model:
- Config:
- Checkpoint:
- Command / Slurm job:
- Environment:

### Metrics
Target metrics and evaluation protocol.

### Results
Key results, logs, metric summary, and output paths.

### Conclusion
- Verified:
- Assumed:
- Unknown:
- Relation to prior results:

### Issues
Failures, anomalies, bias, reproducibility gaps, or data risks.

### Next
Next experiment or fix.
```

### Change

```markdown
## YYYY-MM-DD HH:MM:SS CST - Change title

Tags: optional, comma-separated, stable identifiers

### Context
Why the change was needed.

### Changes
What code, data, config, script, docs, or workflow changed.

### Validation
How it was checked and the result.

### Impact
- Verified:
- Assumed:
- Compatibility / scope:

### Next
Follow-up actions.
```

### Plan

```markdown
## YYYY-MM-DD HH:MM:SS CST - Plan title

Tags: optional, comma-separated, stable identifiers

### Goal
Research or engineering goal.

### Steps
1. Concrete step.
2. Concrete step.

### Acceptance
Completion criteria.

### Risks
Risks, dependencies, or blockers.

### Next
The nearest next action.
```

### Handoff

```markdown
## YYYY-MM-DD HH:MM:SS CST - Handoff title

Tags: optional, comma-separated, stable identifiers

### Current Focus
What the next conversation or researcher should continue.

### Completed
What has already been done.

### Current State
Latest verified state, outputs, metrics, or blockers.

### Key Paths
- Code:
- Data:
- Outputs:
- Logs:
- Config:

### Commands
Commands that matter for continuation.

### Open Issues
Known failures, uncertainties, or risks.

### Next
Exact next actions in order.
```

## Size management

- Keep weekly logs concise: key parameters, evidence, conclusions, and paths only.
- Do not paste full training logs, long CSV/JSON files, large tables, or long stdout/stderr.
- Reference large artifacts in their existing locations, such as `outputs/`, `slurm/`, or `datasets/`.
- For long commands, record the script path, key parameters, output path, and result instead of the full invocation when that is enough to reproduce or understand the work.
- Record commands only when they are needed to reproduce, verify, resume, or debug the state.
- Never record credentials, access tokens, private keys, or sensitive environment variable values.
- Use clear titles in the form of action + object + outcome when possible, for example `Run smoke eval and hit CUDA OOM`.
- Keep `START_HERE.md` compact: last updated, focus, state, evidence, key paths, up to 5 recent records, open issues, and next actions.
- Keep `INDEX.md` as a link index only.
- If one record would exceed about 200 lines, write a short weekly-log summary and create/link a separate topic document only when necessary.
- For a type that receives records during a week, prefer one weekly file; avoid creating a separate file for every small update.
- Avoid repeating the same event across multiple records. If a related update is needed, reference the earlier timestamp or title and record only the new information.

## New conversation startup

When asked to continue research work in a new conversation, read in this order:

1. `docs/logs/START_HERE.md`
2. `docs/logs/INDEX.md`
3. The 3-5 recent records linked from `START_HERE.md`
4. The current weekly file for the task's relevant type, only when not already covered by `START_HERE.md` recent records

Use `INDEX.md` only to locate relevant weekly files; do not treat it as source context.

Do not read older or unrelated weekly logs unless the user request or recent records points to them.

Then summarize using this startup summary format before making changes: `Focus`, `State`, `Evidence`, `Open Issues`, `Next`.

When recent records conflict with `START_HERE.md`, prefer the newest verified record with evidence.

Before acting on stale or high-impact state, cheaply verify referenced paths, git status, running jobs, or output files when relevant.

## Slurm projects

For repositories using Slurm, distinguish scheduler logs from program outputs:

- Scheduler logs usually live under `slurm/`.
- Model artifacts, metrics, and reports usually live under `outputs/` or another configured output directory.

Record both when relevant, but do not conflate them.
