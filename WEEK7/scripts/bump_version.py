#!/usr/bin/env python3
"""Bump the version and roll the CHANGELOG's [Unreleased] section into a release.

Usage:
    python scripts/bump_version.py 1.0.0 --note "Add multiply()" --note "Add divide()"
"""
import argparse
import datetime
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
INIT = ROOT / "app" / "__init__.py"
CHANGELOG = ROOT / "CHANGELOG.md"
SEMVER = re.compile(r"^\d+\.\d+\.\d+$")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("version", help="new version, e.g. 1.2.0")
    parser.add_argument("--note", action="append", default=[],
                        help="bullet for the changelog (repeatable)")
    parser.add_argument("--date", default=datetime.date.today().isoformat())
    args = parser.parse_args()

    if not SEMVER.match(args.version):
        sys.exit(f"'{args.version}' is not MAJOR.MINOR.PATCH")

    # 1) version string
    init_text = INIT.read_text()
    new_init, count = re.subn(r'__version__ = "[^"]*"',
                              f'__version__ = "{args.version}"', init_text)
    if count != 1:
        sys.exit("could not find __version__ in app/__init__.py")
    INIT.write_text(new_init)

    # 2) changelog: move [Unreleased] content under the new version
    text = CHANGELOG.read_text()
    if f"## [{args.version}]" in text:
        sys.exit(f"CHANGELOG already contains version {args.version}")
    match = re.search(r"^## \[Unreleased\][ \t]*\n(.*?)(?=^## \[|\Z)", text, re.S | re.M)
    if not match:
        sys.exit("CHANGELOG.md has no '## [Unreleased]' section")
    bullets = [match.group(1).strip()] if match.group(1).strip() else []
    bullets += [f"- {note}" for note in args.note]
    if not bullets:
        bullets = ["- No notable changes."]
    section = (f"## [Unreleased]\n\n## [{args.version}] - {args.date}\n\n"
               + "\n".join(bullets) + "\n\n")
    CHANGELOG.write_text(text[:match.start()] + section + text[match.end():])
    print(f"Bumped to {args.version} (app/__init__.py, CHANGELOG.md)")


if __name__ == "__main__":
    main()
