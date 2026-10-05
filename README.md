# THE LAST SETTLEMENT

> **The old world died. Build the next one.**

**The Last Settlement** is an original PC survival/civilization simulation by DPN Technology. The player manages humanity's last known organized settlement from an overhead view, starting with a handful of survivors and growing toward a self-sustaining civilization.

## Current Build: Foundation 0.1

The repository now contains a runnable Godot 4 prototype with:

- Overhead settlement map
- Live population simulation
- Individual survivor identities, traits, skills, needs, health, morale, and loyalty
- Work assignment simulation
- Food, water, power, medicine, materials, and scrap
- Day/time progression
- Resource consumption and production
- Settlement buildings and infrastructure status
- Dynamic incident/event feed
- Population growth pressure and survivor death states
- Command HUD with pause and time-speed controls
- Architecture prepared for deeper relationships, politics, logistics, expeditions, factions, and generational gameplay

## Vision

The game is being designed around one rule:

> **Every major system should affect another major system.**

A failed generator should be capable of stopping water pumps. Lost water should damage sanitation and farming. A shortage should affect morale. Morale should affect work. Poor work should reduce production. A production collapse can become a political or security crisis.

### Long-term simulation pillars

1. Citizens, needs, memories, relationships, families and generations
2. Construction and room-scale building
3. Electrical, water, sewage and heating networks
4. Food, farming, storage and spoilage
5. Workshops, factories and supply chains
6. Medical care, injury, disease and mental health
7. Crime, policing, courts and internal security
8. Government, laws, ideology and elections
9. Exploration, scavenging and expedition teams
10. Dynamic factions, trade, diplomacy and warfare
11. Weather, seasons and disasters
12. Research based on recovered knowledge
13. Multi-settlement logistics and regional expansion
14. Civilization history and emergent storytelling

## Tech

- **Engine:** Godot 4.x
- **Language:** GDScript
- **Target:** Windows/Linux PC
- **Current mode:** 2D overhead prototype
- **Future rendering path:** 2.5D/isometric or full 3D after simulation systems stabilize

## Run

1. Install Godot 4.3+.
2. Clone this repository.
3. Open `project.godot`.
4. Press **F6/F5**.

No external assets are required for the current prototype.

## Controls

- **Space** — Pause/unpause
- **1** — Normal speed
- **2** — Fast speed
- **3** — Very fast speed
- **Mouse wheel** — Zoom
- **Middle mouse drag** — Pan

## Project structure

```text
The-Last-Settlement/
├── project.godot
├── src/
│   ├── Main.tscn
│   └── main.gd
├── simulation/
│   ├── settlement_simulation.gd
│   ├── citizen_factory.gd
│   └── event_director.gd
├── docs/
│   ├── GAME_DESIGN.md
│   └── ROADMAP.md
├── tools/
│   └── validate_project.py
└── .github/workflows/
    └── validate.yml
```

## Development philosophy

The Last Settlement should not become a collection of disconnected minigames. Citizens, infrastructure, economy, politics, health, exploration, weather and combat will share state through the simulation layer so consequences propagate through the colony.

---

**DPN Technology**  
**Develop. Pioneer. Navigate.**
