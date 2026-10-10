# New playtest: Geographic Atlas, Settlement Minimap, Real Operations Dashboard

This PR build responds to the latest player screenshots showing a plain circular radar, no settlement minimap, large unused menu regions, and long red/white diagonal streaks across the monitor.

## Two actual map systems

**Region (M):** The old flat radar backdrop is replaced with a cached fictional topographic atlas generated using Godot FastNoiseLite. The terrain layer includes rolling relief, a winding river, scrubland, wooded lowlands and faded pre-collapse road traces. This is **in-universe procedural cartography**, not a real-world/satellite dataset, and the roads are illustrative rather than playable pathfinding. Every actual site marker is positioned directly from `WorldSimulation.locations`; undiscovered locations no longer leak through as gray dots. The player's radio coverage is a thin ring, not a giant red opaque map disk. Clicking a real mapped site still selects it for the existing team/strategy/provision/recall controls. Missions display live dashed route traces. The map is cached until radio coverage changes to avoid FPS spikes per draw frame.

**Last Haven plan map (F5):** The 3D scene now has a small top-down **facility minimap** in the lower left, showing the actual positions and relative sizes of buildings, resident workers, construction plans and the current camera target. Click any point in the minimap to shift the real 3D camera there. Press F5 to hide/show it. It automatically stays out of the way while full-size menus, inspectors and Build mode are open.

## Deeper real menu data

**Industry** now summarizes actual warehouse occupancy, line efficiency, running vs pending batch counts and real active-order progress in individual row cards (when viewport height permits). Full queue control, cancel, reorder, recipe selection and pause are still inside Workshop Control.

**Govern** now includes council representation for the four genuine resident civic affiliations with member counts and percentages based on the simulation's real support figures. It only uses the additional space when the panel is tall enough to avoid covering the existing law actions.

## Red diagonal streak diagnosis

The user photos show diagonal red/white lines crossing the 3D map, opaque UI panels and Windows window furniture. A search of this game's UI and world renderers found no full-screen diagonal-stripe rendering command. The effects may come from the monitor, camera/moiré, GPU display output, or some unlocated rendering issue. We do **not** claim they were fixed in code without a direct frame capture.

1. Launch this **new** Windows playtest and press **F8**. The game will open its `playtest-screenshots` folder; attach that original PNG. Do not photograph the display for this specific test.
2. If the streaks are visible in the PNG, they are present in the captured graphics pipeline and require further game/GPU diagnosis.
3. If they are missing from the PNG but still on the screen or phone photo, compare with Windows desktop and another application to distinguish camera interference from monitor/cable/panel problems.
4. Report whether the streaks appear on the Windows taskbar with the game minimized. The taskbar cannot be painted by Godot's own CanvasItem commands.

**Acceptance:** in Region, verify real geographical texture, legible terrain and correct selected-site/expedition markers; in 3D view, click the minimap to focus different buildings and test F5; in Industry, look for warehouse/production live cards; in Govern, see live council representation. The PR remains unmerged pending visual approval and verified final-head CI.

---

# October 9 player screenshot feedback — UI readability & density pass

Eight photographed Windows playtest screenshots identified the specific problems this patch addresses: HUD labels small at 1280×720, cramped bottom dock / speed row, miniature build/region list entries, wide nearly-empty Nation and Factions panels, and weak hierarchy between commands and live values.

**Implemented fixes:** the dock remains shallow (62 logical pixels) while the nine navigation buttons gain larger click targets and readable labels; speed controls remain distinct above navigation. Top resources emphasize larger numbers instead of tiny values. Build and Region lists have taller rows, stronger type and more legible prices/risks. Nation Overview adds three actual telemetry cards (**discovered sites**, **cleared colony sites**, **active field teams**) and, if vertical space permits, a live event feed. Factions without radio contacts now shows live site/team/relay cards when room permits. These are drawn only when they fit above the action footer. Decorative binary stays inside the dock instead of over the playing field.

**NEW: F7 UI SCALE.** Press F7 to cycle interface sizes 100%, 115%, and 130%. The game refuses a setting that would leave fewer than 960×600 *logical* pixels and resets to 100% in a too-small window. This uses Godot's window content scaling, so drawn hit targets and mouse interaction should remain aligned. The setting is currently for the current session only, not written to the save file.

