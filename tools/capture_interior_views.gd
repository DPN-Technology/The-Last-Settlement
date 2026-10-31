extends SceneTree

# Real OpenGL captures of deliberately inspected interiors (selected-building
# cutaway) plus each facility's entrance in normal exterior view.
# Run non-headless with gl_compatibility; writes to res://dist/visual/.
func _initialize() -> void:
	call_deferred("_render_interiors")

func _render_interiors() -> void:
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://dist/visual"))!=OK:
		push_error("INTERIOR QA: no output folder")
		quit(1)
		return
	var game=(load("res://src/Main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.sim.paused=true
	game.sim.hour=10.0
	game.roof_view_mode=0
	for target in ["medical","industry"]:
		var building: Dictionary={}
		for b in game.sim.buildings:
			if str(b.get("type",""))==target:
				building=b
				break
		if building.is_empty():
			push_error("INTERIOR QA: no building of type "+target)
			quit(1)
			return
		game.selected_building=building
		game.settlement_world.focus_game(Vector2(building["position"]))
		for view in [[20.0,55.0,0.0],[15.0,62.0,0.5]]:
			if not await _capture(game,view,"res://dist/visual/interior_%s_%d.png" % [target,int(view[0])]):
				return
		# Ordinary exterior gameplay view of the entrance side, roofs intact.
		game.selected_building={}
		game.roof_view_mode=2
		if not await _capture(game,[24.0,38.0,PI],"res://dist/visual/exterior_%s_entrance.png" % target):
			return
		game.roof_view_mode=0
	quit()

func _capture(game: Node, view: Array, path: String) -> bool:
	game.settlement_world.camera_distance=view[0]
	game.settlement_world.pitch=deg_to_rad(view[1])
	game.settlement_world.yaw=view[2]
	game.settlement_world._position_camera()
	for frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image=root.get_texture().get_image()
	if image==null or image.is_empty() or image.save_png(path)!=OK:
		push_error("INTERIOR QA: capture failed "+path)
		quit(1)
		return false
	print("INTERIOR QA CAPTURE: "+path)
	return true
