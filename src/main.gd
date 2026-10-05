extends Node2D

const BG := Color("#090b0e")
const GRID := Color("#231b1b")
const PANEL := Color("#12161bcc")
const PANEL_SOLID := Color("#12161b")
const PANEL_EDGE := Color("#4c3030")
const TEXT := Color("#e8e2db")
const MUTED := Color("#9b9188")
const GOOD := Color("#73c991")
const WARN := Color("#e6b566")
const BAD := Color("#e05252")
const ACCENT := Color("#c64242")
const RUST := Color("#a46d45")

var sim := SettlementSimulation.new()
var camera_offset := Vector2.ZERO
var zoom := 1.0
var dragging := false
var drag_origin := Vector2.ZERO
var selected_citizen: Dictionary = {}
var selected_building: Dictionary = {}
var build_mode := false
var build_catalog_index := 0
var mouse_world := Vector2.ZERO

func _ready() -> void:
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	sim.update(delta)
	_update_citizens(delta)
	queue_redraw()

func _update_citizens(delta: float) -> void:
	for c in sim.citizens:
		if not c["alive"]:
			continue
		if int(c.get("target_blueprint_id", 0)) > 0:
			var bp := sim.get_blueprint_by_id(int(c["target_blueprint_id"]))
			if not bp.is_empty():
				c["target"] = bp["position"]
				c["position"] = c["position"].move_toward(c["target"], 25.0 * delta * maxf(0.5, sim.speed))
				continue
		if c["target"] == Vector2.ZERO or c["position"].distance_to(c["target"]) < 8.0:
			var b := sim.get_building_by_type(c["target_building"])
			c["target"] = b["position"] + Vector2(
				sim.rng.randf_range(-float(b["size"].x) * 0.34, float(b["size"].x) * 0.34),
				sim.rng.randf_range(-float(b["size"].y) * 0.28, float(b["size"].y) * 0.28)
			)
		c["position"] = c["position"].move_toward(c["target"], 25.0 * delta * maxf(0.5, sim.speed))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), BG)
	_draw_world()
	_draw_hud()
	_draw_selection_panel()

func _world_point(p: Vector2) -> Vector2:
	return (p + camera_offset) * zoom

func _screen_to_world(p: Vector2) -> Vector2:
	return p / zoom - camera_offset

