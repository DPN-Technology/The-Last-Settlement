# Contributing to The Last Settlement

Changes should preserve deterministic-friendly simulation architecture, avoid disconnected systems, and keep the project compatible with Godot 4.3.

Before submitting a pull request:

- Run `python tools/validate_project.py`.
- Run `python tools/security_audit.py`.
- Do not commit credentials, generated builds, executable binaries, or editor caches.
- Keep GitHub Actions pinned to full commit SHAs.
- Document new simulation systems and cascading dependencies.
- Treat changes to process execution, networking, file encryption, save formats, or external services as security-sensitive.
