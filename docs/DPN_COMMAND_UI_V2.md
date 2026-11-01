# DPN // The Last Settlement — Command UI and Gameplay Controls
**Status:** implementation contract for PR #6, live Windows playtests required. **Scope:** modern DPN visual language *and actual clickable simulation actions*; no invented back-end gameplay.

## Design system
- Dark iron #090e13 / charcoal panels #121a20, DPN signal red #da474b and a restrained amber warning; teal reserved for safe resources. Only small highlights glow. All labels use plain English; no clearance or corporate operational jargon in player controls.
- Player's 3D world always owns center stage. Top metrics remain <=82px and navigation <=58px at 1280×720. Pointer targets and rendering share named Rect2 functions.
- Sidebars own focus and intercept clicks within their background so clicking text cannot accidentally place structures in the world. Hover summaries explain consequence, price and why an action is disabled; state changes come from sim APIs.
- Theming: beveled graphite card borders, thin red rail, segmented indicator lines, subtle corner nodes, command numbers/hotkeys. No unreadable 1s-and-0s foreground clutter. UI typography >=10 logical pixels at 1280p; no broken tab overflow.

## Build: working settlement construction (B)
- Six category chips: All, Homes, Power, Water, Services, Basics; only display types actually defined in `get_build_catalog`.
- Catalog must include housing, storage, farm, clinic, workshop, basic pieces and utility nodes, all placeable and buildable by the existing blueprint loop.
- Every item must show available materials vs cost and a purpose in plain English. Selected item details show footprint and jobs/capacity when applicable; visible affordance to rotate supported pieces, click world to place and Esc to cancel.
- Clicking a category filters the *actual* catalog, not text alone. Q/E/wheel cycles the currently filtered items. Picking an option selects its actual catalog index. UI components must intercept world clicks.
- `can_place_blueprint`, material costs, work queues and refund/cancel must continue to be enforced by existing simulation. Not allowed: free/ghost buildings or fake queue completion.

## Region: functional salvaging and traversal (M)
- Plot real discovered sites and active caravans/expeditions; show unknown sites as unidentified signals. Radio range centered on home. Dynamic scale cannot overlap the right intel panel at 960-1920px.
- Locations selectable by **map markers and textual site list** with matching transformations; selection preserved across redraws.
- Details: visible site, type, danger, estimated distance, depleted/available, supplies and dispatch blockers; do not promise specific loot amounts when not known.
- Dispatch calls `create_expedition` only if site is discovered, valid, not depleted, and not inhabited. Show success/reason by reading actual sim events. No fake trips.

## Govern: actual policy actions (V)
- Show leadership, legitimacy, unrest, safety, and the live law register with current value.
- Clicking a law row changes the selection; clicking a clearly labeled **Change law** control runs existing `cycle_law` and citizen reactions. Communicate law consequences, not hypothetical powers.
- Button actions respond to mouse; no need to memorize arrows/Enter. Use clear confirmation feedback including the resulting law value.

## Industry: craft + markets that operate (K)
- Show available credits, stock, capacity, efficiency and queue using data directly from `EconomySimulation`.
- Click a market row to select a tradable item. Choose market using a button, buy/sell through existing verified `trade_with_source`, show success/failure reason. Don't suggest sales will occur if market or settlement lacks stock.
- Browse actual recipe keys, display required inputs + outputs from `recipes`, queue 1 batch through existing `queue_recipe` and show the queued count. Never fake created items.
- Use a two-row context action strip if needed, rather than hiding production controls behind keyboard-only keys.

## Supply Intelligence: measured resource flow (FOOD / WATER / POWER / MEALS chips)
- `ResourceLedger` (`simulation/resource_ledger.gd`) records stock changes in hourly buckets over a rolling ~24 game-hour window. Each `SettlementSimulation.update()` phase (Weather, Survivor activity, Utilities, Community, Expeditions, Governance, Industry & trade, Factions, Federal network, Colony logistics, Incidents) is measured by before/after snapshots of `supply_totals()`, so recorded net flow equals the real stock change. Survivor work is itemised with `note()` (meals, drinking, farm harvest, salvage, scavenging, meal preparation, cook/haul orders, truck refuelling, treatment). Workshop inputs/outputs and successful local/caravan trades retain separate gains and losses even when they cancel within one tick or while paused. Other subsystem contributions are net changes per phase; other player actions between ticks appear as **Command orders**.
- Rates are **per game day** and only appear after 0.5 measured game hours. Run-out time is `stock / measured net decline`; empty stock reports **EMPTY** even with zero recent consumption, including after depletion leaves the rolling window. Nothing is projected from design constants. The HUD chips show the measured net trend (POWER shows battery or generator-fuel run-out). Severity escalates to warning under 24 game hours and critical under 6.
- Clicking FOOD, WATER, POWER or MEALS opens the analysis side panel. Previously FOOD/WATER/POWER opened construction and MEALS opened Overview; the identity header still opens Overview. The panel has nine resource tabs (mouse or arrow keys), stock / produced / consumed / run-out cards, ranked *Produced by* and *Consumed by* sources, and actions that route to real systems: build crop field, purifier, water pump, generator, battery bank; Workforce; Industry & Trade; Region salvage.
- The panel shares `SettlementUILayout.supply_*` rectangles for drawing and hit testing. X, Esc, an outside click or re-clicking the same chip closes it. The Overview **SUPPLY RESERVES** and **SUPPLY OUTLOOK** rows open it; SUPPLY OUTLOOK replaces the former static "ENERGY RESPONSE" instruction row.
- The ledger is transient by design: it is not written to saves (schema stays v14) and restarts measuring after load. Viewing analysis never mutates stock.

## Global navigation / other screens
- Navigation icons + text + hotkeys (no unicode glyph dependencies), active state with strong red/teal contrast, hover helper and notification mark for actionable shortages. The same DPN frame extends to survivors, buildings, factions, civilization, save/load, field guide.
- Shared right-hand panels use consistent safe bounds above the bottom dock. Esc closes the active overlay. F8 screenshot. Keyboard shortcuts and mouse actions must dispatch identically.
- Every screen must have obvious next action, plus failure feedback. Optional future: tree-based inventories, region minimap, facility interior cutaways, tooltips with keyboard focus.

## CI and acceptance
1. Headless Godot parser + smoke checks on every commit; Windows export must include current head.
2. Real inputs must exercise build category select + blueprint placement, region site click + dispatch, governance law mutation, industry recipe queue and market selection. Verify invalid actions are blocked.
3. Test 960×720, 1280×720 and 1366×768 panel bounds; assert labels/action areas do not clash.
4. Human PC review using **F8** screenshots of world and each of Build, Region, Govern, Industry; prove visible feedback, not only a passing CI.
5. Do not merge PR #6 until the user accepts the real packaged Windows gameplay. Navigation/collision/interiors remain independently tracked in issue #8.