**Player test:** use F7 at your desired Windows resolution and compare overall legibility, then open Build, Region, Nation, Factions, Industry, Governance, Workforce and an inspected survivor. Specifically confirm the four speed controls don't overlap the nine dock tabs; Nation and Factions never cover their bottom action buttons; text remains inside cards; and the simulation remains responsive to clicks. Use **F8** to capture direct game screenshots rather than photographing the monitor. Long diagonal light streaks in the supplied photos were not found in the DPN UI renderer and may be a camera/display moiré artifact; a direct F8 screenshot will confirm that rather than prompting a speculative 3D graphics fix.

This is a targeted improvement, not a claimed complete high-end commercial UI redesign. Typography and responsive compositing still require real Windows visual acceptance before merging PR #6.

---

# Dust Fronts & Settlement Emergency Orders — Windows playtest

This developer preview adds a dynamic **dust-storm weather front** to the actual Godot simulation. A first front can begin after approximately two simulation days; subsequent fronts recur with a varied interval, duration and severity. The game shows the active weather in the thin HUD data rail, surfaces an urgent **STORM: TAKE COVER** warning, and adds a weather briefing with estimated time remaining in the Overview screen. It uses no real-world forecast service.

**Gameplay effects** are not decorative: a dust front degrades generator efficiency and water purification, increases the fatigue and stress of survivors assigned to outdoor tasks, and may cause a small health penalty under severe exposure. The severity determines the degree of these effects. Click the upper-right **STORM: TAKE COVER** alert to issue **Shelter In Place**. Exposed field workers (Farmers, Builders, Scavengers, Haulers and Guards) leave outside duties for housing, so crop gathering, salvage hauling and outside construction slow or stop. Click **SHELTER ACTIVE** again to release the emergency order. Engineering, medical work and cooking continue under normal shift/health rules; the workshop now also refuses to use any Builder explicitly taking cover. A shelter order does not magically repair a generator or water pump.

The 3D world now contains a GPU-instanced airborne-dust field, warmer obscured skyline, longer-distance dust haze and reduced storm daylight. The visual volume follows the playable camera rather than instantiating hundreds of individual mesh nodes. The weather front and order persist through a compatible v14 save; loading older saves defaults safely to clear weather.

**Manual Windows acceptance:** accelerate simulation to 12× to reach an actual dust front; verify HUD warning, dust particles and changed horizon and power/water readings. Click the alert to shelter outdoor crews; inspect real survivor actions and confirm outdoor work output halts while indoor shifts continue. Resume field work and observe that exposure, production and the alert react accordingly. Save in a storm, reload, and confirm the same severity and policy remain. Let the front pass and confirm weather visuals clear, shelter releases automatically, and normal production returns. Test with the camera orbiting at 960×720 and 1920×1080; use F8 to capture unaltered screenshots.

**Current limits:** This implements storm lighting, airborne grit and concrete gameplay decisions, not cinematic volumetric VFX, realistic wind audio, rain/snow, handcrafted weather textures, or full-body cover animations. Visual quality needs manual Windows playtesting even when the headless build passes. PR #6 stays unmerged until accepted.

---

# 3D Settlement Worksite Pass — PR #6 candidate

The next Windows preview adds a **physical press-and-conveyor yard** outside the industrial workshop rather than a decorative HUD representation. The modeled environment includes a hydraulic stamping press, traveling die head, roller conveyor carrying a metal blank, operator safety rails, an electrical cabinet, storage pallets, service conduit and status lighting. The assembly remains to the right of the workshop's central doorway, preserving the existing exterior navigation approach. It is procedural transitional game art; licensed, realistic mechanical models and collisions have not yet been shipped.

**Real simulation link:** The press/conveyor animate only while an actual production batch is marked **working**, the workshop has an eligible on-shift Engineer or Builder, and the workshop/settlement are not paused. The machine holds its current pose during pause. The running status lamp turns off when production stops. The economic process still executes in the existing simulation: visuals don't manufacture bonus parts or assume production where none exists.

