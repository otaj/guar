#!/usr/bin/env bash
# Run dart test in every workspace package.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_FVM="${ROOT}/scripts/run_fvm.sh"

for pkg in "${ROOT}"/packages/*/; do
  (cd "${pkg}" && "${RUN_FVM}" dart test)
done
