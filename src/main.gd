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
var build_rotated := false
var mouse_world := Vector2.ZERO
var utility_overlay := 0
var world_map_mode := false
var selected_world_location_id := 0
var governance_mode := false
var economy_mode := false
var economy_item_index := 0
var economy_source_index := 0
var economy_recipe_index := 0
const ECONOMY_RECIPES := ["Machine Parts","Components","Tool Kit","Fuel Blend","Vehicle Repair Kit","Utility Truck"]
const ECONOMY_ITEMS := ["food","water","medicine","materials","scrap","fuel","parts"]
var governance_law_index := 0
const GOVERNANCE_LAWS := ["rationing","security","labor","justice","speech"]
const UTILITY_OVERLAYS := ["OFF", "POWER", "WATER", "SEWAGE"]

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
				c["position"] = _move_with_obstacle_avoidance(c["position"], c["target"], 25.0 * delta * maxf(0.5, sim.speed))
				continue
		if c["target"] == Vector2.ZERO or c["position"].distance_to(c["target"]) < 8.0:
			var b := sim.get_building_by_type(c["target_building"])
			c["target"] = b["position"] + Vector2(
				sim.rng.randf_range(-float(b["size"].x) * 0.34, float(b["size"].x) * 0.34),
				sim.rng.randf_range(-float(b["size"].y) * 0.28, float(b["size"].y) * 0.28)
			)
		c["position"] = _move_with_obstacle_avoidance(c["position"], c["target"], 25.0 * delta * maxf(0.5, sim.speed))

func _move_with_obstacle_avoidance(origin: Vector2, target: Vector2, distance: float) -> Vector2:
	var direct := origin.move_toward(target, distance)
	for b in sim.buildings:
		if b["type"] != "wall":
			continue
		var rect := Rect2(b["position"] - b["size"]/2.0, b["size"]).grow(5.0)
		if rect.has_point(direct):
			var direction := (target - origin).normalized()
			var perpendicular := Vector2(-direction.y, direction.x)
			var option_a := origin + perpendicular * distance
			var option_b := origin - perpendicular * distance
			return option_a if option_a.distance_to(target) <= option_b.distance_to(target) else option_b
	return direct

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), BG)
	if world_map_mode:
		_draw_world_map()
	else:
		_draw_world()
		_draw_utility_overlay()
	_draw_hud()
	if governance_mode:
		_draw_governance_panel()
	elif economy_mode:
		_draw_economy_panel()
	else:
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
			"generator": color = Color("#3a2f1e")
			"battery": color = Color("#2d3022")
			"power_pole": color = Color("#272727")
			"water_pump": color = Color("#1d3038")
			"purifier": color = Color("#1e3837")
			"water_tank": color = Color("#22313a")
			"pipe": color = Color("#26343b")
			"sewage": color = Color("#303522")
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
		var ghost_world_size: Vector2 = definition["size"]
		if build_rotated and (definition["type"] == "wall" or definition["type"] == "door" or definition["type"] == "pipe"):
			ghost_world_size = Vector2(ghost_world_size.y, ghost_world_size.x)
		var ghost_size: Vector2 = ghost_world_size * zoom
		var ghost_rect := Rect2(ghost_pos - ghost_size/2.0, ghost_size)
		var valid := sim.can_place_blueprint(Vector2(round(mouse_world.x / 20.0) * 20.0, round(mouse_world.y / 20.0) * 20.0), ghost_world_size)
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

func _draw_utility_overlay() -> void:
	if utility_overlay == 0:
		return
	var mode := UTILITY_OVERLAYS[utility_overlay]
	var nodes: Array[Dictionary] = []
	for b in sim.buildings:
		var utility := str(b.get("utility", b.get("type","")))
		if mode == "POWER" and utility in ["generator","battery","power_pole","water_pump","purifier","sewage"]:
			nodes.append(b)
		elif mode == "WATER" and utility in ["water_pump","purifier","water_tank","pipe","sewage"]:
			nodes.append(b)
		elif mode == "SEWAGE" and utility in ["sewage","pipe","water_pump","purifier","water_tank"]:
			nodes.append(b)

	for i in range(nodes.size()):
		for j in range(i + 1, nodes.size()):
			var a := nodes[i]
			var b := nodes[j]
			var max_distance := 260.0 if mode == "POWER" else 180.0
			if a["position"].distance_to(b["position"]) <= max_distance:
				var line_color := WARN if mode == "POWER" else (Color("#5aa7c7") if mode == "WATER" else Color("#88924b"))
				draw_line(_world_point(a["position"]), _world_point(b["position"]), line_color, 2.0)

	for node in nodes:
		var p := _world_point(node["position"])
		var ring := WARN if mode == "POWER" else (Color("#5aa7c7") if mode == "WATER" else Color("#88924b"))
		draw_arc(p, 16.0 * zoom, 0.0, TAU, 24, ring, 2.0)

