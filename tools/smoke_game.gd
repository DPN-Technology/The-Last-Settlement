extends SceneTree

# Lightweight non-interactive boot test for Windows preview candidates.
# Executes the real main scene and the UI's command input without writing a save.
func _initialize() -> void:
	call_deferred("_smoke")

func _smoke() -> void:
	var scene_resource: PackedScene = load("res://src/Main.tscn")
	if scene_resource == null:
		push_error("SMOKE: Main scene missing")
		quit(1)
		return
	var instance = scene_resource.instantiate()
	root.add_child(instance)
	if instance == null or instance.sim == null:
		push_error("SMOKE: Simulation not initialized")
		quit(1)
		return
	var sim: SettlementSimulation = instance.sim
	# The DPN command skin and all nine physical dock stations are checked
	# along with the existing mouse-action tests below. This is an integration
	# gate, not a claim that headless rendering proves visual excellence.
	if DPNUISkin.ICONS.size()!=9 or DPNUISkin.RED!=Color("#e2374c") or DPNUISkin.BLACK!=Color("#07080c"):
		push_error("SMOKE: DPN crimson/black shared command skin is missing")
		quit(1)
		return
	# Issue #9: the 9 button frames and 6 resource shells are now SVG
	# rasterized textures. Require the rasterization to work in exported Godot,
	# rather than silently reverting to the old primitive fallback.
	for glyph_index in range(9):
		var raster_glyph: Texture2D=DPNUISkin._nav_glyph(glyph_index)
		if raster_glyph==null or raster_glyph.get_width()<20:
			push_error("SMOKE: UI icon texture was not rasterized for station "+str(glyph_index))
			quit(1)
			return
	for current in [false,true]:
		var nav_shell: Texture2D=DPNUISkin._nav_background(current,false)
		var telemetry_shell: Texture2D=DPNUISkin._resource_background(current)
		if nav_shell==null or nav_shell.get_width()<120 or telemetry_shell==null or telemetry_shell.get_width()<120:
			push_error("SMOKE: UI raster control backgrounds unavailable")
			quit(1)
			return
	# Full-screen red line captures were absent from the isolated 3D pass:
	# lock the UI decoration toggle to reversible behavior without gameplay
	# state changes, so the player can isolate any residual graphics artifact.
	DPNUISkin.diagnostic_minimal_strokes=true
	if not DPNUISkin.diagnostic_minimal_strokes:
		push_error("SMOKE: UI graphics safety mode unavailable")
		quit(1)
		return
	DPNUISkin.diagnostic_minimal_strokes=false
	# Prevent the exact unsafe draw command family from creeping back into the
	# Windows portable build while testing red diagonal line artifacts.
	if str(ProjectSettings.get_setting("rendering/renderer/rendering_method",""))!="gl_compatibility":
		push_error("SMOKE: Windows preview must default to compatibility renderer")
		quit(1)
		return
	for source_path in ["res://src/main.gd","res://src/dpn_ui_skin.gd","res://src/region_atlas.gd"]:
		var source_code := FileAccess.get_file_as_string(source_path)
		if source_code.is_empty() or source_code.contains("draw_line(") or source_code.contains("draw_polyline(") or source_code.contains("draw_colored_polygon(") or source_code.contains("draw_primitive("):
			push_error("SMOKE: Unsafe raw canvas line primitives in "+source_path)
			quit(1)
			return
		for source_line in source_code.split("\n"):
			if source_line.contains("draw_rect(") and (source_line.contains(",false,") or source_line.contains(", false,") or source_line.contains(", false)")):
				push_error("SMOKE: Native UI rectangle outlines must use filled border strips: "+source_path)
				quit(1)
				return
	for visual_size in [Vector2(960,720),Vector2(1024,600),Vector2(1280,720),Vector2(1366,768),Vector2(1920,1080)]:
		var nav_last_right := 0.0
		for n in range(9):
			var dock := SettlementUILayout.navbar_rect(visual_size,n)
			if dock.position.x<nav_last_right or dock.end.x>visual_size.x or dock.end.y>visual_size.y or dock.position.y<visual_size.y-SettlementUILayout.BOTTOM_H:
				push_error("SMOKE: DPN command dock icon/button geometry overflows at "+str(visual_size))
				quit(1)
				return
			nav_last_right=dock.end.x
		for chip in SettlementUILayout.resource_rects(visual_size):
			if chip.position.x<0 or chip.end.x>visual_size.x or chip.position.y<0 or chip.end.y>SettlementUILayout.TOP_H:
				push_error("SMOKE: DPN top telemetry chip does not fit at "+str(visual_size))
				quit(1)
				return
		# Buttons were overlapping at the right edge of the command dock.
		for control_i in range(4):
			var speed := SettlementUILayout.time_control(visual_size,control_i)
			if speed.position.x<0.0 or speed.end.x>visual_size.x or speed.position.y<visual_size.y-SettlementUILayout.BOTTOM_H or speed.end.y>SettlementUILayout.navbar_rect(visual_size,0).position.y:
				push_error("SMOKE: speed control overlaps the full-width navigation dock")
				quit(1)
				return
		var catalog := SettlementUILayout.build_palette(visual_size,0)
		var visible := SettlementUILayout.palette_rows(visual_size,16)
		for row_i in range(visible):
			var build_row := SettlementUILayout.build_row_rect(visual_size,row_i)
			if not catalog.encloses(build_row) or build_row.end.y>=catalog.end.y-108.0:
				push_error("SMOKE: larger build catalog entries obscure selected blueprint details")
				quit(1)
				return
		for site_i in range(6):
			var site_row := SettlementUILayout.region_site_row(visual_size,site_i)
			if site_row.end.y>visual_size.y-SettlementUILayout.BOTTOM_H:
				push_error("SMOKE: field-intelligence site row escapes game viewport")
				quit(1)
				return
	# Region MUST render a real textured fictional terrain atlas, rather
	# than only a flat radar circle. Atlas caching is important for UI FPS.
	var terrain_atlas := RegionAtlas.new()
	var atlas_texture := terrain_atlas.get_texture(sim.world_simulation.get_radio_range())
	if atlas_texture==null or atlas_texture.get_width()!=RegionAtlas.MAP_W or atlas_texture.get_height()!=RegionAtlas.MAP_H:
		push_error("SMOKE: Actual regional topographic map texture was not generated")
		quit(1)
		return
	if terrain_atlas.get_texture(sim.world_simulation.get_radio_range())!=atlas_texture:
		push_error("SMOKE: Terrain atlas rebuilds every frame instead of caching")
		quit(1)
		return
	var terrain_image := atlas_texture.get_image()
	if terrain_image.get_pixel(30,30).is_equal_approx(terrain_image.get_pixel(300,240)):
		push_error("SMOKE: Region atlas is a flat fill rather than terrain relief")
		quit(1)
		return
	# The click-to-focus settlement minimap must derive from actual building
	# coordinates and must not inadvertently trigger building placement.
	var mini_plot := SettlementUILayout.minimap_plot(Vector2(1280,720))
	var mini_frame := SettlementUILayout.settlement_minimap(Vector2(1280,720))
	if not mini_frame.encloses(mini_plot) or mini_frame.position.y<SettlementUILayout.TOP_H or mini_frame.end.y>720.0-SettlementUILayout.BOTTOM_H:
		push_error("SMOKE: Tactical settlement minimap conflicts with command rails")
		quit(1)
		return
	if not instance._can_draw_settlement_minimap():
		push_error("SMOKE: Starting settlement has no available live facility minimap")
		quit(1)
		return
	var saved_focus: Vector3=instance.settlement_world.focus
	var live_frame := SettlementUILayout.minimap_plot(instance.get_viewport_rect().size)
	if not instance._handle_minimap_click(live_frame.position+live_frame.size*0.75) or instance.settlement_world.focus.is_equal_approx(saved_focus):
		push_error("SMOKE: Facility minimap does not actually focus the live 3D camera")
		quit(1)
		return
	instance.settlement_world.focus=saved_focus
	instance.settlement_world._position_camera()
	var toggle_map := InputEventKey.new()
	toggle_map.keycode=KEY_F5
	toggle_map.pressed=true
	instance._unhandled_input(toggle_map)
	if instance.settlement_minimap_visible or instance._can_draw_settlement_minimap():
		push_error("SMOKE: F5 cannot hide the settlement minimap")
		quit(1)
		return
	instance._unhandled_input(toggle_map)
	if not instance.settlement_minimap_visible:
		push_error("SMOKE: F5 cannot restore the minimap")
		quit(1)
		return
	if sim.get_alive_citizens().size() < 1 or sim.buildings.size() < 5:
		push_error("SMOKE: Starting settlement lacks survivors or buildings")
		quit(1)
		return
	if instance.help_mode:
		push_error("SMOKE: Tutorial must not block the settlement by default")
		quit(1)
		return
	if not (instance.settlement_world is SettlementWorld3D):
		push_error("SMOKE: True 3D world scene unavailable")
		quit(1)
		return
	if instance.settlement_world.camera == null or not (instance.settlement_world.camera is Camera3D):
		push_error("SMOKE: Perspective Camera3D unavailable")
		quit(1)
		return
	if instance.settlement_world.terrain_layer == null or instance.settlement_world.terrain_layer.get_child_count() < 10:
		push_error("SMOKE: Three-dimensional terrain failed to initialize")
		quit(1)
		return
	instance.settlement_world.sync(sim, {}, {}, false, Vector2(700, 450), sim.get_build_catalog()[0], false, 0.016)
	if instance.settlement_world.structure_layer.get_child_count() < sim.buildings.size():
		push_error("SMOKE: Building meshes missing in 3D")
		quit(1)
		return
	if instance.settlement_world.people.size() < sim.get_alive_citizens().size():
		push_error("SMOKE: 3D survivors were not created")
		quit(1)
		return
	# The industrial art has to be physical 3D equipment, and its mechanism
	# must only run when an active job and eligible worker exist.
	var world_3d: SettlementWorld3D=instance.settlement_world
	if world_3d.industrial_yards.is_empty():
		push_error("SMOKE: No physically modeled press-and-conveyor yard at the workshop")
		quit(1)
		return
	var sign: Label3D=world_3d.structure_layer.get_node_or_null("Command/LastHavenPhysicalSign") as Label3D
	if sign==null or not sign.text.contains("LAST HAVEN"):
		push_error("SMOKE: Command HQ is missing its readable real-world DPN identity plaque")
		quit(1)
		return
	var machine: Dictionary=world_3d.industrial_yards[0]
	var yard_root: Node3D=machine["root"]
	if yard_root.get_node_or_null("StampingRam")==null or yard_root.get_node_or_null("MovingBlankCarrier")==null or yard_root.get_node_or_null("PressUpright")==null:
		push_error("SMOKE: Missing real industrial press components")
		quit(1)
		return
	var visual_worker: Dictionary=sim.get_settlement_citizens()[0]
	var original_worker: Dictionary=visual_worker.duplicate(true)
	var original_hour: float=sim.hour
	visual_worker["age"]=35
	visual_worker["job"]="Engineer"
	visual_worker["shift"]="DAY"
	visual_worker["health"]=90.0
	visual_worker["incarcerated"]=false
	visual_worker["on_expedition"]=false
	visual_worker["work_priority"]["Engineer"]=3
	sim.hour=10.0
	var eco_visual: EconomySimulation=sim.economy_simulation
	var old_hold: bool=eco_visual.production_paused
	eco_visual.production_paused=false
	var active_visual_batch: Dictionary={"id":-5555,"recipe":"Machine Parts","status":"working","progress":6.0}
	eco_visual.production_queue.push_front(active_visual_batch)
	world_3d.sync(sim,{}, {}, false, Vector2(700,450),sim.get_build_catalog()[0],false,0.35)
	if not world_3d._industry_operating(sim) or not bool((machine["running_light"] as MeshInstance3D).visible):
		push_error("SMOKE: Working industrial crew does not activate the 3D equipment")
		quit(1)
		return
	var press: Node3D=machine["ram"]
	var moving_y: float=press.position.y
	world_3d.sync(sim,{}, {}, false, Vector2(700,450),sim.get_build_catalog()[0],false,0.48)
	if is_equal_approx(moving_y,press.position.y):
		push_error("SMOKE: Production press has no animated hydraulic stroke")
		quit(1)
		return
	var stopped_y: float=press.position.y
	eco_visual.production_paused=true
	world_3d.sync(sim,{}, {}, false, Vector2(700,450),sim.get_build_catalog()[0],false,0.67)
	if not is_equal_approx(stopped_y,press.position.y) or bool((machine["running_light"] as MeshInstance3D).visible):
		push_error("SMOKE: Paused workshop press moves or incorrectly shows RUNNING")
		quit(1)
		return
	var worker_id := str(visual_worker["id"])
	var worker_mesh: Node3D=world_3d.people[worker_id]
	visual_worker["current_action"]="Work: Engineering"
	SettlementActivity3D.update(worker_mesh,visual_worker,false,false,0.4)
	if not bool((worker_mesh.get_node("LiveDutyEquipment/Construction") as Node3D).visible):
		push_error("SMOKE: Working Engineer lacks visible 3D work equipment")
		quit(1)
		return
	visual_worker["current_action"]="Off Duty"
	SettlementActivity3D.update(worker_mesh,visual_worker,false,false,0.4)
	if bool((worker_mesh.get_node("LiveDutyEquipment/Construction") as Node3D).visible):
		push_error("SMOKE: Off-duty worker still appears to use machinery tools")
		quit(1)
		return
	visual_worker["on_expedition"]=true
	world_3d._update_people(sim,{})
	if world_3d.people.has(worker_id):
		push_error("SMOKE: Survivor deployed on expedition still rendered at home")
		quit(1)
		return
	for key in original_worker.keys():
		visual_worker[key]=original_worker[key]
	sim.hour=original_hour
	eco_visual.production_paused=old_hold
	eco_visual.production_queue.erase(active_visual_batch)
	world_3d.sync(sim,{}, {},false,Vector2(700,450),sim.get_build_catalog()[0],false,0.016)
	if not world_3d.people.has(worker_id):
		push_error("SMOKE: Returned survivor does not reappear in physical settlement")
		quit(1)
		return
	var original_pause := sim.paused
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_SPACE
	instance._unhandled_input(event)
	if sim.paused == original_pause:
		push_error("SMOKE: Pause control did not change simulation state")
		quit(1)
		return
	event.keycode = KEY_F1
	instance._unhandled_input(event)
	if not instance.help_mode:
		push_error("SMOKE: Field guide did not open")
		quit(1)
		return
	event.keycode = KEY_B
	instance._unhandled_input(event)
	if not instance.build_mode:
		push_error("SMOKE: Construction control did not activate")
		quit(1)
		return
	# Exterior navigation must keep physical building footprints solid. The
	# current production game does not yet simulate walkable interiors.
	var test_buildings: Array[Dictionary] = [
		{"name":"Blocking Shelter","type":"housing","position":Vector2(200,200),"size":Vector2(100,80)},
		{"name":"Test Farm","type":"farm","position":Vector2(360,200),"size":Vector2(100,80)}
	]
	var crossing_a := Vector2(100,200)
	var crossing_b := Vector2(300,200)
	if SettlementNavigation.valid_step(crossing_a,crossing_b,test_buildings):
		push_error("SMOKE: Solid housing wall can still be walked through")
		quit(1)
		return
	var path := SettlementNavigation.route(crossing_a,crossing_b,test_buildings)
	if path.is_empty():
		push_error("SMOKE: Navigation did not route around occupied shelter")
		quit(1)
		return
	var nav_from := crossing_a
	for waypoint in path:
		if not SettlementNavigation.valid_step(nav_from,waypoint,test_buildings):
			push_error("SMOKE: Navigation waypoint crosses a building wall")
			quit(1)
			return
		nav_from = waypoint
	if nav_from.distance_to(crossing_b)>1.0:
		push_error("SMOKE: Navigation fails to reach safe outdoor destination")
		quit(1)
		return
	var doorway := SettlementNavigation.exterior_entry(test_buildings[0])
	if doorway.y >= 160.0 or SettlementNavigation.collision_rects(test_buildings)[0].has_point(doorway):
		push_error("SMOKE: Shelter visitor target is inside a solid building")
		quit(1)
		return
	var spawn_inside := SettlementNavigation.resolve_walkable(Vector2(200,200),test_buildings)
	if SettlementNavigation.collision_rects(test_buildings)[0].has_point(spawn_inside):
		push_error("SMOKE: Saved survivor inside shelter cannot reach exterior")
		quit(1)
		return
	if SettlementNavigation.exterior_entry(test_buildings[1]) != Vector2(360,200):
		push_error("SMOKE: Outdoor farm workers cannot reach farm rows")
		quit(1)
		return
	# Facility management is a real repair work-order and a two-step
	# demolition transaction, never one accidental click through a panel.
	var repair_fixture: Dictionary = {"name":"Smoke Maintenance Shed","type":"storage","position":Vector2(1960,940),"size":Vector2(100,80),"condition":48.0,"capacity":2}
	sim.buildings.append(repair_fixture)
	instance.selected_building=repair_fixture
	var order_count := sim.work_orders.size()
	var inspector_size: Vector2 = instance.get_viewport_rect().size
	if not instance._handle_inspector_click(SettlementUILayout.facility_action(inspector_size,0).get_center()):
		push_error("SMOKE: Building Repair button is not clickable")
		quit(1)
		return
	if sim.work_orders.size()!=order_count+1 or not instance._facility_repair_queued(repair_fixture):
		push_error("SMOKE: Facility repair did not create an actual Builder work order")
		quit(1)
		return
	instance._handle_inspector_click(SettlementUILayout.facility_action(inspector_size,0).get_center())
	if sim.work_orders.size()!=order_count+1:
		push_error("SMOKE: Clicking Repair twice created duplicate work orders")
		quit(1)
		return
	instance._handle_inspector_click(SettlementUILayout.facility_action(inspector_size,1).get_center())
	if not repair_fixture in sim.buildings or instance.pending_demolition_key=="":
		push_error("SMOKE: One-click salvage illegally destroyed a facility")
		quit(1)
		return
	var cancel_key := InputEventKey.new()
	cancel_key.pressed=true
	cancel_key.keycode=KEY_ESCAPE
	instance._unhandled_input(cancel_key)
	if instance.pending_demolition_key!="":
		push_error("SMOKE: ESC cannot cancel building salvage confirmation")
		quit(1)
		return
	instance._handle_inspector_click(SettlementUILayout.facility_action(inspector_size,1).get_center())
	instance._handle_inspector_click(SettlementUILayout.facility_action(inspector_size,1).get_center())
	if repair_fixture in sim.buildings or not instance.selected_building.is_empty():
		push_error("SMOKE: Confirmed facility salvage did not remove building")
		quit(1)
		return
	# The paused simulation must not animate living survivors in the background.
	var snapshot: Vector2 = Vector2(sim.citizens[0]["position"])
	instance._process(0.2)
	if Vector2(sim.citizens[0]["position"]) != snapshot:
		push_error("SMOKE: Survivors moved while simulation paused")
		quit(1)
		return
	# Player can follow the opening objective and choose a blueprint by mouse.
	instance._handle_objective_click(SettlementUILayout.objective_panel().position + Vector2(50,72))
	if not bool(sim.field_objectives["inspected"]) or instance.selected_citizen.is_empty():
		push_error("SMOKE: Survivor inspection directive did not complete")
		quit(1)
		return
	instance._handle_objective_click(SettlementUILayout.objective_panel().position + Vector2(50,98))
	if not instance.build_mode:
		push_error("SMOKE: Directive did not open construction")
		quit(1)
		return
	instance._handle_build_palette_click(SettlementUILayout.build_palette(instance.get_viewport_rect().size, sim.get_build_catalog().size()).position + Vector2(45,134 + 2 * 27 + 13))
	if instance.build_catalog_index != 2:
		push_error("SMOKE: Construction catalog did not respond to mouse")
		quit(1)
		return
	var build_site := Vector2(320, 860)
	if not sim.place_blueprint("wall", build_site):
		push_error("SMOKE: Could not create an actual construction blueprint")
		quit(1)
		return
	if not bool(sim.field_objectives["blueprint"]):
		push_error("SMOKE: Blueprint milestone did not complete")
		quit(1)
		return
	# Optional campaign fields must survive existing v14-format JSON saves.
	var test_save := "user://settlement-playtest-smoke.json"
	if not sim.save_game(test_save):
		push_error("SMOKE: Could not save settlement")
		quit(1)
		return
	sim.field_objectives["inspected"] = false
	if not sim.load_game(test_save) or not bool(sim.field_objectives["inspected"]):
		push_error("SMOKE: Opening directive progress did not survive save/load")
		quit(1)
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save))
	if sim.blueprints.is_empty():
		push_error("SMOKE: Blueprint disappeared after saving and loading")
		quit(1)
		return
	instance.build_mode = false
	instance._select_at(instance._world_point(Vector2(sim.blueprints[-1]["position"])))
	if instance.selected_blueprint.is_empty():
		push_error("SMOKE: Player cannot select a construction blueprint")
		quit(1)
		return
	instance._handle_inspector_click(SettlementUILayout.side_panel(instance.get_viewport_rect().size,350.0).position + Vector2(190,167))
	if not sim.blueprints.is_empty():
		push_error("SMOKE: Clickable blueprint cancellation failed")
		quit(1)
		return
	# Expanded catalog is real gameplay, not an inaccessible decorative menu.
	for required in ["farm","medical","industry"]:
		var found := false
		for entry in sim.get_build_catalog():
			if str(entry["type"])==required:
				found = true
		if not found:
			push_error("SMOKE: Essential production/care building missing: "+required)
			quit(1)
			return
	instance.build_mode = true
	instance._handle_build_palette_click(SettlementUILayout.build_category_rect(instance.get_viewport_rect().size,4).get_center())
	if instance.build_category != "SERVICES" or str(sim.get_build_catalog()[instance.build_catalog_index]["type"]) != "farm":
		push_error("SMOKE: Service building category did not filter to real crop fields")
		quit(1)
		return
	var farm_site := Vector2(1820,920)
	if not sim.place_blueprint("farm",farm_site):
		push_error("SMOKE: Farm catalog option cannot create an actual blueprint")
		quit(1)
		return
	var new_id := int(sim.blueprints[-1]["id"])
	if not sim.cancel_blueprint(new_id):
		push_error("SMOKE: New farm blueprint cannot be cancelled")
		quit(1)
		return
	instance._set_build_category("ALL")
	instance.build_mode = false

	# All toolbars and resource chips must fit in the live viewport and share
	# click geometry; previous hard-coded 118px/88px HUD obscured the 3D world.
	var screen: Vector2 = instance.get_viewport_rect().size
	var resource_rectangles := SettlementUILayout.resource_rects(screen)
	if resource_rectangles.size() != 6:
		push_error("SMOKE: Expected six compact resource indicators")
		quit(1)
		return
	if SettlementUILayout.TOP_H > 85.0 or SettlementUILayout.BOTTOM_H > 62.0:
		push_error("SMOKE: UI bars still consume too much of the 3D view")
		quit(1)
		return
	for card in resource_rectangles:
		if card.position.y < 0 or card.end.y > SettlementUILayout.TOP_H or card.end.x > screen.x:
			push_error("SMOKE: Resource card clipped by screen edge")
			quit(1)
			return
	for index in range(9):
		var nav_rect := SettlementUILayout.navbar_rect(screen,index)
		if nav_rect.position.y < screen.y-SettlementUILayout.BOTTOM_H or nav_rect.end.y > screen.y or nav_rect.end.x > screen.x:
			push_error("SMOKE: Compact navigation tab outside bottom bar")
			quit(1)
			return
	for width in [350.0,480.0,700.0]:
		var side := SettlementUILayout.side_panel(screen,width)
		if side.position.y < SettlementUILayout.TOP_H or side.end.y > screen.y-SettlementUILayout.BOTTOM_H:
			push_error("SMOKE: Secondary command panel is clipped by HUD")
			quit(1)
			return
	# Toolbar Build is not the same action as keyboard B in Civilization
	# Command. It must never trigger emergency federal spending.
	instance.civilization_mode = true
	instance.world_map_mode = true
	instance.build_mode = false
	sim.federal_governance_simulation.federal_treasury = 300.0
	var treasury_before: float = sim.federal_governance_simulation.federal_treasury
	var build_button := SettlementUILayout.navbar_rect(instance.get_viewport_rect().size,0).get_center()
	instance._handle_toolbar_click(build_button)
	if not instance.build_mode or instance.civilization_mode or instance.world_map_mode:
		push_error("SMOKE: Build toolbar did not enter settlement construction")
		quit(1)
		return
	if sim.federal_governance_simulation.federal_treasury != treasury_before:
		push_error("SMOKE: Build toolbar unexpectedly spent federal funds")
		quit(1)
		return
	instance._handle_toolbar_click(build_button)
	if instance.build_mode:
		push_error("SMOKE: Clicking active Build toolbar did not close construction")
		quit(1)
		return
	# The command screens must be mouse-operable; input must act on the
	# selected mode without changing unrelated treasury or game state.
	instance.economy_mode = true
	instance.governance_mode = false
	var old_item: int = instance.economy_item_index
	if not instance._handle_panel_action_click(instance._panel_action_rect(1,8).get_center()):
		push_error("SMOKE: Industry NEXT ITEM button does not accept mouse clicks")
		quit(1)
		return
	if instance.economy_item_index != (old_item+1) % instance.ECONOMY_ITEMS.size():
		push_error("SMOKE: Industry NEXT ITEM click did not change selection")
		quit(1)
		return
	# New production actions must affect the real batch queue.
	instance.economy_recipe_index = 0
	var initial_batches := sim.economy_simulation.production_queue.size()
	instance._handle_panel_action_click(instance._panel_action_rect(6,8).get_center())
	if sim.economy_simulation.production_queue.size() != initial_batches+1:
		push_error("SMOKE: Industry QUEUE action did not create a live production batch")
		quit(1)
		return
	instance._handle_command_content_click(SettlementUILayout.side_panel(screen,480.0).position+Vector2(75,158+3*22+10))
	if instance.economy_item_index != 3:
		push_error("SMOKE: Clicking an item in Industry did not select it")
		quit(1)
		return
	instance._handle_panel_action_click(instance._panel_action_rect(7,8).get_center())
	if instance.economy_mode:
		push_error("SMOKE: Industry CLOSE mouse button did not dismiss panel")
		quit(1)
		return
	# Dedicated workshop is a real queue manager, not an informational mock.
	var eco: EconomySimulation=sim.economy_simulation
	instance.economy_mode=true
	if not instance._handle_command_content_click(SettlementUILayout.workshop_entry(screen).get_center()) or not instance.industry_workshop_visible:
		push_error("SMOKE: Industry cannot open its clickable Workshop Control")
		quit(1)
		return
	for preview_size in [Vector2(960,720),Vector2(1280,720),Vector2(1366,768),Vector2(1024,600)]:
		var workshop_bounds := SettlementUILayout.workshop_panel(preview_size)
		for recipe_i in range(instance.ECONOMY_RECIPES.size()):
			if not workshop_bounds.encloses(SettlementUILayout.workshop_recipe(preview_size,recipe_i)):
				push_error("SMOKE: Workshop recipe button escapes available panel")
				quit(1)
				return
		for action_i in range(10):
			if not workshop_bounds.encloses(SettlementUILayout.workshop_action(preview_size,action_i)):
				push_error("SMOKE: Workshop action button escapes available panel")
				quit(1)
				return
		for queue_i in range(SettlementUILayout.workshop_visible_rows(preview_size)):
			if not workshop_bounds.encloses(SettlementUILayout.workshop_queue_row(preview_size,queue_i)):
				push_error("SMOKE: Workshop active-order row escapes panel")
				quit(1)
				return
	# Recipe selection and queue button must mutate actual simulation orders.
	var queue_count := eco.production_queue.size()
	instance._handle_workshop_click(SettlementUILayout.workshop_recipe(screen,3).get_center())
	if instance.economy_recipe_index!=3:
		push_error("SMOKE: Workshop recipe picker is not interactive")
		quit(1)
		return
	instance._handle_workshop_click(SettlementUILayout.workshop_action(screen,1).get_center())
	if eco.production_queue.size()!=queue_count+5:
		push_error("SMOKE: Workshop QUEUE 5 did not add 5 real jobs")
		quit(1)
		return
	# Batches may change priority only before any inputs have been consumed.
	var orders := eco.get_open_batches()
	var last: Dictionary=orders.back()
	var previous: Dictionary=orders[orders.size()-2]
	var chosen_id := int(last["id"])
	instance.industry_queue_page=int(floor(float(orders.size()-1)/float(SettlementUILayout.workshop_visible_rows(screen))))
	instance.industry_batch_id=chosen_id
	instance._handle_workshop_click(SettlementUILayout.workshop_action(screen,2).get_center())
	orders=eco.get_open_batches()
	if int(orders[orders.size()-2]["id"])!=chosen_id or int(orders.back()["id"])!=int(previous["id"]):
		push_error("SMOKE: Workshop MOVE UP failed to change pending production order")
		quit(1)
		return
	instance._handle_workshop_click(SettlementUILayout.workshop_action(screen,4).get_center())
	if not eco.get_batch_by_id(chosen_id).is_empty():
		push_error("SMOKE: Workshop CANCEL did not remove unstarted order")
		quit(1)
		return
	var active_fixture := eco.get_open_batches()[0]
	active_fixture["status"]="working"
	active_fixture["progress"]=6.0
	var working_id := int(active_fixture["id"])
	var stock_before := float(sim.stockpiles["industry"]["materials"])
	if eco.cancel_queued_batch(sim,working_id) or eco.move_queued_batch(sim,working_id,-1):
		push_error("SMOKE: Started production batch was wrongly cancellable/reorderable")
		quit(1)
		return
	instance._handle_workshop_click(SettlementUILayout.workshop_action(screen,5).get_center())
	if not eco.production_paused:
		push_error("SMOKE: Workshop pause button did not stop real production")
		quit(1)
		return
	eco._update_production(sim,3.0)
	if not is_equal_approx(float(active_fixture["progress"]),6.0) or not is_equal_approx(float(sim.stockpiles["industry"]["materials"]),stock_before):
		push_error("SMOKE: Production advanced or consumed inputs while paused")
		quit(1)
		return
	instance._handle_workshop_click(SettlementUILayout.workshop_action(screen,5).get_center())
	if eco.production_paused:
		push_error("SMOKE: Workshop resume button failed")
		quit(1)
		return
	instance._handle_workshop_click(SettlementUILayout.workshop_action(screen,8).get_center())
	if instance.industry_workshop_visible or not instance.economy_mode:
		push_error("SMOKE: Workshop TRADE did not return to existing industry screen")
		quit(1)
		return
	instance.economy_mode=false
	instance.governance_mode = true
	var old_law: int = instance.governance_law_index
	instance._handle_panel_action_click(instance._panel_action_rect(1,4).get_center())
	if instance.governance_law_index != (old_law+1) % instance.GOVERNANCE_LAWS.size():
		push_error("SMOKE: Civic NEXT LAW action did not change highlighted law")
		quit(1)
		return
	instance._handle_command_content_click(SettlementUILayout.side_panel(screen,480.0).position+Vector2(55,263+2*28+10))
	if instance.governance_law_index != 2:
		push_error("SMOKE: Clicking governance law row did not select labor policy")
		quit(1)
		return
	var old_setting := str(sim.governance_simulation.laws["labor"])
	instance._handle_panel_action_click(instance._panel_action_rect(2,4).get_center())
	if str(sim.governance_simulation.laws["labor"]) == old_setting:
		push_error("SMOKE: Governance change button did not update real law")
		quit(1)
		return
	instance._handle_panel_action_click(instance._panel_action_rect(3,4).get_center())
	if instance.governance_mode:
		push_error("SMOKE: Civic CLOSE action did not dismiss panel")
		quit(1)
		return
	# The regional map projection and list must select the same actual site.
	instance.world_map_mode = true
	var available_locations := sim.world_simulation.get_discovered_locations()
	if available_locations.size()<2:
		push_error("SMOKE: No explored salvage location available on starting map")
		quit(1)
		return
	var destination: Dictionary = available_locations[1]
	instance._world_map_select(SettlementUILayout.region_point(screen,Vector2(destination["position"])))
	if instance.selected_world_location_id != int(destination["id"]):
		push_error("SMOKE: Regional map marker selection uses incorrect projection")
		quit(1)
		return
	instance.selected_world_location_id = 1
	if instance._dispatch_region():
		push_error("SMOKE: Home location illegally allowed a salvage mission")
		quit(1)
		return
	instance._handle_region_click(SettlementUILayout.region_site_row(screen,1).get_center())
	if instance.selected_world_location_id != int(destination["id"]):
		push_error("SMOKE: Regional site list click did not select location")
		quit(1)
		return
	# Seed an eligible adult to avoid random citizen job assignments creating
	# nondeterministic smoke failures. Dispatch must use the real game API.
	var scout: Dictionary = sim.get_alive_citizens()[0]
	scout["age"] = maxi(23,int(scout["age"]))
	scout["job"] = "Scavenger"
	scout["on_expedition"] = false
	sim.stockpiles["command"]["meals"] = maxf(24.0,float(sim.stockpiles["command"].get("meals",0.0)))
	sim.stockpiles["command"]["water"] = maxf(30.0,float(sim.stockpiles["command"].get("water",0.0)))
	# Region is now a mission-planning screen, not an unconfigurable
	# launch button. The same immutable preview drives actual dispatch.
	for target_size in [Vector2(960,720),Vector2(1280,720),Vector2(1366,768)]:
		var region_frame := SettlementUILayout.side_panel(target_size,372.0)
		for control_index in range(3):
			if not region_frame.encloses(SettlementUILayout.region_team_control(target_size,control_index)):
				push_error("SMOKE: Mission planning button outside region panel")
				quit(1)
				return
		if not region_frame.encloses(SettlementUILayout.region_dispatch_rect(target_size)):
			push_error("SMOKE: Mission dispatch button outside region panel")
			quit(1)
			return
	instance._handle_region_click(SettlementUILayout.region_team_control(screen,0).get_center())
	instance._handle_region_click(SettlementUILayout.region_team_control(screen,2).get_center())
	if instance.expedition_team_size!=2 or str(WorldSimulation.STRATEGIES[instance.expedition_strategy_index])!="cautious":
		push_error("SMOKE: Expedition team size or route selector is not mouse-controlled")
		quit(1)
		return
	var meal_before: float=float(sim.stockpiles["command"]["meals"])
	var water_before: float=float(sim.stockpiles["command"]["water"])
	var mission: Dictionary=sim.world_simulation.plan_expedition(sim,int(destination["id"]),instance.expedition_team_size,"cautious")
	var rapid: Dictionary=sim.world_simulation.plan_expedition(sim,int(destination["id"]),instance.expedition_team_size,"rapid")
	if not bool(mission["ok"]) or not bool(rapid["ok"]):
		push_error("SMOKE: Valid expedition planner wrongly blocked an eligible crew")
		quit(1)
		return
	if mission["members"].size()!=2 or float(mission["risk"])>=float(rapid["risk"]) or float(mission["travel_hours"])<=float(rapid["travel_hours"]):
		push_error("SMOKE: Mission strategy has no real impact on safety / travel")
		quit(1)
		return
	if not is_equal_approx(float(sim.stockpiles["command"]["meals"]),meal_before) or not is_equal_approx(float(sim.stockpiles["command"]["water"]),water_before):
		push_error("SMOKE: Read-only mission preview silently spent resources")
		quit(1)
		return
	var prior_trips := sim.world_simulation.expeditions.size()
	if not instance._dispatch_region() or sim.world_simulation.expeditions.size() != prior_trips+1:
		push_error("SMOKE: Discovered salvage site cannot dispatch a real survivor team")
		quit(1)
		return
	var launched: Dictionary=sim.world_simulation.expeditions.back()
	if str(launched.get("strategy",""))!="cautious" or launched["members"].size()!=2:
		push_error("SMOKE: Configured expedition team and tactic were ignored")
		quit(1)
		return
	if not is_equal_approx(float(sim.stockpiles["command"]["meals"]),meal_before-float(mission["food_cost"])) or not is_equal_approx(float(sim.stockpiles["command"]["water"]),water_before-float(mission["water_cost"])):
		push_error("SMOKE: Dispatch supply cost differs from mission preview")
		quit(1)
		return
	for scout_id in launched["members"]:
		if not bool(sim.get_citizen_by_id(int(scout_id)).get("on_expedition",false)):
			push_error("SMOKE: Planned survivor never departed from the settlement")
			quit(1)
			return
	var after_launch_meals: float=float(sim.stockpiles["command"]["meals"])
	if sim.world_simulation.create_expedition(sim,int(destination["id"]),1) or not is_equal_approx(float(sim.stockpiles["command"]["meals"]),after_launch_meals):
		push_error("SMOKE: Duplicate active mission started or consumed extra supplies")
		quit(1)
		return
	var starving_plan: Dictionary=sim.world_simulation.plan_expedition(sim,3,4,"rapid")
	var last_meals: float=float(sim.stockpiles["command"]["meals"])
	if not bool(starving_plan.get("ok",false)) and sim.world_simulation.create_expedition(sim,3,4,"invalid-tactic"):
		push_error("SMOKE: Invalid mission tactic was accepted")
		quit(1)
		return
	if not is_equal_approx(float(sim.stockpiles["command"]["meals"]),last_meals):
		push_error("SMOKE: Rejected mission spent supplies")
		quit(1)
		return
	# Mid-route recall must reverse the real team, preserve supplies and
	# return from its actual position, not teleport to the destination.
	var departure_distance: float=float(launched["distance"])
	launched["progress"]=departure_distance*0.32
	var expected_backtrack: float=float(launched["progress"])
	if not instance._handle_region_click(SettlementUILayout.region_recall_rect(screen,0).get_center()):
		push_error("SMOKE: Region recall click is not consumed")
		quit(1)
		return
	if str(launched["status"])!="returning" or not bool(launched.get("recalled",false)) or not is_equal_approx(float(launched.get("return_distance",0.0)),expected_backtrack):
		push_error("SMOKE: Mission recall did not reverse at the team's real location")
		quit(1)
		return
	if sim.world_simulation.recall_expedition(sim,int(launched["id"])):
		push_error("SMOKE: Returning mission incorrectly accepts duplicate recall")
		quit(1)
		return
	if not is_equal_approx(float(sim.stockpiles["command"]["meals"]),last_meals):
		push_error("SMOKE: Recall incorrectly refunded consumed provisions")
		quit(1)
		return
	sim.world_simulation._update_returning(sim,launched,expected_backtrack/float(launched["travel_speed"])+0.1)
	if str(launched["status"])!="returned":
		push_error("SMOKE: Recalled team cannot finish its shorter return path")
		quit(1)
		return
	for scout_id in launched["members"]:
		if bool(sim.get_citizen_by_id(int(scout_id)).get("on_expedition",false)):
			push_error("SMOKE: Recalled survivor remains locked on expedition")
			quit(1)
			return
	if not bool(sim.field_objectives.get("expedition",false)):
		push_error("SMOKE: Salvage expedition did not advance campaign objectives")
		quit(1)
		return
	instance.world_map_mode = false
	# No mutually exclusive screens may remain layered after keyboard tabs.
	instance.world_map_mode = true
	instance.governance_mode = false
	var toggle := InputEventKey.new()
	toggle.pressed = true
	toggle.keycode = KEY_V
	instance._unhandled_input(toggle)
	if instance.world_map_mode or not instance.governance_mode:
		push_error("SMOKE: Govern left the broken regional map open behind it")
		quit(1)
		return
	toggle.keycode = KEY_B
	instance._unhandled_input(toggle)
	if not instance.build_mode or instance.governance_mode:
		push_error("SMOKE: Keyboard Build overlaps an existing command screen")
		quit(1)
		return
	toggle.keycode = KEY_ESCAPE
	instance._unhandled_input(toggle)
	# Real faction discovery path: before radio expansion, the diplomacy UI
	# must lead players to the already-discovered relay, not a dead-end panel.
	instance.faction_mode = true
	instance.civilization_mode = false
	if not sim.faction_simulation.get_visible_factions(sim).is_empty():
		push_error("SMOKE: Initial factions incorrectly bypass fog of war")
		quit(1)
		return
	if str(instance._panel_action_items()[0][0]) != "FIND RELAY":
		push_error("SMOKE: Empty factions screen provides no actionable radio-relay route")
		quit(1)
		return
	instance._handle_panel_action_click(instance._panel_action_rect(0,2).get_center())
	if not instance.world_map_mode or instance.faction_mode or instance.selected_world_location_id != 3:
		push_error("SMOKE: Find Relay action did not navigate to actual North Ridge Relay")
		quit(1)
		return
	instance.world_map_mode = false
	# Discover a genuine faction location and verify an actual aid transaction.
	var contact: Dictionary = sim.world_simulation.get_location_by_id(9)
	contact["discovered"] = true
	instance.faction_mode = true
	var known_factions := sim.faction_simulation.get_visible_factions(sim)
	if not known_factions.has("Cedar Union"):
		push_error("SMOKE: Faction visibility ignores discovered world location")
		quit(1)
		return
	instance._handle_command_content_click(SettlementUILayout.side_panel(screen,480.0).position+Vector2(40,65))
	if instance.faction_index != 0:
		push_error("SMOKE: Faction portrait tab does not select a discovered neighbor")
		quit(1)
		return
	sim.stockpiles["command"]["food"] = maxf(25.0,float(sim.stockpiles["command"].get("food",0.0)))
	sim.stockpiles["medical"]["medicine"] = maxf(5.0,float(sim.stockpiles["medical"].get("medicine",0.0)))
	var old_reputation := float(sim.faction_simulation.factions["Cedar Union"]["reputation"])
	instance._handle_panel_action_click(instance._panel_action_rect(2,6).get_center())
	if float(sim.faction_simulation.factions["Cedar Union"]["reputation"]) <= old_reputation:
		push_error("SMOKE: Faction SEND AID does not change actual diplomatic reputation")
		quit(1)
		return
	contact["discovered"] = false
	instance.faction_mode = false

	# Nation is six readable, clickable screens, not one unreadable wall of
	# eight-point keyboard commands. Every tab must match shared geometry.
	instance.civilization_mode = true
	for target in [Vector2(960,720),Vector2(1280,720),Vector2(1366,768)]:
		var nation_area := SettlementUILayout.side_panel(target,620.0)
		for i in range(6):
			var tab := SettlementUILayout.civilization_tab_rect(target,i)
			if not nation_area.encloses(tab):
				push_error("SMOKE: Nation tab extends outside command panel")
				quit(1)
				return
	for i in range(6):
		var tab := SettlementUILayout.civilization_tab_rect(screen,i)
		if not instance._handle_command_content_click(tab.get_center()) or instance.civilization_tab != i:
			push_error("SMOKE: Nation page tab not clickable: "+str(i))
			quit(1)
			return
		if instance._panel_action_items().is_empty():
			push_error("SMOKE: Nation tab missing its contextual actions")
			quit(1)
			return
	instance.civilization_tab = 3
	var nation_panel := SettlementUILayout.side_panel(screen,620.0)
	var selected_project_rect := Rect2(nation_panel.position+Vector2(21,214),Vector2(nation_panel.size.x-43,46))
	instance._handle_command_content_click(selected_project_rect.get_center())
	if instance.civilization_recovery_project_index != 1:
		push_error("SMOKE: Recovery-project cards do not select actual projects")
		quit(1)
		return
	sim.stockpiles["industry"]["materials"] = maxf(35.0,float(sim.stockpiles["industry"].get("materials",0.0)))
	sim.stockpiles["command"]["water"] = maxf(70.0,float(sim.stockpiles["command"].get("water",0.0)))
	var old_progress := sim.civilization_simulation.get_recovery_project_progress("Clean Water Network")
	instance._handle_panel_action_click(instance._panel_action_rect(1,3).get_center())
	if sim.civilization_simulation.get_recovery_project_progress("Clean Water Network") <= old_progress:
		push_error("SMOKE: Nation CONTRIBUTE did not consume resources and progress real recovery")
		quit(1)
		return
	instance.civilization_tab = 4
	var old_autonomy := str(sim.civilization_simulation.civilization_policies["autonomy"])
	instance._handle_panel_action_click(instance._panel_action_rect(0,8).get_center())
	if str(sim.civilization_simulation.civilization_policies["autonomy"]) == old_autonomy:
		push_error("SMOKE: Nation policy action did not affect real autonomy rules")
		quit(1)
		return
	instance.civilization_mode = false
	if instance._display_settlement_name() != "Last Haven":
		push_error("SMOKE: Old Site-01 developer jargon still appears in player identity")
		quit(1)
		return
	# A practical resource HUD lets players resolve a power shortfall with a
	# real generator blueprint, not another abstract warning light.
	instance.governance_mode = false
	instance.build_mode = false
	var power_card: Rect2 = SettlementUILayout.resource_rects(screen)[3]
	if not instance._handle_resource_chip_click(power_card.get_center()) or not instance.build_mode:
		push_error("SMOKE: Power telemetry does not open functional construction")
		quit(1)
		return
	if str(sim.get_build_catalog()[instance.build_catalog_index]["type"]) != "generator":
		push_error("SMOKE: Power telemetry selected the wrong construction blueprint")
		quit(1)
		return
	instance.build_mode = false
	if not instance._handle_resource_chip_click(SettlementUILayout.resource_rects(screen)[0].get_center()) or not instance.workforce_mode:
		push_error("SMOKE: Population telemetry cannot open playable workforce command")
		quit(1)
		return
	# Workforce uses the same rectangles for drawing and mouse hits. Reassign
	# a real resident and verify that production's primary job actually changes.
	var roster := sim.get_settlement_citizens()
	if roster.is_empty():
		push_error("SMOKE: Workforce roster unexpectedly empty")
		quit(1)
		return
	instance._handle_workforce_click(SettlementUILayout.workforce_row(screen,0).get_center())
	if instance.workforce_selected_id != int(roster[0]["id"]):
		push_error("SMOKE: Workforce roster row fails to select survivor")
		quit(1)
		return
	var original_job: String = str(roster[0]["job"])
	var new_job := "Farmer" if original_job!="Farmer" else "Engineer"
	var job_index := CitizenFactory.JOBS.find(new_job)
	instance._handle_workforce_click(SettlementUILayout.workforce_job(screen,job_index).get_center())
	if str(roster[0]["job"])!=new_job or int(roster[0]["target_blueprint_id"])!=0:
		push_error("SMOKE: Job selection failed to change real production assignment")
		quit(1)
		return
	# A Builder changing job cannot leave a claimed blueprint behind.
	roster[0]["job"]="Builder"
	roster[0]["target_blueprint_id"]=9002
	var held_blueprint: Dictionary={"id":9002,"assigned_builder":int(roster[0]["id"])}
	sim.blueprints.append(held_blueprint)
	if not sim.assign_citizen_job(roster[0],"Engineer") or int(held_blueprint["assigned_builder"])!=0:
		push_error("SMOKE: Reassigned Builder left stale construction lock")
		quit(1)
		return
	sim.blueprints.erase(held_blueprint)
	# The redesigned personnel command makes both shift and duty buttons real,
	# without requiring a second survivor inspector to change assignments.
	var old_roster_shift := str(roster[0]["shift"])
	instance._handle_workforce_click(SettlementUILayout.workforce_duty_control(screen,0).get_center())
	if str(roster[0]["shift"])==old_roster_shift:
		push_error("SMOKE: DPN Workforce SHIFT button does not change actual survivor shift")
		quit(1)
		return
	var prior_duty := sim.is_selected_work_enabled(roster[0])
	instance._handle_workforce_click(SettlementUILayout.workforce_duty_control(screen,1).get_center())
	if sim.is_selected_work_enabled(roster[0])==prior_duty:
		push_error("SMOKE: DPN Workforce DUTY control is cosmetic rather than actionable")
		quit(1)
		return
	instance._handle_workforce_click(SettlementUILayout.workforce_duty_control(screen,1).get_center())
	if sim.is_selected_work_enabled(roster[0])!=prior_duty:
		push_error("SMOKE: Workforce duty cannot be restored through command controls")
		quit(1)
		return
	# Suspending a construction worker must unclaim their worksite for peers.
	roster[0]["job"]="Builder"
	roster[0]["work_priority"]["Builder"]=3
	roster[0]["target_blueprint_id"]=9003
	var off_duty_plan: Dictionary={"id":9003,"assigned_builder":int(roster[0]["id"])}
	sim.blueprints.append(off_duty_plan)
	instance._handle_workforce_click(SettlementUILayout.workforce_duty_control(screen,1).get_center())
	if sim.is_selected_work_enabled(roster[0]) or int(off_duty_plan["assigned_builder"])!=0 or int(roster[0]["target_blueprint_id"])!=0:
		push_error("SMOKE: Off-duty Builder left a blocked reserved blueprint")
		quit(1)
		return
	sim.blueprints.erase(off_duty_plan)
	sim.assign_citizen_job(roster[0],"Engineer")
	# Children and away teams must never be silently reassigned.
	var second_person: Dictionary=roster[1]
	var old_age: int=int(second_person["age"])
	var old_role: String=str(second_person["job"])
	second_person["age"]=8
	second_person["job"]="Child"
	if sim.assign_citizen_job(second_person,"Guard"):
		push_error("SMOKE: Child was assigned adult guard duty")
		quit(1)
		return
	second_person["age"]=old_age
	second_person["job"]=old_role
	# Pagination is a real mouse action, with no world input passthrough.
	if roster.size()>SettlementUILayout.workforce_page_size(screen):
		instance._handle_workforce_click(SettlementUILayout.workforce_action(screen,1).get_center())
		if instance.workforce_page!=1:
			push_error("SMOKE: Workforce page navigation is not clickable")
			quit(1)
			return
	instance._handle_workforce_click(SettlementUILayout.workforce_action(screen,2).get_center())
	if instance.workforce_mode:
		push_error("SMOKE: Workforce close control did not dismiss overlay")
		quit(1)
		return
	for target_size in [Vector2(960,720),Vector2(1280,720),Vector2(1366,768),Vector2(1024,600)]:
		var personnel_panel := SettlementUILayout.workforce_panel(target_size)
		for role_i in range(CitizenFactory.JOBS.size()):
			if not personnel_panel.encloses(SettlementUILayout.workforce_job(target_size,role_i)):
				push_error("SMOKE: Workforce job target falls outside modal")
				quit(1)
				return
		for row_i in range(SettlementUILayout.workforce_page_size(target_size)):
			if not personnel_panel.encloses(SettlementUILayout.workforce_row(target_size,row_i)):
				push_error("SMOKE: Workforce roster target falls outside modal")
				quit(1)
				return
		for action_i in range(3):
			if not personnel_panel.encloses(SettlementUILayout.workforce_action(target_size,action_i)):
				push_error("SMOKE: Workforce page action falls outside modal")
				quit(1)
				return
		for control_i in range(2):
			if not personnel_panel.encloses(SettlementUILayout.workforce_duty_control(target_size,control_i)):
				push_error("SMOKE: DPN workforce shift/duty control falls outside modal")
				quit(1)
				return
	# Keyboard opens and closes the same command, not a second UI state.
	var f6 := InputEventKey.new()
	f6.keycode=KEY_F6
	f6.pressed=true
	instance._unhandled_input(f6)
	if not instance.workforce_mode:
		push_error("SMOKE: F6 failed to open workforce")
		quit(1)
		return
	instance._unhandled_input(f6)
	if instance.workforce_mode:
		push_error("SMOKE: F6 failed to close workforce")
		quit(1)
		return
	if not instance._handle_resource_chip_click(SettlementUILayout.resource_rects(screen)[5].get_center()) or not instance.governance_mode:
		push_error("SMOKE: Morale telemetry cannot open real governance controls")
		quit(1)
		return
	instance.governance_mode = false
	# Speed controls are gameplay buttons, not a decorative RUNNING label.
	var old_speed: float=sim.speed
	var old_pause: bool=sim.paused
	if not instance._handle_time_control_click(SettlementUILayout.time_control(screen,0).get_center()) or sim.paused==old_pause:
		push_error("SMOKE: Clickable timeline failed to toggle pause")
		quit(1)
		return
	if not instance._handle_time_control_click(SettlementUILayout.time_control(screen,2).get_center()) or sim.paused or not is_equal_approx(sim.speed,4.0):
		push_error("SMOKE: Timeline 4x speed failed to resume simulation")
		quit(1)
		return
	sim.speed=old_speed
	sim.paused=old_pause
	for target_size in [Vector2(960,720),Vector2(1280,720),Vector2(1366,768)]:
		for ctrl_i in range(4):
			var control := SettlementUILayout.time_control(target_size,ctrl_i)
			if control.end.y>SettlementUILayout.navbar_rect(target_size,0).position.y or control.end.x>target_size.x:
				push_error("SMOKE: Playback control collides with bottom navigation")
				quit(1)
				return
	# Food and water warning text now provides a one-click recovery route.
	var remembered_food: float=float(sim.resources["food"])
	var remembered_water: float=float(sim.resources["water"])
	sim.resources["food"]=0.0
	sim.resources["water"]=float(sim.get_alive_citizens().size())*10.0
	var warning_hit := Vector2(screen.x-80.0,66.0)
	instance.build_mode=false
	if not instance._handle_resource_chip_click(warning_hit) or not instance.build_mode or str(sim.get_build_catalog()[instance.build_catalog_index]["type"])!="farm":
		push_error("SMOKE: Food emergency does not open the farm blueprint")
		quit(1)
		return
	sim.resources["food"]=remembered_food
	sim.resources["water"]=0.0
	instance.build_mode=false
	if not instance._handle_resource_chip_click(warning_hit) or not instance.build_mode or str(sim.get_build_catalog()[instance.build_catalog_index]["type"])!="purifier":
		push_error("SMOKE: Water emergency does not open the purifier blueprint")
		quit(1)
		return
	sim.resources["water"]=remembered_water
	instance.build_mode=false

	# The branding area must explain the home settlement, open a real briefing,
	# and close without sending clicks into the 3D construction world.
	for target_size in [Vector2(960,720),Vector2(1280,720),Vector2(1366,768)]:
		var identity: Rect2 = SettlementUILayout.identity_rect(target_size)
		var overview: Rect2 = SettlementUILayout.overview_rect(target_size)
		if identity.end.x > SettlementUILayout.resource_rects(target_size)[0].position.x:
			push_error("SMOKE: Home-base identity collides with the population indicator")
			quit(1)
			return
		if overview.end.x > target_size.x or overview.end.y > target_size.y-SettlementUILayout.BOTTOM_H:
			push_error("SMOKE: Clickable settlement overview escapes the usable screen")
			quit(1)
			return
		for button in range(3):
			if not overview.has_point(SettlementUILayout.overview_button_rect(target_size,button).get_center()):
				push_error("SMOKE: Overview action outside its modal panel")
				quit(1)
				return
	var home_identity: Rect2 = SettlementUILayout.identity_rect(screen)
	if not instance._handle_overview_click(home_identity.get_center()) or not instance.overview_visible:
		push_error("SMOKE: Home-base header cannot open readable overview")
		quit(1)
		return
	if not instance._next_settlement_goal().contains("Inspect") and not instance._next_settlement_goal().contains("construction") and not instance._next_settlement_goal().contains("Explore") and not instance._next_settlement_goal().contains("Day 2") and not instance._next_settlement_goal().contains("completed"):
		push_error("SMOKE: Settlement overview has no actionable next-step guidance")
		quit(1)
		return
	var safe_click: Vector2 = Vector2(screen.x*0.5,screen.y*0.5)
	if not instance._handle_overview_click(safe_click) or instance.overview_visible:
		push_error("SMOKE: Clicking outside the briefing did not consume/close it")
		quit(1)
		return
	instance._handle_overview_click(home_identity.get_center())
	var close_key := InputEventKey.new()
	close_key.pressed = true
	close_key.keycode = KEY_ESCAPE
	instance._unhandled_input(close_key)
	if instance.overview_visible:
		push_error("SMOKE: ESC does not close settlement briefing")
		quit(1)
		return
	instance._handle_overview_click(home_identity.get_center())
	instance._handle_overview_click(SettlementUILayout.overview_button_rect(screen,1).get_center())
	if instance.overview_visible or not instance.field_directives_visible:
		push_error("SMOKE: Overview SHOW GOALS cannot reveal field directives")
		quit(1)
		return
	instance._handle_overview_click(home_identity.get_center())
	instance._handle_overview_click(SettlementUILayout.overview_button_rect(screen,0).get_center())
	if instance.overview_visible or not instance.build_mode:
		push_error("SMOKE: Overview OPEN BUILD does not activate construction")
		quit(1)
		return
	if sim.federal_governance_simulation.federal_treasury != treasury_before:
		push_error("SMOKE: Opening Build from briefing unexpectedly spent treasury")
		quit(1)
		return
	instance._handle_toolbar_click(build_button)
	# The overview smoke flow intentionally expanded objectives; reset to the
	# initial collapsed state before checking the F3 open/close regressions.
	instance.field_directives_visible = false
	# Renderer-specific regression tests: lighting must have a real
	# night/day difference and the new terrain must be an actual 3D mesh.
	var world: SettlementWorld3D = instance.settlement_world
	var ground := world.terrain_layer.get_node_or_null("PlayableHeightfieldTerrain") as MeshInstance3D
	if ground == null or not (ground.mesh is ArrayMesh):
		push_error("SMOKE: Height-mapped 3D terrain is unavailable")
		quit(1)
		return
	for key in ["roof", "wall", "concrete", "rust", "asphalt"]:
		var photo := world.materials[key] as StandardMaterial3D
		if photo == null or photo.albedo_texture == null:
			push_error("SMOKE: Photographic PBR diffuse material missing for " + key)
			quit(1)
			return
		if not photo.normal_enabled or photo.normal_texture == null:
			push_error("SMOKE: Photographic PBR normal map missing for " + key)
			quit(1)
			return
	world._update_daylight(12.0)
	var sunlight_noon := world.light.light_energy
	world._update_daylight(23.0)
	var sunlight_night := world.light.light_energy
	if sunlight_noon < sunlight_night * 3.0 or world.command_lamp.light_energy < 0.3:
		push_error("SMOKE: Daylight/night lighting curve is broken")
		quit(1)
		return
	if world.animated_vent_fans.is_empty():
		push_error("SMOKE: Powered mechanical visual details are missing")
		quit(1)
		return
	var rotor := world.animated_vent_fans[0]
	var before_rotation := rotor.rotation.y
	world._animate_machinery(0.25, true)
	if is_equal_approx(before_rotation, rotor.rotation.y):
		push_error("SMOKE: Running industrial fan has no motion")
		quit(1)
		return
	world._animate_machinery(0.25, false)
	if not is_equal_approx(rotor.rotation.y, before_rotation + 0.25 * 2.8):
		push_error("SMOKE: Industrial fan did not stop without power")
		quit(1)
		return
	# The ground texture must be visibly dark, not a shader fallback that
	# renders as a nearly white surface on the player's Windows GPU.
	var ground_material := ground.material_override as StandardMaterial3D
	if ground_material == null or ground_material.albedo_texture == null:
		push_error("SMOKE: Baked earth/gravel albedo texture is not bound to terrain")
		quit(1)
		return
	if ground_material.cull_mode != BaseMaterial3D.CULL_DISABLED:
		push_error("SMOKE: Generated ground triangles can still be backface-culled")
		quit(1)
		return
	var fallback_core := world.terrain_layer.get_node_or_null("GroundFailsafeSettlementCore") as MeshInstance3D
	var fallback_outer := world.terrain_layer.get_node_or_null("GroundFailsafeOuter") as MeshInstance3D
	if fallback_core == null or fallback_outer == null:
		push_error("SMOKE: Opaque sky-blocking ground layers missing")
		quit(1)
		return
	if fallback_core.position.y > -0.15 or fallback_core.position.y < -0.6:
		push_error("SMOKE: Opaque settlement core is not directly below gameplay ground")
		quit(1)
		return
	var failsafe_material := fallback_core.material_override as StandardMaterial3D
	if failsafe_material == null or failsafe_material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
		push_error("SMOKE: Sky-blocking floor has invalid material")
		quit(1)
		return
	if failsafe_material.albedo_color.r > 0.3:
		push_error("SMOKE: Failsafe floor is too bright")
		quit(1)
		return
	var sampled_rubble := world.terrain_layer.get_node_or_null("DarkSoilGravelAndRubble") as MultiMeshInstance3D
	if sampled_rubble == null or sampled_rubble.multimesh == null:
		push_error("SMOKE: Terrain rubble was not created")
		quit(1)
		return
	if not (sampled_rubble.multimesh.mesh is SphereMesh):
		push_error("SMOKE: Terrain still contains square white confetti instead of stones")
		quit(1)
		return
	var sample_image := GroundAppearance.bake_image()
	var sample_brightness := GroundAppearance.sample_luminance(sample_image)
	if sample_brightness < 0.07 or sample_brightness > 0.44:
		push_error("SMOKE: Terrain contrast outside target luminance range")
		quit(1)
		return
	if world.camera_distance > 51.0:
		push_error("SMOKE: Default 3D camera is still zoomed too far away")
		quit(1)
		return
	if instance.field_directives_visible:
		push_error("SMOKE: Full-height mission panel should begin collapsed")
		quit(1)
		return
	event.keycode = KEY_F3
	instance._unhandled_input(event)
	if not instance.field_directives_visible:
		push_error("SMOKE: F3 did not expand settlement directives")
		quit(1)
		return
	instance._unhandled_input(event)
	if instance.field_directives_visible:
		push_error("SMOKE: F3 did not collapse settlement directives")
		quit(1)
		return
	# Artwork regression: a farm must contain actual leaf meshes rather than
	# the old evenly spaced sphere stand-ins.
	var canopy: MultiMeshInstance3D = null
	for structure in world.structure_layer.get_children():
		var found := structure.get_node_or_null("LeafyCropCanopy") as MultiMeshInstance3D
		if found != null:
			canopy = found
			break
	if canopy == null or canopy.multimesh == null or canopy.multimesh.instance_count < 270:
		push_error("SMOKE: Mesh foliage did not replace spherical crop rows")
		quit(1)
		return
	var crop_stems := canopy.get_parent().get_node_or_null("CropStems") as MultiMeshInstance3D
	if crop_stems == null or crop_stems.multimesh.instance_count != 54:
		push_error("SMOKE: Farm plant stalk layout invalid")
		quit(1)
		return
	# Verify generic procedural human figures are no longer the old basic
	# glowing construction cylinders; imported art remains an optional path.
	if world.people.is_empty():
		push_error("SMOKE: Visual survivor collection is empty")
		quit(1)
		return
	var npc: Node3D = world.people.values()[0]
	var model := npc.get_node_or_null("ProductionArt") as Node3D
	if model == null:
		push_error("SMOKE: Real CC0 glTF survivor did not replace the capsule placeholder")
		quit(1)
		return
	# The external GLB was previously displayed as a white mannequin whose
	# height was inconsistent with the modular architecture. Validate that
	# every spawned survivor is scaled, costumed and equipped.
	for entry in world.people.values():
		var person := entry as Node3D
		var rig := person.get_node_or_null("ProductionArt") as Node3D
		if rig == null:
			push_error("SMOKE: A survivor reverted to placeholder geometry")
			quit(1)
			return
		var rendered_height := float(rig.get_meta("visual_height_m", -1.0))
		if rendered_height < 1.6 or rendered_height > 2.1:
			push_error("SMOKE: Human rig not scaled to plausible world dimensions")
			quit(1)
			return
		if int(rig.get_meta("garment_mesh_count", 0)) < 1:
			push_error("SMOKE: White source mannequin was not recolored")
			quit(1)
			return
		var hiking_pack := person.get_node_or_null("SurvivorEquipment/Backpack") as MeshInstance3D
		if hiking_pack == null or not (hiking_pack.mesh is CapsuleMesh):
			push_error("SMOKE: Survivor still wearing oversized square block backpack")
			quit(1)
			return
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		push_error("SMOKE: Imported survivor lacks rigged human skeleton")
		quit(1)
		return
	var animator := world._find_animation_player(model)
	if animator == null or animator.get_animation_list().is_empty():
		push_error("SMOKE: CC0 survivor has no walking/idle animation clips")
		quit(1)
		return
	world._animate_imported_survivor(npc, true)
	if not animator.is_playing():
		push_error("SMOKE: Animated glTF survivor cannot play movement clip")
		quit(1)
		return
	# The initial settlement must contain actual modular architecture,
	# with visible door openings instead of a single solid building cube.
	for structure in world.structure_layer.get_children():
		var shell := structure.get_node_or_null("RearWall")
		if shell == null:
			continue
		if structure.get_node_or_null("EntryDoor") == null:
			push_error("SMOKE: Building shell missing its real front access opening")
			quit(1)
			return
	var house_found := false
	var clinic_found := false
	var workshop_found := false
	for structure in world.structure_layer.get_children():
		if structure.get_node_or_null("PitchedHousingRoof") != null:
			house_found = true
			if structure.get_node_or_null("ShelterGableEndWalls") == null:
				push_error("SMOKE: Pitched roof is missing realistic filled end gables")
				quit(1)
				return
		if structure.get_node_or_null("ClinicRoof") != null:
			clinic_found = true
		if structure.get_node_or_null("RaisedMachineRoom") != null:
			workshop_found = true
	if not house_found or not clinic_found or not workshop_found:
		push_error("SMOKE: Unique housing, medical or workshop roof geometry missing")
		quit(1)
		return
	var workwear := world.materials["workwear"] as StandardMaterial3D
	if workwear == null or workwear.emission_enabled:
		push_error("SMOKE: Workwear must not glow as if it is a warning lamp")
		quit(1)
		return
	# Quick-start cards are real clickable navigation, not a tutorial-only
	# text wall. Shared hitboxes must stay inside the modal on typical PCs.
	for display_size in [Vector2(960,720),Vector2(1280,720),Vector2(1366,768)]:
		var guide_bounds := SettlementUILayout.guide_rect(display_size)
		for i in range(6):
			if not guide_bounds.encloses(SettlementUILayout.guide_lesson_rect(display_size,i)):
				push_error("SMOKE: Clickable guide card outside viewport: "+str(i))
				quit(1)
				return
	var mode_names := ["overview_visible","build_mode","world_map_mode","governance_mode","economy_mode","civilization_mode"]
	for i in range(6):
		instance.help_mode=true
		if not instance._handle_guide_click(SettlementUILayout.guide_lesson_rect(screen,i).get_center()):
			push_error("SMOKE: Quick-start lesson does not accept mouse click")
			quit(1)
			return
		if instance.help_mode or not bool(instance.get(mode_names[i])):
			push_error("SMOKE: Quick-start lesson failed to open live gameplay: "+mode_names[i])
			quit(1)
			return
	instance.help_mode=false
	instance.civilization_mode=false
	# A workshop stopped by a player must remain stopped after reloading a
	# current or pre-existing v14 settlement. No save-schema bump is required.
	sim.economy_simulation.set_production_paused(sim,true)
	var workshop_save := "user://settlement-workshop-smoke.json"
	if not sim.save_game(workshop_save):
		push_error("SMOKE: Could not persist industrial workshop state")
		quit(1)
		return
	sim.economy_simulation.production_paused=false
	if not sim.load_game(workshop_save) or not sim.economy_simulation.production_paused:
		push_error("SMOKE: Workshop pause was not restored from save")
		quit(1)
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(workshop_save))
	# Dynamic dust fronts must be a saved gameplay hazard, visible in 3D
	# and actionable by the player even during a power-shortfall alert.
	var weather: WeatherSimulation=sim.weather_simulation
	if weather.condition!=WeatherSimulation.CLEAR or not weather.begin_storm(sim,0.8,4.0):
		push_error("SMOKE: Weather failed to start a deterministic dust front")
		quit(1)
		return
	if weather.power_factor()>=1.0 or weather.water_factor()>=1.0 or weather.remaining_hours(sim)<3.99:
		push_error("SMOKE: Dust conditions do not impair real utilities or track duration")
		quit(1)
		return
	world.sync(sim,{}, {},false,Vector2(700,450),sim.get_build_catalog()[0],false,0.2)
	if world.weather_effects==null or world.weather_effects.dust==null or not world.weather_effects.dust.visible or world.weather_effects.dust.multimesh.instance_count<100:
		push_error("SMOKE: Dust front missing its efficient visible 3D airborne volume")
		quit(1)
		return
	if world.world_environment.fog_density<=0.002:
		push_error("SMOKE: Active storm does not change environment visibility")
		quit(1)
		return
	var saved_food: float=float(sim.resources["food"])
	var saved_water: float=float(sim.resources["water"])
	var saved_generated: float=float(sim.utility_state["power_generated"])
	var saved_demand: float=float(sim.utility_state["power_demand"])
	sim.resources["food"]=999.0
	sim.resources["water"]=999.0
	sim.utility_state["power_generated"]=0.0
	sim.utility_state["power_demand"]=99.0
	if str(instance._settlement_attention()[0])!="STORM: TAKE COVER":
		push_error("SMOKE: Storm shelter alert hidden behind its own power penalty")
		quit(1)
		return
	var storm_warning := Vector2(screen.x-80.0,66.0)
	if not instance._handle_resource_chip_click(storm_warning) or not weather.shelter_in_place:
		push_error("SMOKE: Storm shelter order cannot be issued via clickable warning")
		quit(1)
		return
	var field_survivor: Dictionary=sim.get_settlement_citizens()[0]
	field_survivor["job"]="Farmer"
	field_survivor["age"]=30
	field_survivor["health"]=95.0
	field_survivor["injury"]=""
	field_survivor["hunger"]=0.0
	field_survivor["thirst"]=0.0
	field_survivor["fatigue"]=0.0
	field_survivor["stress"]=0.0
	field_survivor["morale"]=90.0
	field_survivor["shift"]="DAY"
	field_survivor["incarcerated"]=false
	field_survivor["on_expedition"]=false
	var prior_hour: float=sim.hour
	sim.hour=10.0
	sim._choose_action(field_survivor)
	if str(field_survivor["current_action"])!="Shelter: Dust Storm":
		push_error("SMOKE: Shelter order did not stop exposed outdoor field duty")
		quit(1)
		return
	var prior_harvest: float=float(sim.stockpiles["farm"]["food"])
	sim._apply_citizen_work(field_survivor,2.0)
	if not is_equal_approx(float(sim.stockpiles["farm"]["food"]),prior_harvest):
		push_error("SMOKE: Sheltered farmer still produced crops outdoors")
		quit(1)
		return
	if str(instance._settlement_attention()[0])!="SHELTER ACTIVE" or not instance._handle_resource_chip_click(storm_warning) or weather.shelter_in_place:
		push_error("SMOKE: Storm shelter order cannot be safely released")
		quit(1)
		return
	if not weather.set_shelter_order(sim,true):
		push_error("SMOKE: Weather cannot reissue protection for save test")
		quit(1)
		return
	var weather_save := "user://settlement-weather-smoke.json"
	if not sim.save_game(weather_save):
		push_error("SMOKE: Could not write storm-compatible settlement save")
		quit(1)
		return
	weather.condition=WeatherSimulation.CLEAR
	weather.intensity=0.0
	weather.shelter_in_place=false
	if not sim.load_game(weather_save) or sim.weather_simulation.condition!=WeatherSimulation.DUST_STORM or not sim.weather_simulation.shelter_in_place or not is_equal_approx(sim.weather_simulation.intensity,0.8):
		push_error("SMOKE: Weather front or player shelter order did not survive save/load")
		quit(1)
		return
	# A pre-weather v14 save has no weather key and must load safely.
	var prior_json: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(weather_save))
	prior_json.erase("weather")
	var legacy_file := FileAccess.open(weather_save,FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(prior_json))
	legacy_file.close()
	if not sim.load_game(weather_save) or sim.weather_simulation.condition!=WeatherSimulation.CLEAR or sim.weather_simulation.shelter_in_place:
		push_error("SMOKE: Existing v14 saves without weather fail to load clearly")
		quit(1)
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(weather_save))
	world.sync(sim,{}, {},false,Vector2(700,450),sim.get_build_catalog()[0],false,0.2)
	if world.weather_effects.dust.visible or world.world_environment.fog_density>0.002:
		push_error("SMOKE: Airborne dust/fog persists when the storm ends")
		quit(1)
		return
	sim.hour=prior_hour
	sim.resources["food"]=saved_food
	sim.resources["water"]=saved_water
	sim.utility_state["power_generated"]=saved_generated
	sim.utility_state["power_demand"]=saved_demand
	# A player-reported F2 trap is a release blocker. Prove the console
	# is always dismissible and all mouse actions stay inside its modal layer.
	var incident_screen: Vector2=instance.get_viewport_rect().size
	var events_before := sim.events.size()
	sim.add_event("GRID TRIP","Primary generator emergency test.","critical")
	sim.add_event("GRID TRIP","Primary generator emergency test.","critical")
	var incident_all := SettlementIncidentUI.groups(sim.events,0,{})
	if incident_all.is_empty() or int(incident_all[0].get("occurrences",0))!=2:
		push_error("SMOKE: Repeated incident history not grouped into a readable row")
		quit(1)
		return
	if SettlementIncidentUI.route_for_event(incident_all[0])!="BUILD":
		push_error("SMOKE: Incident does not point to its actual relevant game system")
		quit(1)
		return
	instance.economy_mode=true
	instance._incident_open()
	var incident_frame := SettlementIncidentUI.panel_rect(incident_screen)
	if not instance.incident_panel_visible or not incident_frame.encloses(SettlementIncidentUI.close_rect(incident_screen)):
		push_error("SMOKE: F2 console has no reachable close icon")
		quit(1)
		return
	for i in range(4):
		if not incident_frame.encloses(SettlementIncidentUI.tab_rect(incident_screen,i)) or not incident_frame.encloses(SettlementIncidentUI.action_rect(incident_screen,i)):
			push_error("SMOKE: Responsive incident control falls outside visible command panel")
			quit(1)
			return
	instance._handle_incident_click(SettlementIncidentUI.tab_rect(incident_screen,1).get_center())
	if instance.incident_filter_index!=1 or SettlementIncidentUI.groups(sim.events,1,{}).is_empty():
		push_error("SMOKE: Severity filter is not operational")
		quit(1)
		return
	instance._handle_incident_click(SettlementIncidentUI.row_rect(incident_screen,0).get_center())
	instance._handle_incident_click(SettlementIncidentUI.action_rect(incident_screen,0).get_center())
	if instance.incident_acknowledged.is_empty() or sim.events.size()!=events_before+2:
		push_error("SMOKE: Incident acknowledgement corrupts history or has no effect")
		quit(1)
		return
	instance._handle_incident_click(SettlementIncidentUI.tab_rect(incident_screen,3).get_center())
	var unread_groups := instance._incident_entries()
	if not unread_groups.is_empty() and bool(unread_groups[0].get("read",false)):
		push_error("SMOKE: Unread filter includes acknowledged events")
		quit(1)
		return
	var active_economy := instance.economy_mode
	if not instance._handle_incident_click(Vector2(2.0,incident_screen.y*0.5)) or instance.incident_panel_visible or instance.economy_mode!=active_economy:
		push_error("SMOKE: Outside click leaked through F2 modal or failed to dismiss")
		quit(1)
		return
	instance._incident_open()
	instance._handle_incident_click(SettlementIncidentUI.close_rect(incident_screen).get_center())
	if instance.incident_panel_visible:
		push_error("SMOKE: Incident X close button is unresponsive")
		quit(1)
		return
	instance._incident_open()
	instance._handle_incident_click(SettlementIncidentUI.action_rect(incident_screen,3).get_center())
	if instance.incident_panel_visible:
		push_error("SMOKE: Incident CLOSE footer is unresponsive")
		quit(1)
		return
	var incident_key := InputEventKey.new()
	incident_key.keycode=KEY_F2
	incident_key.pressed=true
	instance._unhandled_input(incident_key)
	if not instance.incident_panel_visible:
		push_error("SMOKE: F2 did not open incident modal")
		quit(1)
		return
	instance._unhandled_input(incident_key)
	if instance.incident_panel_visible:
		push_error("SMOKE: F2 cannot toggle incident modal closed")
		quit(1)
		return
	instance._incident_open()
	var escape_key := InputEventKey.new()
	escape_key.keycode=KEY_ESCAPE
	escape_key.pressed=true
	instance._unhandled_input(escape_key)
	if instance.incident_panel_visible or not instance.economy_mode:
		push_error("SMOKE: Escape must close incidents before underlying Economy mode")
		quit(1)
		return
	instance.incident_filter_index=0
	instance.incident_selected_index=0
	instance.incident_acknowledged.clear()
	instance._incident_open()
	instance._handle_incident_click(SettlementIncidentUI.action_rect(incident_screen,2).get_center())
	if instance.incident_panel_visible or not instance.build_mode:
		push_error("SMOKE: Incident OPEN SYSTEM did not navigate to linked Build controls")
		quit(1)
		return
	var build_close := SettlementUILayout.command_close_rect(instance._active_command_panel())
	if not instance._handle_command_close_click(build_close.get_center()) or instance.build_mode:
		push_error("SMOKE: Build screen X close control is not functional")
		quit(1)
		return
	for mode_key in ["governance_mode","economy_mode","faction_mode","civilization_mode","world_map_mode","help_mode"]:
		instance.set(mode_key,true)
		var mode_panel: Rect2=instance._active_command_panel()
		if mode_panel.size.x<=0.0 or not instance._handle_command_close_click(SettlementUILayout.command_close_rect(mode_panel).get_center()) or bool(instance.get(mode_key)):
			push_error("SMOKE: Major management screen cannot close by mouse: "+mode_key)
			quit(1)
			return
	instance.incident_filter_index=0
	instance.incident_page=0
	instance.incident_selected_index=0
	instance.incident_acknowledged.clear()
	print("PLAYTEST SMOKE PASS: responsive F2 incident console, dismissals, filters, acknowledgements, route actions, and all command X buttons")
	print("PLAYTEST SMOKE PASS: storm hazards/shelter/save compatibility, live 3D atmosphere, 3D industrial animation, region and workforce gameplay")
	instance.queue_free()
	quit(0)
