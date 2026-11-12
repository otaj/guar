#!/usr/bin/env bash
# Run code generation: Freezed in the workspace packages, l10n in the app.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_FVM="${ROOT}/scripts/run_fvm.sh"

for pkg in guar_parser guar_domain guar_query; do
  (cd "${ROOT}/packages/${pkg}" && "${RUN_FVM}" dart run build_runner build --delete-conflicting-outputs)
done

(cd "${ROOT}/packages/guar" && "${RUN_FVM}" flutter gen-l10n)
