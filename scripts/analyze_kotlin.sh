#!/usr/bin/env bash
# Kotlin analysis for the Android app: detekt, then the Kotlin compiler.
# Detekt does not resolve the Android or Flutter classpath, so an unresolved
# type such as MethodChannel.MethodCall is invisible to it. compileDebugKotlin
# is the analysis that reports those errors, without packaging an APK.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${ROOT}/packages/guar"
# Keep in sync with packages/guar/android/settings.gradle.kts (detekt plugin version).
DETEKT_VERSION="${DETEKT_VERSION:-1.23.8}"
CACHE_DIR="${DETEKT_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/guar/detekt/${DETEKT_VERSION}}"
CLI_JAR="${CACHE_DIR}/detekt-cli-${DETEKT_VERSION}-all.jar"
FORMATTING_JAR="${CACHE_DIR}/detekt-formatting-${DETEKT_VERSION}.jar"
CONFIG="${APP_DIR}/android/config/detekt/detekt.yml"
INPUT_DIRS=(
  "${APP_DIR}/android/app/src/main/kotlin"
  "${APP_DIR}/android/app/src/main/java"
)

mkdir -p "${CACHE_DIR}"

download() {
  local url="$1"
  local dest="$2"
  if [[ -f "${dest}" ]]; then
    return 0
  fi
  local tmp="${dest}.tmp"
  curl -fsSL --retry 3 --retry-delay 1 -o "${tmp}" "${url}"
  mv "${tmp}" "${dest}"
}

download \
  "https://repo1.maven.org/maven2/io/gitlab/arturbosch/detekt/detekt-cli/${DETEKT_VERSION}/detekt-cli-${DETEKT_VERSION}-all.jar" \
  "${CLI_JAR}"
download \
  "https://repo1.maven.org/maven2/io/gitlab/arturbosch/detekt/detekt-formatting/${DETEKT_VERSION}/detekt-formatting-${DETEKT_VERSION}.jar" \
  "${FORMATTING_JAR}"

inputs=()
for dir in "${INPUT_DIRS[@]}"; do
  if [[ -d "${dir}" ]]; then
    inputs+=("${dir}")
  fi
done
if [[ "${#inputs[@]}" -eq 0 ]]; then
  echo "No Kotlin/Java source directories found under packages/guar/android/app/src/main" >&2
  exit 1
fi

input_csv="$(IFS=,; echo "${inputs[*]}")"

java -jar "${CLI_JAR}" \
  --build-upon-default-config \
  --config "${CONFIG}" \
  --plugins "${FORMATTING_JAR}" \
  --input "${input_csv}" \
  --excludes '**/GeneratedPluginRegistrant.java' \
  --parallel

# pre-commit exports GIT_DIR. Flutter and Gradle then inspect the wrong repository.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
  GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR || true

(
  cd "${APP_DIR}"
  "${ROOT}/scripts/run_fvm.sh" flutter build apk --config-only
)
(
  cd "${APP_DIR}/android"
  ./gradlew :app:compileDebugKotlin --console=plain
)
