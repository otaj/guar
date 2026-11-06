#!/usr/bin/env bash
# Run Dart, Flutter, and Android unit tests for workspace packages.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_FVM="${ROOT}/scripts/run_fvm.sh"
CI_WORKFLOW="${ROOT}/.github/workflows/ci.yml"

is_flutter_package() {
  grep -q '^[[:space:]]*sdk: flutter$' "$1/pubspec.yaml"
}

run_dart_tests() {
  local pkg="$1"
  (cd "${pkg}" && "${RUN_FVM}" dart test)
}

run_flutter_tests() {
  local pkg="$1"
  (cd "${pkg}" && "${RUN_FVM}" flutter test)
}

# pre-commit exports GIT_DIR. Flutter and Gradle then inspect the wrong repository.
unset_git_env() {
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
    GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR || true
}

run_android_unit_tests() {
  local pkg="$1"
  local required="${2:-}"
  if [[ ! -f "${pkg}/android/gradlew" ]]; then
    if [[ -n "${required}" ]]; then
      echo "No Gradle project under ${pkg}/android" >&2
      exit 1
    fi
    return 0
  fi
  unset_git_env
  "${ROOT}/scripts/ensure_android_ndk.sh"
  (cd "${pkg}" && "${RUN_FVM}" flutter build apk --config-only)
  (cd "${pkg}/android" && ./gradlew :app:testDebugUnitTest --console=plain)
}

run_package() {
  local pkg="$1"
  local kind="${2:-}"
  if [[ ! -f "${pkg}/pubspec.yaml" ]]; then
    echo "No package at ${pkg}" >&2
    exit 1
  fi
  if [[ -z "${kind}" ]]; then
    if is_flutter_package "${pkg}"; then
      run_flutter_tests "${pkg}"
      run_android_unit_tests "${pkg}"
    else
      run_dart_tests "${pkg}"
    fi
    return 0
  fi
  case "${kind}" in
    dart) run_dart_tests "${pkg}" ;;
    flutter) run_flutter_tests "${pkg}" ;;
    android) run_android_unit_tests "${pkg}" required ;;
    *)
      echo "Unknown test kind: ${kind} (expected dart, flutter, or android)" >&2
      exit 2
      ;;
  esac
}

# Kinds are paired inside one `- name:` block. mawk has no user functions.
check_ci_matrix() {
  local pkg name kind
  local -a expected
  for pkg in "${ROOT}"/packages/*/; do
    name="$(basename "${pkg}")"
    if is_flutter_package "${pkg}"; then
      expected=(flutter)
      if [[ -f "${pkg}/android/gradlew" ]]; then
        expected+=(android)
      fi
    else
      expected=(dart)
    fi
    for kind in "${expected[@]}"; do
      if ! awk -v pkg="${name}" -v kind="${kind}" '
        $1 == "-" && $2 == "name:" {
          if (has_pkg && has_kind) found = 1
          has_pkg = 0
          has_kind = 0
        }
        $1 == "package:" && $2 == pkg { has_pkg = 1 }
        $1 == "kind:" && $2 == kind { has_kind = 1 }
        END {
          if (has_pkg && has_kind) found = 1
          exit !found
        }
      ' "${CI_WORKFLOW}"; then
        echo "CI test matrix is missing package ${name} kind ${kind}" >&2
        exit 1
      fi
    done
  done
}

if [[ "${1:-}" == "--check-matrix" ]]; then
  if [[ $# -ne 1 ]]; then
    echo "Usage: $0 --check-matrix" >&2
    exit 2
  fi
  check_ci_matrix
  exit 0
fi

if [[ $# -eq 0 ]]; then
  for pkg in "${ROOT}"/packages/*/; do
    run_package "${pkg}"
  done
elif [[ $# -eq 1 || $# -eq 2 ]]; then
  if [[ "$1" == *[!A-Za-z0-9_]* ]]; then
    echo "Unknown package: $1" >&2
    exit 2
  fi
  run_package "${ROOT}/packages/$1" "${2:-}"
else
  echo "Usage: $0 [package [dart|flutter|android]]" >&2
  exit 2
fi
