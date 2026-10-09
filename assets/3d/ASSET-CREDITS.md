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