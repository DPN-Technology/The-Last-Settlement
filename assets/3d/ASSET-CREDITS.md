# Third-party 3D asset licenses — development playtest

The Windows preview downloads these public-domain assets **at build time**,
verifies immutable hashes, imports them into Godot, and packages them in the
offline Windows game. Source checkouts may run `python3 tools/install_cc0_assets.py`
before importing or exporting the project. The actual game does not fetch assets.

## Survivor base model (rigged GLB)

- Origin: [UMRAM-Bilkent/supine-human-model](https://github.com/UMRAM-Bilkent/supine-human-model), `assets/human.glb`, a rigged Quaternius character.
- Original creator: Quaternius. Distribution/preparation: UMRAM-Bilkent.
- License: [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/), confirmed by upstream LICENSE.
- Pinned source commit: `728f23ab5eb9d6cb2c8fb39acb3440bd81db0d3e`
- Pinned source Git blob SHA1: `de56d83cdcd5d741955fe6acd983a61e50e367c3`
- Runtime destination: `assets/3d/characters/survivor.glb`
- **Quality note:** this is a rigged base human, not finished photorealistic
  character art. It still needs wasteland clothing, appropriate motion, and polish.

Never use unlicensed game rips, an unpinned asset URL, or paid art without permission.
## Photo-based PBR surfaces — Poly Haven

- CC0 surface sets: [Rough Concrete](https://polyhaven.com/a/rough_concrete), [Rusty Metal Sheet](https://polyhaven.com/a/rusty_metal_sheet), and [Gravel Ground 01](https://polyhaven.com/a/gravel_ground_01).
- Origin: Poly Haven official CDN; 1K diffuse and OpenGL normal maps.
- License: Poly Haven CC0 public-domain textures, suitable for commercial projects.
- Build location: `assets/3d/pbr/`.
- Source files are fetched only by the CI/export process and packaged for offline use.
- License and source records retained here; texture checksums are recorded in the installer once its initial verified fetch finishes.

These are photographic material scans, not authored 3D facility meshes. They
improve material fidelity but cannot alone make the current modular boxes look
like finished modern-game structures.