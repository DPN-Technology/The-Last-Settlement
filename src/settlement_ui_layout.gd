class_name SettlementUILayout
extends RefCounted

# Centralize every mouse hitbox with its draw rectangle. All measurements are
# logical Godot viewport pixels and remain independent of camera zoom.
const TOP_H := 82.0
const BOTTOM_H := 58.0
const GAP := 6.0
const NAV_LABELS := ["BUILD","REGION","GOVERN","INDUSTRY","FACTIONS","NATION","SAVE","LOAD","GUIDE"]

# Shared rectangles for the clickable identity and short settlement briefing.
# No guessed pixel offsets in mouse handling; resize-safe at the preview size.
static func identity_rect(size: Vector2) -> Rect2:
	var resource_left := clampf(size.x * 0.235,184.0,302.0)
	return Rect2(8.0,5.0,maxf(156.0,resource_left-16.0),49.0)

static func overview_rect(size: Vector2) -> Rect2:
	var width := minf(420.0,maxf(240.0,size.x-28.0))
	var height := minf(397.0,maxf(224.0,size.y-TOP_H-BOTTOM_H-22.0))
	return Rect2(14.0,TOP_H+9.0,width,height)

static func overview_button_rect(size: Vector2, index: int) -> Rect2:
	var panel := overview_rect(size)
	var gap := 7.0
	var inner := panel.size.x-24.0
	var width := (inner-gap*2.0)/3.0
	return Rect2(panel.position.x+12.0+float(index)*(width+gap),panel.end.y-40.0,width,29.0)

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

static func region_map_rect(size: Vector2) -> Rect2:
	var right := side_panel(size,372.0)
	return Rect2(245.0,TOP_H+62.0,maxf(180.0,right.position.x-257.0),maxf(220.0,size.y-TOP_H-BOTTOM_H-83.0))

static func region_point(size: Vector2, world_pos: Vector2) -> Vector2:
	var map := region_map_rect(size)
	return map.position+Vector2(world_pos.x/1200.0*map.size.x,world_pos.y/820.0*map.size.y)

static func region_site_row(size: Vector2, row: int) -> Rect2:
	return Rect2(16.0,TOP_H+85.0+float(row)*29.0,211.0,28.0)

static func region_team_control(size: Vector2, index: int) -> Rect2:
	var panel := side_panel(size,372.0)
	if index==0:
		return Rect2(panel.position+Vector2(16.0,180.0),Vector2(55.0,29.0))
	if index==1:
		return Rect2(panel.position+Vector2(77.0,180.0),Vector2(55.0,29.0))
	return Rect2(panel.position+Vector2(139.0,180.0),Vector2(panel.size.x-155.0,29.0))

static func region_recall_rect(size: Vector2, row: int) -> Rect2:
	var panel := side_panel(size,372.0)
	return Rect2(panel.position+Vector2(panel.size.x-106.0,349.0+float(row)*48.0),Vector2(89.0,25.0))

static func region_dispatch_rect(size: Vector2) -> Rect2:
	var panel := side_panel(size,372.0)
	return Rect2(panel.position+Vector2(16.0,278.0),Vector2(panel.size.x-32.0,34.0))

static func civilization_tab_rect(size: Vector2, index: int, count: int = 6) -> Rect2:
	var area := side_panel(size,620.0)
	var gap := 5.0
	var width := (area.size.x-28.0-gap*float(count-1))/maxf(1.0,float(count))
	return Rect2(area.position+Vector2(14.0+float(index)*(width+gap),66.0),Vector2(width,32.0))

static func guide_rect(size: Vector2) -> Rect2:
	var usable_h := size.y-TOP_H-BOTTOM_H-18.0
	var width := minf(780.0,size.x-36.0)
	var height := minf(502.0,usable_h)
	return Rect2((size.x-width)*0.5,TOP_H+maxf(8.0,(usable_h-height)*0.5),width,height)

