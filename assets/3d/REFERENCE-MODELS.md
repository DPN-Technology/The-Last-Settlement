# Last Haven licensed photorealistic 3D model pack

This pack downloads only real artist-authored glTF mesh models with 1K PBR
texture maps. It verifies every file and texture dependency against the size
and MD5 published in Poly Haven's public file API. The generated binaries are
not committed; they are installed before Godot import and Windows export.

CC0 source asset pages:
- https://polyhaven.com/a/barrel_03 — Serhii Khromov
- https://polyhaven.com/a/painted_wooden_table — Kirill Sannikov
- https://polyhaven.com/a/painted_wooden_bench — Kirill Sannikov
- https://polyhaven.com/a/covered_car — MP
- https://polyhaven.com/a/concrete_road_barrier_02 — Amal Kumar

Build command: python3 tools/install_reference_models.py
Then: godot --headless --path . --import

Do not change the DPN UI or render a static concept image over gameplay.
