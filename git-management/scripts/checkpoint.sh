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

check_blocked_paths() {
  status_file="$1"
  blocked="$(sed -n 's/^...//p' "$status_file" | grep -E '(^|/)(\.env($|\.)|.*\.pem$|.*\.key$|.*_rsa$|.*_dsa$|.*_ecdsa$|.*_ed25519$|id_rsa$|id_dsa$|id_ecdsa$|id_ed25519$|.*token.*|.*secret.*|.*credential.*|.*credentials.*|.*passwd.*|.*password.*)|(^|/)(node_modules|\.venv|venv|__pycache__|\.pytest_cache|\.mypy_cache|\.ruff_cache|\.tox|dist|build|coverage|\.coverage)(/|$)' || true)"
  if [ -n "$blocked" ]; then
    printf 'error: checkpoint blocked because sensitive/generated paths are present:\n' >&2
    printf '%s\n' "$blocked" >&2
    printf 'Add intentional files explicitly, ignore generated files, or move secrets out of the harness worktree.\n' >&2
    exit 1
  fi
}

message="${1:-}"
[ -n "$message" ] || die "usage: checkpoint.sh <message>"

require_command git
require_command python3
require_command sed
require_command grep

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a Git repository"
cd "$repo_root"

[ -f .codex/git-harness.json ] || die "not inside a git-management harness worktree"
branch="$(git branch --show-current)"
expected_branch="$(metadata_value experimental_branch)"
[ -n "$expected_branch" ] || die "missing experimental_branch in harness metadata"
[ "$branch" = "$expected_branch" ] || die "checkpoint branch mismatch: $branch, expected $expected_branch"

status_file="$(mktemp)"
trap 'rm -f "$status_file"' EXIT
git status --short > "$status_file"
check_blocked_paths "$status_file"

git ls-files -z --cached --modified --deleted --others --exclude-standard \
  ':(exclude)AGENTS.md' \
  ':(exclude).codex' \
  ':(exclude).codex/**' \
  | xargs -0 -r git add -A --
git add -f .codex/git-harness.json
if git diff --cached --quiet; then
  printf 'checkpoint=no-op\n'
  printf 'branch=%s\n' "$branch"
  exit 0
fi

git commit -m "agent checkpoint: $message"
commit="$(git rev-parse --short HEAD)"
printf 'checkpoint=created\n'
printf 'branch=%s\n' "$branch"
printf 'commit=%s\n' "$commit"
