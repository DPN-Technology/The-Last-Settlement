# Development Roadmap

## Milestone 0.1 — Living Settlement Foundation
**Status: core complete**

- [x] Godot project bootstrap
- [x] Overhead world rendering
- [x] Individual survivor records
- [x] Jobs and basic movement
- [x] Resource simulation
- [x] Time controls
- [x] Dynamic event feed
- [x] Building visualization
- [x] Click/select citizens
- [x] Citizen detail inspector
- [x] Click/select buildings
- [x] Save/load
- [ ] Deterministic simulation seed

## Milestone 0.2 — Needs & Work
**Status: advanced / active**

- [x] Job schedules
- [x] Needs-driven action selection
- [x] Hunger/thirst/sleep behavior
- [x] Basic job-specific production
- [x] Pocket inventory data model
- [x] Skill matrix visibility
- [x] Basic morale/stress consequences
- [x] Work-order queue
- [x] Food preparation and physical meals
- [x] Storage inventories
- [x] Item hauling between stockpiles
- [x] Skill-based task efficiency
- [x] Injuries and treatment workflow
- [x] Shift reassignment controls
- [x] Priority controls
- [ ] Forbidden-work controls

## Milestone 0.3 — Construction
**Status: core complete / expanding**

- [x] Build mode
- [x] Walls, floors, doors and rooms
- [x] Blueprint placement
- [x] Construction materials
- [x] Worker pathing around walls
- [x] Demolition and salvage
- [x] Room detection
- [x] Building condition and repair
- [x] Rotatable modular pieces
- [x] Construction save/load persistence
- [ ] Drag-to-build walls/floors
- [ ] Full A* navigation grid
- [ ] Room roles and environmental simulation

## Milestone 0.4 — Utilities
**Status: core complete / expanding**

- [x] Electrical network model
- [x] Power producers, consumers and batteries
- [x] Water network model
- [x] Pumps and purification
- [x] Sewage generation and processing
- [x] Utility overlays
- [x] Failure propagation
- [x] Generator trips and pump failures
- [x] Sanitation consequences
- [x] Utility save/load persistence
- [ ] Manual connection validation
- [ ] Per-building load shedding
- [x] Fuel simulation
- [ ] Water contamination chemistry

## Milestone 0.5 — Relationships
**Status: core complete / expanding**

- [x] Social interactions
- [x] Persistent relationship scores
- [x] Friends/enemies foundation
- [x] Romance / partnerships
- [x] Families
- [x] Memories
- [x] Personality-driven compatibility
- [x] Pregnancy and birth
- [x] Aging and coming of age
- [x] Parent/child links
- [ ] Friendship/rival labels
- [ ] Family tree UI
- [ ] Grief and bereavement system
- [ ] Child education/development
- [ ] Death-memory propagation

## Milestone 0.6 — World & Expeditions
**Status: core complete / expanding**

- [x] Regional map
- [x] Fog of war
- [x] Expedition teams
- [x] Supplies and loadouts
- [x] Ruins
- [x] Radio range
- [x] Encounter simulation
- [x] Expedition injuries and casualties
- [x] Salvage return to settlement stockpiles
- [x] Relay restoration / range expansion
- [x] Expedition save/load persistence
- [ ] Player-selected team composition
- [ ] Custom loadouts
- [ ] Branching encounter decisions
- [ ] Weather/travel modifiers
- [ ] Vehicles / convoy travel
- [ ] Procedural regional generation

## Milestone 0.7 — Society
**Status: core complete / expanding**

- [x] Laws
- [x] Government foundation
- [x] Elections
- [x] Political blocs
- [x] Crime
- [x] Police / guard investigations
- [x] Courts
- [x] Incarceration
- [x] Protest and unrest
- [x] Government legitimacy
- [x] Policy-driven citizen loyalty
- [x] Governance save/load persistence
- [ ] Detailed council voting
- [ ] Corruption / bribery
- [ ] Evidence and warrants
- [ ] Prison building capacity
- [ ] Coup / revolt resolution
- [ ] Protest demands and negotiation