Survivors now carry context-sensitive 3D work equipment while their current action matches actual work: construction wrench, farming hoe, first-aid kit, security radio, carried supplies or cooking pan. On-duty tasks gain a restrained stationary work gesture with the procedural character rig. Work props disappear when the survivor is moving to another location, sleeping or off duty. **People deployed on expeditions disappear from the Last Haven scene** until they return; they can no longer be simultaneously away on the regional map and physically present at home. The command building has a world-space **DPN / LAST HAVEN** identification plaque above the entrance.

**Windows visual acceptance:** Open Industry, choose Fuel Blend or Machine Parts and allow a production batch to begin. Pan to the outdoor workshop yard, observe the press cycling and the carrier moving. Pause Workshop Control and verify both freeze; resume and verify movement returns. Reassign the only Engineer/Builder or turn their duty off to check the machine stays idle when there is no available industrial worker. Inspect Farmer, Medic, Guard and Builder activity props while working, traveling and off duty. Launch an expedition to ensure members disappear from the settlement and return once home. Capture actual unaltered Windows F8 screenshots at 1280×720, 1920×1080 and fullscreen to evaluate silhouettes, proportions, readability, possible clipping and machine/character placement.

**Current limits:** This does not provide simulated machine collisions, realistic glTF machinery, full motion-captured work tasks, hand IK, factory interiors or authentic industrial audio. Headless smoke tests check the scene nodes, animation state, staffing, away-member visibility and command identification; they cannot certify how realistic the art looks on a Windows display. Keep PR #6 unmerged until player-approved.

---

# Industry Workshop Command — October 2026 candidate

This pull-request build contains a **real production management screen**, not just a graphical preview. Open **Industry (K)**, then click **Open Workshop Control / Manage Orders** in the middle of the trade screen. The new right-side interface leaves the 3D settlement visible.

The workshop displays the current shift's eligible Builders and Engineers, running efficiency and genuine bottlenecks. Select one of the six production recipes to inspect real inputs, outputs and ingredient readiness. Choose **QUEUE 1** or **QUEUE 5** to add actual orders. Active jobs appear with their statuses and progress; select a queued order to **MOVE UP**, **MOVE DOWN**, or **CANCEL** it. Pagination supports long queues, and production orders have a maximum active backlog of 48 to prevent runaway clicking. Reprioritization never changes a working order. Cancelling is allowed **only before a batch starts and consumes stock**, so no materials are lost or falsely refunded.

**PAUSE / RESUME** stops or restarts the workshop simulation, not the whole settlement clock. It persists in compatible existing save files. Labor availability now checks real shift hours, the on-duty flag, adult status, custody, health and current presence; reassigning an Engineer in Workforce or pausing their duty can leave production short of labor. Resuming labor allows production to continue normally.

**Windows acceptance checks:** queue one Fuel Blend and five Machine Parts; move a pending order, cancel one, and verify the queue changes without stock deduction. Allow one order to become WORKING and confirm it cannot be cancelled; pause production, advance time at 4×, confirm its progress stays fixed; resume and verify actual progress. Send Engineers away on an expedition or set them off duty and confirm production reflects fewer eligible workers. Save while paused, load, and confirm the hold remains. Verify recipe and action buttons at 960×720, 1024×600 and fullscreen, capture F8 screenshots, and report any cut-off areas.

**Limitations:** The screen reuses existing crafting recipes and simulation; this does not add modeled factory interiors, new machines, assembly animations or a full supply-chain logistics network. The automated smoke covers transaction validity and geometry but not visual quality on the player's Windows machine. Keep the PR unmerged until that playtest is approved.

---

## Emergency mission recall

When a mission is **Outbound** or **Searching**, the right-side active-expedition list now includes a clickable **RECALL TEAM** control. This immediately changes that expedition to **Returning**. An outbound team turns back from the distance it actually traveled (the map marker follows its shortened route). A team already searching must make the full trip home. Incomplete missions do not award phantom loot or refund provisions. Recalling a returning or finished mission is rejected. Arrival clears each surviving member's offsite assignment so they can resume work in Last Haven.

**Windows test:** dispatch a team and run 1× until it is one-third of the way out. Click Recall Team. Confirm its marker reverses from that location, not from the remote site; check the status changes to Returning and the control becomes disabled. Let the team arrive and confirm Workforce includes the returned personnel. Capture F8 before and after.

