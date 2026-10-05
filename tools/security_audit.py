from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

TEXT_EXTENSIONS = {".gd", ".tscn", ".tres", ".godot", ".py", ".yml", ".yaml", ".json", ".cfg", ".md"}
SCAN_ROOTS = ["src", "simulation", "tools", ".github"]
MAX_SOURCE_BYTES = 2_000_000

SECRET_PATTERNS = {
    r"gh[pousr]_[A-Za-z0-9_]{20,}": "GitHub token-like value",
    r"AKIA[0-9A-Z]{16}": "AWS access key-like value",
    r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----": "private key material",
    r"(?i)(api[_-]?key|password|token|client[_-]?secret)\s*[:=]\s*[\"'][^\"']{12,}[\"']": "embedded credential-like value",
}

HIGH_RISK_GDSCRIPT = {
    r"\bOS\.execute\s*\(": "OS.execute",
    r"\bOS\.create_process\s*\(": "OS.create_process",
    r"\bJavaScriptBridge\.eval\s*\(": "JavaScriptBridge.eval",
    r"\bFileAccess\.open_encrypted_with_pass\s*\(": "password-based encrypted file access",
}

FORBIDDEN_BINARY_SUFFIXES = {".exe", ".dll", ".so", ".dylib", ".app", ".bin"}

errors: list[str] = []


def iter_files():
    seen = set()
    for rel in SCAN_ROOTS:
        root = ROOT / rel
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if not path.is_file() or ".git" in path.parts:
                continue
            resolved = path.resolve()
            if resolved in seen:
                continue
            seen.add(resolved)
            yield path


for path in iter_files():
    rel = path.relative_to(ROOT).as_posix()
    suffix = path.suffix.lower()

    if suffix in FORBIDDEN_BINARY_SUFFIXES:
        errors.append(f"tracked executable/binary is not allowed in source paths: {rel}")
        continue

    size = path.stat().st_size
    if size > MAX_SOURCE_BYTES and suffix in TEXT_EXTENSIONS:
        errors.append(f"oversized source/config file ({size} bytes): {rel}")

    if suffix not in TEXT_EXTENSIONS:
        continue

    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        errors.append(f"non-UTF-8 text-like file: {rel}")
        continue

    for pattern, label in SECRET_PATTERNS.items():
        if re.search(pattern, text):
            errors.append(f"{label} detected in {rel}")

    if suffix == ".gd":
        for pattern, label in HIGH_RISK_GDSCRIPT.items():
            if re.search(pattern, text):
                errors.append(f"high-risk GDScript API requires explicit security review: {label} in {rel}")

        if "extends " not in text and path.name != "__init__.gd":
            errors.append(f"GDScript file has no extends declaration: {rel}")

for workflow in (ROOT / ".github" / "workflows").glob("*.y*ml"):
    text = workflow.read_text(encoding="utf-8")
    for line_no, line in enumerate(text.splitlines(), 1):
        stripped = line.strip()
        if not stripped.startswith("uses:"):
            continue
        ref = stripped.split("uses:", 1)[1].strip()
        if ref.startswith("./"):
            continue
        if "@" not in ref:
            errors.append(f"unversioned action in {workflow.relative_to(ROOT)}:{line_no}: {ref}")
            continue
        version = ref.rsplit("@", 1)[1].split()[0]
        if not re.fullmatch(r"[0-9a-fA-F]{40}", version):
            errors.append(f"action is not pinned to a full commit SHA in {workflow.relative_to(ROOT)}:{line_no}: {ref}")

project = ROOT / "project.godot"
if project.exists():
    text = project.read_text(encoding="utf-8")
    if 'config/features=PackedStringArray("4.3")' not in text:
        errors.append("project.godot must remain explicitly targeted to Godot 4.3")
    if 'run/main_scene="res://src/Main.tscn"' not in text:
        errors.append("project.godot main scene drifted from res://src/Main.tscn")

main_scene = ROOT / "src" / "Main.tscn"
if main_scene.exists():
    text = main_scene.read_text(encoding="utf-8")
    if "res://src/main.gd" not in text:
        errors.append("src/Main.tscn does not reference res://src/main.gd")

if errors:
    print("THE LAST SETTLEMENT SECURITY AUDIT: FAILED")
    for error in errors:
        print(f" - {error}")
    sys.exit(1)

print("THE LAST SETTLEMENT SECURITY AUDIT: PASS")
print("No embedded credential patterns, prohibited source binaries, unpinned third-party actions, or high-risk GDScript APIs detected.")


UPDATE_MANAGER_REQUIRED_MARKERS = [
    'DEFAULT_MANIFEST_URL := "https://github.com/DPN-Technology/The-Last-Settlement/releases/latest/download/windows-release.json"',
    'RELEASE_ASSET_PREFIX := "https://github.com/DPN-Technology/The-Last-Settlement/releases/download/"',
    'HashingContext.HASH_SHA256',
    'OS.shell_open',
    'target_save_schema < current_save_schema',
    'INSTALLER SHA-256 VERIFICATION FAILED',
]

update_manager = ROOT / "src" / "update_manager.gd"
if not update_manager.exists():
    errors.append("secure update manager is missing")
else:
    updater_text = update_manager.read_text(encoding="utf-8")
    if "http://" in updater_text:
        errors.append("update manager contains an insecure HTTP URL")
    for marker in UPDATE_MANAGER_REQUIRED_MARKERS:
        if marker not in updater_text:
            errors.append(f"update manager security marker missing: {marker}")