static func guide_lesson_rect(size: Vector2, index: int) -> Rect2:
	var panel := guide_rect(size)
	var gap := 12.0
	var width := (panel.size.x-46.0-gap)*0.5
	var height := maxf(84.0,minf(106.0,(panel.size.y-139.0)/3.0))
	return Rect2(panel.position+Vector2(17.0+float(index%2)*(width+gap),69.0+float(int(index/2))*(height+8.0)),Vector2(width,height))

static func facility_inspector(size: Vector2) -> Rect2:
	var area := side_panel(size,372.0)
	return Rect2(area.position,Vector2(area.size.x,minf(354.0,area.size.y)))

static func facility_action(size: Vector2, index: int) -> Rect2:
	var area := facility_inspector(size)
	var gap := 6.0
	var width := (area.size.x-28.0-gap*2.0)/3.0
	return Rect2(area.position+Vector2(14.0+float(index)*(width+gap),area.size.y-48.0),Vector2(width,32.0))

static func build_palette(size: Vector2, _count: int) -> Rect2:
	var max_height := maxf(250.0,size.y-TOP_H-BOTTOM_H-23.0)
	return Rect2(12.0,TOP_H+8.0,minf(350.0,size.x-24.0),minf(443.0,max_height))

static func palette_rows(size: Vector2, count: int) -> int:
	var panel := build_palette(size,count)
	return maxi(1,mini(count,int(floor((panel.size.y-247.0)/27.0))))

static func palette_first(selection: int, count: int, rows: int) -> int:
	return clampi(selection-int(rows/2),0,maxi(0,count-rows))

static func build_category_rect(size: Vector2, index: int) -> Rect2:
	var panel := build_palette(size,0)
	var gap := 5.0
	var width := (panel.size.x-24.0-gap*2.0)/3.0
	return Rect2(panel.position+Vector2(12.0+float(index%3)*(width+gap),64.0+float(index/3)*30.0),Vector2(width,25.0))

static func build_row_rect(size: Vector2, row: int) -> Rect2:
	var panel := build_palette(size,0)
	return Rect2(panel.position+Vector2(9.0,134.0+float(row)*27.0),Vector2(panel.size.x-18.0,26.0))

static func build_action_rect(size: Vector2, index: int) -> Rect2:
	var panel := build_palette(size,0)
	var half := (panel.size.x-31.0)*0.5
	return Rect2(panel.position+Vector2(12.0+float(index)*(half+7.0),panel.size.y-35.0),Vector2(half,25.0))

# Full roster command is intentionally a centered *modal*, separate from the
# construction and nation side panels; all hit targets use these same helpers.
static func workforce_panel(size: Vector2) -> Rect2:
	var width := minf(675.0,size.x-28.0)
	var height := minf(545.0,size.y-TOP_H-BOTTOM_H-20.0)
	return Rect2((size.x-width)*0.5,TOP_H+9.0,width,height)

static func workforce_page_size(size: Vector2) -> int:
	return 8 if workforce_panel(size).size.y>=510.0 else 5

static func workforce_row(size: Vector2, index: int) -> Rect2:
	var panel := workforce_panel(size)
	return Rect2(panel.position+Vector2(16,99+float(index)*28.0),Vector2(panel.size.x-32,27))

static func workforce_job(size: Vector2, index: int) -> Rect2:
	var panel := workforce_panel(size)
	var gap := 7.0
	var unit := (panel.size.x-39.0-gap*3.0)/4.0
	return Rect2(panel.position+Vector2(16.0+float(index%4)*(unit+gap),panel.size.y-158.0+float(int(index/4))*35.0),Vector2(unit,30))

static func workforce_action(size: Vector2, index: int) -> Rect2:
	var panel := workforce_panel(size)
	var gap := 8.0
	var unit := (panel.size.x-32.0-2.0*gap)/3.0
	return Rect2(panel.position+Vector2(16.0+float(index)*(unit+gap),panel.size.y-41.0),Vector2(unit,29))

# Simulation time controls sit in the shallow upper rail of the command dock.
# They never collide with the nine primary navigation stations.
static func time_control(size: Vector2, index: int) -> Rect2:
	return Rect2(size.x-226.0+float(index)*53.0,size.y-BOTTOM_H+2.0,47.0,14.0)
