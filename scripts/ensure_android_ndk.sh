#!/usr/bin/env bash
# Install Flutter's NDK into the Android SDK when that version is missing.
#
# AGP downloads it during configuration and, on GitHub runners, the saved
# archive is not a zip, so compile and unit tests fail before they start.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

android_sdk() {
  if [[ -n "${ANDROID_HOME:-}" ]]; then
    echo "${ANDROID_HOME}"
    return
  fi
  if [[ -n "${ANDROID_SDK_ROOT:-}" ]]; then
    echo "${ANDROID_SDK_ROOT}"
    return
  fi
  local props="${ROOT}/packages/guar/android/local.properties" dir=""
  if [[ -f "${props}" ]]; then
    dir="$(sed -n 's/^sdk\.dir=//p' "${props}" | head -n 1)"
  fi
  if [[ -n "${dir}" ]]; then
    echo "${dir}"
    return
  fi
  return 1
}

flutter_sdk() {
  if [[ -n "${FLUTTER_ROOT:-}" && -d "${FLUTTER_ROOT}/bin" ]]; then
    echo "${FLUTTER_ROOT}"
    return
  fi
  local version="" home
  if [[ -f "${ROOT}/.fvmrc" ]]; then
    version="$(sed -n 's/.*"flutter"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${ROOT}/.fvmrc")"
  fi
  if [[ -n "${version}" ]]; then
    for home in "${FVM_CACHE_PATH:-}" "${FVM_HOME:-}" "${HOME}/fvm" "${HOME}/.fvm"; do
      if [[ -n "${home}" && -d "${home}/versions/${version}" ]]; then
        echo "${home}/versions/${version}"
        return
      fi
    done
  fi
  if command -v flutter >/dev/null 2>&1; then
    local bin
    bin="$(readlink -f "$(command -v flutter)")"
    (cd "$(dirname "${bin}")/.." && pwd)
    return
  fi
  echo "error: Flutter SDK not found" >&2
  return 1
}

host_os() {
  case "$(uname -s)" in
    Linux) echo linux ;;
    Darwin) echo macosx ;;
    *)
      echo "error: unsupported OS for the Android NDK: $(uname -s)" >&2
      return 1
      ;;
  esac
}

SDK="$(android_sdk)" || {
  echo "error: Android SDK not found" >&2
  exit 1
}
FLUTTER="$(flutter_sdk)"
EXT="${FLUTTER}/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt"
NDK_VERSION="$(sed -n 's/.*val ndkVersion: String = "\([^"]*\)".*/\1/p' "${EXT}")"
if [[ -z "${NDK_VERSION}" ]]; then
  echo "error: ndkVersion missing from ${EXT}" >&2
  exit 1
fi
if [[ -f "${SDK}/ndk/${NDK_VERSION}/source.properties" ]]; then
  exit 0
fi

HOST="$(host_os)"
NDK_URL="$(
  python3 - "${NDK_VERSION}" "${HOST}" <<'PY'
import sys
import urllib.request
import xml.etree.ElementTree as ET

version, host = sys.argv[1], sys.argv[2]
with urllib.request.urlopen("https://dl.google.com/android/repository/repository2-1.xml") as response:
    text = response.read().decode("utf-8")
text = text.replace('xmlns="http://schemas.android.com/sdk/android/repo/repository2/01"', "")
root = ET.fromstring(text)
for package in root.iter("remotePackage"):
    if package.get("path") != f"ndk;{version}":
        continue
    for archive in package.iter("archive"):
        if archive.findtext("host-os") == host:
            name = archive.findtext("complete/url")
            if name:
                print(f"https://dl.google.com/android/repository/{name}")
                raise SystemExit(0)
print(f"error: no {host} archive for ndk;{version}", file=sys.stderr)
raise SystemExit(1)
PY
)"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
curl -fsSL --retry 5 --retry-all-errors --retry-delay 2 -o "${WORK}/ndk.zip" "${NDK_URL}"
unzip -t "${WORK}/ndk.zip" >/dev/null
unzip -q "${WORK}/ndk.zip" -d "${WORK}/unpack"
mapfile -t roots < <(find "${WORK}/unpack" -mindepth 1 -maxdepth 1 -type d)
if [[ "${#roots[@]}" -ne 1 ]]; then
  echo "error: expected one top-level directory in the NDK archive" >&2
  exit 1
fi
mkdir -p "${SDK}/ndk"
rm -rf "${SDK}/ndk/${NDK_VERSION}"
mv "${roots[0]}" "${SDK}/ndk/${NDK_VERSION}"
if [[ ! -f "${SDK}/ndk/${NDK_VERSION}/source.properties" ]]; then
  echo "error: NDK ${NDK_VERSION} did not unpack source.properties" >&2
  exit 1
fi
