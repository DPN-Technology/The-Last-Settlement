# The Last Settlement — Game Design Foundation

## Player fantasy

The player is not simply building a base. The player is responsible for whether a new human civilization survives.

The settlement begins small enough that every death matters. Over time it becomes large enough that policy, infrastructure, logistics and history matter more than individual orders.

## Core loop

**Observe → Prioritize → Build → Assign → Survive → Recover → Expand → Govern**

Every loop produces new consequences that feed back into the next.

## Simulation layers

### 1. Human layer
Each citizen will eventually track:
- Identity, age and family
- Physical health and injuries
- Hunger, thirst, fatigue and temperature
- Stress, trauma and mental health
- Skills, aptitudes and profession
- Values, loyalty and political alignment
- Memories and relationships
- Personal goals and fears

### 2. Infrastructure layer
- Electrical generation and distribution
- Water extraction, purification and piping
- Sewage and waste
- Heating/cooling
- Fuel
- Communications
- Roads and logistics

Infrastructure uses a graph-based architecture so failures can cascade.

### 3. Production layer
Raw resources move through production chains rather than appearing from abstract buildings.

Example:

```text
RUINED VEHICLE
   ↓ salvage
SCRAP METAL
   ↓ processing
STEEL STOCK
   ↓ machine shop
MACHINE PARTS
   ↓ assembly
WATER PUMP
```

### 4. Society layer
- Laws
- Government
- Elections or appointments
- Factions
- Crime
- Justice
- Education
- Culture
- Religion/belief systems as world simulation
- Social class and access to resources

### 5. World layer
The world continues to simulate outside the player's settlement:
- Factions expand and collapse
- Trade routes form
- Conflicts occur
- Weather and disasters move through regions
- Ruins are scavenged by others
- Settlements can be founded by former residents

## Emergent history

The simulation will maintain a chronological settlement archive. Important events are promoted into named historical events.

Example:

```text
YEAR 0 — The Founding
YEAR 2 — The Long Winter
YEAR 5 — The North Gate Fire
YEAR 8 — Founding of the Assembly
YEAR 12 — The River War
```

Citizens can remember historic events they personally experienced.

## Scale progression

### Phase I — Camp
5–30 citizens. Personal survival and direct control.

### Phase II — Settlement
30–150 citizens. Infrastructure and specialization.

### Phase III — Town
150–500 citizens. Government, logistics and social pressure.

### Phase IV — City
500–3,000 citizens. Industry, districts, transit and institutions.

### Phase V — Civilization
Multiple settlements and regional governance.

## Design rule

No major system should exist in isolation.

A drought is not just "-20 food." It lowers reservoirs, weakens farms, increases food prices, causes rationing, raises stress, changes public opinion, increases theft, overwhelms security, and may alter an election.
