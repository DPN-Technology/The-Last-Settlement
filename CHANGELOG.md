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
