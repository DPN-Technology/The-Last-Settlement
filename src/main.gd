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
var settlement_visuals := SettlementVisuals.new()
var update_manager := UpdateManager.new()
var update_mode := false
var help_mode := false
var incident_panel_visible := false
var playtest_notice := ""
var playtest_notice_seconds := 0.0
var camera_offset := Vector2(72, -8)
var zoom := 0.86
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
var faction_mode := false
var faction_index := 0
var civilization_mode := false
var civilization_settlement_index := 0
var civilization_route_index := 0
var civilization_colony_project_index := 0
var civilization_recovery_project_index := 0
var civilization_candidate_index := 0
var economy_item_index := 0
var economy_source_index := 0
var economy_recipe_index := 0
const ECONOMY_RECIPES := ["Machine Parts","Components","Tool Kit","Fuel Blend","Vehicle Repair Kit","Utility Truck"]
const ECONOMY_ITEMS := ["food","water","medicine","materials","scrap","fuel","parts"]
const CIV_COLONY_PROJECTS := ["Housing Block","Farm Complex","Clinic Module","Workshop Bay","Defense Perimeter","Freight Depot","Radio Tower"]
const CIV_RECOVERY_PROJECTS := ["Regional Power Grid","Clean Water Network","Medical Corridor","Communications Backbone"]
var governance_law_index := 0
const GOVERNANCE_LAWS := ["rationing","security","labor","justice","speech"]
const UTILITY_OVERLAYS := ["OFF", "POWER", "WATER", "SEWAGE"]

func _ready() -> void:
	add_child(update_manager)
	update_manager.configure(SettlementSimulation.SAVE_VERSION)
	update_manager.state_changed.connect(queue_redraw)
	update_manager.call_deferred("auto_check_if_enabled")
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	sim.update(delta)
	_update_citizens(delta)
	if playtest_notice_seconds > 0.0:
		playtest_notice_seconds = maxf(0.0, playtest_notice_seconds - delta)
	queue_redraw()

func _update_citizens(delta: float) -> void:
	for c in sim.citizens:
		if not c["alive"] or str(c.get("home_settlement","LAST_HAVEN")) != "LAST_HAVEN":
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
	if help_mode:
		_draw_help_panel()
	elif update_mode:
		_draw_update_panel()
	elif governance_mode:
		_draw_governance_panel()
	elif economy_mode:
		_draw_economy_panel()
	elif faction_mode:
		_draw_faction_panel()
	elif civilization_mode:
		_draw_civilization_panel()
	else:
		_draw_selection_panel()

func _world_point(p: Vector2) -> Vector2:
	return (p + camera_offset) * zoom

func _screen_to_world(p: Vector2) -> Vector2:
	return p / zoom - camera_offset

func _draw_world() -> void:
	settlement_visuals.render(self, sim, camera_offset, zoom, selected_building, selected_citizen, build_mode, mouse_world, build_rotated, sim.get_build_catalog()[build_catalog_index])

func _draw_utility_overlay() -> void:
	if utility_overlay == 0:
		return
	var mode: String = str(UTILITY_OVERLAYS[utility_overlay])
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
		var col := GOOD if location["type"] in ["settlement","player_settlement"] else (WARN if location["type"] == "relay" else (Color("#7ca0c2") if location["type"] == "trade_hub" else (BAD if location["type"] == "faction_settlement" else RUST)))
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
		elif str(location["type"]) == "player_settlement":
			draw_string(ThemeDB.fallback_font,Vector2(x+20,301),"PLAYER SETTLEMENT // RECOVERY NETWORK",HORIZONTAL_ALIGNMENT_LEFT,-1,11,GOOD)
		elif str(location["type"]) in ["ruin","signal"] and bool(location.get("depleted",false)):
			draw_string(ThemeDB.fallback_font,Vector2(x+20,301),"SITE SECURED // [I] FOUND SETTLEMENT",HORIZONTAL_ALIGNMENT_LEFT,-1,11,GOOD)
		elif str(location["type"]) == "faction_settlement":
			draw_string(ThemeDB.fallback_font,Vector2(x+20,301),"INHABITED FACTION TERRITORY",HORIZONTAL_ALIGNMENT_LEFT,-1,11,BAD)
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
		var item: String = str(ECONOMY_ITEMS[i])
		var marker := ">" if i == economy_item_index else " "
		var col := TEXT if i == economy_item_index else MUTED
		draw_string(ThemeDB.fallback_font,Vector2(x+22,ry),"%s %-10s %.1f cr" % [marker,item.to_upper(),eco.get_trade_price(item,economy_source_index)],HORIZONTAL_ALIGNMENT_LEFT,-1,11,col)
		ry += 22.0
	draw_string(ThemeDB.fallback_font,Vector2(x+22,ry+4),"[↑/↓] ITEM  [H] MARKET  [ENTER] BUY 1  [BACKSPACE] SELL 1",HORIZONTAL_ALIGNMENT_LEFT,-1,10,RUST)
	ry += 30.0
	var selected_recipe: String = str(ECONOMY_RECIPES[economy_recipe_index])
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
	var vehicle: Dictionary = eco.vehicles[0] if not eco.vehicles.is_empty() else {}
	if not vehicle.is_empty():
		draw_string(ThemeDB.fallback_font,Vector2(x+22,y+h-78),"VEHICLE // %s  COND %.0f%%  FUEL %.1f" % [vehicle["name"],float(vehicle["condition"]),float(vehicle["fuel"])],HORIZONTAL_ALIGNMENT_LEFT,-1,10,MUTED)
		draw_string(ThemeDB.fallback_font,Vector2(x+22,y+h-58),"REPAIR KITS %.0f   FUEL BURN %.2f/day   [Y] REPAIR VEHICLE" % [eco.repair_kits,eco.fuel_consumed_today],HORIZONTAL_ALIGNMENT_LEFT,-1,10,RUST)



