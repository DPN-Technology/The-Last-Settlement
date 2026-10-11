#!/usr/bin/env python3
"""Install CC0 1K glTF reference props, verifying each Poly Haven manifest file."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import time
from urllib.parse import urlparse
from urllib.request import Request, urlopen

ASSETS = ("barrel_03", "painted_wooden_table", "painted_wooden_bench", "covered_car", "concrete_road_barrier_02", "Shelf_01", "portable_generator", "worn_metal_rack", "tool_cart")
ROOT = Path("assets/3d/photoreal")
ALLOWED_HOSTS = {"api.polyhaven.com", "dl.polyhaven.org"}
USER_AGENT = "DPN-TheLastSettlement-ReferenceAssets/1"
MAX_ITEM_BYTES = 35 * 1024 * 1024
MAX_TOTAL_BYTES = 140 * 1024 * 1024

def _open(url: str):
    address = urlparse(url)
    if address.scheme != "https" or address.hostname not in ALLOWED_HOSTS:
        raise ValueError("Asset URL is not Poly Haven HTTPS: " + url)
    response = urlopen(Request(url, headers={"User-Agent": USER_AGENT}), timeout=45)
    final = urlparse(response.url)
    if final.scheme != "https" or final.hostname not in ALLOWED_HOSTS:
        response.close()
        raise ValueError("Untrusted asset redirect: " + response.url)
    return response

def _fetch_json(url: str):
    with _open(url) as stream:
        return json.load(stream)

def _validated_path(relative: str) -> Path:
    pure = PurePosixPath(relative)
    if (not relative or pure.is_absolute() or "\\" in relative or
            ":" in relative or any(p in ("..", ".") for p in pure.parts) or
            not re.fullmatch(r"[A-Za-z0-9_\-./]+", relative)):
        raise ValueError("Unsafe asset dependency path: " + relative)
    return Path(*pure.parts)

def _install_one(destination: Path, relative: str, spec: dict) -> tuple[int, str]:
    path = destination / _validated_path(relative)
    url, expected, size = spec.get("url"), spec.get("md5"), spec.get("size")
    if not isinstance(url, str) or not isinstance(expected, str) or not isinstance(size, int):
        raise ValueError("Missing integrity metadata: " + relative)
    if not re.fullmatch(r"[0-9a-fA-F]{32}", expected) or not 100 <= size <= MAX_ITEM_BYTES:
        raise ValueError("Invalid file MD5 or size: " + relative)

    def valid(candidate: Path) -> bool:
        if not candidate.is_file() or candidate.stat().st_size != size:
            return False
        digest = hashlib.md5()
        with candidate.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
        return digest.hexdigest().lower() == expected.lower()

    if valid(path):
        return size, expected
    path.parent.mkdir(parents=True, exist_ok=True)
    for attempt in range(3):
        temp = path.with_suffix(path.suffix + ".download")
        temp.unlink(missing_ok=True)
        try:
            hasher, received = hashlib.md5(), 0
            with _open(url) as stream, temp.open("wb") as target:
                while chunk := stream.read(1024 * 1024):
                    received += len(chunk)
                    if received > size or received > MAX_ITEM_BYTES:
                        raise ValueError("Unexpected downloaded file length")
                    hasher.update(chunk)
                    target.write(chunk)
            if received != size or hasher.hexdigest().lower() != expected.lower():
                raise ValueError("Poly Haven MD5/size mismatch: " + relative)
            os.replace(temp, path)
            return size, expected
        except Exception:
            temp.unlink(missing_ok=True)
            if attempt == 2:
                raise
            time.sleep(attempt + 1)
    raise AssertionError("Unreachable")

def install(root: Path = ROOT) -> None:
    catalog: dict = {"license": "CC0-1.0", "source": "https://polyhaven.com", "assets": {}}
    total = 0
    for slug in ASSETS:
        response = _fetch_json(f"https://api.polyhaven.com/files/{slug}")
        entry = (response.get("gltf") or {}).get("1k", {}).get("gltf")
        if not isinstance(entry, dict):
            raise ValueError("Missing authentic 1K glTF package: " + slug)
        source_name = Path(urlparse(entry["url"]).path).name
        if not source_name.endswith(".gltf"):
            raise ValueError("Unexpected model format: " + slug)
        deps = entry.get("include") or {}
        if not isinstance(deps, dict):
            raise ValueError("Malformed dependency manifest")
        manifest = {source_name: entry, **deps}
        package_size = sum(int(v["size"]) for v in manifest.values())
        total += package_size
        if total > MAX_TOTAL_BYTES:
            raise ValueError("Reference assets exceed maximum total size")
        folder, record = root / slug, {}
        for relative, spec in manifest.items():
            size, digest = _install_one(folder, relative, spec)
            record[relative] = {"bytes": size, "md5": digest}
        gltf = json.loads((folder / source_name).read_text(encoding="utf-8"))
        for group in ("buffers", "images"):
            for item in gltf.get(group, []):
                uri = item.get("uri", "")
                if uri and not uri.startswith("data:") and not (folder / _validated_path(uri)).is_file():
                    raise ValueError("Broken glTF dependency: " + slug + "/" + uri)
        catalog["assets"][slug] = {"main": source_name, "files": record}
        print(f"REAL REFERENCE MODEL VERIFIED {slug}: {len(record)} files, {package_size} bytes")
    root.mkdir(parents=True, exist_ok=True)
    (root / "verified-manifest.json").write_text(json.dumps(catalog, sort_keys=True, indent=2)+"\n")
    print(f"REFERENCE ART PACK READY: {len(ASSETS)} CC0 models / {total} bytes")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=ROOT)
    install(parser.parse_args().root)
