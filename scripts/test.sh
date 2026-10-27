#!/usr/bin/env bash
# Run Dart tests in every workspace package, and Android unit tests for the app.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_FVM="${ROOT}/scripts/run_fvm.sh"

is_flutter_package() {
  grep -q '^[[:space:]]*sdk: flutter$' "$1/pubspec.yaml"
}

# flutter test does not run Gradle unit tests.
run_android_unit_tests() {
  local pkg="$1"
  if [[ ! -f "${pkg}/android/gradlew" ]]; then
    return 0
  fi
  # pre-commit exports GIT_DIR. Flutter and Gradle then inspect the wrong repository.
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
    GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR || true
  "${ROOT}/scripts/ensure_android_ndk.sh"
  (cd "${pkg}" && "${RUN_FVM}" flutter build apk --config-only)
  (cd "${pkg}/android" && ./gradlew :app:testDebugUnitTest --console=plain)
}

for pkg in "${ROOT}"/packages/*/; do
  if is_flutter_package "${pkg}"; then
    (cd "${pkg}" && "${RUN_FVM}" flutter test)
    run_android_unit_tests "${pkg}"
  else
    (cd "${pkg}" && "${RUN_FVM}" dart test)
  fi
done
