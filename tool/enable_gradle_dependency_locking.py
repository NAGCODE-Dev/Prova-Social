#!/usr/bin/env python3
"""Enable dependency locking in a Flutter-generated Android app module."""

import argparse
from pathlib import Path


LOCKING_BLOCK = """

// Prova Social: keep the audited Android runtime dependency graph locked.
dependencyLocking {
    lockAllConfigurations()
}
"""


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "project_dir",
        nargs="?",
        type=Path,
        default=Path("android/app"),
        help="Flutter-generated Android app module directory",
    )
    project_dir = parser.parse_args().project_dir

    candidates = [project_dir / "build.gradle.kts", project_dir / "build.gradle"]
    build_file = next((path for path in candidates if path.is_file()), None)
    if build_file is None:
        parser.error(f"no Android app Gradle file found in {project_dir}")

    contents = build_file.read_text()
    marker = "// Prova Social: keep the audited Android runtime dependency graph locked."
    if marker in contents:
        return
    if "dependencyLocking" in contents:
        parser.error(f"unexpected existing dependencyLocking block in {build_file}")

    build_file.write_text(contents.rstrip() + LOCKING_BLOCK)
    print(f"Enabled Gradle dependency locking in {build_file}")


if __name__ == "__main__":
    main()
