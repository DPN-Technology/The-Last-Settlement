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