## Milestone 0.8 — Industry
**Status: core complete / expanding**

- [x] Recipes
- [x] Workshop production queue
- [x] Intermediate manufactured goods
- [x] Fuel production foundation
- [x] Vehicle state foundation
- [x] Trade economy
- [x] Scarcity-based market pricing
- [x] Economy save/load persistence
- [x] Multiple factory lines
- [x] Warehousing capacity
- [x] Fuel consumption
- [x] Vehicle repair
- [x] Vehicle manufacturing
- [x] Trade caravans / faction markets
- [x] Trade-pressure market feedback
- [x] Vehicle-assisted hauling
- [x] Production bottleneck visualization
- [x] Player-created production orders
- [x] Regional faction price modifiers
- [x] Caravan route risk
- [x] Regional market save/load persistence
- [ ] Factory-specific recipe assignment
- [ ] Freight contracts
- [ ] Advanced warehouse zoning

## Milestone 0.9 — Factions & Conflict
**Status: core complete / expanding**

- [x] AI faction settlement strategic state
- [x] Diplomacy
- [x] Reputation
- [x] Trade agreements
- [x] Hostile espionage / sabotage
- [x] Raids
- [x] Tactical defense resolution
- [x] Raid warnings / ETA
- [x] Guard and wall defense contribution
- [x] Conflict consequences across resources, buildings, survivors and government
- [x] Friendly / allied support
- [x] Faction save/load persistence
- [ ] Full faction population/economy simulation
- [ ] Offensive player operations
- [ ] Formal war declarations / peace treaties
- [ ] Prisoner exchange
- [ ] Player espionage missions
- [ ] Defensive emplacements / automated defenses

## Milestone 1.0 — Civilization
**Status: advanced / active**

- [x] Multiple player settlements
- [x] Survivor founding teams
- [x] Secondary settlement specialization
- [x] Regional logistics foundation
- [x] Civilization recovery score
- [x] Civilization stability score
- [x] Historical archive
- [x] Critical-event archive integration
- [x] Recovery phase progression
- [x] Civilization Command UI
- [x] Civilization save/load persistence
- [x] Save schema version 14
- [x] Generational simulation foundation
- [x] Detailed secondary settlement construction foundation
- [x] Configurable freight routes
- [x] Civilization-wide policy foundation
- [x] Colony emergency management
- [x] Emergency aid operations
- [x] Colony specialization controls
- [x] Federal governance foundation
- [x] Settlement representatives
- [x] Federal charter / network cohesion / legitimacy
- [x] Survivor migration between Last Haven and colonies
- [ ] Full civilization-wide laws / government
- [x] Endgame civilization recovery objectives
- [x] Backward civilization-state normalization
- [x] Colony module construction
- [x] Civilization recovery megaprojects
- [x] Explicit restoration-state requirements
- [ ] Full save migration tooling
- [ ] Performance profiling
- [ ] Large-population simulation optimization


---

## Packaging & Distribution

**Status: active**

- [x] Windows Desktop export preset
- [x] Automated Windows x86_64 EXE export
- [x] Portable ZIP artifact
- [x] Official engine/template checksum verification
- [x] Godot parse gate before export
- [x] Windows executable format verification
- [x] SHA-256 package manifest
- [x] DPN game icon / Windows resources
- [x] Windows code-signing pipeline hooks
- [ ] Production Windows code-signing certificate
- [x] Per-user MSI installer package
- [x] Release-channel automation
- [x] Machine-readable update manifest
- [x] Tagged GitHub Release publishing
- [x] In-game update notification / installer handoff
- [x] Stable release auto-check
- [x] Update manifest validation
- [x] SHA-256 verified MSI staging
- [x] Explicit user-approved installer handoff
- [ ] Crash reporting / diagnostic bundle
