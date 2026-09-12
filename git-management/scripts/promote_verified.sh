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

commit_message="${1:-}"
require_command git
require_command python3

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a Git repository"
cd "$repo_root"

[ -f .codex/git-harness.json ] || die "not inside a git-management harness worktree"
exp_branch="$(git branch --show-current)"

base_commit="$(metadata_value base_commit)"
verified_branch="$(metadata_value verified_branch)"
expected_exp_branch="$(metadata_value experimental_branch)"
task_id="$(metadata_value task_id)"
validation_status="$(metadata_value validation_status)"
validation_commit="$(metadata_value validation_commit)"
validation_manual="$(metadata_value validation_manual)"
verified_path="$(metadata_value verified_worktree_path)"
[ -n "$base_commit" ] || die "missing base_commit in harness metadata"
[ -n "$verified_branch" ] || die "missing verified_branch in harness metadata"
[ -n "$expected_exp_branch" ] || die "missing experimental_branch in harness metadata"
[ -n "$task_id" ] || die "missing task_id in harness metadata"
[ -n "$verified_path" ] || die "missing verified_worktree_path in harness metadata"
[ "$exp_branch" = "$expected_exp_branch" ] || die "promotion branch mismatch: $exp_branch, expected $expected_exp_branch"
git cat-file -e "$base_commit^{commit}" 2>/dev/null || die "base commit does not exist: $base_commit"
case "$validation_status" in
  passed) ;;
  skipped) die "promotion requires passed validation; current status is skipped" ;;
  *) die "promotion requires validation_status passed in .codex/git-harness.json; current: ${validation_status:-missing}" ;;
esac
[ "$validation_manual" != "true" ] || die "promotion requires validation recorded by validate.sh; manual passed validation is not promotable"
[ -n "$validation_commit" ] || die "promotion requires validation_commit; run validate.sh instead of manual mark_validation.sh"
current_head="$(git rev-parse HEAD)"
git cat-file -e "$validation_commit^{commit}" 2>/dev/null || die "validation commit does not exist: $validation_commit"
if [ "$validation_commit" != "$current_head" ]; then
  if ! git merge-base --is-ancestor "$validation_commit" "$current_head"; then
    die "validation_commit is not an ancestor of HEAD; validation_commit=$validation_commit HEAD=$current_head"
  fi
  git diff --quiet "$validation_commit" "$current_head" -- . ':(exclude).codex/git-harness.json' || die "non-metadata changes exist after validation; rerun validate.sh"
fi

if [ -z "$commit_message" ]; then
  commit_message="agent verified: $task_id"
fi

if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
  die "experimental worktree has uncommitted or untracked changes; run checkpoint.sh first"
fi

tmp_patch="$(mktemp)"
trap 'rm -f "$tmp_patch"' EXIT
git diff --binary "$base_commit" HEAD -- . ':(exclude).codex/git-harness.json' > "$tmp_patch"

if [ -e "$verified_path" ]; then
  git -C "$verified_path" rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "verified path exists but is not a Git worktree: $verified_path"
else
  mkdir -p "$(dirname "$verified_path")"
  if git show-ref --verify --quiet "refs/heads/$verified_branch"; then
    branch_meta="$(git show "$verified_branch:.codex/git-harness.json" 2>/dev/null || true)"
    [ -z "$branch_meta" ] || die "verified branch contains harness metadata; refusing ambiguous reuse: $verified_branch"
    branch_base="$(git merge-base "$verified_branch" "$base_commit")"
    [ "$(git rev-parse "$verified_branch")" = "$base_commit" ] || [ "$branch_base" = "$base_commit" ] || die "verified branch does not derive from base commit: $verified_branch"
    git worktree add "$verified_path" "$verified_branch"
  else
    git worktree add -b "$verified_branch" "$verified_path" "$base_commit"
  fi
fi

cd "$verified_path"
current_branch="$(git branch --show-current)"
[ "$current_branch" = "$verified_branch" ] || die "verified worktree is on $current_branch, expected $verified_branch"
actual_verified_root="$(git rev-parse --show-toplevel)"
[ "$actual_verified_root" = "$verified_path" ] || die "verified worktree root mismatch: $actual_verified_root, expected $verified_path"

if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
  die "verified worktree has uncommitted or untracked changes: $verified_path"
fi

if [ ! -s "$tmp_patch" ]; then
  printf 'promotion=no-op\n'
  printf 'verified_branch=%s\n' "$verified_branch"
  printf 'verified_path=%s\n' "$verified_path"
  exit 0
fi

verified_head="$(git rev-parse HEAD)"
if [ "$verified_head" != "$base_commit" ]; then
  if git diff --quiet "$verified_head" "$exp_branch" -- . ':(exclude).codex/git-harness.json'; then
    printf 'promotion=already-current\n'
    printf 'verified_branch=%s\n' "$verified_branch"
    printf 'verified_path=%s\n' "$verified_path"
    printf 'commit=%s\n' "$(git rev-parse --short HEAD)"
    exit 0
  fi
  die "verified branch already has commits that differ from the experimental final diff; use a new task id or resolve manually"
fi

git apply --check "$tmp_patch" || die "experimental diff does not apply cleanly to verified branch: $verified_path"
git apply --index "$tmp_patch" || die "failed to apply experimental diff to verified branch after check: $verified_path"

if git diff --cached --quiet; then
  printf 'promotion=no-op\n'
  printf 'verified_branch=%s\n' "$verified_branch"
  printf 'verified_path=%s\n' "$verified_path"
  exit 0
fi

git commit -m "$commit_message"
commit="$(git rev-parse --short HEAD)"
printf 'promotion=created\n'
printf 'verified_branch=%s\n' "$verified_branch"
printf 'verified_path=%s\n' "$verified_path"
printf 'commit=%s\n' "$commit"
