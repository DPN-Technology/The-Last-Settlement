## 1.0.4-dev — Windows Release & Update Channel

### Added
- Machine-readable Windows release manifest generator
- `windows-release.json` schema version 1
- Portable and MSI SHA-256 metadata
- Portable and MSI size metadata
- Development / prerelease / stable channel metadata
- Save-schema compatibility metadata
- Signing-state metadata
- Release asset URLs for tagged builds
- CI self-test for manifest hash correctness
- Tag-triggered Windows release builds
- Tag-only GitHub Release publishing
- Job-scoped `contents: write` permission for release publication
- Existing release asset replacement with `--clobber`
- Combined Windows release checksum manifest
- Windows release/update-channel documentation
- Application and Windows resource version advanced to 1.0.4-dev / 1.0.4

### Verified
- 1.0.4 portable build passes Godot export and Windows PE verification
- 1.0.4 MSI builds successfully
- Update manifest hashes exactly match final portable ZIP and MSI
- Update manifest asset sizes exactly match final Windows deliverables
- Main-branch builds correctly skip release publication
- Tagged builds are configured to publish the verified assets only after packaging succeeds

### Security
- Normal `main` Windows builds remain read-only
- Release write permission exists only on the tag-only publish job
- GitHub Actions remain pinned to full commit SHAs
- Unsigned builds explicitly report unsigned signing state
- No updater will be allowed to install an asset without hash verification

## Windows Distribution Recovery — MSI + Green Release Gates

### Added
- Branded The Last Settlement Windows application icon
- Per-user WiX MSI installer
- Desktop shortcut
- DPN Technology Start Menu folder
- Start Menu launch and uninstall shortcuts
- Stable MSI component GUIDs
- Optional Authenticode signing hooks for both EXE and MSI
- Separate self-verifying SHA-256 manifests for portable and installer artifacts
- Final portable and installer artifacts built from the same verified Windows payload

### Fixed
- Removed failing Windows PATH probes from installer verification
- Corrected per-user MSI component definitions to satisfy WiX/ICE requirements
- Replaced unstable installer component GUID generation with stable GUIDs
- Corrected distribution manifests so each artifact can verify itself independently

### Verified
- Windows portable build: green
- Windows MSI installer build: green
- Godot parse/load gate: green
- CI Gate: green
- CodeQL: green
- Supply Chain: green
- Code Quality: green

### Signing
- Signing steps are ready but remain skipped until `WINDOWS_SIGN_CERT_BASE64` and `WINDOWS_SIGN_CERT_PASSWORD` are configured.

## Windows Portable Preview — Automated EXE Pipeline

### Added
- Tracked Godot `Windows Desktop` x86_64 export preset
- Native `TheLastSettlement.exe` release export
- External `TheLastSettlement.pck` game data package
- Portable Windows ZIP packaging
- GitHub Actions artifact upload
- Official Godot 4.3 engine checksum verification
- Official Godot 4.3 export-template checksum verification
- Cached Windows export templates for later builds
- Pre-export Godot parse/load verification
- PE32+/Windows executable validation
- SHA-256 package manifests
- Windows portable run instructions inside the ZIP
- Explicit project version `1.0.3-dev`

### Fixed
- Portable SHA-256 manifest now uses extraction-safe relative filenames

### Security
- Build actions remain pinned to full commit SHAs
- Export templates come from the official `godotengine/godot-builds` release
- PCK remains external to reduce antivirus false positives and preserve future code-signing compatibility

## 1.0.3-dev — Founding Teams & Federal Governance

### Added
- Manual four-survivor founding roster
- Founding candidate cycling and roster toggle controls
- Automatic founding selection fallback when no manual roster is configured
- Survivor deployment from Last Haven to established colonies
- Colony housing-capacity limits driven by Housing Block count
- Real settlement representatives selected from resident survivors
- Federal representation charter
- Federal contribution/tithe charter
- Federal rights charter
- Federal legitimacy
- Recovery-network cohesion
- Federal treasury / reserve
- Weekly federal council sessions
- Council accord, standard session and deadlock outcomes
- Low-cohesion federal disputes
- Charter-driven colony morale reactions
- Federal emergency-reserve intervention for colony emergencies
- Federal legitimacy and cohesion contributions to civilization stability
- Federal governance simulation module validation
- Save schema version 14 persistence for federal governance and founding roster

### Fixed
- Last Haven average morale no longer includes survivors assigned to remote colonies
- Local settlement defense and governance calculations now use Last Haven residents only

### Changed
- Colony expansion is now population-constrained by permanent housing capacity
- Civilization stability now includes federal legitimacy and network cohesion instead of relying only on local government metrics

## 1.0.2-dev — Colony Development & Civilization Recovery Projects

