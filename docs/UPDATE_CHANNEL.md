# Windows Release & Update Channel

**The Last Settlement** uses a versioned Windows distribution pipeline designed for safe manual installs today and a future in-game updater.

## Channels

| Channel | Source | Example | Behavior |
|---|---|---|---|
| Development | `main` | `1.0.4-dev` | Builds Actions artifacts only |
| Prerelease | Git tag containing `-` | `v1.1.0-beta.1` | Publishes a GitHub prerelease |
| Stable | Clean Git tag | `v1.1.0` | Publishes a normal GitHub Release |

A tagged release is only published after the same Windows pipeline successfully builds and verifies:

- Native Windows x86_64 executable
- Godot PCK payload
- Portable ZIP
- Per-user MSI installer
- SHA-256 manifests
- Machine-readable update manifest

## Release manifest

Every final Windows packaging run creates `windows-release.json`.

Schema version: **1**

Example shape:

```json
{
  "schema_version": 1,
  "product": "The Last Settlement",
  "publisher": "DPN Technology",
  "version": "1.0.4-dev",
  "channel": "development",
  "commit": "<git-sha>",
  "platform": "windows-x86_64",
  "save_schema": 14,
  "signing_status": "unsigned",
  "release_tag": null,
  "assets": {
    "portable": {
      "filename": "TheLastSettlement-Windows-x86_64.zip",
      "sha256": "<sha256>",
      "size_bytes": 0,
      "url": null
    },
    "installer": {
      "filename": "TheLastSettlement-Setup-x64.msi",
      "sha256": "<sha256>",
      "size_bytes": 0,
      "url": null
    }
  }
}
```

Tagged builds include release asset URLs in the manifest so a later updater can:

1. Read the latest release metadata.
2. Compare semantic versions.
3. Check save-schema compatibility.
4. Select MSI or portable package.
5. Download the asset.
6. Verify SHA-256 before launch/install.
7. Refuse tampered or incomplete updates.

## Tagging rules

Before creating a release tag:

1. `main` must be green.
2. Windows Build must be green.
3. CI Gate must be green.
4. CodeQL must be green.
5. Supply Chain must be green.
6. Code Quality must be green.
7. Version metadata in `project.godot`, `export_presets.cfg`, and the Windows workflow must agree.
8. The current save schema must be documented.

Recommended tags:

```text
v1.0.4-dev.1
v1.0.4-beta.1
v1.0.4
```

## GitHub Release publishing

On a `v*` tag, the Windows workflow gains a release-publishing job with **job-scoped** `contents: write` permission.

Normal `main` builds remain read-only.

The release job publishes:

- `TheLastSettlement-Windows-x86_64.zip`
- `TheLastSettlement-Setup-x64.msi`
- `SHA256SUMS-WINDOWS.txt`
- `windows-release.json`

If a release already exists for the tag, the workflow updates its assets with `--clobber` rather than creating a duplicate release.

## Signing

The pipeline can Authenticode-sign the EXE and MSI when both repository secrets exist:

- `WINDOWS_SIGN_CERT_BASE64`
- `WINDOWS_SIGN_CERT_PASSWORD`

Until a production DPN Windows signing certificate is configured, manifests correctly report `"signing_status": "unsigned"`.

## Future in-game updater

The game should not silently replace itself.

The planned updater flow is:

**Detect → Explain → Download → Verify → Stage → User approves install → Restart**

No update should execute unless:

- The manifest schema is supported.
- The package SHA-256 matches.
- The target version is newer.
- The save schema is compatible.
- The user explicitly approves the update.

---

**DPN Technology**  
**Develop. Pioneer. Navigate.**
