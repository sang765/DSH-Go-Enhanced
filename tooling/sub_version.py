#!/usr/bin/env python3
"""Fork release version: `<upstream-version>-sub.<n>`.

The upstream base (currently 1.3.0) lives in `app/pubspec.yaml`'s `version:`.
The fork adds `-sub.<n>` to it; `<n>` starts at 1 and increases by one for each
release built from the same upstream base. The number comes from the existing
`v<base>-sub.<n>` git tags, so a fresh clone computes the same next version.

    python3 tooling/sub_version.py --next      # next version name, e.g. 1.3.0-sub.2
    python3 tooling/sub_version.py --check     # pubspec and AppInfo agree
    python3 tooling/sub_version.py --write     # bump both to the next version

Changing the upstream base is a manual edit of the base part in pubspec (for
example `1.3.0-sub.1+1` -> `1.3.1-sub.1+1`); the counter then restarts at 1
because there are no `v1.3.1-sub.*` tags yet. The `+1` in pubspec stays a
placeholder: tooling/build-apk.sh replaces it with the build minute.
"""

import argparse
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent.parent
PUBSPEC = ROOT / "app" / "pubspec.yaml"
APP_INFO = ROOT / "app" / "lib" / "state" / "app_info.dart"

VERSION_RE = re.compile(r"^version:\s*(\d+\.\d+\.\d+)(?:-sub\.(\d+))?\+1\s*$", re.MULTILINE)


def read_pubspec(root: pathlib.Path = ROOT) -> tuple[str, int]:
    """(upstream base, sub number) from pubspec.yaml."""
    text = (pathlib.Path(root) / "app" / "pubspec.yaml").read_text(encoding="utf-8")
    match = VERSION_RE.search(text)
    if match is None:
        raise ValueError(f"{root}/app/pubspec.yaml: expected version X.Y.Z-sub.N+1")
    return match.group(1), int(match.group(2) or 0)


def version_name(root: pathlib.Path = ROOT) -> str:
    """Full version name from pubspec, e.g. 1.3.0-sub.1."""
    base, sub = read_pubspec(root)
    return f"{base}-sub.{sub}" if sub else base


def next_version(base: str, tags: list[str]) -> str:
    """The next `-sub.N` name after the given release tags."""
    pattern = re.compile(rf"^v{re.escape(base)}-sub\.(\d+)$")
    used = [int(m.group(1)) for tag in tags if (m := pattern.fullmatch(tag))]
    return f"{base}-sub.{max(used, default=0) + 1}"


def git_tags(root: pathlib.Path = ROOT) -> list[str]:
    out = subprocess.run(
        ["git", "tag", "--list"], cwd=root, capture_output=True, text=True, check=True
    ).stdout
    return out.splitlines()


def check(root: pathlib.Path = ROOT) -> None:
    """ValueError unless pubspec and AppInfo declare the same version."""
    root = pathlib.Path(root)
    version = version_name(root)
    app_info = (root / "app" / "lib" / "state" / "app_info.dart").read_text(encoding="utf-8")
    fallback = re.search(r"String\.fromEnvironment\('DSH_APP_VERSION', defaultValue: '([^']+)'\)", app_info)
    if fallback is None or fallback.group(1) != f"{version}+1":
        raise ValueError(f"AppInfo default must be {version}+1 to match pubspec")


def write(root: pathlib.Path = ROOT, tags: list[str] | None = None) -> str:
    """Bump pubspec and AppInfo to the next tag-derived version; return it."""
    root = pathlib.Path(root)
    base, _ = read_pubspec(root)
    version = next_version(base, git_tags(root) if tags is None else tags)
    pubspec = root / "app" / "pubspec.yaml"
    text = pubspec.read_text(encoding="utf-8")
    text, count = VERSION_RE.subn(f"version: {version}+1", text, count=1)
    if count != 1:
        raise ValueError(f"{pubspec}: no version to replace")
    pubspec.write_text(text, encoding="utf-8", newline="\n")

    app_info = root / "app" / "lib" / "state" / "app_info.dart"
    text = app_info.read_text(encoding="utf-8")
    text, count = re.subn(
        r"(?<=defaultValue: ')[^']+(?='\))", f"{version}+1", text, count=1
    )
    if count != 1:
        raise ValueError(f"{app_info}: no DSH_APP_VERSION default to replace")
    text = re.sub(r"DSH_APP_VERSION=[^\s`]*", f"DSH_APP_VERSION={version}+7", text, count=1)
    app_info.write_text(text, encoding="utf-8", newline="\n")
    check(root)
    return version


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--next", action="store_true", help="print the next version name")
    group.add_argument("--check", action="store_true", help="exit 1 unless pubspec and AppInfo agree")
    group.add_argument("--write", action="store_true", help="bump pubspec and AppInfo to the next version")
    args = parser.parse_args()
    try:
        if args.check:
            check()
        elif args.write:
            print(write())
        else:
            base, _ = read_pubspec()
            print(next_version(base, git_tags()))
    except ValueError as e:
        raise SystemExit(f"sub_version: {e}") from None


if __name__ == "__main__":
    main()