func _draw_world_map() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(0,118,vp.x,vp.y-118), Color("#0b0d10"))
	draw_string(ThemeDB.fallback_font, Vector2(28,154), "REGIONAL OPERATIONS MAP // RADIO RANGE %.0f" % sim.world_simulation.get_radio_range(), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, TEXT)
	var origin := Vector2(80,180)
	var scale := Vector2((vp.x-500.0)/1200.0,(vp.y-250.0)/820.0)
	var home_screen := origin + Vector2(600,410) * scale
	draw_circle(home_screen, sim.world_simulation.get_radio_range() * minf(scale.x,scale.y), Color(0.55,0.18,0.15,0.08))
	draw_arc(home_screen, sim.world_simulation.get_radio_range() * minf(scale.x,scale.y), 0, TAU, 64, ACCENT, 2.0)

	for location in sim.world_simulation.locations:
		var p := origin + Vector2(location["position"]) * scale
		if not location["discovered"]:
			draw_circle(p, 5.0, Color("#34383d"))
			continue
		var col := GOOD if location["type"] == "settlement" else (WARN if location["type"] == "relay" else (Color("#7ca0c2") if location["type"] == "trade_hub" else RUST))
		if location["depleted"]:
			col = MUTED
		draw_circle(p, 8.0, col)
		if int(location["id"]) == selected_world_location_id:
			draw_arc(p, 14.0, 0, TAU, 24, ACCENT, 2.0)
		draw_string(ThemeDB.fallback_font, p + Vector2(12,-6), location["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TEXT)

	for caravan in sim.economy_simulation.get_inbound_caravans():
		var origin_location := sim.world_simulation.get_location_by_id(int(caravan["origin_location_id"]))
		if origin_location.is_empty():
			continue
		var caravan_start := origin + Vector2(origin_location["position"]) * scale
		var caravan_end := home_screen
		var caravan_progress := clampf(float(caravan["progress"]) / maxf(1.0,float(caravan["distance"])),0.0,1.0)
		var caravan_pos := caravan_start
		if caravan["status"] == "inbound":
			caravan_pos = caravan_start.lerp(caravan_end,caravan_progress)
		elif caravan["status"] == "trading":
			caravan_pos = caravan_end
		else:
			caravan_pos = caravan_end.lerp(caravan_start,caravan_progress)
		draw_line(caravan_start,caravan_end,Color("#3b4650"),1.0)
		draw_rect(Rect2(caravan_pos-Vector2(5,4),Vector2(10,8)),Color("#7ca0c2"),true)
		draw_string(ThemeDB.fallback_font,caravan_pos+Vector2(9,3),"TRD-%02d" % int(caravan["id"]),HORIZONTAL_ALIGNMENT_LEFT,-1,9,MUTED)

	for expedition in sim.world_simulation.get_active_expeditions():
		var destination := sim.world_simulation.get_location_by_id(int(expedition["destination_id"]))
		if destination.is_empty():
			continue
		var start := home_screen
		var end := origin + Vector2(destination["position"]) * scale
		var progress := clampf(float(expedition["progress"]) / maxf(1.0,float(expedition["distance"])),0.0,1.0)
		var p := start.lerp(end, progress if expedition["status"] == "outbound" else (1.0-progress if expedition["status"] == "returning" else 1.0))
		draw_line(start,end,Color("#4a2c2c"),1.0)
		draw_circle(p,6.0,ACCENT)
		draw_string(ThemeDB.fallback_font,p+Vector2(10,4),"EXP-%02d" % int(expedition["id"]),HORIZONTAL_ALIGNMENT_LEFT,-1,10,TEXT)

	var x := vp.x - 390.0
	draw_rect(Rect2(x,140,372,vp.y-190),PANEL_SOLID)
	draw_rect(Rect2(x,140,372,vp.y-190),PANEL_EDGE,false,1.0)
	draw_string(ThemeDB.fallback_font,Vector2(x+20,170),"WORLD INTELLIGENCE",HORIZONTAL_ALIGNMENT_LEFT,-1,14,ACCENT)
	var location := sim.world_simulation.get_location_by_id(selected_world_location_id)
	if not location.is_empty():
		draw_string(ThemeDB.fallback_font,Vector2(x+20,205),location["name"],HORIZONTAL_ALIGNMENT_LEFT,-1,20,TEXT)
		draw_string(ThemeDB.fallback_font,Vector2(x+20,232),"TYPE // %s" % str(location["type"]).to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,11,MUTED)
		draw_string(ThemeDB.fallback_font,Vector2(x+20,255),"DANGER // %d%%" % int(float(location["danger"])*100.0),HORIZONTAL_ALIGNMENT_LEFT,-1,11,WARN)
		draw_string(ThemeDB.fallback_font,Vector2(x+20,278),"STATUS // %s" % ("DEPLETED" if location["depleted"] else "AVAILABLE"),HORIZONTAL_ALIGNMENT_LEFT,-1,11,TEXT)
		if str(location["type"]) == "trade_hub":
			draw_string(ThemeDB.fallback_font,Vector2(x+20,301),"FACTION // %s" % str(location.get("faction","UNKNOWN")).to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("#7ca0c2"))
			draw_string(ThemeDB.fallback_font,Vector2(x+20,323),"TRADE HUB // CARAVANS SERVICE LAST HAVEN",HORIZONTAL_ALIGNMENT_LEFT,-1,10,MUTED)
		else:
			draw_string(ThemeDB.fallback_font,Vector2(x+20,315),"[G] DISPATCH EXPEDITION",HORIZONTAL_ALIGNMENT_LEFT,-1,12,RUST)
	else:
		draw_string(ThemeDB.fallback_font,Vector2(x+20,205),"Select a discovered location.",HORIZONTAL_ALIGNMENT_LEFT,-1,11,MUTED)

	var ey := 365.0
	draw_string(ThemeDB.fallback_font,Vector2(x+20,ey),"ACTIVE EXPEDITIONS",HORIZONTAL_ALIGNMENT_LEFT,-1,12,ACCENT)
	ey += 26.0
	for expedition in sim.world_simulation.get_active_expeditions():
		var destination := sim.world_simulation.get_location_by_id(int(expedition["destination_id"]))
		draw_string(ThemeDB.fallback_font,Vector2(x+20,ey),"EXP-%02d // %s" % [int(expedition["id"]),str(expedition["status"]).to_upper()],HORIZONTAL_ALIGNMENT_LEFT,-1,11,TEXT)
		ey += 18.0
		draw_string(ThemeDB.fallback_font,Vector2(x+20,ey),"TARGET: %s" % destination["name"],HORIZONTAL_ALIGNMENT_LEFT,-1,10,MUTED)
		ey += 28.0

func _world_map_select(screen_pos: Vector2) -> void:
	var vp := get_viewport_rect().size
	var origin := Vector2(80,180)
	var scale := Vector2((vp.x-500.0)/1200.0,(vp.y-250.0)/820.0)
	var nearest_id := 0
	var nearest_dist := 18.0
	for location in sim.world_simulation.locations:
		if not location["discovered"]:
			continue
		var p := origin + Vector2(location["position"]) * scale
		var d := p.distance_to(screen_pos)
		if d < nearest_dist:
			nearest_dist = d
			nearest_id = int(location["id"])
	selected_world_location_id = nearest_id

func _draw_economy_panel() -> void:
	var vp := get_viewport_rect().size
	var x := vp.x - 500.0
	var y := 138.0
	var w := 480.0
	var h := vp.y - 190.0
	var eco := sim.economy_simulation
	var trade_sources := eco.get_trade_sources()
	if trade_sources.is_empty():
		economy_source_index = 0
	elif economy_source_index >= trade_sources.size():
		economy_source_index = 0
	var active_source := trade_sources[economy_source_index]
	draw_rect(Rect2(x,y,w,h),PANEL_SOLID)
	draw_rect(Rect2(x,y,w,h),RUST,false,2.0)
	draw_string(ThemeDB.fallback_font,Vector2(x+22,y+30),"INDUSTRY + ECONOMY COMMAND",HORIZONTAL_ALIGNMENT_LEFT,-1,15,RUST)
	draw_string(ThemeDB.fallback_font,Vector2(x+22,y+62),"CREDITS // %.1f" % eco.credits,HORIZONTAL_ALIGNMENT_LEFT,-1,18,TEXT)
	draw_string(ThemeDB.fallback_font,Vector2(x+220,y+62),"MARKET // %s" % active_source["name"],HORIZONTAL_ALIGNMENT_LEFT,-1,11,GOOD if economy_source_index>0 else MUTED)
	draw_string(ThemeDB.fallback_font,Vector2(x+22,y+88),"FUEL %.1f   PARTS %.1f   TOOLS %.1f   COMPONENTS %.1f" % [float(eco.industry_stock["fuel"]),float(eco.industry_stock["parts"]),float(eco.industry_stock["tools"]),float(eco.industry_stock["components"])],HORIZONTAL_ALIGNMENT_LEFT,-1,11,MUTED)
	draw_string(ThemeDB.fallback_font,Vector2(x+22,y+108),"WAREHOUSE %.0f/%.0f   PRESSURE %.0f%%   PROD EFF %.0f%%" % [eco.warehouse_used,eco.warehouse_capacity,eco.warehouse_pressure*100.0,eco.production_efficiency*100.0],HORIZONTAL_ALIGNMENT_LEFT,-1,10,MUTED)
	if eco.bottleneck_reason != "":
		draw_string(ThemeDB.fallback_font,Vector2(x+22,y+126),"BOTTLENECK // %s" % eco.bottleneck_reason,HORIZONTAL_ALIGNMENT_LEFT,-1,10,WARN)
	var ry := y + 150.0
	draw_string(ThemeDB.fallback_font,Vector2(x+22,ry),"MARKET INDEX",HORIZONTAL_ALIGNMENT_LEFT,-1,12,ACCENT)
	ry += 26.0
	for i in range(ECONOMY_ITEMS.size()):
		var item := ECONOMY_ITEMS[i]
		var marker := ">" if i == economy_item_index else " "
		var col := TEXT if i == economy_item_index else MUTED
		draw_string(ThemeDB.fallback_font,Vector2(x+22,ry),"%s %-10s %.1f cr" % [marker,item.to_upper(),eco.get_trade_price(item,economy_source_index)],HORIZONTAL_ALIGNMENT_LEFT,-1,11,col)
		ry += 22.0
	draw_string(ThemeDB.fallback_font,Vector2(x+22,ry+4),"[↑/↓] ITEM  [H] MARKET  [ENTER] BUY 1  [BACKSPACE] SELL 1",HORIZONTAL_ALIGNMENT_LEFT,-1,10,RUST)
	ry += 30.0
	var selected_recipe := ECONOMY_RECIPES[economy_recipe_index]
	draw_string(ThemeDB.fallback_font,Vector2(x+22,ry),"PRODUCTION ORDER // %s" % selected_recipe.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,10,TEXT)
	ry += 20.0
	draw_string(ThemeDB.fallback_font,Vector2(x+22,ry),"[N] NEXT RECIPE   [C] QUEUE 1",HORIZONTAL_ALIGNMENT_LEFT,-1,10,RUST)
	ry += 30.0
	draw_string(ThemeDB.fallback_font,Vector2(x+22,ry),"PRODUCTION QUEUE",HORIZONTAL_ALIGNMENT_LEFT,-1,12,ACCENT)
	ry += 24.0
	for batch in eco.production_queue:
		var recipe := str(batch["recipe"])
		var status := str(batch["status"]).to_upper()
		draw_string(ThemeDB.fallback_font,Vector2(x+22,ry),"BATCH-%03d // %s // %s" % [int(batch["id"]),recipe,status],HORIZONTAL_ALIGNMENT_LEFT,-1,10,TEXT)
		ry += 20.0
		if ry > y+h-95:
			break
	var vehicle := eco.vehicles[0] if not eco.vehicles.is_empty() else {}
	if not vehicle.is_empty():
		draw_string(ThemeDB.fallback_font,Vector2(x+22,y+h-78),"VEHICLE // %s  COND %.0f%%  FUEL %.1f" % [vehicle["name"],float(vehicle["condition"]),float(vehicle["fuel"])],HORIZONTAL_ALIGNMENT_LEFT,-1,10,MUTED)
		draw_string(ThemeDB.fallback_font,Vector2(x+22,y+h-58),"REPAIR KITS %.0f   FUEL BURN %.2f/day   [Y] REPAIR VEHICLE" % [eco.repair_kits,eco.fuel_consumed_today],HORIZONTAL_ALIGNMENT_LEFT,-1,10,RUST)

func _draw_governance_panel() -> void:
	var vp := get_viewport_rect().size
	var x := vp.x - 500.0
	var y := 138.0
	var w := 480.0
	var h := vp.y - 190.0
	draw_rect(Rect2(x,y,w,h),PANEL_SOLID)
	draw_rect(Rect2(x,y,w,h),ACCENT,false,2.0)
	draw_string(ThemeDB.fallback_font,Vector2(x+22,y+30),"CIVIC COMMAND // GOVERNANCE",HORIZONTAL_ALIGNMENT_LEFT,-1,15,ACCENT)

	var gov := sim.governance_simulation
	var leader := sim.get_citizen_by_id(gov.leader_id)
	var leader_name := "VACANT" if leader.is_empty() else leader["name"]
	draw_string(ThemeDB.fallback_font,Vector2(x+22,y+62),"GOVERNMENT // %s" % gov.government_type,HORIZONTAL_ALIGNMENT_LEFT,-1,12,TEXT)
	draw_string(ThemeDB.fallback_font,Vector2(x+22,y+86),"LEADER // %s" % leader_name,HORIZONTAL_ALIGNMENT_LEFT,-1,13,RUST)

	_draw_meter(Vector2(x+22,y+118),w-44.0,"LEGITIMACY",float(gov.legitimacy))
	_draw_meter(Vector2(x+22,y+154),w-44.0,"UNREST",100.0-float(gov.unrest))
	_draw_meter(Vector2(x+22,y+190),w-44.0,"PUBLIC SAFETY",100.0-float(gov.crime_pressure))

	var ry := y + 242.0
	draw_string(ThemeDB.fallback_font,Vector2(x+22,ry),"LAW REGISTER",HORIZONTAL_ALIGNMENT_LEFT,-1,12,ACCENT)
	ry += 28.0
	for i in range(GOVERNANCE_LAWS.size()):
		var key := GOVERNANCE_LAWS[i]
		var marker := ">" if i == governance_law_index else " "
		var col := TEXT if i == governance_law_index else MUTED
		draw_string(ThemeDB.fallback_font,Vector2(x+22,ry),"%s %-10s // %s" % [marker,key.to_upper(),str(gov.laws[key]).to_upper()],HORIZONTAL_ALIGNMENT_LEFT,-1,11,col)
		ry += 24.0
	draw_string(ThemeDB.fallback_font,Vector2(x+22,ry+4),"[↑/↓] SELECT LAW   [ENTER] CHANGE",HORIZONTAL_ALIGNMENT_LEFT,-1,10,RUST)

	ry += 42.0
	draw_string(ThemeDB.fallback_font,Vector2(x+22,ry),"POLITICAL BLOCS",HORIZONTAL_ALIGNMENT_LEFT,-1,12,ACCENT)
	ry += 26.0
	for faction_name in gov.factions.keys():
		var support := int(float(gov.factions[faction_name]["support"]))
		draw_string(ThemeDB.fallback_font,Vector2(x+22,ry),"%-18s %02d supporters" % [faction_name,support],HORIZONTAL_ALIGNMENT_LEFT,-1,10,MUTED)
		ry += 21.0

	ry += 8.0
	draw_string(ThemeDB.fallback_font,Vector2(x+22,ry),"JUSTICE SYSTEM // OPEN %d" % _open_case_count(),HORIZONTAL_ALIGNMENT_LEFT,-1,12,ACCENT)
	ry += 24.0
	for case in gov.active_cases:
		if case["status"] == "resolved":
			continue
		var suspect := sim.get_citizen_by_id(int(case["suspect_id"]))
		var suspect_name := "UNKNOWN" if suspect.is_empty() else suspect["name"]
		draw_string(ThemeDB.fallback_font,Vector2(x+22,ry),"CASE-%03d %s // %s // %d%%" % [int(case["id"]),case["type"],suspect_name,int(case["progress"])],HORIZONTAL_ALIGNMENT_LEFT,w-44,10,TEXT)
		ry += 22.0
		if ry > y+h-35:
			break

func _open_case_count() -> int:
	var count := 0
	for case in sim.governance_simulation.active_cases:
		if case["status"] != "resolved":
			count += 1
	return count

func _draw_hud() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(0, 0, vp.x, 118), Color("#07090cee"))
	draw_line(Vector2(0,118), Vector2(vp.x,118), ACCENT, 2.0)

	draw_string(ThemeDB.fallback_font, Vector2(24,32), "DPN // THE LAST SETTLEMENT", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, TEXT)
	draw_string(ThemeDB.fallback_font, Vector2(24,57), "CIVILIZATION RECOVERY COMMAND // %s" % sim.settlement_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, RUST)
	draw_string(ThemeDB.fallback_font, Vector2(24,89), "DAY %03d %02d:%02d // MAT %.0f // BP %d // ROOMS %d // GRID %.0f/%.0f // BAT %.0f%% // SAN %.0f%%" % [sim.day, int(sim.hour), int((sim.hour - floor(sim.hour)) * 60.0), float(sim.resources["materials"]), sim.blueprints.size(), sim.completed_rooms, float(sim.utility_state["power_generated"]), float(sim.utility_state["power_demand"]), 100.0 * float(sim.utility_state["battery_charge"]) / maxf(1.0,float(sim.utility_state["battery_capacity"])), float(sim.utility_state["sanitation"])], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ACCENT)

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
		build_text = "  // BUILD: %s  COST %.0f  [Q/E] TYPE  [F] ROTATE" % [definition["name"], float(definition["cost"])]
	var mode_text := "[M] SETTLEMENT MAP" if world_map_mode else "[M] WORLD MAP"
	if governance_mode:
		mode_text = "[V] CLOSE CIVIC COMMAND"
	elif economy_mode:
		mode_text = "[K] CLOSE INDUSTRY COMMAND"
	else:
		mode_text += "  [V] CIVIC COMMAND  [K] INDUSTRY"
	draw_string(ThemeDB.fallback_font, Vector2(24, vp.y - 24), mode_text + "  [B] BUILD  [U] UTIL:" + UTILITY_OVERLAYS[utility_overlay] + "  [R] REPAIR  [X] DEMOLISH  [S/L] SAVE/LOAD" + build_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
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
	var partner_name := "NONE"
	if int(c.get("partner_id",0)) > 0:
		var partner := sim.get_citizen_by_id(int(c["partner_id"]))
		if not partner.is_empty():
			partner_name = partner["name"]
	draw_string(ThemeDB.fallback_font, Vector2(x+20,y+150), "SEX: %s  •  PARTNER: %s" % [str(c.get("sex","UNKNOWN")).to_upper(), partner_name], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)

	var rows := [
		["HEALTH", c["health"]],
		["MORALE", c["morale"]],
		["LOYALTY", c["loyalty"]],
		["HUNGER", 100.0 - float(c["hunger"])],
		["THIRST", 100.0 - float(c["thirst"])],
		["REST", 100.0 - float(c["fatigue"])],
		["STRESS RESIST", 100.0 - float(c["stress"])],
		["SOCIAL", 100.0 - float(c.get("social_need",0.0))]
	]
	var ry := y + 186.0
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
	draw_string(ThemeDB.fallback_font, Vector2(x+20,ry), "SOCIAL RECORD", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ACCENT)
	ry += 24.0
	var children_count := c.get("children_ids", []).size()
	var memory_count := c.get("memories", []).size()
	draw_string(ThemeDB.fallback_font, Vector2(x+20,ry), "CHILDREN %d   MEMORIES %d" % [children_count, memory_count], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
	ry += 22.0
	var memories: Array = c.get("memories", [])
	if not memories.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(x+20,ry), "LATEST // %s" % str(memories[0]["text"]), HORIZONTAL_ALIGNMENT_LEFT, w-40, 10, TEXT)
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
	var utility := str(b.get("utility", ""))
	var node_status := "OPERATIONAL"
	var node_color := GOOD
	if utility == "generator" and sim.utility_failures["generator_trip"]:
		node_status = "TRIPPED"
		node_color = BAD
	elif utility in ["water_pump","purifier"] and not sim.utility_state["water_online"]:
		node_status = "DEGRADED"
		node_color = WARN
	elif utility == "sewage" and sim.utility_failures["sewage_overflow"]:
		node_status = "OVERFLOW"
		node_color = BAD
	draw_string(ThemeDB.fallback_font, Vector2(x+20,y+214), "NODE STATUS // %s" % node_status, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, node_color)
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
					build_rotated = false
			KEY_F:
				if build_mode:
					var definition := sim.get_build_catalog()[build_catalog_index]
					if definition["type"] == "wall" or definition["type"] == "door" or definition["type"] == "pipe":
						build_rotated = not build_rotated
			KEY_K:
				economy_mode = not economy_mode
				governance_mode = false
				world_map_mode = false
				build_mode = false
				selected_citizen = {}
				selected_building = {}
			KEY_V:
				governance_mode = not governance_mode
				economy_mode = false
				build_mode = false
				selected_citizen = {}
				selected_building = {}
			KEY_UP:
				if economy_mode:
					economy_item_index -= 1
					if economy_item_index < 0:
						economy_item_index = ECONOMY_ITEMS.size()-1
				elif governance_mode:
					governance_law_index -= 1
					if governance_law_index < 0:
						governance_law_index = GOVERNANCE_LAWS.size()-1
			KEY_DOWN:
				if economy_mode:
					economy_item_index = (economy_item_index+1) % ECONOMY_ITEMS.size()
				elif governance_mode:
					governance_law_index = (governance_law_index+1) % GOVERNANCE_LAWS.size()
			KEY_H:
				if economy_mode:
					var sources := sim.economy_simulation.get_trade_sources()
					if not sources.is_empty():
						economy_source_index = (economy_source_index+1) % sources.size()
			KEY_N:
				if economy_mode:
					economy_recipe_index = (economy_recipe_index+1) % ECONOMY_RECIPES.size()
			KEY_C:
				if economy_mode:
					sim.economy_simulation.queue_recipe(sim,ECONOMY_RECIPES[economy_recipe_index],1)
			KEY_ENTER:
				if economy_mode:
					sim.economy_simulation.trade_with_source(sim,economy_source_index,ECONOMY_ITEMS[economy_item_index],1.0,true)
				elif governance_mode:
					sim.governance_simulation.cycle_law(sim,GOVERNANCE_LAWS[governance_law_index])
			KEY_BACKSPACE:
				if economy_mode:
					sim.economy_simulation.trade_with_source(sim,economy_source_index,ECONOMY_ITEMS[economy_item_index],1.0,false)
			KEY_Y:
				if economy_mode:
					sim.economy_simulation.repair_vehicle(sim,0)
			KEY_M:
				world_map_mode = not world_map_mode
				governance_mode = false
				build_mode = false
				selected_citizen = {}
				selected_building = {}
			KEY_G:
				if world_map_mode and selected_world_location_id > 1:
					sim.world_simulation.create_expedition(sim, selected_world_location_id)
			KEY_U:
				utility_overlay = (utility_overlay + 1) % UTILITY_OVERLAYS.size()
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
			if governance_mode or economy_mode:
				pass
			elif world_map_mode:
				_world_map_select(event.position)
			elif build_mode:
				var definition := sim.get_build_catalog()[build_catalog_index]
				sim.place_blueprint(definition["type"], _screen_to_world(event.position), build_rotated)
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
