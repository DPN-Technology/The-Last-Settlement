class_name SettlementVisuals
extends RefCounted

# Lightweight RTS-style field renderer. All artwork is generated at draw time;
# there are no external textures, unsafe downloads, or save-schema changes.
const ASH := Color("#171b1a")
const DIRT := Color("#2b3029")
const DUST := Color("#424036")
const TRACK := Color("#595348")
const BLACK := Color("#0a1112")
const TEXT := Color("#edf0dc")
const MUTED := Color("#b9b9a5")
const HIGHLIGHT := Color("#f6bd69")
const SELECT := Color("#edc269")
const SUCCESS := Color("#6bc69a")
const DANGER := Color("#ec766a")
const GLASS := Color("#73aebb")

func _screen(point: Vector2, offset: Vector2, zoom: float) -> Vector2:
	return (point + offset) * zoom

func _box(point: Vector2, size: Vector2, offset: Vector2, zoom: float) -> Rect2:
	return Rect2(_screen(point, offset, zoom) - size * zoom * 0.5, size * zoom)

func render(
		canvas: CanvasItem, sim: SettlementSimulation,
		camera_offset: Vector2, zoom: float,
		selected_building: Dictionary, selected_citizen: Dictionary,
		build_mode: bool, mouse_world: Vector2,
		build_rotated: bool, selected_blueprint: Dictionary
	) -> void:
	_draw_terrain(canvas, camera_offset, zoom)
	_draw_roads(canvas, sim.buildings, camera_offset, zoom)
	_draw_props(canvas, camera_offset, zoom)
	for structure in sim.buildings:
		_draw_structure(canvas, structure, camera_offset, zoom, selected_building == structure)
	for blueprint in sim.blueprints:
		_draw_blueprint(canvas, blueprint, camera_offset, zoom)
	if build_mode:
		_draw_placement(canvas, sim, mouse_world, selected_blueprint, build_rotated, camera_offset, zoom)
	for citizen in sim.citizens:
		if str(citizen.get("home_settlement", "LAST_HAVEN")) != "LAST_HAVEN":
			continue
		_draw_survivor(canvas, citizen, camera_offset, zoom, selected_citizen == citizen)
	_draw_atmosphere(canvas, sim.hour, zoom)

func _draw_terrain(canvas: CanvasItem, offset: Vector2, zoom: float) -> void:
	var vp := canvas.get_viewport_rect().size
	canvas.draw_rect(Rect2(Vector2.ZERO, vp), ASH)
	# Camera-aware chunks: deterministic color and debris, no flicker on redraw.
	var tile := 64
	var ix_start := maxi(-8, int(floor(-offset.x / float(tile))) - 1)
	var ix_end := mini(40, int(ceil((vp.x / zoom - offset.x) / float(tile))) + 1)
	var iy_start := maxi(-8, int(floor(-offset.y / float(tile))) - 1)
	var iy_end := mini(30, int(ceil((vp.y / zoom - offset.y) / float(tile))) + 1)
	for ix in range(ix_start, ix_end):
		for iy in range(iy_start, iy_end):
			var noise := absi((ix * 617 + iy * 1291 + ix * iy * 37) % 997)
			var world := Vector2(ix * tile, iy * tile)
			var pos := _screen(world, offset, zoom)
			var side := float(tile) * zoom + 0.6
			var tone := DIRT.lerp(DUST, float(noise % 12) / 42.0)
			if noise % 19 == 0:
				tone = tone.lerp(Color("#344138"), 0.36)
			canvas.draw_rect(Rect2(pos, Vector2(side, side)), tone)
			if noise % 5 == 0:
				var stone := pos + Vector2(float(noise % 39 + 9), float(noise % 31 + 13)) * zoom
				canvas.draw_colored_polygon(PackedVector2Array([
					stone, stone + Vector2(12, 3) * zoom,
					stone + Vector2(8, 10) * zoom, stone + Vector2(-2, 7) * zoom
				]), Color("#65675b", 0.5))
			if noise % 7 == 0:
				var dry := pos + Vector2(16, 42) * zoom
				canvas.draw_line(dry, dry + Vector2(18, -5) * zoom, Color("#6b6651", 0.36), maxf(1.0, zoom))
			if noise % 23 == 0:
				var grass := pos + Vector2(31, 31) * zoom
				_draw_shrub(canvas, grass, zoom * 0.8)
	# Overgrown map limits and the former city highway.
	var border := Rect2(_screen(Vector2(170, 130), offset, zoom), Vector2(1290, 720) * zoom)
	canvas.draw_rect(border, Color("#776c51", 0.22), false, maxf(1.0, zoom * 1.4))