### Added
- Permanent secondary-settlement module construction
- Housing Block, Farm Complex, Clinic Module, Workshop Bay, Defense Perimeter, Freight Depot and Radio Tower projects
- Colony-local construction resource costs
- Colony construction speed driven by assigned survivors' construction / engineering skill
- Colony module telemetry in Civilization Command
- Farm-module food production
- Clinic-module medicine production and disease containment chance
- Workshop-module materials and machine-parts production
- Defense-module security growth
- Freight Depot regional logistics throughput bonuses
- Radio Tower morale/security benefits
- Regional Power Grid recovery project
- Clean Water Network recovery project
- Medical Corridor recovery project
- Communications Backbone recovery project
- Incremental recovery-project resource contributions from real Last Haven stockpiles
- Permanent recovery-project effects on infrastructure, water efficiency, medicine resilience and logistics
- Recovery-project completion contribution to civilization recovery score
- Explicit CIVILIZATION RESTORED endgame state
- Save schema version 13 persistence for colony projects and civilization recovery projects
- Civilization Command controls for colony module queues and recovery-project funding

### Changed
- Civilization restoration now requires all four regional recovery megaprojects, at least three settlements, 90+ recovery score and 75+ civilization stability
- Colony development now depends on delivered local resources rather than abstract infrastructure growth alone

## 1.0.1-dev — Civilization Operations & Engine-Verified CI

### Added
- Colony status states: Stable, Recovering, Degraded and Emergency
- Colony emergency simulation
- Food shortage, water crisis, infrastructure failure, security incident, storm damage, disease cluster and equipment failure events
- Manual emergency aid shipments from Last Haven
- Player-controlled colony specialization changes
- Civilization autonomy policy
- Civilization freight policy
- Civilization security policy
- Configurable freight-route activation
- Freight-route priority levels
- Freight-route cargo focus: Balanced, Survival and Industrial
- Policy-driven colony production, freight throughput and security growth
- Civilization emergency log
- Backward normalization for older civilization save data
- Save schema version 12
- Checksum-verified official Godot 4.3 installation in CI
- Headless Godot project parse/load gate

### Fixed
- Invalid three-argument `minf()` logistics call detected by the new engine gate
- Godot 4.3 Variant type-inference parse errors in civilization, governance and UI code
- Invisible offsite colonists can no longer be selected at their old Last Haven positions
- Founding history now records the original expedition site name correctly
- Colony emergency events no longer create duplicate archive entries
- Fortress Network policy now provides the intended stronger security-growth effect

### Changed
- A green CI Gate now requires Godot itself to parse/load the project successfully
- Civilization Command now exposes colony emergencies, policy controls and configurable freight operations

## 1.0.0-dev — Civilization Network Foundation

### Added
- Civilization-wide simulation layer
- Player-founded secondary settlements
- Founding requirements tied to real materials, meals, water and machine parts
- Live survivor colonist assignment
- Survivor home-settlement tracking
- Secondary-settlement specializations
- Independent colony resource stores
- Colony morale, infrastructure and security
- Automatic regional logistics routes
- Daily bidirectional surplus transfer between recovery-network settlements using real stockpiles
- Civilization recovery score
- Civilization stability score
- Recovery phase progression
- Civilization milestones
- Civilization history archive
- Automatic archival of critical incidents
- Civilization Command UI
- Settlement network telemetry
- Founding controls on secured world-map sites
- Player-settlement world-map state
- Civilization persistence in save schema version 11
- Civilization simulation module validation in CI

### Changed
- Regional logistics now deduct and deliver real resources instead of moving synced ledger snapshots
- Recovery routes now move surplus in both directions between Last Haven and colonies
- Colonists assigned to secondary settlements no longer render, move, socialize or consume local occupancy at Last Haven
- Local random incidents now target Last Haven residents rather than colonists assigned elsewhere
- README upgraded for build 1.0.0-dev with live security badges, system-status matrix and civilization documentation

## 0.9.0-dev — Factions, Diplomacy & Conflict

### Added
- Cedar Union, Riverbend Collective, Iron Pact and Lantern Medics strategic faction states
- External faction settlements on the regional map
- Reputation and disposition model
- Faction strength, wealth, aggression and intelligence
- Faction Command UI
- Aid shipments
- Trade agreements
- Trade-agreement caravan price discounts
- Truce offers
- Hostile espionage and sabotage
- Raid scheduling and advance warnings
- Raid ETA and attack-strength tracking
- Settlement defense calculation from guards, security skill, walls, command condition and morale
- Raid victory / breach outcomes
- Supply theft and building damage after breaches
- Defender injuries
- Government-unrest consequences from failed defense
- Friendly/allied support events
- Conflict history log
- Faction persistence in save schema version 10
- Faction module validation in CI

### Fixed
- Radio relay range now expands only after the relay is actually restored
- Restored relay range now remains active instead of disappearing after salvage
- Inhabited trade/faction settlements cannot be incorrectly depleted as salvage expedition sites

## 0.8.2-dev — Regional Trade & Production Control

### Added
- Cedar Junction and Riverbend Enclave trade hubs
- Cedar Union and Riverbend Collective faction markets
- Faction-specific stock and price modifiers
- Market reputation and reputation discounts
- Inbound / trading / returning caravan lifecycle
- Route-danger caravan-loss simulation
- 36-hour caravan trading windows
- Regional buy and sell transactions
- Caravan credits and inventory
- World-map caravan visualization
- Trade-hub faction intelligence
- Player market-source switching
- Player-created production orders
- Utility Truck manufacturing recipe
- Dynamically created additional utility trucks
- Regional market / caravan persistence in save schema version 9

