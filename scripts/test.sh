#!/usr/bin/env bash
# Run dart test (or flutter test) in every workspace package.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_FVM="${ROOT}/scripts/run_fvm.sh"

is_flutter_package() {
  grep -q '^[[:space:]]*sdk: flutter$' "$1/pubspec.yaml"
}

for pkg in "${ROOT}"/packages/*/; do
  if is_flutter_package "${pkg}"; then
    (cd "${pkg}" && "${RUN_FVM}" flutter test)
  else
    (cd "${pkg}" && "${RUN_FVM}" dart test)
  fi
done
