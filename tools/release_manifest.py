#!/usr/bin/env python3
"""Build a machine-readable Windows release manifest for The Last Settlement."""

from __future__ import annotations

import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def asset_record(path: Path, repository: str, release_tag: str | None) -> dict:
    record = {
        "filename": path.name,
        "sha256": sha256(path),
        "size_bytes": path.stat().st_size,
    }
    if repository and release_tag:
        record["url"] = (
            f"https://github.com/{repository}/releases/download/"
            f"{release_tag}/{path.name}"
        )
    else:
        record["url"] = None
    return record


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True)
    parser.add_argument("--channel", required=True, choices=("development", "prerelease", "stable"))
    parser.add_argument("--commit", required=True)
    parser.add_argument("--portable", required=True, type=Path)
    parser.add_argument("--installer", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--repository", default="")
    parser.add_argument("--release-tag", default="")
    parser.add_argument("--signing-status", choices=("signed", "unsigned"), default="unsigned")
    parser.add_argument("--save-schema", type=int, default=14)
    args = parser.parse_args()

    for path in (args.portable, args.installer):
        if not path.is_file() or path.stat().st_size == 0:
            raise SystemExit(f"missing release asset: {path}")

    manifest = {
        "schema_version": 1,
        "product": "The Last Settlement",
        "publisher": "DPN Technology",
        "version": args.version,
        "channel": args.channel,
        "commit": args.commit,
        "platform": "windows-x86_64",
        "save_schema": args.save_schema,
        "signing_status": args.signing_status,
        "generated_at_utc": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "release_tag": args.release_tag or None,
        "assets": {
            "portable": asset_record(args.portable, args.repository, args.release_tag or None),
            "installer": asset_record(args.installer, args.repository, args.release_tag or None),
        },
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    # Self-validate the JSON we just wrote.
    loaded = json.loads(args.output.read_text(encoding="utf-8"))
    if loaded["version"] != args.version or loaded["commit"] != args.commit:
        raise SystemExit("release manifest self-validation failed")

    print(f"Wrote release manifest: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