func _draw_roads(canvas: CanvasItem, buildings: Array[Dictionary], offset: Vector2, zoom: float) -> void:
	var center := _screen(Vector2(705, 380), offset, zoom)
	for building in buildings:
		var kind := str(building.get("type", ""))
		if kind in ["command", "pipe", "wall", "floor", "door", "power_pole"]:
			continue
		var target := _screen(Vector2(building["position"]), offset, zoom)
		var elbow := Vector2(target.x, center.y)
		var points := PackedVector2Array([center, elbow, target])
		canvas.draw_polyline(points, Color("#171817", 0.88), 36.0 * zoom)
		canvas.draw_polyline(points, TRACK, 28.0 * zoom)
		canvas.draw_polyline(points, Color("#817866", 0.28), 2.0 * zoom)
	# Broken highway approaching the camp from the west.
	var a := _screen(Vector2(-180, 425), offset, zoom)
	var b := _screen(Vector2(400, 425), offset, zoom)
	canvas.draw_line(a, b, BLACK, 61.0 * zoom)
	canvas.draw_line(a, b, Color("#5d594d"), 53.0 * zoom)
	for i in range(-3, 11):
		var x := float(i) * 54.0
		var s := _screen(Vector2(x, 425), offset, zoom)
		canvas.draw_line(s, s + Vector2(22, 0) * zoom, Color("#c3ab77", 0.42), maxf(1.0, 2.0 * zoom))

func _draw_props(canvas: CanvasItem, offset: Vector2, zoom: float) -> void:
	# Abandoned objects sell the post-collapse scale and world identity.
	for site in [Vector2(295, 275), Vector2(1490, 415), Vector2(280, 690), Vector2(1340, 845)]:
		var p := _screen(site, offset, zoom)
		canvas.draw_rect(Rect2(p + Vector2(6, 6) * zoom, Vector2(38, 20) * zoom), Color("#070c0e", 0.55))
		canvas.draw_rect(Rect2(p, Vector2(42, 21) * zoom), Color("#635c4d"))
		canvas.draw_rect(Rect2(p + Vector2(5, 3) * zoom, Vector2(15, 12) * zoom), Color("#283639"))
		canvas.draw_rect(Rect2(p + Vector2(27, 3) * zoom, Vector2(10, 12) * zoom), Color("#283639"))
		canvas.draw_line(p, p + Vector2(42, 21) * zoom, Color("#8e6250"), maxf(1.0, zoom * 2.0))
		for wheel in [Vector2(8, 21), Vector2(34, 21)]:
			canvas.draw_circle(p + wheel * zoom, 4.0 * zoom, BLACK)
	for site in [Vector2(310, 340), Vector2(315, 360), Vector2(1370, 290), Vector2(1392, 305)]:
		var p := _screen(site, offset, zoom)
		canvas.draw_rect(Rect2(p + Vector2(3, 4) * zoom, Vector2(18, 15) * zoom), BLACK)
		canvas.draw_rect(Rect2(p, Vector2(19, 14) * zoom), Color("#78654a"))
		canvas.draw_rect(Rect2(p + Vector2(2, 2) * zoom, Vector2(15, 3) * zoom), Color("#ac986e"))
		canvas.draw_line(p + Vector2(9, 0) * zoom, p + Vector2(9, 14) * zoom, Color("#4a4438"), maxf(1.0, zoom))
	for site in [Vector2(220, 230), Vector2(1480, 250), Vector2(235, 775), Vector2(1480, 775)]:
		_draw_shrub(canvas, _screen(site, offset, zoom), zoom * 1.6)

func _draw_shrub(canvas: CanvasItem, p: Vector2, zoom: float) -> void:
	canvas.draw_circle(p + Vector2(3, 4) * zoom, 9.0 * zoom, Color("#111b16", 0.48))
	for q in [Vector2(-5, 0), Vector2(3, -5), Vector2(8, 1)]:
		canvas.draw_circle(p + q * zoom, 5.2 * zoom, Color("#46553c"))
	canvas.draw_circle(p + Vector2(-3, -2) * zoom, 3.0 * zoom, Color("#68734a"))