### Changed
- Friendly trade hubs can no longer be incorrectly scavenged as expedition ruins
- Industry Command now prices goods per selected local or faction market
- Milestone 0.8 now covers its core production, logistics, vehicle and regional trade loop

## 0.8.1-dev — Industrial Logistics

### Added
- Multiple concurrent industrial lines based on workshop count
- Warehouse capacity calculated from storage modules
- Warehouse utilization and overflow pressure
- Storage-overflow material loss
- Production efficiency penalties from warehouse congestion
- Tool-kit production efficiency bonus
- Generator fuel consumption
- Vehicle fuel consumption
- Vehicle-assisted hauling multiplier
- Automatic vehicle refueling from industrial fuel stock
- Vehicle repair-kit recipe
- Player vehicle repair action
- Production bottleneck reporting
- Trade-pressure feedback into future market pricing
- Industrial logistics persistence in save schema version 8
- Industry Command telemetry for warehousing, bottlenecks, fuel burn and vehicle repair

### Changed
- Generators now depend on industrial fuel availability
- Hauling efficiency can improve when an operational fueled truck is available
- Market prices react to both scarcity and recent buying/selling pressure

## 0.8.0-dev — Industry & Economy

### Added
- Manufacturing recipe system
- Workshop production queue
- Machine-parts production
- Component production
- Tool-kit production
- Fuel blending
- Skill-weighted industrial work
- Industrial fuel, parts, tools and components stock
- Settlement credits
- Scarcity-driven market pricing
- Buying and selling
- Trade log
- Vehicle condition/fuel foundation
- Industry & Economy command panel
- Economy persistence in save schema version 7
- Economy module validation in CI

### Changed
- Workshop output now includes intermediate manufactured goods
- Scarcity can now alter market value rather than only affecting survival metrics

## 0.7.0-dev — Government, Law & Society

### Added
- Interim settlement leader and civic council
- Recurring election cycle
- Government legitimacy
- Unrest simulation
- Crime-pressure model
- Political factions and citizen faction membership
- Liberty, order and welfare political values
- Player-controlled rationing, security, labor, justice and speech laws
- Citizen loyalty reactions to policy
- Theft, assault and sabotage incidents
- Guard-driven investigations
- Court-case progression
- Restorative, balanced and punitive justice outcomes
- Incarceration and sentence completion
- Protests and governance-crisis escalation
- Civic Command government UI
- Open-case visibility
- Faction support display
- Governance persistence in save schema version 6
- Governance module validation in CI

### Changed
- Scarcity, citizen stress and guard staffing now influence internal crime
- Law choices directly affect citizen loyalty and public order
- High unrest can interrupt citizens with protest behavior

## 0.6.0-dev — Regional World & Expeditions

### Added
- Regional operations map
- Fog-of-war discovery model
- Radio-range exploration
- Discoverable ruins, relay sites and unknown signals
- Expedition team formation
- Expedition food/water/medical provisioning
- Outbound travel, search and return phases
- Radio-contact state
- Location danger and security-based risk reduction
- Expedition injuries and casualties
- Salvage cargo
- Resource recovery into live settlement stockpiles
- Depleted world locations
- Relay restoration that expands radio range
- Active expedition tracking UI
- Save/load persistence for world locations and expeditions
- World simulation validation in CI

### Changed
- Save schema advanced to version 5
- Expedition members no longer participate in home settlement social/occupancy simulation while away
- Exploration now has direct resource and survivor consequences

## 0.5.0-dev — Relationships, Families & Generations

### Added
- Persistent pairwise relationship scores
- Trait-based compatibility
- Positive and negative social interactions
- Social-need simulation
- Persistent survivor memories
- Partnership formation and separation
- Family names and partner links
- Biological sex state for family simulation
- Pregnancy and birth
- Parent/child relationship links
- Child citizens
- Aging and birthday progression
- Coming-of-age workforce assignment
- Social/family visibility in the survivor inspector
- Social simulation module validation in CI

### Changed
- Save schema advanced to version 4
- Children prioritize survival, rest and play/learning rather than adult work
- Social outcomes now directly influence morale and stress

## 0.4.0-dev — Utilities & Infrastructure

### Added
- Dynamic settlement power generation and demand
- Battery reserve simulation
- Generator condition affecting available output
- Water extraction and raw-water reserves
- Purification into clean settlement water
- Sewage generation and treatment
- Sanitation rating
- Generator-trip failures
- Water-pump failures
- Engineer-driven restoration events
- Utility consequences for citizen stress, morale, thirst and health
- Buildable generators, batteries, power poles, pumps, purifiers, water tanks, pipes and sewage processors
- Power / water / sewage overlays
- Utility infrastructure status in the building inspector
- Utility telemetry in the command HUD
- Utility-state persistence in save schema version 3

### Changed
- Power is now derived from production, demand and battery support rather than a passive percentage
- Water availability now depends on extraction, power and purification
- Population generates sewage that must be processed
- Infrastructure failure can cascade into sanitation and survivor-health pressure

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
