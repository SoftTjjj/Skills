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

status="${1:-}"
command_text="${2:-}"
case "$status" in
  passed|failed|skipped) ;;
  *) die "usage: mark_validation.sh <passed|failed|skipped> [command]" ;;
esac

require_command git
require_command python3

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a Git repository"
cd "$repo_root"

[ -f .codex/git-harness.json ] || die "not inside a git-management harness worktree"
branch="$(git branch --show-current)"
expected_branch="$(metadata_value experimental_branch)"
[ -n "$expected_branch" ] || die "missing experimental_branch in harness metadata"
[ "$branch" = "$expected_branch" ] || die "validation branch mismatch: $branch, expected $expected_branch"
validation_commit="$(git rev-parse HEAD)"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
python3 -c '
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
status = sys.argv[2]
command = sys.argv[3]
data = json.loads(path.read_text())
data["validation_status"] = status
data["validation_command"] = command
data["validation_commit"] = sys.argv[4]
data["validation_manual"] = "true"
Path(sys.argv[5]).write_text(json.dumps(data, indent=2, sort_keys=False) + "\n")
' .codex/git-harness.json "$status" "$command_text" "$validation_commit" "$tmp"
mv "$tmp" .codex/git-harness.json

git add -f .codex/git-harness.json
if ! git diff --cached --quiet; then
  git commit -m "agent checkpoint: validation $status"
fi

printf 'validation_status=%s\n' "$status"
printf 'validation_command=%s\n' "$command_text"
printf 'validation_commit=%s\n' "$validation_commit"