func _draw_civilization_panel() -> void:
	var vp := get_viewport_rect().size
	var x := maxf(18.0,vp.x-720.0)
	var y := 112.0
	var w := minf(700.0,vp.x-36.0)
	var h := vp.y-150.0
	var civ := sim.civilization_simulation
	var fed := sim.federal_governance_simulation
	var settlements: Array[Dictionary] = civ.get_settlement_list()
	var founding_candidates: Array[Dictionary] = civ.get_founding_candidates(sim)
	if civilization_settlement_index >= settlements.size():
		civilization_settlement_index = 0
	if civilization_route_index >= civ.logistics_routes.size():
		civilization_route_index = 0
	if civilization_colony_project_index >= CIV_COLONY_PROJECTS.size():
		civilization_colony_project_index = 0
	if civilization_recovery_project_index >= CIV_RECOVERY_PROJECTS.size():
		civilization_recovery_project_index = 0
	if civilization_candidate_index >= founding_candidates.size():
		civilization_candidate_index = 0

	draw_rect(Rect2(x,y,w,h),PANEL_SOLID)
	draw_rect(Rect2(x,y,w,h),GOOD,false,2.0)
	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+26),"CIVILIZATION COMMAND // RECOVERY NETWORK",HORIZONTAL_ALIGNMENT_LEFT,-1,14,GOOD)
	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+50),"PHASE // %s   NODES %d   ROUTES %d" % [civ.endgame_stage,settlements.size(),civ.logistics_routes.size()],HORIZONTAL_ALIGNMENT_LEFT,-1,11,TEXT)
	_draw_meter(Vector2(x+20,y+72),310.0,"RECOVERY",civ.recovery_score)
	_draw_meter(Vector2(x+360,y+72),310.0,"STABILITY",civ.civilization_stability)

	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+112),"NETWORK POLICY // A:%s  F:%s  S:%s" % [civ.civilization_policies["autonomy"],civ.civilization_policies["freight"],civ.civilization_policies["security"]],HORIZONTAL_ALIGNMENT_LEFT,w-40,9,MUTED)
	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+129),"[4] AUTONOMY  [5] FREIGHT  [6] SECURITY",HORIZONTAL_ALIGNMENT_LEFT,-1,9,RUST)
	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+149),"FEDERAL // LEG %.0f  COH %.0f  RESERVE %.1f" % [fed.federal_legitimacy,fed.network_cohesion,fed.federal_treasury],HORIZONTAL_ALIGNMENT_LEFT,320,9,ACCENT)
	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+166),"CHARTER // %s / %s / %s" % [fed.charter["representation"],fed.charter["contribution"],fed.charter["rights"]],HORIZONTAL_ALIGNMENT_LEFT,650,8,MUTED)
	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+182),"[T] REPRESENTATION  [Y] CONTRIBUTION  [U] RIGHTS  [B] FEDERAL RESERVE",HORIZONTAL_ALIGNMENT_LEFT,650,8,RUST)

	var recovery_name: String = CIV_RECOVERY_PROJECTS[civilization_recovery_project_index]
	var recovery_progress := civ.get_recovery_project_progress(recovery_name)
	var recovery_done := civ._recovery_project_complete(recovery_name)
	draw_string(ThemeDB.fallback_font,Vector2(x+360,y+149),"RECOVERY PROJECT // %s" % recovery_name.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,310,9,GOOD if recovery_done else ACCENT)
	draw_string(ThemeDB.fallback_font,Vector2(x+360,y+166),"PROGRESS %.0f%% // [7] NEXT  [8] CONTRIBUTE" % recovery_progress,HORIZONTAL_ALIGNMENT_LEFT,310,9,RUST)

	var split_x := x+344.0
	var left_x := x+20.0
	var right_x := split_x+16.0
	var body_y := y+210.0
	draw_line(Vector2(split_x,body_y),Vector2(split_x,y+h-18),PANEL_EDGE,1.0)

	draw_string(ThemeDB.fallback_font,Vector2(left_x,body_y),"COLONY OPERATIONS",HORIZONTAL_ALIGNMENT_LEFT,-1,11,ACCENT)
	if not settlements.is_empty():
		var s: Dictionary = settlements[civilization_settlement_index]
		var status: String = str(s.get("status","STABLE"))
		var status_color := BAD if status == "EMERGENCY" else (WARN if status in ["DEGRADED","RECOVERING"] else GOOD)
		draw_string(ThemeDB.fallback_font,Vector2(left_x,body_y+26),"[%d/%d] %s" % [civilization_settlement_index+1,settlements.size(),s["name"]],HORIZONTAL_ALIGNMENT_LEFT,305,16,TEXT)
		draw_string(ThemeDB.fallback_font,Vector2(left_x,body_y+48),"%s // %s" % [status,str(s["specialization"]).to_upper()],HORIZONTAL_ALIGNMENT_LEFT,305,9,status_color)
		if str(s.get("emergency","")) != "":
			draw_string(ThemeDB.fallback_font,Vector2(left_x,body_y+65),"EMERGENCY // %s" % str(s["emergency"]).to_upper(),HORIZONTAL_ALIGNMENT_LEFT,305,9,BAD)
		draw_string(ThemeDB.fallback_font,Vector2(left_x,body_y+84),"POP %d  INFRA %.0f  MORALE %.0f  SEC %.0f" % [int(s["population"]),float(s["infrastructure"]),float(s["morale"]),float(s["security"])],HORIZONTAL_ALIGNMENT_LEFT,305,9,MUTED)
		var res: Dictionary = s["resources"]
		draw_string(ThemeDB.fallback_font,Vector2(left_x,body_y+102),"F %.0f W %.0f MED %.0f MAT %.0f FUEL %.0f PART %.0f" % [float(res["food"]),float(res["water"]),float(res["medicine"]),float(res["materials"]),float(res["fuel"]),float(res["parts"])],HORIZONTAL_ALIGNMENT_LEFT,305,8,RUST)
		var modules: Dictionary = s.get("modules",{})
		draw_string(ThemeDB.fallback_font,Vector2(left_x,body_y+120),"MODULES H%d F%d C%d W%d D%d FD%d R%d" % [int(modules.get("housing",0)),int(modules.get("farm",0)),int(modules.get("clinic",0)),int(modules.get("workshop",0)),int(modules.get("defense",0)),int(modules.get("freight_depot",0)),int(modules.get("radio",0))],HORIZONTAL_ALIGNMENT_LEFT,305,8,MUTED)

		var selected_project: String = CIV_COLONY_PROJECTS[civilization_colony_project_index]
		var active_project: Dictionary = civ.get_active_colony_project(str(s["id"]))
		draw_string(ThemeDB.fallback_font,Vector2(left_x,body_y+148),"BUILD // %s" % selected_project.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,305,9,TEXT)
		draw_string(ThemeDB.fallback_font,Vector2(left_x,body_y+165),"[N] NEXT MODULE  [C] QUEUE",HORIZONTAL_ALIGNMENT_LEFT,305,9,RUST)
		if not active_project.is_empty():
			var project_progress := 100.0*float(active_project["progress"])/maxf(1.0,float(active_project["work"]))
			draw_string(ThemeDB.fallback_font,Vector2(left_x,body_y+184),"ACTIVE // %s // %.0f%%" % [active_project["project"],project_progress],HORIZONTAL_ALIGNMENT_LEFT,305,9,WARN)

		draw_string(ThemeDB.fallback_font,Vector2(left_x,body_y+214),"[←/→] SETTLEMENT  [E] REFOCUS",HORIZONTAL_ALIGNMENT_LEFT,305,9,GOOD)
		draw_string(ThemeDB.fallback_font,Vector2(left_x,body_y+232),"[A] EMERGENCY AID",HORIZONTAL_ALIGNMENT_LEFT,305,9,GOOD)
		var representative_name: String = fed.get_representative_name(sim,str(s["id"]))
		var capacity: int = civ.get_colony_capacity(s)
		draw_string(ThemeDB.fallback_font,Vector2(left_x,body_y+252),"REP // %s   CAPACITY %d" % [representative_name,capacity],HORIZONTAL_ALIGNMENT_LEFT,305,8,MUTED)

		draw_string(ThemeDB.fallback_font,Vector2(left_x,body_y+278),"FOUNDING / MIGRATION ROSTER // %d/%d" % [civ.founding_roster.size(),civ.FOUNDING_POPULATION],HORIZONTAL_ALIGNMENT_LEFT,305,9,ACCENT)
		if not founding_candidates.is_empty():
			var candidate: Dictionary = founding_candidates[civilization_candidate_index]
			var rostered: bool = civ.founding_roster.has(int(candidate["id"]))
			draw_string(ThemeDB.fallback_font,Vector2(left_x,body_y+298),"[%d/%d] %s // %s // %s" % [civilization_candidate_index+1,founding_candidates.size(),candidate["name"],candidate["job"],"ROSTER" if rostered else "AVAILABLE"],HORIZONTAL_ALIGNMENT_LEFT,305,8,GOOD if rostered else TEXT)
			draw_string(ThemeDB.fallback_font,Vector2(left_x,body_y+316),"[9] NEXT  [0] TOGGLE ROSTER  [D] DEPLOY TO COLONY",HORIZONTAL_ALIGNMENT_LEFT,305,8,RUST)
		else:
			draw_string(ThemeDB.fallback_font,Vector2(left_x,body_y+298),"No eligible Last Haven colonists.",HORIZONTAL_ALIGNMENT_LEFT,305,8,MUTED)

	draw_string(ThemeDB.fallback_font,Vector2(right_x,body_y),"REGIONAL LOGISTICS",HORIZONTAL_ALIGNMENT_LEFT,-1,11,ACCENT)
	var ry := body_y+24.0
	if civ.logistics_routes.is_empty():
		draw_string(ThemeDB.fallback_font,Vector2(right_x,ry),"No routes. Found a second settlement.",HORIZONTAL_ALIGNMENT_LEFT,320,9,MUTED)
		ry += 20.0
	else:
		for i in range(civ.logistics_routes.size()):
			var route: Dictionary = civ.logistics_routes[i]
			var source: Dictionary = civ.settlements[str(route["source"])]
			var destination: Dictionary = civ.settlements[str(route["destination"])]
			var marker: String = ">" if i == civilization_route_index else " "
			var route_status: String = "ON" if bool(route.get("active",true)) else "OFF"
			var route_color := TEXT if i == civilization_route_index else MUTED
			draw_string(ThemeDB.fallback_font,Vector2(right_x,ry),"%sR%02d %s↔%s // %s P%d %s" % [marker,int(route["id"]),source["name"],destination["name"],route_status,int(route.get("priority",2)),str(route.get("focus","Balanced")).to_upper()],HORIZONTAL_ALIGNMENT_LEFT,320,8,route_color)
			ry += 17.0
			if ry > body_y+110:
				break
		draw_string(ThemeDB.fallback_font,Vector2(right_x,ry+2),"[↑/↓] ROUTE [R] ON/OFF [F] FOCUS [P] PRIORITY",HORIZONTAL_ALIGNMENT_LEFT,320,8,RUST)
		ry += 24.0

	draw_string(ThemeDB.fallback_font,Vector2(right_x,ry+4),"RECOVERY PROGRAM",HORIZONTAL_ALIGNMENT_LEFT,-1,11,ACCENT)
	ry += 25.0
	for project_name_variant in CIV_RECOVERY_PROJECTS:
		var project_name: String = str(project_name_variant)
		var progress := civ.get_recovery_project_progress(project_name)
		var done := civ._recovery_project_complete(project_name)
		draw_string(ThemeDB.fallback_font,Vector2(right_x,ry),"%s // %.0f%%" % [project_name,progress],HORIZONTAL_ALIGNMENT_LEFT,320,8,GOOD if done else MUTED)
		ry += 16.0

	var archive_y := maxf(ry+10.0,body_y+230.0)
	draw_string(ThemeDB.fallback_font,Vector2(right_x,archive_y),"CIVILIZATION ARCHIVE",HORIZONTAL_ALIGNMENT_LEFT,-1,11,ACCENT)
	archive_y += 20.0
	var shown := 0
	for entry in civ.history_archive:
		draw_string(ThemeDB.fallback_font,Vector2(right_x,archive_y),"D%03d // %s" % [int(entry["day"]),entry["title"]],HORIZONTAL_ALIGNMENT_LEFT,320,8,TEXT)
		archive_y += 15.0
		shown += 1
		if shown >= 6 or archive_y > y+h-12:
			break

