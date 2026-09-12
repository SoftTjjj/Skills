#!/usr/bin/env bash
set -euo pipefail

die() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

canonical_dir() {
  path="$1"
  mkdir -p "$path"
  cd "$path"
  pwd -P
}

metadata_value() {
  file="$1"
  key="$2"
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get(sys.argv[2], ""))' "$file" "$key"
}

repo_key() {
  printf '%s' "$1" | git hash-object --stdin | cut -c1-16
}

write_metadata() {
  file="$1"
  validation_status="$2"
  validation_command="$3"
  created_at="$4"
  mkdir -p "$(dirname "$file")"
  python3 -c '
import json
import sys

keys = [
    "task_id",
    "base_commit",
    "user_branch",
    "user_checkout_path",
    "experimental_branch",
    "verified_branch",
    "worktree_path",
    "verified_worktree_path",
    "validation_status",
    "validation_command",
    "created_at",
]
data = dict(zip(keys, sys.argv[2:]))
with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
' "$file" \
    "$task_id" \
    "$base_commit" \
    "$user_branch" \
    "$repo_root" \
    "$exp_branch" \
    "$verified_branch" \
    "$worktree_path" \
    "$verified_path" \
    "$validation_status" \
    "$validation_command" \
    "$created_at"
}

assert_harness_worktree() {
  path="$1"
  expected_branch="$2"
  expected_path="$3"
  actual_root="$(git -C "$path" rev-parse --show-toplevel 2>/dev/null)" || die "worktree path is not a Git worktree: $path"
  actual_branch="$(git -C "$path" branch --show-current 2>/dev/null || true)"
  [ "$actual_root" = "$expected_path" ] || die "worktree root mismatch: $actual_root, expected $expected_path"
  [ "$actual_branch" = "$expected_branch" ] || die "worktree branch mismatch: $actual_branch, expected $expected_branch"
}

task_id="${1:-}"
[ -n "$task_id" ] || die "usage: start_harness.sh <task-id>"
printf '%s' "$task_id" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]{0,80}$' || die "unsafe task id: $task_id"

require_command git
require_command python3
require_command cut

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a Git repository"
cd "$repo_root"

base_commit="$(git rev-parse HEAD)"
user_branch="$(git branch --show-current 2>/dev/null || true)"
user_status="$(git status --short)"
exp_branch="codex/exp/$task_id"
verified_branch="codex/verified/$task_id"
git check-ref-format --branch "$exp_branch" >/dev/null 2>&1 || die "unsafe experimental branch name: $exp_branch"
git check-ref-format --branch "$verified_branch" >/dev/null 2>&1 || die "unsafe verified branch name: $verified_branch"
default_worktree_root="$HOME/.git-worktrees/$(repo_key "$repo_root")"
worktree_root="${CODEX_GIT_WORKTREE_ROOT:-$default_worktree_root}"
home_worktree_root="$(canonical_dir "$HOME/.git-worktrees")"
worktree_root="$(canonical_dir "$worktree_root")"
case "$worktree_root" in
  "$home_worktree_root"|"$home_worktree_root"/*) ;;
  *) die "CODEX_GIT_WORKTREE_ROOT must be under $home_worktree_root: $worktree_root" ;;
esac
worktree_path="$worktree_root/$task_id"
verified_path="$worktree_root/$task_id-verified"
metadata_path="$worktree_path/.codex/git-harness.json"

if [ -e "$worktree_path" ]; then
  [ -f "$metadata_path" ] || die "worktree path exists without harness metadata: $worktree_path"
  existing_task="$(metadata_value "$metadata_path" task_id)"
  existing_base="$(metadata_value "$metadata_path" base_commit)"
  [ "$existing_task" = "$task_id" ] || die "existing worktree metadata task id mismatch"
  [ "$existing_base" = "$base_commit" ] || die "existing worktree base commit differs from current HEAD"
  existing_branch="$(metadata_value "$metadata_path" experimental_branch)"
  existing_path="$(metadata_value "$metadata_path" worktree_path)"
  [ "$existing_branch" = "$exp_branch" ] || die "existing worktree experimental branch mismatch"
  [ "$existing_path" = "$worktree_path" ] || die "existing worktree path mismatch in metadata"
  assert_harness_worktree "$worktree_path" "$exp_branch" "$worktree_path"
  created_at="$(metadata_value "$metadata_path" created_at)"
else
  mkdir -p "$worktree_root"
  if git show-ref --verify --quiet "refs/heads/$exp_branch"; then
    branch_metadata="$(git show "$exp_branch:.codex/git-harness.json" 2>/dev/null || true)"
    [ -n "$branch_metadata" ] || die "experimental branch exists without harness metadata: $exp_branch"
    tmp_meta="$(mktemp)"
    trap 'rm -f "$tmp_meta"' EXIT
    printf '%s\n' "$branch_metadata" > "$tmp_meta"
    existing_task="$(metadata_value "$tmp_meta" task_id)"
    existing_base="$(metadata_value "$tmp_meta" base_commit)"
    [ "$existing_task" = "$task_id" ] || die "existing branch metadata task id mismatch"
    [ "$existing_base" = "$base_commit" ] || die "existing branch base commit differs from current HEAD"
    existing_branch="$(metadata_value "$tmp_meta" experimental_branch)"
    existing_verified_branch="$(metadata_value "$tmp_meta" verified_branch)"
    existing_path="$(metadata_value "$tmp_meta" worktree_path)"
    existing_verified_path="$(metadata_value "$tmp_meta" verified_worktree_path)"
    [ "$existing_branch" = "$exp_branch" ] || die "existing branch experimental branch mismatch"
    [ "$existing_verified_branch" = "$verified_branch" ] || die "existing branch verified branch mismatch"
    [ "$existing_path" = "$worktree_path" ] || die "existing branch worktree path mismatch in metadata"
    [ "$existing_verified_path" = "$verified_path" ] || die "existing branch verified worktree path mismatch in metadata"
    git worktree add "$worktree_path" "$exp_branch"
    assert_harness_worktree "$worktree_path" "$exp_branch" "$worktree_path"
    created_at="$(metadata_value "$metadata_path" created_at)"
  else
    git worktree add -b "$exp_branch" "$worktree_path" "$base_commit"
    created_at="$(date -Iseconds)"
    write_metadata "$metadata_path" "not_run" "" "$created_at"
    cd "$worktree_path"
    git add -f .codex/git-harness.json
    git commit -m "agent checkpoint: initialize harness"
    cd "$repo_root"
  fi
fi

printf 'repo_root=%s\n' "$repo_root"
printf 'base_commit=%s\n' "$base_commit"
printf 'user_branch=%s\n' "$user_branch"
printf 'user_dirty=%s\n' "$([ -n "$user_status" ] && printf yes || printf no)"
printf 'experimental_branch=%s\n' "$exp_branch"
printf 'verified_branch=%s\n' "$verified_branch"
printf 'worktree_path=%s\n' "$worktree_path"
printf 'verified_worktree_path=%s\n' "$verified_path"
printf 'metadata_path=%s\n' "$metadata_path"
printf 'created_at=%s\n' "$created_at"
