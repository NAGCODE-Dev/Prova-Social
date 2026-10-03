#!/usr/bin/env python3
"""Enable dependency locking in a Flutter-generated Android app module."""

import argparse
import re
from pathlib import Path


LOCKING_BLOCK = """

// Prova Social: keep the audited Android runtime dependency graph locked.
dependencyLocking {
    lockAllConfigurations()
}
"""
KOTLIN_COMMON_MARKER = (
    "// Prova Social: lock Kotlin metadata selected by the Android runtime variant."
)


def kotlin_plugin_version(settings_file: Path) -> str:
    if not settings_file.is_file():
        raise ValueError(f"no Android settings file found at {settings_file}")

    settings = settings_file.read_text()
    patterns = (
        r"""id\(["']org\.jetbrains\.kotlin\.android["']\)\s+version\s+["']([^"']+)["']""",
        r"""id\s+["']org\.jetbrains\.kotlin\.android["']\s+version\s+["']([^"']+)["']""",
    )
    for pattern in patterns:
        match = re.search(pattern, settings)
        if match:
            return match.group(1)

    raise ValueError(
        f"could not find the Kotlin Android plugin version in {settings_file}"
    )


def kotlin_common_dependency(build_file: Path, version: str) -> str:
    if build_file.suffix == ".kts":
        dependency = (
            f'    implementation("org.jetbrains.kotlin:kotlin-stdlib-common:{version}")'
        )
    else:
        dependency = (
            f"    implementation 'org.jetbrains.kotlin:kotlin-stdlib-common:{version}'"
        )
    return f"\n{KOTLIN_COMMON_MARKER}\ndependencies {{\n{dependency}\n}}\n"


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
    if marker not in contents and "dependencyLocking" in contents:
        parser.error(f"unexpected existing dependencyLocking block in {build_file}")

    updated = contents
    if marker not in updated:
        updated = updated.rstrip() + LOCKING_BLOCK

    if KOTLIN_COMMON_MARKER not in updated:
        try:
            version = kotlin_plugin_version(project_dir.parent / "settings.gradle.kts")
        except ValueError as error:
            parser.error(str(error))
        updated = updated.rstrip() + kotlin_common_dependency(build_file, version)

    if updated != contents:
        build_file.write_text(updated)
        print(f"Prepared Android dependency locking in {build_file}")


if __name__ == "__main__":
    main()