func _draw_faction_panel() -> void:
	var vp := get_viewport_rect().size
	var x := vp.x - 500.0
	var y := 138.0
	var w := 480.0
	var h := vp.y - 190.0
	var fs := sim.faction_simulation
	var visible := fs.get_visible_factions(sim)
	if faction_index >= visible.size():
		faction_index = 0

	draw_rect(Rect2(x,y,w,h),PANEL_SOLID)
	draw_rect(Rect2(x,y,w,h),BAD,false,2.0)
	draw_string(ThemeDB.fallback_font,Vector2(x+22,y+30),"FACTION COMMAND // REGIONAL INTELLIGENCE",HORIZONTAL_ALIGNMENT_LEFT,-1,14,BAD)

	if visible.is_empty():
		draw_string(ThemeDB.fallback_font,Vector2(x+22,y+70),"NO EXTERNAL SETTLEMENTS IN ACTIVE INTELLIGENCE RANGE.",HORIZONTAL_ALIGNMENT_LEFT,w-44,11,MUTED)
		draw_string(ThemeDB.fallback_font,Vector2(x+22,y+98),"Restore radio infrastructure and expand regional discovery.",HORIZONTAL_ALIGNMENT_LEFT,w-44,10,RUST)
		return

	var faction_name:String = visible[faction_index]
	var faction:Dictionary = fs.factions[faction_name]
	var location := sim.world_simulation.get_location_by_id(int(faction["location_id"]))
	var disposition := str(faction["disposition"])
	var disposition_color := GOOD if disposition in ["FRIENDLY","ALLIED"] else (BAD if disposition == "HOSTILE" else WARN)

	draw_string(ThemeDB.fallback_font,Vector2(x+22,y+66),faction_name,HORIZONTAL_ALIGNMENT_LEFT,-1,23,TEXT)
	draw_string(ThemeDB.fallback_font,Vector2(x+22,y+92),"%s // %s" % [location["name"],disposition],HORIZONTAL_ALIGNMENT_LEFT,-1,11,disposition_color)
	_draw_meter(Vector2(x+22,y+126),w-44.0,"REPUTATION",clampf((float(faction["reputation"])+100.0)*0.5,0.0,100.0))
	_draw_meter(Vector2(x+22,y+162),w-44.0,"STRENGTH",float(faction["strength"]))
	_draw_meter(Vector2(x+22,y+198),w-44.0,"WEALTH",float(faction["wealth"]))
	_draw_meter(Vector2(x+22,y+234),w-44.0,"INTELLIGENCE",float(faction["intel"]))

	var agreement := "ACTIVE" if bool(faction["trade_agreement"]) else "NONE"
	draw_string(ThemeDB.fallback_font,Vector2(x+22,y+286),"TRADE AGREEMENT // %s" % agreement,HORIZONTAL_ALIGNMENT_LEFT,-1,11,GOOD if agreement=="ACTIVE" else MUTED)
	draw_string(ThemeDB.fallback_font,Vector2(x+22,y+314),"[↑/↓] FACTION   [A] SEND AID   [D] TRADE AGREEMENT   [Z] TRUCE",HORIZONTAL_ALIGNMENT_LEFT,-1,10,RUST)

	if not fs.active_raid.is_empty():
		var attacker := str(fs.active_raid["faction"])
		var eta := float(fs.active_raid["eta_hours"])
		draw_string(ThemeDB.fallback_font,Vector2(x+22,y+356),"ACTIVE THREAT // %s // ETA %.1f HOURS" % [attacker,eta],HORIZONTAL_ALIGNMENT_LEFT,-1,12,BAD)
	else:
		draw_string(ThemeDB.fallback_font,Vector2(x+22,y+356),"ACTIVE THREAT // NONE",HORIZONTAL_ALIGNMENT_LEFT,-1,11,MUTED)

	draw_string(ThemeDB.fallback_font,Vector2(x+22,y+398),"RECENT CONFLICT",HORIZONTAL_ALIGNMENT_LEFT,-1,12,ACCENT)
	var ry := y + 424.0
	for record in fs.raid_log:
		var result := "REPELLED" if bool(record["victory"]) else "BREACHED"
		draw_string(ThemeDB.fallback_font,Vector2(x+22,ry),"D%d // %s // %s // DEF %.0f / ATK %.0f" % [int(record["day"]),record["faction"],result,float(record["defense"]),float(record["attack"])],HORIZONTAL_ALIGNMENT_LEFT,w-44,10,TEXT)
		ry += 22.0
		if ry > y+h-35:
			break