func _roof_color(kind: String) -> Color:
	match kind:
		"command": return Color("#48545a")
		"medical": return Color("#d1cebd")
		"farm": return Color("#524b31")
		"industry": return Color("#6d5d51")
		"generator", "power", "battery": return Color("#8a714c")
		"water", "water_pump", "purifier", "water_tank": return Color("#527b83")
		"sewage": return Color("#65734e")
		"housing": return Color("#777363")
		"storage": return Color("#787055")
		"wall", "floor", "door": return Color("#797e73")
		_: return Color("#565d5c")

func _draw_structure(canvas: CanvasItem, building: Dictionary, offset: Vector2, zoom: float, selected: bool) -> void:
	var p: Vector2 = _screen(Vector2(building["position"]), offset, zoom)
	var size: Vector2 = Vector2(building["size"]) * zoom
	var r := Rect2(p - size * 0.5, size)
	var kind := str(building["type"])
	var roof := _roof_color(kind)
	if kind == "farm":
		_draw_farm(canvas, r, zoom)
	elif kind in ["wall", "floor", "door", "pipe", "power_pole"]:
		_draw_small_piece(canvas, r, kind, zoom)
	else:
		var shadow := r
		shadow.position += Vector2(9, 12) * zoom
		canvas.draw_rect(shadow, Color("#050809", 0.58))
		var outer := r.grow(4.0 * zoom)
		canvas.draw_rect(outer, Color("#252b2b"))
		canvas.draw_rect(r, roof)
		var side := roof.darkened(0.39)
		canvas.draw_colored_polygon(PackedVector2Array([
			r.position + Vector2(0, r.size.y),
			r.position + r.size,
			r.position + r.size + Vector2(0, 9) * zoom,
			r.position + Vector2(0, r.size.y + 9.0 * zoom)
		]), side)
		canvas.draw_line(r.position + Vector2(4, 5) * zoom, r.position + Vector2(r.size.x - 5 * zoom, 5 * zoom), roof.lightened(0.24), maxf(1.0, zoom * 3.0))
		canvas.draw_rect(r.grow(-7.0 * zoom), Color("#091319", 0.30), false, maxf(1.0, zoom * 1.6))
		# Roof seams / vents / metal plates and outside light.
		for i in range(1, 4):
			var seam_x := r.position.x + r.size.x * float(i) / 4.0
			canvas.draw_line(Vector2(seam_x, r.position.y + 10.0 * zoom), Vector2(seam_x, r.end.y - 9.0 * zoom), Color("#151f20", 0.24), maxf(1.0, zoom))
		for i in range(3):
			var wx := r.position.x + (19.0 + float(i) * 24.0) * zoom
			if wx + 14.0 * zoom < r.end.x:
				canvas.draw_rect(Rect2(Vector2(wx, r.position.y + 14 * zoom), Vector2(13, 7) * zoom), Color("#253538"))
				canvas.draw_rect(Rect2(Vector2(wx + 1.0 * zoom, r.position.y + 15 * zoom), Vector2(11, 2) * zoom), GLASS)
		if kind == "command":
			_draw_command_roof(canvas, p, zoom)
		elif kind == "medical":
			_draw_clinic_roof(canvas, p, zoom)
		elif kind in ["generator", "power", "battery"]:
			_draw_generator(canvas, p, zoom)
		elif kind in ["water", "water_pump", "purifier", "water_tank", "sewage"]:
			_draw_tanks(canvas, p, zoom, kind)
		elif kind in ["industry", "storage"]:
			_draw_industry(canvas, p, zoom)
		elif kind == "housing":
			_draw_housing(canvas, p, zoom)
		canvas.draw_rect(Rect2(Vector2(p.x - 14 * zoom, r.end.y - 3 * zoom), Vector2(28, 10) * zoom), Color("#182021"))
		canvas.draw_rect(Rect2(Vector2(p.x - 12 * zoom, r.end.y - 2 * zoom), Vector2(24, 4) * zoom), Color("#eab569"))
	_draw_structure_label(canvas, building, r, zoom)
	if selected:
		canvas.draw_rect(r.grow(10.0 * zoom), SELECT, false, maxf(2.0, 2.5 * zoom))
		for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			canvas.draw_circle(corner, maxf(2.0, 3.0 * zoom), HIGHLIGHT)

