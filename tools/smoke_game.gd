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
	instance._handle_objective_click(Vector2(70, 210))
	if not bool(sim.field_objectives["inspected"]) or instance.selected_citizen.is_empty():
		push_error("SMOKE: Survivor inspection directive did not complete")
		quit(1)
		return
	instance._handle_objective_click(Vector2(70, 242))
	if not instance.build_mode:
		push_error("SMOKE: Directive did not open construction")
		quit(1)
		return
	instance._handle_build_palette_click(Vector2(75, 214 + 2 * 30 + 9))
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
	instance._handle_inspector_click(Vector2(instance.get_viewport_rect().size.x - 200, 307))
	if not sim.blueprints.is_empty():
		push_error("SMOKE: Clickable blueprint cancellation failed")
		quit(1)
		return
	# Toolbar Build is not the same action as keyboard B in Civilization
	# Command. It must never trigger emergency federal spending.
	instance.civilization_mode = true
	instance.world_map_mode = true
	instance.build_mode = false
	sim.federal_governance_simulation.federal_treasury = 300.0
	var treasury_before: float = sim.federal_governance_simulation.federal_treasury
	var build_button := Vector2(50, instance.get_viewport_rect().size.y - 36.0)
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
	var ground := world.terrain_layer.get_child(0) as MeshInstance3D
	if ground == null or not (ground.mesh is ArrayMesh):
		push_error("SMOKE: Height-mapped 3D terrain is unavailable")
		quit(1)
		return
	if not (world.materials["roof"] is ShaderMaterial):
		push_error("SMOKE: Weathered physical roof material is unavailable")
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
	print("PLAYTEST SMOKE PASS: 3D world, realistic terrain, weathered materials, day-night, powered machines, gameplay and save/load")
	instance.queue_free()
	quit(0)