func _draw_help_panel() -> void:
	var vp := get_viewport_rect().size
	var w := minf(760.0, vp.x - 60.0)
	var h := minf(610.0, vp.y - 80.0)
	var x := (vp.x - w) * 0.5
	var y := (vp.y - h) * 0.5
	draw_rect(Rect2(x,y,w,h),Color("#090b0ef2"),true)
	draw_rect(Rect2(x,y,w,h),ACCENT,false,3.0)
	draw_string(ThemeDB.fallback_font,Vector2(x+28,y+42),"DPN // FIELD COMMAND ORIENTATION",HORIZONTAL_ALIGNMENT_LEFT,w-56,22,TEXT)
	draw_string(ThemeDB.fallback_font,Vector2(x+28,y+70),"LAST HAVEN SURVIVAL CONSOLE // QUICK START",HORIZONTAL_ALIGNMENT_LEFT,w-56,11,RUST)
	var lines := [
		["1 // KEEP PEOPLE ALIVE","Watch FOOD, WATER, POWER and MORALE. Select survivors to inspect health, needs, job, shift and skills."],
		["2 // BUILD THE SETTLEMENT","Press B for construction. Q/E changes the blueprint, F rotates compatible pieces, then left-click to place."],
		["3 // CONTROL TIME","SPACE pauses. 1 / 2 / 3 sets normal, fast and emergency simulation speed."],
		["4 // EXPAND BEYOND LAST HAVEN","Press M for the regional map. Select discovered sites, G dispatches expeditions, I founds eligible settlements."],
		["5 // RUN THE RECOVERY","V opens government, K industry, O factions and J civilization command. These systems become critical as the network grows."],
		["6 // PROTECT YOUR RUN","S saves, L loads. F9 writes diagnostics; F2 opens incidents. Right-drag pans."]
	]
	var ry := y + 112.0
	for row in lines:
		draw_string(ThemeDB.fallback_font,Vector2(x+28,ry),row[0],HORIZONTAL_ALIGNMENT_LEFT,w-56,12,ACCENT)
		ry += 23.0
		draw_string(ThemeDB.fallback_font,Vector2(x+28,ry),row[1],HORIZONTAL_ALIGNMENT_LEFT,w-56,10,MUTED)
		ry += 48.0
	draw_line(Vector2(x+28,y+h-82),Vector2(x+w-28,y+h-82),PANEL_EDGE,1.0)
	draw_string(ThemeDB.fallback_font,Vector2(x+28,y+h-48),"F1 // CLOSE OR REOPEN FIELD GUIDE     ESC // CLOSE",HORIZONTAL_ALIGNMENT_LEFT,w-56,12,GOOD)

