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