---

# Region Mission Planner — PR #6 playtest

**This preview changes gameplay, not merely the layout of the map.**

Open **Region (M)**, choose a discovered salvage site on the map or the site list, then configure **team size (1–4)** with − TEAM / + TEAM and choose a route with the **TACTIC** button. The site card previews who will actually go, required prepared meals / clean water / optional medicine, estimated one-way travel duration, search time and encounter hazard. The dispatch button uses the exact same validation shown in the preview; when a team is unavailable, another expedition is already at the site, or supplies are insufficient, a human-readable reason appears. Rejected missions **never debit supplies**.

The three tactics affect simulated travel, encounter risk and recovery time:
- **Balanced:** conventional speed, risk and salvage.
- **Cautious:** slower travel and longer search, reduced encounter risk, slightly more water, and a better expected loot recovery.
- **Rapid:** faster travel and shorter search, increased encounter risk, one more meal per member, and lower expected loot recovery.

A mission only takes eligible present adults who are healthy enough to travel; Scavengers, Guards, Medics and Engineers receive priority over other jobs. If a Builder departs, their blueprint is released for another worker. Once launched, Region shows actual progress on outbound, searching and returning legs. Members stay marked away from home until they return.

**Acceptance checks on Windows:** verify the preview updates when you change team size or tactic; confirm the mission consumes exactly the listed provisions; re-open the same location and confirm duplicate dispatch is blocked; advance time to see the phase bar progress; verify staffing reductions in Workforce while teams are away; after returning, check supplies and survivor state. Save during a mission and reload to confirm the strategy and elapsed phase persist. F8 captures real screenshots. Do not merge into stable without direct Windows gameplay acceptance.

---

# Workforce Command and Live Timeline — PR #6 playtest

**This is a development-branch feature, not part of the installed stable v1.0.5 build.**

The **PEOPLE** metric in the top HUD, or **F6**, opens a new Workforce Command overlay. The panel lists the current Last Haven population, shows each resident's job, shift and duty status, and has **Previous Page / Next Page** buttons for longer rosters. Click a person, then click one of eight actual production roles (Farmer, Engineer, Builder, Medic, Scavenger, Guard, Cook, Hauler). A successful change updates the survivor's simulation job immediately. Reassignment releases any blueprint previously claimed by a Builder. The panel deliberately rejects jobs for children, away teams, and unchanged assignments; it does not introduce new fictional simulation mechanics.

The thin bottom information rail now contains **PAUSE/RESUME, 1x, 4x and 12x** mouse controls above the nine command stations. Clicking a speed resumes play at that selected rate. Keyboard Space, 1, 2 and 3 still work. Clicking a **CHECK FOOD**, **CHECK WATER**, or **POWER SHORTFALL** alert in the top-right HUD opens a real farm, purifier, or generator blueprint, respectively.

**Windows checks:** Open Workforce from PEOPLE and F6; select the last survivor on page 2, reassign them to a new job and confirm the displayed role updates; verify work behavior changes with time running. Click PAUSE, then 4x, and verify the simulation resumes at 4x. Trigger a food/water shortage with an existing save and click its warning to reach an actual building placement. Confirm no input passes through the personnel panel to the 3D world and the modal remains fully on screen at both 960×720 and 1366×768. Capture F8 screenshots and use F9 for a local diagnostic report. The headless CI smoke validates state, hit targets, and transactions but cannot replace Windows visual acceptance.

---

## New players: understanding Last Haven

**The Last Settlement** is the game's title. **Last Haven** is the name of the settlement you're controlling. The earlier words "Recovery Network" and "Site-01" were internal project labels, not useful gameplay instructions, so they are gone from the player-facing header.

Click **Last Haven • Overview ›** in the top-left corner to open a concise, interactive briefing. The briefing explains what to do next, how many opening objectives are completed, available building materials, construction progress, current electricity generation and demand, battery charge, and sanitation. Everything comes from the current live simulation, not hard-coded fictional numbers.

Use **Open Build** to start construction, **Show Goals** to open field directives, or **Close** / **Esc** to go back to the settlement. Clicking outside the briefing closes it without accidentally giving an order in the 3D world.

