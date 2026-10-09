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
	if not (instance.settlement_visuals is SettlementVisuals):
		push_error("SMOKE: Scene visual renderer unavailable")
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
	print("PLAYTEST SMOKE PASS: scene, rendering, movement pause, clickable directives, build catalog, save/load and blueprint cancellation")
	instance.queue_free()
	quit(0)
