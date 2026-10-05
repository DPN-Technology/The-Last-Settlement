## 0.3.0-dev — Construction & Reclamation

### Added
- Player build mode
- Grid-snapped blueprint placement
- Build catalog for walls, floors, doors, shelter modules and storage modules
- Wall/door rotation
- Construction material costs
- Builder reservation and assignment to active blueprints
- Skill-based construction progress
- Blueprint progress rendering
- Completed structures entering the live settlement
- Demolition and salvage
- Repair work orders targeting selected buildings
- Basic enclosed-room detection
- Wall-aware survivor movement
- Construction telemetry in the command HUD
- Construction/blueprint persistence in save files

### Changed
- Save schema advanced to version 2
- Builders prioritize active blueprints before ordinary builder work orders
- Modular construction pieces may touch adjacent pieces without false overlap rejection

# Changelog

All notable development changes to **The Last Settlement** are tracked here.

## 0.2.1-dev — Settlement Operations Layer

### Added
- Physical stockpiles by settlement zone
- Hauling between farm, industry and command stock
- Work-order queue with priorities and completion effects
- Skill-weighted work output
- Day/night shift controls
- Per-survivor job priorities
- Injury state and treatment progression
- Medical supply consumption
- Meals separated from raw food
- JSON save/load support
- Incident integration with real stockpiles
- New command hotkeys for save/load, shifts and priorities

### Changed
- Production is now routed through stockpiles instead of only aggregate counters
- Needs consume resources from real settlement storage
- Random incidents affect stored supplies directly
- Citizen job logic checks active shift, needs, injury status and queued work before default work

## 0.2.0-dev — Living Survivor Systems

### Added
- Clickable survivor selection
- Full survivor command/inspection panel
- Building inspection panel
- Needs-driven decision making
- Day/night work schedule behavior
- Hunger, thirst, fatigue, stress and health consequences
- Eating, drinking and sleeping behaviors
- Job-specific work states
- Pocket inventory foundation
- Building capacities
- Work-output simulation for farming, engineering, construction, medicine and scavenging
- DPN reconstruction-command visual treatment in the in-game HUD

### Changed
- Settlement simulation now uses citizen actions rather than passive resource ticks
- Survivor movement now targets buildings according to current action
- Event panel yields to contextual inspector panels when a citizen or building is selected
- Visual language shifted toward a dark emergency-command / rust-red post-collapse identity

## 0.1.0-dev — Foundation
- Initial Godot 4 project
- Settlement rendering
- Basic survivors and jobs
- Resource simulation
- Event feed
- Time controls