Below the resource indicators, the compact status line now spells out **Day / Time / Materials / Building projects / Electricity / Battery** rather than unexplained codes like MAT, BP, GRID, BAT, or SAN. At smaller window sizes it shows a shorter version and the full overview remains clickable. A right-side status indicator warns about low food/water or insufficient power.

**Acceptance checks** on the Windows game: (1) read the game name at normal zoom, (2) open the briefing by clicking the settlement's name, (3) close using Esc and outside-click, (4) follow Show Goals and Open Build, (5) confirm electricity is described as "produced / needed," (6) resize the Windows window and ensure header controls don't overlap resources.

## Compact HUD & responsive command panels (current development playtest)

- The old 118px top bar is now **82px** high; the old 88px bottom command bar is **58px**. All six top resources are compact, include a quick health strip, and show a plain-English explanation when you hover.
- The nine bottom buttons still support mouse clicks and their original key shortcuts, now using the same central layout coordinates as the click hitboxes. Hover a button for what the screen does.
- The construction picker displays a compact, visible section of the catalog and automatically follows the selected blueprint. Hover the construction list and **scroll the mouse wheel** to browse without zooming the camera; Q/E also cycles items.
- World map pin rendering and click selection now share the same origin; the dispatch button moves with its right-hand command panel.
- Governance, industry, factions, civilization, updates, survivor and building sidebars use aligned responsive placement rather than older fixed 138px offsets. The F1 field guide is shorter and explains the live controls.
- A selected survivor has a thin ground-level ring, rather than an opaque glowing yellow disc.
- **Visual QA:** open each of the nine bottom screens at your normal resolution and fullscreen. Check that the resource row and the inspector controls are visible and clickable; use **F8** to capture unmodified game screenshots. The CI smoke test validates basic geometry/input, but it cannot establish monitor-specific legibility.

# The Last Settlement — Windows Playtest Loop

This guide separates **stable releases** from **work-in-progress test builds**. Install Godot only if you want to work with source code; Windows ZIPs run without Godot.

## 1. Install and play the stable version

