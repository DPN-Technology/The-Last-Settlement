#!/usr/bin/env python3
"""Import three CC0 photographic 1K PBR materials into the offline game.

Sources are the public Poly Haven asset CDN. For development we print hashes
then pin them in MATERIALS_SHA256 after the first verified fetch; publishing
an unpinned texture is prohibited once the fingerprint is recorded.
"""
from __future__ import annotations

import hashlib
import struct
from pathlib import Path
import time
import urllib.request

ASSETS = ("rough_concrete", "rusty_metal_sheet", "gravel_ground_01")
SUFFIXES = ("diff", "nor_gl")
PATH = Path("assets/3d/pbr")
# Filled only after actual public-CDN checksums have been observed and reviewed.
MATERIALS_SHA256: dict[str, str] = {}
MAX_BYTES = 20_000_000


def install() -> None:
    PATH.mkdir(parents=True, exist_ok=True)
    for asset in ASSETS:
        for suffix in SUFFIXES:
            name = f"{asset}_{suffix}_1k.png"
            target = PATH / name
            url = (
                "https://dl.polyhaven.org/file/ph-assets/Textures/png/1k/"
                f"{asset}/{name}"
            )
            payload: bytes | None = None
            if target.is_file():
                payload = target.read_bytes()
            if payload is None:
                for attempt in range(3):
                    try:
                        request = urllib.request.Request(
                            url, headers={"User-Agent": "DPN-TLS-PBR-Build/1"}
                        )
                        with urllib.request.urlopen(request, timeout=40) as response:
                            payload = response.read(MAX_BYTES + 1)
                        break
                    except Exception:
                        if attempt == 2:
                            raise
                        time.sleep(1 + attempt)
            if payload is None or not payload.startswith(b"\x89PNG\r\n\x1a\n"):
                raise ValueError(f"Invalid PNG texture: {name}")
            if len(payload) < 10_000 or len(payload) > MAX_BYTES:
                raise ValueError(f"Unexpected PBR texture length: {name} bytes={len(payload)} url={url}")
            width, height = struct.unpack(">II", payload[16:24])
            if width not in (1024, 2048) or height not in (1024, 2048):
                raise ValueError(f"Unexpected PBR resolution for {name}: {width}x{height}")
            actual = hashlib.sha256(payload).hexdigest()
            expected = MATERIALS_SHA256.get(name)
            if expected and expected != actual:
                raise ValueError(f"Unexpected Poly Haven texture hash for {name}")
            if not target.exists():
                target.write_bytes(payload)
            print(f"PBR VERIFIED {name}: sha256={actual} bytes={len(payload)}")


if __name__ == "__main__":
    install()
