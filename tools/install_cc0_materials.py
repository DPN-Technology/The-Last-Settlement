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
MATERIALS_SHA256: dict[str, str] = {
    "rough_concrete_diff_1k.png": "5d1fc425ae5fffdd8c4b8245394301c1fedbf19b26567c43619d2ba5a40d9aff",
    "rough_concrete_nor_gl_1k.png": "36f547dc69d3cf9ea076b68e59fe6fe5af2b6281196ec913a54fcd9822fef3cf",
    "rusty_metal_sheet_diff_1k.png": "b8e47f1d84acbe20119a351217d7a9d1139a21ea99a9fe0dd653880c9ee897ba",
    "rusty_metal_sheet_nor_gl_1k.png": "ad8284e25754f109a46ab418f08a26f7ab8030f9c6cdf60d5b939f441a30b789",
    "gravel_ground_01_diff_1k.png": "98de56b46955d2a196a74b5bff9fa6e72e01b8e8f047f0217b82c3361e2c9db5",
    "gravel_ground_01_nor_gl_1k.png": "4e20f2dd84237fb46b3ae7005b8134ec2f8f08c6dc57c69df7c24d28df7d83b0"
}
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
            if expected is None or expected != actual:
                raise ValueError(f"Unexpected Poly Haven texture hash for {name}")
            if not target.exists():
                target.write_bytes(payload)
            print(f"PBR VERIFIED {name}: sha256={actual} bytes={len(payload)}")


if __name__ == "__main__":
    install()