func _draw_update_panel() -> void:
	var vp := get_viewport_rect().size
	var x := vp.x-520.0
	var y := 138.0
	var w := 500.0
	var h := minf(520.0,vp.y-180.0)
	var state_label := update_manager.get_state_label()
	var state_color := WARN
	if state_label in ["CURRENT","VERIFIED"]:
		state_color = GOOD
	elif state_label == "ERROR":
		state_color = BAD

	draw_rect(Rect2(x,y,w,h),PANEL_SOLID)
	draw_rect(Rect2(x,y,w,h),state_color,false,2.0)
	draw_string(ThemeDB.fallback_font,Vector2(x+22,y+32),"DPN UPDATE COMMAND // WINDOWS RELEASE CHANNEL",HORIZONTAL_ALIGNMENT_LEFT,w-44,14,state_color)
	draw_string(ThemeDB.fallback_font,Vector2(x+22,y+66),"CURRENT // %s" % update_manager.current_version,HORIZONTAL_ALIGNMENT_LEFT,-1,12,TEXT)
	draw_string(ThemeDB.fallback_font,Vector2(x+260,y+66),"SAVE SCHEMA // %d" % SettlementSimulation.SAVE_VERSION,HORIZONTAL_ALIGNMENT_LEFT,-1,11,MUTED)
	draw_string(ThemeDB.fallback_font,Vector2(x+22,y+96),"STATE // %s" % state_label,HORIZONTAL_ALIGNMENT_LEFT,-1,13,state_color)
	draw_string(ThemeDB.fallback_font,Vector2(x+22,y+122),update_manager.message,HORIZONTAL_ALIGNMENT_LEFT,w-44,10,MUTED)

	var ry := y+164.0
	if not update_manager.manifest.is_empty():
		var signing := str(update_manager.manifest.get("signing_status","unknown")).to_upper()
		var channel := str(update_manager.manifest.get("channel","stable")).to_upper()
		var target_schema := int(update_manager.manifest.get("save_schema",0))
		draw_string(ThemeDB.fallback_font,Vector2(x+22,ry),"TARGET // %s   CHANNEL // %s" % [update_manager.available_version,channel],HORIZONTAL_ALIGNMENT_LEFT,-1,11,TEXT)
		ry += 24.0
		draw_string(ThemeDB.fallback_font,Vector2(x+22,ry),"TARGET SAVE SCHEMA // %d   SIGNING // %s" % [target_schema,signing],HORIZONTAL_ALIGNMENT_LEFT,-1,10,WARN if signing=="UNSIGNED" else GOOD)
		ry += 32.0

	if state_label == "DOWNLOADING":
		draw_string(ThemeDB.fallback_font,Vector2(x+22,ry),"DOWNLOAD // %.1f%%" % update_manager.get_download_percent(),HORIZONTAL_ALIGNMENT_LEFT,-1,12,ACCENT)
		_draw_meter(Vector2(x+22,ry+18),w-44.0,"INSTALLER",update_manager.get_download_percent())
		ry += 64.0
	elif state_label == "AVAILABLE":
		draw_string(ThemeDB.fallback_font,Vector2(x+22,ry),"[F11] DOWNLOAD + VERIFY MSI",HORIZONTAL_ALIGNMENT_LEFT,-1,12,GOOD)
		ry += 32.0
	elif state_label == "VERIFIED":
		draw_string(ThemeDB.fallback_font,Vector2(x+22,ry),"SHA-256 VERIFIED // INSTALLER STAGED",HORIZONTAL_ALIGNMENT_LEFT,-1,11,GOOD)
		ry += 26.0
		draw_string(ThemeDB.fallback_font,Vector2(x+22,ry),"[F12] SAVE GAME + OPEN WINDOWS INSTALLER",HORIZONTAL_ALIGNMENT_LEFT,-1,12,GOOD)
		ry += 36.0
	elif state_label in ["ERROR","CURRENT","IDLE"]:
		draw_string(ThemeDB.fallback_font,Vector2(x+22,ry),"[F10] CLOSE / REOPEN TO CHECK AGAIN",HORIZONTAL_ALIGNMENT_LEFT,-1,10,RUST)
		ry += 34.0

	draw_string(ThemeDB.fallback_font,Vector2(x+22,ry),"UPDATE SAFETY POLICY",HORIZONTAL_ALIGNMENT_LEFT,-1,11,ACCENT)
	ry += 24.0
	draw_string(ThemeDB.fallback_font,Vector2(x+22,ry),"• HTTPS release manifest from the DPN GitHub release origin only",HORIZONTAL_ALIGNMENT_LEFT,w-44,9,MUTED)
	ry += 19.0
	draw_string(ThemeDB.fallback_font,Vector2(x+22,ry),"• Newer version required; downgrade packages are rejected",HORIZONTAL_ALIGNMENT_LEFT,w-44,9,MUTED)
	ry += 19.0
	draw_string(ThemeDB.fallback_font,Vector2(x+22,ry),"• Save schema may advance but may not downgrade current saves",HORIZONTAL_ALIGNMENT_LEFT,w-44,9,MUTED)
	ry += 19.0
	draw_string(ThemeDB.fallback_font,Vector2(x+22,ry),"• MSI must match release SHA-256 before installer handoff",HORIZONTAL_ALIGNMENT_LEFT,w-44,9,MUTED)
	ry += 19.0
	draw_string(ThemeDB.fallback_font,Vector2(x+22,ry),"• F12 explicitly approves installer launch; updates are never silent",HORIZONTAL_ALIGNMENT_LEFT,w-44,9,MUTED)

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
	var leader_name: String = "VACANT" if leader.is_empty() else str(leader["name"])
	draw_string(ThemeDB.fallback_font,Vector2(x+22,y+62),"GOVERNMENT // %s" % gov.government_type,HORIZONTAL_ALIGNMENT_LEFT,-1,12,TEXT)
	draw_string(ThemeDB.fallback_font,Vector2(x+22,y+86),"LEADER // %s" % leader_name,HORIZONTAL_ALIGNMENT_LEFT,-1,13,RUST)

	_draw_meter(Vector2(x+22,y+118),w-44.0,"LEGITIMACY",float(gov.legitimacy))
	_draw_meter(Vector2(x+22,y+154),w-44.0,"UNREST",100.0-float(gov.unrest))
	_draw_meter(Vector2(x+22,y+190),w-44.0,"PUBLIC SAFETY",100.0-float(gov.crime_pressure))

	var ry := y + 242.0
	draw_string(ThemeDB.fallback_font,Vector2(x+22,ry),"LAW REGISTER",HORIZONTAL_ALIGNMENT_LEFT,-1,12,ACCENT)
	ry += 28.0
	for i in range(GOVERNANCE_LAWS.size()):
		var key: String = str(GOVERNANCE_LAWS[i])
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
		var suspect_name: String = "UNKNOWN" if suspect.is_empty() else str(suspect["name"])
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
		if incident_panel_visible:
			_draw_event_panel()
		else:
			_draw_event_toasts()

	var status := "PAUSED" if sim.paused else ("x%.0f" % sim.speed)
	var build_text := ""
	if build_mode:
		var definition := sim.get_build_catalog()[build_catalog_index]
		build_text = "  // BUILD: %s  COST %.0f  [Q/E] TYPE  [F] ROTATE" % [definition["name"], float(definition["cost"])]
	var mode_text := "[M] SETTLEMENT MAP" if world_map_mode else "[M] WORLD MAP"
	if update_mode:
		mode_text = "[F10] CLOSE UPDATE COMMAND"
	elif governance_mode:
		mode_text = "[V] CLOSE CIVIC COMMAND"
	elif economy_mode:
		mode_text = "[K] CLOSE INDUSTRY COMMAND"
	elif faction_mode:
		mode_text = "[O] CLOSE FACTION COMMAND"
	elif civilization_mode:
		mode_text = "[J] CLOSE CIVILIZATION COMMAND"
	else:
		mode_text += "  [F1] GUIDE  [F2] EVENTS  [V] CIVIC  [K] INDUSTRY  [O] FACTIONS  [J] CIVILIZATION"
	var update_alert := ""
	if update_manager.get_state_label() == "AVAILABLE":
		update_alert = "  // UPDATE %s AVAILABLE" % update_manager.available_version
	elif update_manager.get_state_label() == "VERIFIED":
		update_alert = "  // UPDATE VERIFIED"
	draw_string(ThemeDB.fallback_font, Vector2(24, vp.y - 24), mode_text + "  [B] BUILD  [U] UTIL:" + UTILITY_OVERLAYS[utility_overlay] + "  [R] REPAIR  [X] DEMOLISH  [S/L] SAVE/LOAD" + build_text + update_alert, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GOOD if not update_alert.is_empty() else MUTED)
	draw_string(ThemeDB.fallback_font, Vector2(vp.x - 115, vp.y - 24), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ACCENT)
	if playtest_notice_seconds > 0.0:
		var width := minf(vp.x - 44.0, 680.0)
		draw_rect(Rect2(22, 125, width, 37), PANEL_SOLID, true)
		draw_rect(Rect2(22, 125, width, 37), GOOD, false, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(35, 148), playtest_notice, HORIZONTAL_ALIGNMENT_LEFT, width - 25.0, 12, GOOD)