func _draw_world() -> void:
	for x in range(260, 1450, 40):
		draw_line(_world_point(Vector2(x, 150)), _world_point(Vector2(x, 790)), GRID, 1.0)
	for y in range(150, 820, 40):
		draw_line(_world_point(Vector2(260, y)), _world_point(Vector2(1450, y)), GRID, 1.0)

	for b in sim.buildings:
		var pos: Vector2 = _world_point(b["position"])
		var sz: Vector2 = b["size"] * zoom
		var rect := Rect2(pos - sz / 2.0, sz)
		var color := Color("#24282b")
		match b["type"]:
			"medical": color = Color("#20322f")
			"power": color = Color("#362c20")
			"farm": color = Color("#243024")
			"industry": color = Color("#30282a")
			"command": color = Color("#352322")
		draw_rect(rect, color, true)
		var edge := ACCENT if selected_building == b else PANEL_EDGE
		draw_rect(rect, edge, false, 2.0 if selected_building != b else 4.0)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-sz.x * 0.43, -sz.y * 0.12), b["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, TEXT)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-sz.x * 0.43, sz.y * 0.17), "COND %d%%" % int(b["condition"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)

	for bp in sim.blueprints:
		var bp_pos: Vector2 = _world_point(bp["position"])
		var bp_size: Vector2 = bp["size"] * zoom
		var bp_rect := Rect2(bp_pos - bp_size / 2.0, bp_size)
		draw_rect(bp_rect, Color(0.55, 0.18, 0.15, 0.18), true)
		draw_rect(bp_rect, ACCENT, false, 2.0)
		var pct := 100.0 * float(bp["progress"]) / maxf(1.0, float(bp["work_required"]))
		draw_string(ThemeDB.fallback_font, bp_pos + Vector2(-bp_size.x*0.42, 0), "%s %d%%" % [bp["name"], int(pct)], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TEXT)

	if build_mode:
		var definition := sim.get_build_catalog()[build_catalog_index]
		var ghost_pos := _world_point(Vector2(round(mouse_world.x / 20.0) * 20.0, round(mouse_world.y / 20.0) * 20.0))
		var ghost_size: Vector2 = definition["size"] * zoom
		var ghost_rect := Rect2(ghost_pos - ghost_size/2.0, ghost_size)
		var valid := sim.can_place_blueprint(Vector2(round(mouse_world.x / 20.0) * 20.0, round(mouse_world.y / 20.0) * 20.0), definition["size"])
		draw_rect(ghost_rect, Color(0.25,0.65,0.35,0.18) if valid else Color(0.8,0.15,0.15,0.18), true)
		draw_rect(ghost_rect, GOOD if valid else BAD, false, 2.0)

	for c in sim.citizens:
		var p: Vector2 = _world_point(c["position"])
		var col := GOOD if c["health"] > 55.0 else BAD
		if not c["alive"]:
			col = Color("#555b63")
		if selected_citizen == c:
			draw_circle(p, 10.0 * zoom, Color(0.8, 0.2, 0.2, 0.18))
			draw_arc(p, 9.0 * zoom, 0.0, TAU, 24, ACCENT, 2.0)
		draw_circle(p, 5.0 * zoom, col)
		if zoom > 0.82 and c["alive"]:
			draw_string(ThemeDB.fallback_font, p + Vector2(8, -8), c["name"].split(" ")[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MUTED)

func _draw_hud() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(0, 0, vp.x, 118), Color("#07090cee"))
	draw_line(Vector2(0,118), Vector2(vp.x,118), ACCENT, 2.0)

	draw_string(ThemeDB.fallback_font, Vector2(24,32), "DPN // THE LAST SETTLEMENT", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, TEXT)
	draw_string(ThemeDB.fallback_font, Vector2(24,57), "CIVILIZATION RECOVERY COMMAND // %s" % sim.settlement_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, RUST)
	draw_string(ThemeDB.fallback_font, Vector2(24,89), "DAY %03d   %02d:%02d" % [sim.day, int(sim.hour), int((sim.hour - floor(sim.hour)) * 60.0)], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ACCENT)

	var alive := sim.get_alive_citizens().size()
	var stats := [
		["POP", str(alive)],
		["FOOD", "%.0f" % sim.resources["food"]],
		["WATER", "%.0f" % sim.resources["water"]],
		["POWER", "%.0f%%" % sim.resources["power"]],
		["MEALS", "%.0f" % sim.resources["meals"]],
		["MORALE", "%.0f%%" % sim.get_average_morale()]
	]
	var sx := 390.0
	for stat in stats:
		draw_string(ThemeDB.fallback_font, Vector2(sx,35), stat[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
		draw_string(ThemeDB.fallback_font, Vector2(sx,70), stat[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, TEXT)
		sx += 142.0

	if selected_citizen.is_empty() and selected_building.is_empty():
		_draw_event_panel()

	var status := "PAUSED" if sim.paused else ("x%.0f" % sim.speed)
	var build_text := ""
	if build_mode:
		var definition := sim.get_build_catalog()[build_catalog_index]
		build_text = "  // BUILD: %s  COST %.0f  [Q/E] TYPE" % [definition["name"], float(definition["cost"])]
	draw_string(ThemeDB.fallback_font, Vector2(24, vp.y - 24), "[B] BUILD  [LMB] PLACE/INSPECT  [R] REPAIR  [X] DEMOLISH  [S/L] SAVE/LOAD" + build_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUTED)
	draw_string(ThemeDB.fallback_font, Vector2(vp.x - 115, vp.y - 24), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ACCENT)

func _draw_event_panel() -> void:
	var vp := get_viewport_rect().size
	var panel_w := 350.0
	var panel_x := vp.x - panel_w - 18
	var panel_y := 140.0
	draw_rect(Rect2(panel_x, panel_y, panel_w, vp.y - panel_y - 48), PANEL)
	draw_rect(Rect2(panel_x, panel_y, panel_w, vp.y - panel_y - 48), PANEL_EDGE, false, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(panel_x + 18, panel_y + 30), "/// SETTLEMENT INCIDENT CHANNEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TEXT)
	var ey := panel_y + 60.0
	for e in sim.events:
		var marker := GOOD
		if e["severity"] == "warning":
			marker = WARN
		elif e["severity"] == "critical":
			marker = BAD
		draw_circle(Vector2(panel_x + 22, ey - 4), 3.0, marker)
		draw_string(ThemeDB.fallback_font, Vector2(panel_x + 34, ey), "%s // D%d" % [e["title"], int(e["day"])], HORIZONTAL_ALIGNMENT_LEFT, panel_w - 50, 11, TEXT)
		draw_string(ThemeDB.fallback_font, Vector2(panel_x + 34, ey + 18), e["body"], HORIZONTAL_ALIGNMENT_LEFT, panel_w - 55, 10, MUTED)
		ey += 58.0
		if ey > vp.y - 70:
			break

func _draw_selection_panel() -> void:
	if not selected_citizen.is_empty():
		_draw_citizen_panel(selected_citizen)
	elif not selected_building.is_empty():
		_draw_building_panel(selected_building)

func _draw_citizen_panel(c: Dictionary) -> void:
	var vp := get_viewport_rect().size
	var x := vp.x - 390.0
	var y := 140.0
	var w := 372.0
	var h := vp.y - 188.0
	draw_rect(Rect2(x,y,w,h), PANEL_SOLID)
	draw_rect(Rect2(x,y,w,h), ACCENT, false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(x+20,y+30), "SURVIVOR // #%03d" % int(c["id"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ACCENT)
	draw_string(ThemeDB.fallback_font, Vector2(x+20,y+60), c["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, TEXT)
	draw_string(ThemeDB.fallback_font, Vector2(x+20,y+84), "AGE %d  •  %s  •  %s" % [int(c["age"]), c["job"], c["trait"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUTED)
	draw_string(ThemeDB.fallback_font, Vector2(x+20,y+112), "CURRENT: %s" % c["current_action"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, RUST)
	draw_string(ThemeDB.fallback_font, Vector2(x+20,y+132), "SHIFT: %s  •  %s PRIORITY: %d" % [c["shift"], c["job"].to_upper(), int(c["work_priority"].get(c["job"],3))], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)

	var rows := [
		["HEALTH", c["health"]],
		["MORALE", c["morale"]],
		["LOYALTY", c["loyalty"]],
		["HUNGER", 100.0 - float(c["hunger"])],
		["THIRST", 100.0 - float(c["thirst"])],
		["REST", 100.0 - float(c["fatigue"])],
		["STRESS RESIST", 100.0 - float(c["stress"])]
	]
	var ry := y + 168.0
	for row in rows:
		_draw_meter(Vector2(x+20, ry), w-40.0, row[0], float(row[1]))
		ry += 34.0

	draw_string(ThemeDB.fallback_font, Vector2(x+20,ry+12), "SKILL MATRIX", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ACCENT)
	ry += 38.0
	for skill in ["construction","medicine","farming","engineering","security"]:
		draw_string(ThemeDB.fallback_font, Vector2(x+20,ry), skill.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 132, 11, MUTED)
		draw_string(ThemeDB.fallback_font, Vector2(x+180,ry), "%02d" % int(c["skills"][skill]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT)
		ry += 24.0

	ry += 8.0
	if c["injury"] != "":
		draw_string(ThemeDB.fallback_font, Vector2(x+20,ry), "INJURY // %s // TREATMENT %d%%" % [c["injury"], int(c["treatment_progress"])], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, BAD)
		ry += 24.0
	draw_string(ThemeDB.fallback_font, Vector2(x+20,ry), "POCKET INVENTORY", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ACCENT)
	ry += 28.0
	var inv := c["inventory"]
	draw_string(ThemeDB.fallback_font, Vector2(x+20,ry), "RATION %d   WATER %d   MED %d   SCRAP %d" % [int(inv["food_ration"]),int(inv["water_ration"]),int(inv["medicine"]),int(inv["scrap"])], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)

func _draw_building_panel(b: Dictionary) -> void:
	var vp := get_viewport_rect().size
	var x := vp.x - 390.0
	var y := 140.0
	var w := 372.0
	var h := 270.0
	draw_rect(Rect2(x,y,w,h), PANEL_SOLID)
	draw_rect(Rect2(x,y,w,h), ACCENT, false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(x+20,y+30), "INFRASTRUCTURE NODE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ACCENT)
	draw_string(ThemeDB.fallback_font, Vector2(x+20,y+64), b["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, TEXT)
	draw_string(ThemeDB.fallback_font, Vector2(x+20,y+92), "TYPE // %s" % str(b["type"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUTED)
	_draw_meter(Vector2(x+20,y+126), w-40.0, "CONDITION", float(b["condition"]))
	draw_string(ThemeDB.fallback_font, Vector2(x+20,y+184), "WORK CAPACITY // %d" % int(b["capacity"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TEXT)
	draw_string(ThemeDB.fallback_font, Vector2(x+20,y+214), "NODE STATUS // OPERATIONAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GOOD)
	draw_string(ThemeDB.fallback_font, Vector2(x+20,y+240), "[R] QUEUE REPAIR   [X] DEMOLISH / SALVAGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, RUST)

func _draw_meter(pos: Vector2, width: float, label: String, value: float) -> void:
	draw_string(ThemeDB.fallback_font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, 150, 10, MUTED)
	draw_string(ThemeDB.fallback_font, pos + Vector2(width-42,0), "%d%%" % int(clampf(value,0.0,100.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, TEXT)
	var bar_y := pos.y + 10.0
	draw_rect(Rect2(pos.x,bar_y,width,8), Color("#25282c"))
	draw_rect(Rect2(pos.x,bar_y,width * clampf(value,0.0,100.0)/100.0,8), ACCENT if value < 45.0 else GOOD)

func _select_at(screen_pos: Vector2) -> void:
	var world := _screen_to_world(screen_pos)
	var nearest: Dictionary = {}
	var nearest_distance := 18.0 / zoom
	for c in sim.citizens:
		if not c["alive"]:
			continue
		var d: float = c["position"].distance_to(world)
		if d < nearest_distance:
			nearest = c
			nearest_distance = d
	if not nearest.is_empty():
		selected_citizen = nearest
		selected_building = {}
		return

	for b in sim.buildings:
		var rect := Rect2(b["position"] - b["size"]/2.0, b["size"])
		if rect.has_point(world):
			selected_building = b
			selected_citizen = {}
			return

	selected_citizen = {}
	selected_building = {}

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				sim.paused = not sim.paused
			KEY_1:
				sim.speed = 1.0
			KEY_2:
				sim.speed = 4.0
			KEY_3:
				sim.speed = 12.0
			KEY_S:
				sim.save_game()
			KEY_L:
				sim.load_game()
				selected_citizen = {}
				selected_building = {}
			KEY_T:
				if not selected_citizen.is_empty():
					sim.cycle_selected_shift(selected_citizen)
			KEY_P:
				if not selected_citizen.is_empty():
					sim.cycle_selected_priority(selected_citizen)
			KEY_B:
				build_mode = not build_mode
				selected_citizen = {}
				selected_building = {}
			KEY_Q:
				if build_mode:
					build_catalog_index -= 1
					if build_catalog_index < 0:
						build_catalog_index = sim.get_build_catalog().size() - 1
			KEY_E:
				if build_mode:
					build_catalog_index = (build_catalog_index + 1) % sim.get_build_catalog().size()
			KEY_R:
				if not selected_building.is_empty():
					sim.queue_repair(selected_building)
			KEY_X:
				if not selected_building.is_empty():
					sim.demolish_building(selected_building)
					selected_building = {}
			KEY_ESCAPE:
				selected_citizen = {}
				selected_building = {}
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if build_mode:
				var definition := sim.get_build_catalog()[build_catalog_index]
				sim.place_blueprint(definition["type"], _screen_to_world(event.position))
			else:
				_select_at(event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom = minf(1.6, zoom + 0.08)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom = maxf(0.65, zoom - 0.08)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = event.pressed
			drag_origin = event.position
	elif event is InputEventMouseMotion:
		mouse_world = _screen_to_world(event.position)
		if dragging:
			var drag_delta := event.position - drag_origin
			camera_offset += drag_delta / zoom
			drag_origin = event.position
