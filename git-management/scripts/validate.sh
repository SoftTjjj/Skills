#!/usr/bin/env bash
set -euo pipefail

die() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

metadata_value() {
  key="$1"
  python3 -c 'import json,sys; print(json.load(open(".codex/git-harness.json")).get(sys.argv[1], ""))' "$key"
}

update_validation() {
  status="$1"
  command_text="$2"
  exit_code="$3"
  started_at="$4"
  finished_at="$5"
  commit="$6"
  tmp="$(mktemp)"
  python3 -c '
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text())
data["validation_status"] = sys.argv[2]
data["validation_command"] = sys.argv[3]
data["validation_exit_code"] = sys.argv[4]
data["validation_started_at"] = sys.argv[5]
data["validation_finished_at"] = sys.argv[6]
data["validation_commit"] = sys.argv[7]
data["validation_manual"] = "false"
Path(sys.argv[8]).write_text(json.dumps(data, indent=2, sort_keys=False) + "\n")
' .codex/git-harness.json "$status" "$command_text" "$exit_code" "$started_at" "$finished_at" "$commit" "$tmp"
  mv "$tmp" .codex/git-harness.json
}

command_text="${1:-}"
[ -n "$command_text" ] || die "usage: validate.sh <command>"

require_command git
require_command python3
require_command bash

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a Git repository"
cd "$repo_root"

[ -f .codex/git-harness.json ] || die "not inside a git-management harness worktree"
branch="$(git branch --show-current)"
expected_branch="$(metadata_value experimental_branch)"
[ -n "$expected_branch" ] || die "missing experimental_branch in harness metadata"
[ "$branch" = "$expected_branch" ] || die "validation branch mismatch: $branch, expected $expected_branch"

if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
  die "worktree has uncommitted or untracked changes; run checkpoint.sh before validation"
fi

commit="$(git rev-parse HEAD)"
started_at="$(date -Iseconds)"
set +e
bash -lc "$command_text"
exit_code="$?"
set -e
finished_at="$(date -Iseconds)"

if [ "$exit_code" -eq 0 ]; then
  status="passed"
else
  status="failed"
fi

update_validation "$status" "$command_text" "$exit_code" "$started_at" "$finished_at" "$commit"
git add -f .codex/git-harness.json
if ! git diff --cached --quiet; then
  git commit -m "agent checkpoint: validation $status"
fi

printf 'validation_status=%s\n' "$status"
printf 'validation_command=%s\n' "$command_text"
printf 'validation_exit_code=%s\n' "$exit_code"
printf 'validation_commit=%s\n' "$commit"
printf 'validation_started_at=%s\n' "$started_at"
printf 'validation_finished_at=%s\n' "$finished_at"

exit "$exit_code"
