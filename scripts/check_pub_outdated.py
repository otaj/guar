#!/usr/bin/env python3
# Fail when direct/dev pub deps can be upgraded in-constraint, or are unsafe.

from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

_RUN_FVM = Path(__file__).resolve().parent / "run_fvm.sh"


def _version(entry: dict | None) -> str | None:
    if entry is None:
        return None
    return entry.get("version")


def _extract_json(raw: str) -> dict:
    start = raw.find("{")
    if start < 0:
        raise ValueError("no JSON object in dart pub outdated output")
    return json.loads(raw[start:])


def _pub_outdated_cmd() -> list[str]:
    if _RUN_FVM.is_file() and shutil.which("fvm"):
        return [str(_RUN_FVM), "dart", "pub", "outdated", "--json"]
    return ["dart", "pub", "outdated", "--json"]


def main() -> int:
    try:
        proc = subprocess.run(
            _pub_outdated_cmd(),
            check=False,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError:
        print("error: dart/fvm not found or not executable", file=sys.stderr)
        return 1

    if proc.returncode != 0:
        sys.stderr.write(proc.stderr or proc.stdout or "dart pub outdated failed\n")
        return proc.returncode or 1

    try:
        data = _extract_json(proc.stdout)
    except (json.JSONDecodeError, ValueError) as exc:
        print(f"error: could not parse pub outdated JSON: {exc}", file=sys.stderr)
        return 1

    failures: list[str] = []
    for pkg in data.get("packages", []):
        kind = pkg.get("kind")
        if kind not in ("direct", "dev"):
            continue

        name = pkg.get("package", "?")
        current = _version(pkg.get("current"))
        upgradable = _version(pkg.get("upgradable"))

        reasons: list[str] = []
        if pkg.get("isDiscontinued"):
            reasons.append("discontinued")
        if pkg.get("isCurrentRetracted"):
            reasons.append("current version retracted")
        if pkg.get("isCurrentAffectedByAdvisory"):
            reasons.append("affected by security advisory")

        if current and upgradable and current != upgradable:
            reasons.append(f"upgradable within constraints {current} -> {upgradable}")

        if reasons:
            label = "dev" if kind == "dev" else "direct"
            failures.append(f"  - {name} ({label}): {', '.join(reasons)}")

    if failures:
        print("Outdated or unsafe direct/dev dependencies:")
        print("\n".join(failures))
        print(
            "\nUpdate with `fvm dart pub upgrade`. For constraint-blocked majors, "
            "edit pubspec.yaml (e.g. `fvm dart pub upgrade --major-versions`) "
            "and resolve peer conflicts, then re-run."
        )
        return 1

    print(
        "No upgradable/unsafe direct/dev dependencies (within current pubspec constraints)."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