func _draw_small_piece(canvas: CanvasItem, r: Rect2, kind: String, zoom: float) -> void:
	canvas.draw_rect(r.grow(3.0 * zoom), BLACK)
	canvas.draw_rect(r, _roof_color(kind))
	if kind == "power_pole":
		canvas.draw_circle(r.get_center(), 8.0 * zoom, Color("#222a2b"))
		canvas.draw_line(r.position + Vector2(2, 2) * zoom, r.end - Vector2(2, 2) * zoom, HIGHLIGHT, 2.0 * zoom)
	elif kind == "pipe":
		canvas.draw_line(r.position, r.end, GLASS, maxf(2.0, 3.0 * zoom))

func _draw_farm(canvas: CanvasItem, r: Rect2, zoom: float) -> void:
	var shadow := r
	shadow.position += Vector2(6, 8) * zoom
	canvas.draw_rect(shadow, Color("#09120b", 0.50))
	canvas.draw_rect(r.grow(3.0 * zoom), Color("#777154"))
	canvas.draw_rect(r, Color("#4b3b2b"))
	for i in range(1, 8):
		var row_x := r.position.x + r.size.x * float(i) / 8.0
		canvas.draw_line(Vector2(row_x, r.position.y + 8.0 * zoom), Vector2(row_x, r.end.y - 8.0 * zoom), Color("#241e18"), 11.0 * zoom)
		for j in range(1, 5):
			var crop := Vector2(row_x, r.position.y + r.size.y * float(j) / 5.0)
			canvas.draw_circle(crop + Vector2(2, 3) * zoom, 5.0 * zoom, Color("#162819"))
			canvas.draw_circle(crop + Vector2(-2, -2) * zoom, 4.0 * zoom, Color("#6c8550"))
			canvas.draw_circle(crop + Vector2(2, -1) * zoom, 3.0 * zoom, Color("#82925c"))
	canvas.draw_rect(Rect2(r.position + Vector2(5, 4) * zoom, Vector2(20, 8) * zoom), Color("#bea56e"))

func _draw_housing(canvas: CanvasItem, p: Vector2, zoom: float) -> void:
	for d in [-1, 1]:
		var x := p.x + float(d) * 20.0 * zoom
		canvas.draw_rect(Rect2(Vector2(x - 13 * zoom, p.y - 20 * zoom), Vector2(26, 30) * zoom), Color("#383f3c"))
		canvas.draw_rect(Rect2(Vector2(x - 10 * zoom, p.y - 17 * zoom), Vector2(20, 24) * zoom), Color("#878c79"))
		canvas.draw_line(Vector2(x - 14 * zoom, p.y - 24 * zoom), Vector2(x + 14 * zoom, p.y - 24 * zoom), Color("#d3b27b"), maxf(1.0, zoom * 2.0))
	canvas.draw_circle(p + Vector2(0, -5) * zoom, 8.0 * zoom, Color("#c5a974"))

func _draw_industry(canvas: CanvasItem, p: Vector2, zoom: float) -> void:
	for i in range(3):
		var x := p.x - 42.0 * zoom + float(i) * 38.0 * zoom
		canvas.draw_rect(Rect2(Vector2(x, p.y - 10 * zoom), Vector2(27, 21) * zoom), Color("#293338"))
		canvas.draw_rect(Rect2(Vector2(x + 3 * zoom, p.y - 7 * zoom), Vector2(21, 12) * zoom), Color("#778a87"))
		canvas.draw_line(Vector2(x, p.y + 7 * zoom), Vector2(x + 27 * zoom, p.y + 7 * zoom), HIGHLIGHT, maxf(1.0, zoom * 1.5))

