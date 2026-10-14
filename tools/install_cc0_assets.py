#!/usr/bin/env python3
"""Install license-checked immutable CC0 third-party 3D art for CI and exports."""
from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path
import time
import urllib.request

SOURCE_COMMIT = "728f23ab5eb9d6cb2c8fb39acb3440bd81db0d3e"
SOURCE_BLOB_SHA1 = "de56d83cdcd5d741955fe6acd983a61e50e367c3"
SOURCE_URL = (
    "https://raw.githubusercontent.com/UMRAM-Bilkent/supine-human-model/"
    f"{SOURCE_COMMIT}/assets/human.glb"
)
DESTINATION = Path("assets/3d/characters/survivor.glb")
MAX_DOWNLOAD_BYTES = 3_000_000


def git_blob_sha1(payload: bytes) -> str:
    return hashlib.sha1(
        b"blob " + str(len(payload)).encode("ascii") + b"\0" + payload
    ).hexdigest()


def verify(payload: bytes) -> None:
    if not payload.startswith(b"glTF"):
        raise ValueError("Expected a valid glTF binary header")
    if len(payload) > MAX_DOWNLOAD_BYTES or len(payload) < 60_000:
        raise ValueError("Model is outside expected size constraints")
    actual = git_blob_sha1(payload)
    if actual != SOURCE_BLOB_SHA1:
        raise ValueError(f"Pinned CC0 character asset checksum mismatch: {actual}")


def install(destination: Path) -> None:
    if destination.is_file():
        payload = destination.read_bytes()
        verify(payload)
        print(f"CC0 ART VERIFIED: {destination} ({len(payload)} bytes)")
        return

    last_error: Exception | None = None
    for attempt in range(3):
        try:
            request = urllib.request.Request(
                SOURCE_URL, headers={"User-Agent": "DPN-The-Last-Settlement-Assets/1"}
            )
            with urllib.request.urlopen(request, timeout=35) as response:
                payload = response.read(MAX_DOWNLOAD_BYTES + 1)
            verify(payload)
            destination.parent.mkdir(parents=True, exist_ok=True)
            temporary = destination.with_suffix(".glb.tmp")
            temporary.write_bytes(payload)
            os.replace(temporary, destination)
            print(
                f"CC0 ART INSTALLED: {destination} ({len(payload)} bytes)"
                f" pinned git blob {SOURCE_BLOB_SHA1}"
            )
            return
        except Exception as error:
            last_error = error
            time.sleep(attempt + 1)
    raise RuntimeError("Cannot install immutable CC0 rigged character") from last_error


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--destination", type=Path, default=DESTINATION)
    args = parser.parse_args()
    install(args.destination)


if __name__ == "__main__":
    main()
