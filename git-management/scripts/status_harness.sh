#!/usr/bin/env bash
set -euo pipefail

die() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

metadata_json() {
  python3 -c '
import json
import sys
from pathlib import Path

path = Path(".codex/git-harness.json")
data = json.loads(path.read_text())
for key in sys.argv[1:]:
    print(f"{key}={data.get(key, '')}")
' "$@"
}

require_command git
require_command python3

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a Git repository"
cd "$repo_root"

[ -f .codex/git-harness.json ] || die "not inside a git-management harness worktree"
branch="$(git branch --show-current)"
head="$(git rev-parse HEAD)"
short_head="$(git rev-parse --short HEAD)"
dirty="$([ -n "$(git status --short)" ] && printf yes || printf no)"
latest_checkpoint="$(git log -1 --format=%h 2>/dev/null || true)"

printf 'repo_root=%s\n' "$repo_root"
printf 'branch=%s\n' "$branch"
printf 'head=%s\n' "$head"
printf 'short_head=%s\n' "$short_head"
printf 'dirty=%s\n' "$dirty"
printf 'latest_checkpoint=%s\n' "$latest_checkpoint"
metadata_json \
  task_id \
  base_commit \
  experimental_branch \
  verified_branch \
  worktree_path \
  verified_worktree_path \
  validation_status \
  validation_command \
  validation_commit \
  validation_exit_code \
  validation_started_at \
  validation_finished_at