func _draw_command_roof(canvas: CanvasItem, p: Vector2, zoom: float) -> void:
	canvas.draw_rect(Rect2(p - Vector2(30, 16) * zoom, Vector2(60, 30) * zoom), Color("#29383b"))
	canvas.draw_rect(Rect2(p - Vector2(24, 12) * zoom, Vector2(48, 22) * zoom), Color("#4a686d"))
	canvas.draw_line(p, p + Vector2(21, -43) * zoom, Color("#e1c18a"), maxf(1.0, 3.0 * zoom))
	canvas.draw_arc(p + Vector2(21, -43) * zoom, 15.0 * zoom, PI * 0.2, PI * 0.85, 15, GLASS, maxf(1.0, 2.0 * zoom))
	canvas.draw_circle(p + Vector2(21, -43) * zoom, 4.0 * zoom, HIGHLIGHT)
	canvas.draw_rect(Rect2(p + Vector2(-49, 24) * zoom, Vector2(13, 8) * zoom), Color("#e5bb6a"))

func _draw_clinic_roof(canvas: CanvasItem, p: Vector2, zoom: float) -> void:
	canvas.draw_rect(Rect2(p - Vector2(5, 27) * zoom, Vector2(10, 54) * zoom), DANGER)
	canvas.draw_rect(Rect2(p - Vector2(27, 5) * zoom, Vector2(54, 10) * zoom), DANGER)
	canvas.draw_rect(Rect2(p + Vector2(34, -20) * zoom, Vector2(11, 9) * zoom), Color("#a4c3bb"))

func _draw_generator(canvas: CanvasItem, p: Vector2, zoom: float) -> void:
	for dx in [-23.0, 23.0]:
		var c := p + Vector2(dx, -7) * zoom
		canvas.draw_circle(c, 18.0 * zoom, Color("#202e32"))
		canvas.draw_arc(c, 14.0 * zoom, 0, TAU, 24, Color("#d4a45e"), maxf(1.0, 2.0 * zoom))
		canvas.draw_circle(c, 5.0 * zoom, Color("#98adb0"))
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			canvas.draw_line(c + d * 6.0 * zoom, c + d * 13.0 * zoom, Color("#52676c"), 3.0 * zoom)
	canvas.draw_rect(Rect2(p + Vector2(-15, 17) * zoom, Vector2(30, 8) * zoom), Color("#e6bd68"))

func _draw_tanks(canvas: CanvasItem, p: Vector2, zoom: float, kind: String) -> void:
	for dx in [-21.0, 21.0]:
		var c := p + Vector2(dx, -5) * zoom
		canvas.draw_circle(c + Vector2(3, 4) * zoom, 18.0 * zoom, Color("#152529"))
		canvas.draw_circle(c, 17.0 * zoom, Color("#1f4a53" if kind != "sewage" else "#43543b"))
		canvas.draw_arc(c, 13.0 * zoom, 0, TAU, 28, GLASS if kind != "sewage" else Color("#a9ab70"), maxf(1.0, zoom * 3.0))
		canvas.draw_circle(c, 5.0 * zoom, Color("#8bb7bb" if kind != "sewage" else "#99945c"))
	canvas.draw_line(p + Vector2(-21, 18) * zoom, p + Vector2(21, 18) * zoom, GLASS, maxf(2.0, zoom * 4.0))

func _draw_structure_label(canvas: CanvasItem, building: Dictionary, r: Rect2, zoom: float) -> void:
	if zoom < 0.70:
		return
	var caption := str(building["name"]).to_upper()
	var font_size := maxi(10, int(11.0 * zoom))
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var label_width := maxf(66.0 * zoom, width + 17.0)
	var x := r.get_center().x - label_width * 0.5
	var y := r.end.y + 10.0 * zoom
	canvas.draw_rect(Rect2(x, y, label_width, 20.0), Color("#0c191b", 0.91))
	canvas.draw_line(Vector2(x, y), Vector2(x + label_width, y), Color("#daa65f"), maxf(1.0, zoom))
	canvas.draw_string(font, Vector2(x + 8, y + 14), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TEXT)

func _draw_blueprint(canvas: CanvasItem, bp: Dictionary, offset: Vector2, zoom: float) -> void:
	var rect := _box(Vector2(bp["position"]), Vector2(bp["size"]), offset, zoom)
	canvas.draw_rect(rect, Color("#7a9a9c", 0.23))
	canvas.draw_rect(rect, GLASS, false, maxf(1.0, 2.0 * zoom))
	for i in range(4):
		var x := rect.position.x + rect.size.x * float(i) / 4.0
		canvas.draw_line(Vector2(x, rect.position.y), Vector2(x + rect.size.y * 0.22, rect.end.y), Color("#b7e3d6", 0.42), maxf(1.0, zoom))
	var progress := clampf(float(bp["progress"]) / maxf(1.0, float(bp["work_required"])), 0.0, 1.0)
	canvas.draw_rect(Rect2(rect.position.x, rect.end.y + 3, rect.size.x * progress, 4), SUCCESS)
	canvas.draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, -7), "%s %d%%" % [str(bp["name"]), int(progress * 100.0)], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TEXT)

