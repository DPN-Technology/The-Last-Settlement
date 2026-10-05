extends Node2D

const BG := Color("#101318")
const GRID := Color("#202832")
const PANEL := Color("#151a21")
const PANEL_EDGE := Color("#394553")
const TEXT := Color("#d9e2ec")
const MUTED := Color("#8f9baa")
const GOOD := Color("#73c991")
const WARN := Color("#e6b566")
const BAD := Color("#df6b6b")
const ACCENT := Color("#c8a96b")

var sim := SettlementSimulation.new()
var camera_offset := Vector2.ZERO
var zoom := 1.0
var dragging := false
var drag_origin := Vector2.ZERO
var citizen_visuals: Dictionary = {}

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
		if c["target"] == Vector2.ZERO or c["position"].distance_to(c["target"]) < 8.0:
			var b: Dictionary = sim.buildings[sim.rng.randi_range(0, sim.buildings.size() - 1)]
			c["target"] = b["position"] + Vector2(
				sim.rng.randf_range(-float(b["size"].x) * 0.34, float(b["size"].x) * 0.34),
				sim.rng.randf_range(-float(b["size"].y) * 0.28, float(b["size"].y) * 0.28)
			)
		c["position"] = c["position"].move_toward(c["target"], 22.0 * delta * maxf(0.5, sim.speed))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), BG)
	_draw_world()
	_draw_hud()

func _world_point(p: Vector2) -> Vector2:
	return (p + camera_offset) * zoom

func _draw_world() -> void:
	for x in range(260, 1450, 40):
		draw_line(_world_point(Vector2(x, 150)), _world_point(Vector2(x, 790)), GRID, 1.0)
	for y in range(150, 820, 40):
		draw_line(_world_point(Vector2(260, y)), _world_point(Vector2(1450, y)), GRID, 1.0)

	for b in sim.buildings:
		var pos: Vector2 = _world_point(b["position"])
		var sz: Vector2 = b["size"] * zoom
		var rect := Rect2(pos - sz / 2.0, sz)
		var color := Color("#26323a")
		match b["type"]:
			"medical": color = Color("#263b38")
			"power": color = Color("#3b3426")
			"farm": color = Color("#29382a")
			"industry": color = Color("#343039")
			"command": color = Color("#3a3026")
		draw_rect(rect, color, true)
		draw_rect(rect, PANEL_EDGE, false, 2.0)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-sz.x * 0.43, -sz.y * 0.12), b["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, TEXT)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-sz.x * 0.43, sz.y * 0.17), "COND %d%%" % int(b["condition"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)

	for c in sim.citizens:
		var p: Vector2 = _world_point(c["position"])
		var col := GOOD if c["health"] > 55.0 else BAD
		if not c["alive"]:
			col = Color("#555b63")
		draw_circle(p, 5.0 * zoom, col)
		if zoom > 0.82 and c["alive"]:
			draw_string(ThemeDB.fallback_font, p + Vector2(8, -8), c["name"].split(" ")[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MUTED)

func _draw_hud() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(0, 0, vp.x, 118), Color("#0b0e12ee"))
	draw_line(Vector2(0,118), Vector2(vp.x,118), ACCENT, 2.0)

	draw_string(ThemeDB.fallback_font, Vector2(24,34), "THE LAST SETTLEMENT", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, TEXT)
	draw_string(ThemeDB.fallback_font, Vector2(24,60), "THE OLD WORLD DIED. BUILD THE NEXT ONE.", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
	draw_string(ThemeDB.fallback_font, Vector2(24,91), "DAY %03d   %02d:%02d" % [sim.day, int(sim.hour), int((sim.hour - floor(sim.hour)) * 60.0)], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ACCENT)

	var alive := sim.get_alive_citizens().size()
	var stats := [
		["POP", str(alive)],
		["FOOD", "%.0f" % sim.resources["food"]],
		["WATER", "%.0f" % sim.resources["water"]],
		["POWER", "%.0f%%" % sim.resources["power"]],
		["MED", "%.0f" % sim.resources["medicine"]],
		["MORALE", "%.0f%%" % sim.get_average_morale()]
	]
	var sx := 390.0
	for stat in stats:
		draw_string(ThemeDB.fallback_font, Vector2(sx,37), stat[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
		draw_string(ThemeDB.fallback_font, Vector2(sx,72), stat[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, TEXT)
		sx += 142.0

	var panel_w := 330.0
	var panel_x := vp.x - panel_w - 18
	var panel_y := 140.0
	draw_rect(Rect2(panel_x, panel_y, panel_w, vp.y - panel_y - 18), PANEL)
	draw_rect(Rect2(panel_x, panel_y, panel_w, vp.y - panel_y - 18), PANEL_EDGE, false, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(panel_x + 18, panel_y + 30), "SETTLEMENT EVENT FEED", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TEXT)
	var ey := panel_y + 58.0
	for e in sim.events:
		var marker := GOOD
		if e["severity"] == "warning": marker = WARN
		elif e["severity"] == "critical": marker = BAD
		draw_circle(Vector2(panel_x + 22, ey - 4), 3.0, marker)
		draw_string(ThemeDB.fallback_font, Vector2(panel_x + 34, ey), "%s // D%d" % [e["title"], int(e["day"])], HORIZONTAL_ALIGNMENT_LEFT, panel_w - 50, 11, TEXT)
		draw_string(ThemeDB.fallback_font, Vector2(panel_x + 34, ey + 18), e["body"], HORIZONTAL_ALIGNMENT_LEFT, panel_w - 55, 10, MUTED)
		ey += 58.0
		if ey > vp.y - 45:
			break

	var status := "PAUSED" if sim.paused else ("x%.0f" % sim.speed)
	draw_string(ThemeDB.fallback_font, Vector2(24, vp.y - 24), "[SPACE] PAUSE   [1/2/3] SPEED   [WHEEL] ZOOM   [MMB] PAN", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUTED)
	draw_string(ThemeDB.fallback_font, Vector2(vp.x - 115, vp.y - 24), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ACCENT)

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
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom = minf(1.6, zoom + 0.08)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom = maxf(0.65, zoom - 0.08)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = event.pressed
			drag_origin = event.position
	elif event is InputEventMouseMotion and dragging:
		var delta := event.position - drag_origin
		camera_offset += delta / zoom
		drag_origin = event.position
