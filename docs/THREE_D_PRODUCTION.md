# The Last Settlement — 3D Production Art Contract

**Status:** True 3D gameplay architecture is integrated into the Godot 4.3 development branch. The bundled geometry is a **procedural test stand-in**. It is not photorealistic art and must not be described or marketed as such.

## Graphics direction

A believable post-collapse settlement: weathered concrete, corroded sheet steel, faded painted warnings, dirty glass, uneven terrain, patched roads, machines, overgrown fields, derelict vehicles, and survivors in worn clothing. Camera: freely pan/zoomable **3D oblique perspective** (never fake 2D render cards). DPN identity belongs primarily in HUD, controls and emergency command hardware; the environment should feel like a living world.

## Implemented rendering backbone

- `src/settlement_world_3d.gd` runs a real `Node3D` world in an offscreen `SubViewport`, viewed through `Camera3D`.
- Physical 3D ground, roads, buildings, farm rows, survivors, junk vehicles, vegetation, sunlight, sky, fog and shadow-casting geometry.
- Existing settlement/citizen positions are mapped to 3D meters without modifying save data.
- Camera projection supports selecting the actual world at mouse coordinates; mouse buttons retain original construction interaction.
- Structure meshes rebuild when layout/condition changes; survivor transforms sync continuously.
- Existing game simulation and UI stay operational. The old `SettlementVisuals` 2D path is no longer used to render the world.
- Windows 3D preview is an Actions artifact. No new installer or stable release should be pushed before in-game approval.

## First actual source-licensed art integration (development branch)

- The Windows export and Godot CI import a **real CC0 rigged human**
  into `assets/3d/characters/survivor.glb` from an immutable upstream Git commit.
  Animation playback selects compatible walk and idle clips where present.
- Photo-based Poly Haven **1K diffuse + normal** maps replace the procedural
  shader on the core building concrete, walls, roof, steel, and gravel.
- All seven third-party items use locked Git blob or SHA-256 fingerprints.
  CI fails if a downloaded asset is modified, malformed or unavailable.
- Import takes place at **build time**; players do not download art at runtime.
- Licensing, original URLs, and checksums are recorded in
  `assets/3d/ASSET-CREDITS.md` and the installation scripts under `tools/`.
- Current building bodies remain modular **geometry placeholders** despite
  the genuine photographic materials; the human is a rigged base model, not
  a finished textured and costumed survival character.

Remaining major art work: licensed realistic wasteland outfits, authored
building models with true entry/exit geometry, modular ruined architecture,
rigged activity animations, rain/smoke/weather, and actual GPU performance
profiling from a running Windows build.
## Art pipeline for the next milestone

The renderer looks for external `PackedScene` models in these locations and uses them instead of its built-in 3D geometry **when available**:

```text
assets/3d/
  structures/
    command.glb
    housing.glb
    medical.glb
    industry.glb
    farm.glb
    power.glb
    generator.glb
    water.glb
    water_pump.glb
    purifier.glb
    sewage.glb
    storage.glb
    battery.glb
    wall.glb
    floor.glb
    door.glb
  characters/
    survivor.glb
```

**Important:** These are asset paths, not claims that the finished models already exist. Export models as glTF 2.0 binary (`.glb`), use meters for units, place the pivot at ground level in the center, orient forward toward -Z, and avoid baked lighting in albedo. Build UV-unwrapped meshes with physically based albedo, normal, roughness, metallic and ambient occlusion maps. Supply at least LOD0/LOD1/LOD2 where sensible, collision proxies, and animated rigs for people.

The runtime currently assumes imported meshes already match each building blueprint's expected scale. Preserve the blueprint footprint when authoring and keep roofs within the assigned plot unless intentional. Lighting/exposure and occlusion need adjustment once photographed surfaces are imported.

### Legitimate free asset sources for evaluation

- [Poly Haven](https://polyhaven.com/) — CC0 photoscanned PBR materials, 3D props and HDRIs.
- [ambientCG](https://ambientcg.com/) — CC0 photo-based PBR surface maps (gravel, soil, asphalt, rust and concrete).
- [Quaternius](https://quaternius.com/) — CC0 model packs useful for kitbashing, though generally stylized rather than photorealistic.

**Do not blindly hotlink assets or download them during user play.** Select exact assets, review their licenses and files, optimize in Blender, import into Godot, commit the selected reproducible source or maintain a checksum-pinned asset package, and record the source/license in `assets/3d/ASSET-CREDITS.md`. Never use paid or unlicensed third-party content.

## Required quality gates before calling this 'realistic'

- **Actual Windows gameplay captures** show a 3D settlement, 3D camera movement and visibly animated settlers.
- Structures identifiable from geometry and materials, without relying on text labels.
- Proper normal/roughness maps, consistent texture scale, contact shadows and variation; realistic character assets and animations.
- Coherent day/night, weather, particles, construction effects, equipment motion, audio, and hostile-event feedback.
- Gameplay interactions (build, select, repair, move, dispatch, save/load) are exercised on **the packaged Windows executable**.
- Performance profiling at 1080p; responsive camera and predictable frame pacing without expensive mesh rebuilds each frame.
- No save-schema regression and no red CI/security checks.

**Do not merge based on passing static tests alone.** CI checks parsing, boot, and exports; the player must visually accept the Windows build.

DPN TECHNOLOGY // DEVELOP. PIONEER. NAVIGATE.
