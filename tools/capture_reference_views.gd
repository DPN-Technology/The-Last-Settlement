extends SceneTree

# Actual OpenGL rendered captures, not a fake image-generation preview.
# Run with xvfb-run + Godot 4.3 gl_compatibility, no --headless flag.
func _initialize() -> void:
	call_deferred("_render_capture_suite")

func _save_frame(instance: Node, title: String) -> bool:
	await process_frame
	await RenderingServer.frame_post_draw
	var screen: Image=root.get_texture().get_image()
	if screen==null or screen.is_empty():
		push_error("VISUAL QA: empty rendered screen: "+title)
		return false
	var path: String="res://dist/visual/"+title+"_HUD.png"
	if screen.save_png(path)!=OK:
		push_error("VISUAL QA: cannot write "+path)
		return false
	var raw: Image=instance.settlement_viewport.get_texture().get_image()
	if raw==null or raw.is_empty() or raw.save_png("res://dist/visual/"+title+"_WORLD.png")!=OK:
		push_error("VISUAL QA: cannot save isolated world pass: "+title)
		return false
	print("VISUAL QA CAPTURE: "+path+" "+str(screen.get_width())+"x"+str(screen.get_height()))
	return true

func _render_capture_suite() -> void:
	var output := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://dist/visual"))
	if output!=OK:
		push_error("VISUAL QA: no output folder")
		quit(1)
		return
	var scene_resource := load("res://src/Main.tscn") as PackedScene
	if scene_resource==null:
		push_error("VISUAL QA: main scene unavailable")
		quit(1)
		return
	var game=scene_resource.instantiate()
	root.add_child(game)
	if game.settlement_world==null:
		push_error("VISUAL QA: game world missing")
		quit(1)
		return
	# Keep the simulation and 3D layout stable across all captured viewpoints.
	# Exteriors stay roofed for honest comparison with the cinematic settlement target.
	game.sim.paused=true
	game.sim.hour=8.1
	game.roof_view_mode=2
	game.settlement_world.pitch=deg_to_rad(52.0)
	game.settlement_world.yaw=0.0
	game.settlement_world.camera_distance=63.0
	game.settlement_world.focus=Vector3(4.0,0.0,2.0)
	game.settlement_world._position_camera()
	for frame in range(8):
		await process_frame
	if not await _save_frame(game,"01_Overview"):
		quit(1)
		return
	for target in ["housing","command","medical"]:
		var building: Dictionary={}
		for b in game.sim.buildings:
			if str(b.get("type",""))==target:
				building=b
				break
		if building.is_empty():
			push_error("VISUAL QA: cannot capture "+target)
			quit(1)
			return
		game.selected_building=building
		game.roof_view_mode=2
		game.settlement_world.focus_game(Vector2(building["position"]))
		game.settlement_world.camera_distance=24.0
		game.settlement_world._position_camera()
		for frame in range(5):
			await process_frame
		if not await _save_frame(game,"02_"+target):
			quit(1)
			return
	print("VISUAL QA: 4 fully rendered camera positions saved with 3D+unchanged HUD")
	quit()
