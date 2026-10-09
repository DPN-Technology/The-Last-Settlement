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
	instance._handle_build_palette_click(SettlementUILayout.build_palette(instance.get_viewport_rect().size, sim.get_build_catalog().size()).position + Vector2(45,70 + 2 * 28 + 10))
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
	# All toolbars and resource chips must fit in the live viewport and share
	# click geometry; previous hard-coded 118px/88px HUD obscured the 3D world.
	var screen := instance.get_viewport_rect().size
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
	print("PLAYTEST SMOKE PASS: compact responsive HUD and controls, gabled 3D roofs, survivor rigs, PBR and saves")
	instance.queue_free()
	quit(0)