1. Visit [the latest stable release](https://github.com/DPN-Technology/The-Last-Settlement/releases/latest).
2. Download `TheLastSettlement-Setup-x64.msi` to install, **or** `TheLastSettlement-Windows-x86_64.zip` to run portably.
3. For the portable package, extract **all** files, keep `TheLastSettlement.exe` next to `TheLastSettlement.pck`, and launch the EXE.
4. Expect a possible Windows **Unknown publisher** warning while packages remain unsigned. Only download from the DPN Technology GitHub repository, and use release SHA-256 checksums if desired.

Stable updates use the game's **F10** Update Command. Development artifacts are **not** published through that update channel.

## IMPORTANT: New 3D world candidate

**The latest PR #6 preview is now a TRUE 3D renderer, not the old top-down canvas.** It needs a Windows computer with Vulkan support to use the default **Forward+** graphics profile; it has not yet been visually verified on the player's computer.

- Run `Launch-TheLastSettlement.cmd` for the 3D build.
- If the game shows a graphics API/driver error, try `Launch-TheLastSettlement-Compatibility.cmd` (OpenGL Compatibility). Update GPU drivers when possible.
- **Right or middle drag** pans the 3D camera; **Alt + right drag** orbits the camera; the wheel zooms perspective; **Home** recenters the command site.
- The new scene keeps mouse construction, survivors, expeditions and save/load. Controls and campaign UI have not yet received a complete 3D-era redesign.
- The current environment geometry is authored procedurally as a **3D technical foundation**; realism requires imported high-quality meshes, photo-based PBR surfaces, animation, particle/weather systems and gameplay captures. Read [3D production art requirements](THREE_D_PRODUCTION.md).

## 2. Test a new change *before* it is merged

1. Open [Actions → DPN Settlement Windows Build](https://github.com/DPN-Technology/The-Last-Settlement/actions/workflows/windows-build.yml).
2. Select a successful run associated with the feature pull request you want to test. The run must finish its **Windows x86_64 Portable Build** job successfully.
3. In **Artifacts**, download `TheLastSettlement-Windows-x86_64`.
4. Extract the downloaded GitHub artifact archive; it contains `TheLastSettlement-Windows-x86_64.zip`. Extract that inner ZIP to a **new folder**.
5. Double-click `Launch-TheLastSettlement.cmd` (or launch `TheLastSettlement.exe` directly). Keep the `.pck` alongside the EXE.
6. Compare the candidate against the installed stable version. Do not overwrite your stable install with a pull-request build.

Artifacts have limited retention (currently 30 days). A successful pull-request build is **a test candidate**, not a production release. Preview builds use the same local game save directory as stable builds, so **back up your saves before testing any development build**.

## 3. Test a merged change on main

Use a successful `main` Windows Build run. The `TheLastSettlement-Windows-Portable-Final` artifact contains the ZIP and checksum; the `TheLastSettlement-Windows-Installer` artifact contains an MSI. Stable releases remain separate and only change through the release process.

## 4. In-game playtest workflow

- **F1** — optional field guide (not forced at startup)
- **Space** — pause/resume; **1/2/3** — simulation speed
- **Right or middle mouse drag** — pan the real 3D camera; **Alt + right drag** — 3D orbit; **mouse wheel** — 3D perspective zoom; **Home** — center Last Haven
- **Clickable bottom toolbar** — build, map, governance, economy, factions, civilization, save, load and guide
- **F2** — expand/collapse the settlement incident feed
- **F3** — open/collapse the mission board; it starts as a small tab to keep the world visible
- **F4** — toggle immersive fullscreen
- **F8** — capture a PNG screenshot of the actual game to the local playtest-screenshots folder
- **B**, then **Q/E** and mouse click — place a structure
- **M** — world map; **V / K / O / J** — governance, economy, factions and civilization screens
- **S / L** — save/load
- **F9** — write a game-only diagnostic report in your Godot user data folder, then open the report folder in Windows Explorer
- **F10** — stable-release update channel, *not* preview updates

The F9 JSON report includes the game version, save schema, in-game day, survivor counts, resources and recent incidents. It intentionally excludes machine identifiers and full save data.

## 5. File a useful bug report

Create an [issue](https://github.com/DPN-Technology/The-Last-Settlement/issues/new) with:

- **Build:** stable tag **or** the exact pull-request run/commit from `PLAYTEST-INFO.txt`
- **Steps to reproduce:** what you clicked or pressed, in order
- **Expected vs actual:** what should happen and what happened
- **Impact:** game cannot open, cannot continue, incorrect behavior, or visual issue
- **Evidence:** screenshot, error message and (if safe) your **F9 report**. Review reports before sharing; they contain your in-game settlement state.
- **Save compatibility:** mention if a prior saved settlement fails to load; preserve a backup

### Focus of the new terrain/lighting acceptance pass

Confirm against the previous washed-out screenshot that the **ground is dark clay/gravel**, the buildings occupy more of the initial frame, ruined service yards and scrap are visible, and the mission board is collapsed until you click it or press **F3**. The ground now uses a CPU-baked texture in a Godot `StandardMaterial3D`, so the default look does not rely on a custom fragment shader working on the player's GPU. Both Forward+ and Compatibility launchers should be checked.

Try morning, afternoon and nighttime. Report obvious white surfaces, z-fighting, slow frames, missing shadows, or unexpectedly tiny camera framing. **Do not call this photorealism**: detailed licensed structures, scanned PBR assets and fully rigged animated humans remain future milestones.

### Suggested smoke test for every candidate

1. Start the game and verify it opens in a **3D perspective world** with lit buildings and physical survivor meshes, not the old 2D world.
2. Advance the clock and pause/resume.
3. Select a survivor and building.
4. Use the clickable build palette to place a construction blueprint **in 3D world space**.
5. Switch to the world map and back.
6. Save, close the application, relaunch, and load.
7. Press **F9**, verify a JSON report is written.
8. Check that the game doesn't crash and previously saved progress is preserved.

**Release policy:** review and merge only after required green gates and hands-on playtesting. Preview artifacts must not silently overwrite stable releases.

---

**DPN TECHNOLOGY // THE OLD WORLD DIED. BUILD THE NEXT ONE.**
