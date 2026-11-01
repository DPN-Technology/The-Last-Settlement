# DPN TECHNOLOGY // THE LAST SETTLEMENT — COMMAND INTERFACE

**Development status:** v1.0.5 remains stable. The DPN command-interface redesign lives in the open `feature/windows-playtest-loop` playtest branch / PR #6. This document describes implemented runtime UI, not a concept render.

## Design goals

- **DPN identity:** black graphite, crimson warning accents, subtle binary telemetry and a vector lightning insignia. The wasteland world keeps its own 3D visual identity behind the interface.
- **Game-first:** display what people care about (resources, population, emergencies, actions), minimize unnecessary text and preserve direct map interaction.
- **Consistent controls:** shared selected / hovered / idle / dangerous / disabled states on a single UI-rendering helper. Buttons and hit targets always use the same `SettlementUILayout` definitions.
- **Legible information:** white primary text, muted context, semantic green for healthy systems, amber for watch conditions, and red for dangerous conditions. Red is also the DPN brand color; status meaning is not inferred from hue alone.
- **Truthful simulation:** all numbers, decisions and buttons come from existing simulation state. Visual effects never manufacture resources or claim that work happened.

## Runtime design system

`src/dpn_ui_skin.gd` (`DPNUISkin`) provides reusable code-drawn panels, corner brackets, scanner light, dual-surface buttons, clipped-width labels, vector dock icons, striped list rows, meter tracks, status markers, DPN command rail and resource telemetry. Common colors:

| Purpose | RGB |
| --- | --- |
| Command black | `#07080c` |
| Panel glass | `#0c0e14` |
| Raised controls | `#1b1d27` |
| Accent red | `#e2374c` |
| Muted red | `#852431` |
| Primary text | `#f1e8e7` |
| Supporting text | `#a69b9c` |
| Operational green | `#82cf9e` |
| Caution amber | `#f0b873` |

## Real screens using the design system

| Screen | Delivered visual architecture | Actual interactions retained |
| --- | --- | --- |
| Upper HUD | DPN lightning emblem, compact system rail, six live numeric status modules, live incident command | Personnel, food, water, power, morale and weather/emergency actions |
| Lower command dock | Nine icon-labeled command stations with red active stripe, keyboard hints, hover feedback and speed rail | Build, Region, Govern, Industry, Factions, Nation, Save, Load, Guide |
| Overview | framed recovery briefing, resources, operational meters, mission priorities, clickable actions | Open Build, show directives, close, inspect systems |
| Workforce | selection-highlighted roster and eight consistent job assignment controls | Paginated survivor assignment, personnel profiles |
| Build | categorized selectors, selectable structure list, live affordability, primary rotate/close actions | Placement, selection, blueprint costs/rotate |
| Region | dark tactical map grid, moving radar sweep, route markers, mission control buttons | Mission tactics, team size, dispatch, recall |
| Industry | structured exchange and workshop, recipe cards, queue rows, stateful buttons | Real trades, production ordering, priority, cancel, pause |
| Governance | shared DPN policy frame, consistent meters, interactive law rows | Change laws, inspect civic legitimacy |
| Factions | command-style contact tabs and disposition/strength metrics | Real aid, trade, truce once contact established |
| Nation | matching six-tab strategy interface, recovery project cards, status meters | Colonies, logistics, recovery, policy and roster |
| Guide | dark interactive lesson cards linked to live systems | Launch gameplay screens via mouse |
| Inspector | command panels for survivors, facilities and blueprints, explicit destructive state | Shift/duty/priority changes, repair and salvage |
| Notifications | compact severity-striped live events | Open expanded incident list via F2 |

The shared Godot skin is applied in `src/main.gd`. The UI uses `CanvasItem` draw commands so it does not create a separate GUI toolkit or silently destroy the world view. All existing gameplay handlers, shortcuts and save structure are retained.

## Responsive constraints and acceptance gates

`SettlementUILayout` still owns the game hitboxes. Its top command region is 82px and its bottom dock is 58px. This pass **does not** pretend to solve every narrow-screen issue or implement touch/mobile UI. Automated smoke verifies telemetry bounds and all nine stations at 960×720, 1024×600, 1280×720, 1366×768 and 1920×1080.

**Windows acceptance — test the actual EXE:**

1. Pan the 3D settlement while the command HUD is visible. Confirm black/red identity and that the UI does not obscure critical world information.
2. Hover the six top resources; click Population and open Workforce; choose an adult survivor and assign a new role.
3. Open Build; switch categories, choose a blueprint, rotate/place it; confirm the selected control is visibly distinct from a hover state.
4. Switch through **every** lower command station and verify only the intended screen is open.
5. In Region, change crew count and strategy; inspect map marker/label contrast and dispatch an actual expedition.
6. In Govern and Factions, inspect reputation/law meters; execute real policy or diplomacy controls if available.
7. In Nation, click all six tabs and select a recovery project; verify no text or buttons are clipped.
8. In Industry, queue multiple production jobs, reorder an unstarted order and pause production; check state colors and action-row visibility.
9. Open Guide, load/save, inspect a survivor, inspect a building, view notifications; ensure every screen has the same DPN identity and legible action labels.
10. Repeat at 960×720, 1366×768 and native 1920×1080; use **F8** to save unmodified screenshots for PR #6 review.

**Not yet claimed:** commercial-quality custom typography, icon asset library, advanced animated screen transitions, responsive mobile UI, UI gamepad navigation, hand-authored cinematic HUD shaders or an approved Windows visual playtest. Those are future design tasks; passing CI proves code correctness, not that the user likes the final appearance.