func _draw_event_toasts() -> void:
	var vp := get_viewport_rect().size
	var left := vp.x - 334.0
	var y := vp.y - 171.0
	draw_rect(Rect2(left, y, 309, 106), Color("#111b1bd9"), true)
	draw_line(Vector2(left, y), Vector2(left + 309, y), ACCENT, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(left + 13, y + 20), "SETTLEMENT ACTIVITY    [F2] EXPAND", HORIZONTAL_ALIGNMENT_LEFT, 289, 11, TEXT)
	for i in range(mini(2, sim.events.size())):
		var incident: Dictionary = sim.events[i]
		var color := GOOD if str(incident.get("severity", "")) == "good" else WARN
		if str(incident.get("severity", "")) == "critical":
			color = BAD
		var row_y := y + 39.0 + float(i) * 30.0
		draw_circle(Vector2(left + 16, row_y), 3.0, color)
		draw_string(ThemeDB.fallback_font, Vector2(left + 27, row_y + 3), str(incident.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, 267, 11, TEXT)
		draw_string(ThemeDB.fallback_font, Vector2(left + 27, row_y + 17), str(incident.get("body", "")), HORIZONTAL_ALIGNMENT_LEFT, 267, 9, MUTED)

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
	var duty_enabled := sim.is_selected_work_enabled(c)
	draw_string(ThemeDB.fallback_font, Vector2(x+20,y+132), "SHIFT: %s  •  %s PRIORITY: %s  •  DUTY: %s" % [c["shift"], c["job"].to_upper(), "-" if not duty_enabled else str(int(c["work_priority"].get(c["job"],3))), "ACTIVE" if duty_enabled else "OFF"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GOOD if duty_enabled else WARN)
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
	var children_count: int = c.get("children_ids", []).size()
	var memory_count: int = c.get("memories", []).size()
	draw_string(ThemeDB.fallback_font, Vector2(x+20,ry), "CHILDREN %d   MEMORIES %d" % [children_count, memory_count], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
	ry += 22.0
	var memories: Array = c.get("memories", [])
	if not memories.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(x+20,ry), "LATEST // %s" % str(memories[0]["text"]), HORIZONTAL_ALIGNMENT_LEFT, w-40, 10, TEXT)
		ry += 24.0
	draw_string(ThemeDB.fallback_font, Vector2(x+20,ry), "POCKET INVENTORY", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ACCENT)
	ry += 28.0
	var inv: Dictionary = c["inventory"]
	draw_string(ThemeDB.fallback_font, Vector2(x+20,ry), "RATION %d   WATER %d   MED %d   SCRAP %d" % [int(inv["food_ration"]),int(inv["water_ration"]),int(inv["medicine"]),int(inv["scrap"])], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
	ry += 28.0
	draw_string(ThemeDB.fallback_font, Vector2(x+20,ry), "[T] SHIFT   [P] PRIORITY   [W] TOGGLE DUTY", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, RUST)

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
		if not c["alive"] or str(c.get("home_settlement","LAST_HAVEN")) != "LAST_HAVEN":
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
			KEY_F1:
				help_mode = not help_mode
			KEY_F2:
				incident_panel_visible = not incident_panel_visible
			KEY_F9:
				var report_path := PlaytestReporter.capture(sim)
				if report_path.is_empty():
					playtest_notice = "PLAYTEST REPORT FAILED // CHECK USER DATA FOLDER"
				else:
					playtest_notice = "PLAYTEST REPORT SAVED // " + report_path.get_file()
					if OS.get_name() == "Windows":
						OS.shell_open(report_path.get_base_dir())
				playtest_notice_seconds = 9.0
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
				if civilization_mode:
					sim.federal_governance_simulation.cycle_charter(sim,"representation")
				elif not selected_citizen.is_empty():
					sim.cycle_selected_shift(selected_citizen)
			KEY_P:
				if civilization_mode and not sim.civilization_simulation.logistics_routes.is_empty():
					var route := sim.civilization_simulation.logistics_routes[civilization_route_index]
					sim.civilization_simulation.cycle_route_priority(int(route["id"]))
				elif not selected_citizen.is_empty():
					sim.cycle_selected_priority(selected_citizen)
			KEY_F10:
				update_mode = not update_mode
				governance_mode = false
				economy_mode = false
				faction_mode = false
				civilization_mode = false
				build_mode = false
				selected_citizen = {}
				selected_building = {}
				if update_mode and update_manager.get_state_label() in ["IDLE","ERROR","CURRENT"]:
					update_manager.check_for_updates()
			KEY_F11:
				if update_mode:
					update_manager.download_update()
			KEY_F12:
				if update_mode and update_manager.get_state_label() == "VERIFIED":
					if sim.save_game():
						sim.paused = true
						if not update_manager.handoff_installer():
							sim.paused = false
			KEY_B:
				if civilization_mode:
					var settlements := sim.civilization_simulation.get_settlement_list()
					if not settlements.is_empty():
						var settlement: Dictionary = settlements[civilization_settlement_index]
						sim.federal_governance_simulation.spend_reserve_for_emergency(sim,str(settlement["id"]))
				else:
					build_mode = not build_mode
					selected_citizen = {}
					selected_building = {}
			KEY_Q:
				if build_mode:
					build_catalog_index -= 1
					if build_catalog_index < 0:
						build_catalog_index = sim.get_build_catalog().size() - 1
			KEY_E:
				if civilization_mode:
					var settlements := sim.civilization_simulation.get_settlement_list()
					if not settlements.is_empty():
						var settlement:Dictionary = settlements[civilization_settlement_index]
						sim.civilization_simulation.cycle_settlement_specialization(sim,str(settlement["id"]))
				elif build_mode:
					build_catalog_index = (build_catalog_index + 1) % sim.get_build_catalog().size()
					build_rotated = false
			KEY_F:
				if civilization_mode and not sim.civilization_simulation.logistics_routes.is_empty():
					var route := sim.civilization_simulation.logistics_routes[civilization_route_index]
					sim.civilization_simulation.cycle_route_focus(int(route["id"]))
				elif build_mode:
					var definition := sim.get_build_catalog()[build_catalog_index]
					if definition["type"] == "wall" or definition["type"] == "door" or definition["type"] == "pipe":
						build_rotated = not build_rotated
			KEY_K:
				economy_mode = not economy_mode
				governance_mode = false
				faction_mode = false
				civilization_mode = false
				world_map_mode = false
				build_mode = false
				selected_citizen = {}
				selected_building = {}
			KEY_V:
				governance_mode = not governance_mode
				economy_mode = false
				faction_mode = false
				civilization_mode = false
				build_mode = false
				selected_citizen = {}
				selected_building = {}
			KEY_O:
				faction_mode = not faction_mode
				governance_mode = false
				economy_mode = false
				civilization_mode = false
				world_map_mode = false
				build_mode = false
				selected_citizen = {}
				selected_building = {}
			KEY_J:
				civilization_mode = not civilization_mode
				governance_mode = false
				economy_mode = false
				faction_mode = false
				world_map_mode = false
				build_mode = false
				selected_citizen = {}
				selected_building = {}
			KEY_LEFT:
				if civilization_mode:
					var settlements := sim.civilization_simulation.get_settlement_list()
					if not settlements.is_empty():
						civilization_settlement_index -= 1
						if civilization_settlement_index < 0:
							civilization_settlement_index = settlements.size()-1
			KEY_RIGHT:
				if civilization_mode:
					var settlements := sim.civilization_simulation.get_settlement_list()
					if not settlements.is_empty():
						civilization_settlement_index = (civilization_settlement_index+1) % settlements.size()
			KEY_I:
				if world_map_mode and selected_world_location_id > 1:
					sim.civilization_simulation.found_settlement(sim,selected_world_location_id)
			KEY_UP:
				if civilization_mode:
					if not sim.civilization_simulation.logistics_routes.is_empty():
						civilization_route_index -= 1
						if civilization_route_index < 0:
							civilization_route_index = sim.civilization_simulation.logistics_routes.size()-1
				elif faction_mode:
					var visible := sim.faction_simulation.get_visible_factions(sim)
					if not visible.is_empty():
						faction_index -= 1
						if faction_index < 0:
							faction_index = visible.size()-1
				elif economy_mode:
					economy_item_index -= 1
					if economy_item_index < 0:
						economy_item_index = ECONOMY_ITEMS.size()-1
				elif governance_mode:
					governance_law_index -= 1
					if governance_law_index < 0:
						governance_law_index = GOVERNANCE_LAWS.size()-1
			KEY_DOWN:
				if civilization_mode:
					if not sim.civilization_simulation.logistics_routes.is_empty():
						civilization_route_index = (civilization_route_index+1) % sim.civilization_simulation.logistics_routes.size()
				elif faction_mode:
					var visible := sim.faction_simulation.get_visible_factions(sim)
					if not visible.is_empty():
						faction_index = (faction_index+1) % visible.size()
				elif economy_mode:
					economy_item_index = (economy_item_index+1) % ECONOMY_ITEMS.size()
				elif governance_mode:
					governance_law_index = (governance_law_index+1) % GOVERNANCE_LAWS.size()
			KEY_A:
				if civilization_mode:
					var settlements := sim.civilization_simulation.get_settlement_list()
					if not settlements.is_empty():
						var settlement:Dictionary = settlements[civilization_settlement_index]
						sim.civilization_simulation.send_emergency_aid(sim,str(settlement["id"]))
				elif faction_mode:
					var visible := sim.faction_simulation.get_visible_factions(sim)
					if not visible.is_empty():
						sim.faction_simulation.send_aid(sim,visible[faction_index])
			KEY_D:
				if civilization_mode:
					var candidates := sim.civilization_simulation.get_founding_candidates(sim)
					var settlements := sim.civilization_simulation.get_settlement_list()
					if not candidates.is_empty() and not settlements.is_empty():
						if civilization_candidate_index >= candidates.size():
							civilization_candidate_index = 0
						var candidate: Dictionary = candidates[civilization_candidate_index]
						var settlement: Dictionary = settlements[civilization_settlement_index]
						sim.civilization_simulation.deploy_citizen_to_colony(sim,int(candidate["id"]),str(settlement["id"]))
				elif faction_mode:
					var visible := sim.faction_simulation.get_visible_factions(sim)
					if not visible.is_empty():
						sim.faction_simulation.propose_trade_agreement(sim,visible[faction_index])
			KEY_Z:
				if faction_mode:
					var visible := sim.faction_simulation.get_visible_factions(sim)
					if not visible.is_empty():
						sim.faction_simulation.request_truce(sim,visible[faction_index])
			KEY_H:
				if economy_mode:
					var sources := sim.economy_simulation.get_trade_sources()
					if not sources.is_empty():
						economy_source_index = (economy_source_index+1) % sources.size()
			KEY_N:
				if civilization_mode:
					civilization_colony_project_index = (civilization_colony_project_index+1) % CIV_COLONY_PROJECTS.size()
				elif economy_mode:
					economy_recipe_index = (economy_recipe_index+1) % ECONOMY_RECIPES.size()
			KEY_C:
				if civilization_mode:
					var settlements := sim.civilization_simulation.get_settlement_list()
					if not settlements.is_empty():
						var settlement: Dictionary = settlements[civilization_settlement_index]
						sim.civilization_simulation.queue_colony_project(sim,str(settlement["id"]),CIV_COLONY_PROJECTS[civilization_colony_project_index])
				elif economy_mode:
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
				if civilization_mode:
					sim.federal_governance_simulation.cycle_charter(sim,"contribution")
				elif economy_mode:
					sim.economy_simulation.repair_vehicle(sim,0)
			KEY_4:
				if civilization_mode:
					sim.civilization_simulation.cycle_policy(sim,"autonomy")
			KEY_5:
				if civilization_mode:
					sim.civilization_simulation.cycle_policy(sim,"freight")
			KEY_6:
				if civilization_mode:
					sim.civilization_simulation.cycle_policy(sim,"security")
			KEY_7:
				if civilization_mode:
					civilization_recovery_project_index = (civilization_recovery_project_index+1) % CIV_RECOVERY_PROJECTS.size()
			KEY_8:
				if civilization_mode:
					sim.civilization_simulation.contribute_recovery_project(sim,CIV_RECOVERY_PROJECTS[civilization_recovery_project_index])
			KEY_9:
				if civilization_mode:
					var candidates := sim.civilization_simulation.get_founding_candidates(sim)
					if not candidates.is_empty():
						civilization_candidate_index = (civilization_candidate_index+1) % candidates.size()
			KEY_0:
				if civilization_mode:
					var candidates := sim.civilization_simulation.get_founding_candidates(sim)
					if not candidates.is_empty():
						if civilization_candidate_index >= candidates.size():
							civilization_candidate_index = 0
						sim.civilization_simulation.toggle_founding_candidate(sim,int(candidates[civilization_candidate_index]["id"]))
			KEY_M:
				world_map_mode = not world_map_mode
				governance_mode = false
				economy_mode = false
				faction_mode = false
				civilization_mode = false
				build_mode = false
				selected_citizen = {}
				selected_building = {}
			KEY_G:
				if world_map_mode and selected_world_location_id > 1:
					sim.world_simulation.create_expedition(sim, selected_world_location_id)
			KEY_U:
				if civilization_mode:
					sim.federal_governance_simulation.cycle_charter(sim,"rights")
				else:
					utility_overlay = (utility_overlay + 1) % UTILITY_OVERLAYS.size()
			KEY_R:
				if civilization_mode and not sim.civilization_simulation.logistics_routes.is_empty():
					var route := sim.civilization_simulation.logistics_routes[civilization_route_index]
					sim.civilization_simulation.toggle_route(int(route["id"]))
				elif not selected_building.is_empty():
					sim.queue_repair(selected_building)
			KEY_X:
				if not selected_building.is_empty():
					sim.demolish_building(selected_building)
					selected_building = {}
			KEY_ESCAPE:
				if help_mode:
					help_mode = false
				elif update_mode:
					update_mode = false
				else:
					selected_citizen = {}
					selected_building = {}
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if update_mode or governance_mode or economy_mode or faction_mode or civilization_mode:
				pass
			elif world_map_mode:
				_world_map_select(event.position)
			elif build_mode:
				var definition := sim.get_build_catalog()[build_catalog_index]
				sim.place_blueprint(definition["type"], _screen_to_world(event.position), build_rotated)
			else:
				_select_at(event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			var world_anchor := _screen_to_world(event.position)
			zoom = minf(1.75, zoom + 0.08)
			camera_offset = event.position / zoom - world_anchor
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			var world_anchor := _screen_to_world(event.position)
			zoom = maxf(0.6, zoom - 0.08)
			camera_offset = event.position / zoom - world_anchor
		elif event.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			dragging = event.pressed
			drag_origin = event.position
	elif event is InputEventMouseMotion:
		mouse_world = _screen_to_world(event.position)
		if dragging:
			var drag_delta: Vector2 = event.position - drag_origin
			camera_offset += drag_delta / zoom
			drag_origin = event.position
