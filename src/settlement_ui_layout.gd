class_name SettlementUILayout
extends RefCounted

# Centralize every mouse hitbox with its draw rectangle. All measurements are
# logical Godot viewport pixels and remain independent of camera zoom.
const TOP_H := 82.0
const BOTTOM_H := 58.0
const GAP := 6.0
const NAV_LABELS := ["BUILD","REGION","GOVERN","INDUSTRY","FACTIONS","NATION","SAVE","LOAD","GUIDE"]

static func resource_rects(size: Vector2) -> Array[Rect2]:
	var left := clampf(size.x * 0.235, 184.0, 302.0)
	var width := maxf(44.0, (size.x - left - 14.0 - GAP * 5.0) / 6.0)
	var boxes: Array[Rect2] = []
	for i in range(6):
		boxes.append(Rect2(left + float(i) * (width + GAP), 7.0, width, 46.0))
	return boxes

static func navbar_rect(size: Vector2, index: int) -> Rect2:
	var unit := (size.x - 22.0 - GAP * 8.0) / 9.0
	return Rect2(11.0 + float(index) * (unit + GAP), size.y - 42.0, unit, 32.0)

static func side_panel(size: Vector2, preferred_width: float, top_offset: float = 8.0, reserve_bottom: float = 10.0) -> Rect2:
	var width := minf(preferred_width, maxf(230.0, size.x - 28.0))
	var y := TOP_H + top_offset
	return Rect2(maxf(10.0, size.x - width - 12.0), y, width, maxf(110.0, size.y - y - BOTTOM_H - reserve_bottom))

static func directive_tab() -> Rect2:
	return Rect2(14.0, TOP_H + 9.0, 268.0, 30.0)

static func objective_panel() -> Rect2:
	return Rect2(14.0, TOP_H + 9.0, 300.0, 188.0)

static func build_palette(size: Vector2, count: int) -> Rect2:
	var available_rows := mini(8, count)
	var height := 77.0 + float(available_rows) * 28.0
	var max_height := maxf(110.0, size.y - TOP_H - BOTTOM_H - 25.0)
	return Rect2(14.0, TOP_H + 9.0, minf(316.0, size.x - 28.0), minf(max_height, height))

static func palette_rows(size: Vector2, count: int) -> int:
	var panel := build_palette(size, count)
	return maxi(1, mini(count, int(floor((panel.size.y - 77.0) / 28.0))))

static func palette_first(selection: int, count: int, rows: int) -> int:
	return clampi(selection - int(rows / 2), 0, maxi(0, count - rows))