func _draw_placement(canvas: CanvasItem, sim: SettlementSimulation, world: Vector2, definition: Dictionary, rotated: bool, offset: Vector2, zoom: float) -> void:
	var snap := Vector2(round(world.x / 20.0) * 20.0, round(world.y / 20.0) * 20.0)
	var size := Vector2(definition["size"])
	if rotated and str(definition["type"]) in ["wall", "door", "pipe"]:
		size = Vector2(size.y, size.x)
	var rect := _box(snap, size, offset, zoom)
	var valid := sim.can_place_blueprint(snap, size)
	var color := SUCCESS if valid else DANGER
	canvas.draw_rect(rect, Color(color.r, color.g, color.b, 0.25))
	canvas.draw_rect(rect, color, false, 2.0)
	canvas.draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, -10), str(definition["name"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)

func _draw_survivor(canvas: CanvasItem, citizen: Dictionary, offset: Vector2, zoom: float, selected: bool) -> void:
	var p := _screen(Vector2(citizen["position"]), offset, zoom)
	var color := SUCCESS
	match str(citizen["job"]):
		"Medic": color = Color("#e4dfd0")
		"Guard": color = Color("#b16857")
		"Farmer": color = Color("#829c68")
		"Engineer": color = Color("#dfa85b")
		"Builder": color = Color("#bda371")
		"Scavenger": color = Color("#92aab2")
		"Cook": color = Color("#cfb58f")
		"Hauler": color = Color("#8d94a0")
	if not bool(citizen["alive"]):
		color = Color("#595b57")
	canvas.draw_circle(p + Vector2(3, 8) * zoom, 8.0 * zoom, Color("#080b0c", 0.55))
	if selected:
		canvas.draw_circle(p, 14.0 * zoom, Color("#e5b15d", 0.18))
		canvas.draw_arc(p, 15.0 * zoom, 0, TAU, 28, SELECT, maxf(1.0, 2.0 * zoom))
	# Top-down survivor: helmet, shoulders, pack and boots instead of 5px dot.
	canvas.draw_line(p + Vector2(-3, 3) * zoom, p + Vector2(-3, 10) * zoom, Color("#252b2b"), maxf(2.0, 3.0 * zoom))
	canvas.draw_line(p + Vector2(3, 3) * zoom, p + Vector2(3, 10) * zoom, Color("#252b2b"), maxf(2.0, 3.0 * zoom))
	canvas.draw_rect(Rect2(p - Vector2(7, 4) * zoom, Vector2(14, 10) * zoom), color)
	canvas.draw_rect(Rect2(p + Vector2(-9, -2) * zoom, Vector2(4, 9) * zoom), color.darkened(0.2))
	canvas.draw_rect(Rect2(p + Vector2(5, -2) * zoom, Vector2(4, 9) * zoom), color.darkened(0.2))
	canvas.draw_circle(p + Vector2(0, -6) * zoom, 5.4 * zoom, Color("#cdb28b"))
	canvas.draw_arc(p + Vector2(0, -7) * zoom, 5.5 * zoom, PI, TAU, 10, color.darkened(0.15), maxf(1.0, 3.0 * zoom))
	if selected and zoom >= 0.75:
		canvas.draw_string(ThemeDB.fallback_font, p + Vector2(12, -9) * zoom, str(citizen["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TEXT)
	elif zoom >= 1.05:
		canvas.draw_string(ThemeDB.fallback_font, p + Vector2(12, -7) * zoom, str(citizen["name"]).get_slice(" ", 0), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MUTED)

func _draw_atmosphere(canvas: CanvasItem, hour: float, zoom: float) -> void:
	# Time-of-day grading. Night remains readable so construction is always usable.
	var vp := canvas.get_viewport_rect().size
	if hour < 6.0 or hour > 20.0:
		canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color("#07121f", 0.25))
	elif hour < 8.0 or hour > 18.0:
		canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color("#55331d", 0.08))
