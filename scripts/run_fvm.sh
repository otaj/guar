#!/usr/bin/env bash
# Run fvm with a clean git environment; fall back to PATH in CI.
#
# pre-commit (especially in git worktrees) exports GIT_DIR / GIT_INDEX_FILE /
# GIT_WORK_TREE. FVM and Flutter run `git` inside the shared SDK clone; with
# those vars set they read *this* repo instead, report guar's HEAD as the
# Flutter framework revision, and FVM "auto-repairs" by deleting
# ~/fvm/versions/ — corrupting the cache for every worktree.
set -euo pipefail

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
  GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR || true

if command -v fvm >/dev/null 2>&1; then
  exec fvm "$@"
fi

# CI (flutter-action) has dart/flutter on PATH, not fvm.
exec "$@"
