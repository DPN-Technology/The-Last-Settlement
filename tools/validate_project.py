from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = [
    "project.godot",
    "README.md",
    "src/Main.tscn",
    "src/main.gd",
    "simulation/settlement_simulation.gd",
    "simulation/citizen_factory.gd",
    "simulation/event_director.gd",
    "simulation/social_simulation.gd",
    "simulation/world_simulation.gd",
    "simulation/governance_simulation.gd",
    "simulation/economy_simulation.gd",
    "simulation/faction_simulation.gd",
    "simulation/civilization_simulation.gd",
    "docs/GAME_DESIGN.md",
    "docs/ROADMAP.md",
]

errors = []
for rel in REQUIRED:
    path = ROOT / rel
    if not path.exists():
        errors.append(f"missing required file: {rel}")
    elif path.stat().st_size == 0:
        errors.append(f"empty required file: {rel}")

project = (ROOT / "project.godot").read_text(encoding="utf-8") if (ROOT / "project.godot").exists() else ""
if 'run/main_scene="res://src/Main.tscn"' not in project:
    errors.append("project.godot does not point to src/Main.tscn")

if errors:
    print("The Last Settlement validation FAILED")
    for error in errors:
        print(f" - {error}")
    sys.exit(1)

print("The Last Settlement validation passed.")
