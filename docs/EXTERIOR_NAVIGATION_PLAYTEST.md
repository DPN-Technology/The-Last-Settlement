# The Last Settlement — Survivor Navigation & Facility Management Playtest

## What changed in this playable build

This development pass fixes an important source of unrealistic behavior: survivors used to avoid only standalone `wall` blueprints, so they could walk in straight lines through solid houses, workshops, clinics and other structures.

### New navigation behavior
- Solid building footprints and standalone walls are treated as nonwalkable ground zones.
- Walking routes are generated from outside corners of real building footprints using a small visibility graph. Routes are cached per survivor and invalidated when the building layout changes.
- Survivors working at a solid building now route to the **front exterior door**, cross its threshold, move to an interior work position and exit through the door when their destination changes. Farm workers still work in farm rows, since fields are outdoors.
- Older save files that spawn a survivor physically inside a new solid building are relocated to an exterior walkable edge.
- A survivor cannot move across a structure from one side to the other along a blocked line segment; if no safe path is found, they wait rather than pass through geometry.
- Interior visits are a lightweight world-plane state machine, **not full NavMesh3D or furniture-aware navigation**. The actor enters at the assigned front doorway and moves to an interior work position; furniture collision, animated door operation and richer room interactions remain future work.
- The current founding roster receives twelve deterministic interior work positions per facility. Larger settlements still need capacity-aware reservations and local collision avoidance at shared doors.

### Building management (select a built facility)
- Facility detail now reports live condition, number of workers targeting that facility type, its role, maintenance state and associated utility metrics where applicable.
- **Repair** submits a genuine Builder work order; clicking again does not silently queue duplicates.
- **Salvage** requires a second deliberate click/press before the building is demolished and recovered resources are granted. Esc cancels the confirmation; the Command center cannot be demolished.
- **Close** exits the inspector. Keyboard shortcuts remain R (repair), X (begin/confirm salvage), and Esc (cancel).

### Field Guide (Guide / F1)
Six clickable tutorial cards open the actual **Survival Overview, Build, Region, Govern, Industry, and Nation** modes. No tutorial card pretends to perform an action without opening a functional game screen.

## What to manually verify on Windows

1. Download the newest Direct Playtest artifact from the latest successful Windows Build workflow on PR #6, extract the EXE and accompanying .pck together and launch.
2. Pause and zoom toward the workshop/shelter fronts, then resume at 1x. Workers should travel **around** solid footprints, cross the front doorway to an interior work position, and leave through that doorway when changing destinations. If a worker gets stuck, capture an F8 screenshot and an F9 playtest report.
3. Select a damaged building, click Repair once, and verify one new repair work order. Click Repair again; confirm it does not duplicate the request.
4. Click Salvage once and confirm the building remains. Click Esc and verify confirmation disappears. Only a second confirmed Salvage action may remove the building.
5. Press F1 and click all six quick-start cards, verifying each opens its intended management screen, with Esc exiting those screens. Check ordinary 1280×720 window and fullscreen.
6. Save (S), reload (L), and verify the building and construction simulation remains usable. Route cache is intentionally not saved because it is transient.

## Outstanding realism work
- Furniture-aware interior routes and physics/collision barriers for indoor props.
- Capacity-aware work-slot reservations, robust local crowd separation and collision-aware worker avoidance when several survivors share one narrow doorway.
- Animated door operation and visible task-specific room interactions.
- Author-quality environmental assets, animation transitions, interior lighting, and detailed player feedback.

**Release policy:** This branch is a Windows playtest, not a stable merge. The user needs to approve the visual and gameplay behavior before PR #6 is merged.
