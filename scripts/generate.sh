#!/usr/bin/env bash
# Run build_runner in packages that generate Freezed code.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_FVM="${ROOT}/scripts/run_fvm.sh"

for pkg in guar_parser guar_domain guar_query; do
  (cd "${ROOT}/packages/${pkg}" && "${RUN_FVM}" dart run build_runner build --delete-conflicting-outputs)
done
