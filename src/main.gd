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
# 3D world renders to a dedicated viewport; the existing campaign HUD stays
# CanvasItem-based until it is replaced with proper screen-space UI scenes.
var settlement_viewport: SubViewport
var settlement_world: SettlementWorld3D
var update_manager := UpdateManager.new()
var update_mode := false
var help_mode := false
var incident_panel_visible := false
var field_directives_visible := false
var overview_visible := false
var playtest_notice := ""
var playtest_notice_seconds := 0.0
var camera_offset := Vector2(-75, -34)
var zoom := 1.04
var dragging := false
var drag_origin := Vector2.ZERO
var selected_citizen: Dictionary = {}
var selected_building: Dictionary = {}
var selected_blueprint: Dictionary = {}
var build_mode := false
var build_catalog_index := 0
var build_category := "ALL"
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
const TOOLBAR_NAMES := ["BUILD", "REGION", "GOVERN", "INDUSTRY", "FACTIONS", "NATION", "SAVE", "LOAD", "GUIDE"]
const TOOLBAR_HINTS := ["B", "M", "V", "K", "O", "J", "S", "L", "F1"]
const TOOLBAR_KEYS := [KEY_B, KEY_M, KEY_V, KEY_K, KEY_O, KEY_J, KEY_S, KEY_L, KEY_F1]

func _ready() -> void:
	settlement_viewport = SubViewport.new()
	settlement_viewport.name = "Live3DViewport"
	settlement_viewport.size = Vector2i(get_viewport_rect().size)
	settlement_viewport.own_world_3d = true
	settlement_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	settlement_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(settlement_viewport)
	settlement_world = SettlementWorld3D.new()
	settlement_world.name = "LastHavenWorld"
	settlement_viewport.add_child(settlement_world)
	add_child(update_manager)
	update_manager.configure(SettlementSimulation.SAVE_VERSION)
	update_manager.state_changed.connect(queue_redraw)
	update_manager.call_deferred("auto_check_if_enabled")
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	var screen_size := Vector2i(get_viewport_rect().size)
	if settlement_viewport.size != screen_size and screen_size.x > 0 and screen_size.y > 0:
		settlement_viewport.size = screen_size
	sim.update(delta)
	sim.check_field_objectives()
	if not sim.paused:
		_update_citizens(delta)
	if playtest_notice_seconds > 0.0:
		playtest_notice_seconds = maxf(0.0, playtest_notice_seconds - delta)
	settlement_world.sync(sim, selected_building, selected_citizen, build_mode, mouse_world, sim.get_build_catalog()[build_catalog_index], build_rotated, delta)
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
	if not help_mode and not update_mode:
		if build_mode:
			_draw_build_palette()
		elif not world_map_mode and not governance_mode and not economy_mode and not faction_mode and not civilization_mode:
			if field_directives_visible:
				_draw_field_objectives()
			else:
				_draw_directive_tab()
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
	# Action buttons are drawn after command content and use the same hitboxes
	# as input handling. Keyboard-only workflows now have mouse equivalents.
	_draw_panel_actions()
	if overview_visible:
		_draw_overview()

func _panel_action_items() -> Array:
	if help_mode:
		return []
	if update_mode:
		return [["DOWNLOAD",KEY_F11],["INSTALL",KEY_F12],["CLOSE",KEY_ESCAPE]]
	if governance_mode:
		return [["PREV LAW",KEY_UP],["NEXT LAW",KEY_DOWN],["CHANGE",KEY_ENTER],["CLOSE",KEY_ESCAPE]]
	if economy_mode:
		return [["PREV",KEY_UP],["NEXT",KEY_DOWN],["MARKET",KEY_H],["RECIPE",KEY_N],["BUY 1",KEY_ENTER],["SELL 1",KEY_BACKSPACE],["QUEUE",KEY_C],["CLOSE",KEY_ESCAPE]]
	if faction_mode:
		return [["PREV",KEY_UP],["NEXT",KEY_DOWN],["SEND AID",KEY_A],["TRADE",KEY_D],["TRUCE",KEY_Z],["CLOSE",KEY_ESCAPE]]
	if civilization_mode:
		return [["PREV SITE",KEY_LEFT],["NEXT SITE",KEY_RIGHT],["PREV ROUTE",KEY_UP],["NEXT ROUTE",KEY_DOWN],["CLOSE",KEY_ESCAPE]]
	if world_map_mode:
		return [["DISPATCH",KEY_G],["CLOSE",KEY_ESCAPE]]
	return []

func _action_panel_area() -> Rect2:
	var vp := get_viewport_rect().size
	if civilization_mode:
		return SettlementUILayout.side_panel(vp,700.0)
	if update_mode:
		var r := SettlementUILayout.side_panel(vp,500.0)
		return Rect2(r.position,Vector2(r.size.x,minf(520.0,r.size.y)))
	if world_map_mode:
		return SettlementUILayout.side_panel(vp,372.0)
	return SettlementUILayout.side_panel(vp,480.0)

func _panel_action_rect(index: int, count: int) -> Rect2:
	var area := _action_panel_area()
	var gap := 5.0
	if count > 5:
		var columns := 4
		var width := (area.size.x-26.0-gap*float(columns-1))/float(columns)
		var row := int(index / columns)
		return Rect2(area.position.x+13.0+float(index%columns)*(width+gap),area.end.y-73.0+float(row)*33.0,width,28.0)
	var width := (area.size.x-26.0-gap*float(count-1))/maxf(1.0,float(count))
	return Rect2(area.position.x+13.0+float(index)*(width+gap),area.end.y-40.0,width,29.0)

func _draw_panel_actions() -> void:
	var actions := _panel_action_items()
	if actions.is_empty():
		return
	var area := _action_panel_area()
	var tall := actions.size()>5
	draw_rect(Rect2(area.position.x+5,area.end.y-(80.0 if tall else 47.0),area.size.x-10,77.0 if tall else 44.0),Color("#0b161def"))
	draw_line(Vector2(area.position.x+12,area.end.y-(80.0 if tall else 47.0)),Vector2(area.end.x-12,area.end.y-(80.0 if tall else 47.0)),ACCENT,1.0)
	for i in range(actions.size()):
		var row: Array = actions[i]
		var rect := _panel_action_rect(i,actions.size())
		var hover := rect.has_point(get_local_mouse_position())
		draw_rect(rect,Color("#603037") if hover else Color("#213039"))
		draw_rect(rect,ACCENT if hover else Color("#48636b"),false,1.0)
		draw_string(ThemeDB.fallback_font,rect.position+Vector2(6,18),str(row[0]),HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-10,10,TEXT)

func _handle_panel_action_click(position: Vector2) -> bool:
	var actions := _panel_action_items()
	for i in range(actions.size()):
		var rect := _panel_action_rect(i,actions.size())
		if not rect.has_point(position):
			continue
		var action: Array = actions[i]
		var previous_credits := sim.economy_simulation.credits
		var previous_queue := sim.economy_simulation.production_queue.size()
		var previous_law: String = str(sim.governance_simulation.laws[GOVERNANCE_LAWS[governance_law_index]])
		var mode_industry := economy_mode
		var mode_governance := governance_mode
		var event := InputEventKey.new()
		event.keycode = int(action[1])
		event.pressed = true
		_unhandled_input(event)
		if mode_industry and str(action[0]) in ["BUY 1","SELL 1"]:
			playtest_notice = "TRADE COMPLETED" if absf(sim.economy_simulation.credits-previous_credits)>0.001 else "TRADE NOT AVAILABLE  /  CHECK STOCK & CREDITS"
			playtest_notice_seconds = 5.0
		elif mode_industry and str(action[0])=="QUEUE":
			playtest_notice = "PRODUCTION ORDER ADDED" if sim.economy_simulation.production_queue.size()>previous_queue else "PRODUCTION ORDER UNAVAILABLE"
			playtest_notice_seconds = 4.0
		elif mode_governance and str(action[0])=="CHANGE":
			var current := str(sim.governance_simulation.laws[GOVERNANCE_LAWS[governance_law_index]])
			playtest_notice = "LAW UPDATED  /  "+current if current!=previous_law else "NO POLICY CHANGE"
			playtest_notice_seconds = 4.0
		return true
	return false

func _handle_command_content_click(position: Vector2) -> bool:
	var vp := get_viewport_rect().size
	if governance_mode:
		var area := SettlementUILayout.side_panel(vp,480.0)
		for i in range(GOVERNANCE_LAWS.size()):
			var row := Rect2(area.position+Vector2(18,263.0+float(i)*28.0),Vector2(area.size.x-36.0,26.0))
			if row.has_point(position):
				governance_law_index = i
				return true
		return area.has_point(position)
	if economy_mode:
		var area := SettlementUILayout.side_panel(vp,480.0)
		for i in range(ECONOMY_ITEMS.size()):
			var row := Rect2(area.position+Vector2(17.0,158.0+float(i)*22.0),Vector2(area.size.x-34.0,21.0))
			if row.has_point(position):
				economy_item_index = i
				return true
		return area.has_point(position)
	return false

func _world_point(p: Vector2) -> Vector2:
	return settlement_world.screen_at(p) if settlement_world != null else (p + camera_offset) * zoom

func _screen_to_world(p: Vector2) -> Vector2:
	return settlement_world.ground_at(p) if settlement_world != null else p / zoom - camera_offset

func _draw_world() -> void:
	if settlement_viewport != null:
		draw_texture_rect(settlement_viewport.get_texture(), Rect2(Vector2.ZERO, get_viewport_rect().size), false)


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

func _region_can_dispatch(location: Dictionary) -> bool:
	if location.is_empty():
		return false
	return int(location.get("id",0)) > 1 and bool(location.get("discovered",false)) and not bool(location.get("depleted",false)) and str(location.get("type","")) not in ["settlement","player_settlement","trade_hub","faction_settlement"]

func _dispatch_region() -> bool:
	var place := sim.world_simulation.get_location_by_id(selected_world_location_id)
	if not _region_can_dispatch(place):
		playtest_notice = "SELECT A DISCOVERED SALVAGE SITE FIRST"
		playtest_notice_seconds = 4.0
		return false
	var ok := sim.world_simulation.create_expedition(sim,selected_world_location_id)
	var event_text := ""
	if not sim.events.is_empty():
		event_text = str(sim.events[0].get("body",""))
	playtest_notice = ("EXPEDITION DISPATCHED  /  " + str(place["name"])) if ok else ("EXPEDITION BLOCKED  /  " + event_text)
	playtest_notice_seconds = 5.0
	return ok

func _draw_world_map() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(0,SettlementUILayout.TOP_H,vp.x,vp.y-SettlementUILayout.TOP_H),Color("#090f14"))
	var side := SettlementUILayout.side_panel(vp,372.0)
	var map := SettlementUILayout.region_map_rect(vp)
	draw_string(ThemeDB.fallback_font,Vector2(17,SettlementUILayout.TOP_H+27.0),"REGION  /  EXPLORE & SALVAGE",HORIZONTAL_ALIGNMENT_LEFT,440,17,TEXT)
	draw_string(ThemeDB.fallback_font,Vector2(17,SettlementUILayout.TOP_H+45.0),"Select a discovered location to inspect it.",HORIZONTAL_ALIGNMENT_LEFT,320,11,MUTED)
	draw_rect(Rect2(12,SettlementUILayout.TOP_H+58,220,vp.y-SettlementUILayout.TOP_H-SettlementUILayout.BOTTOM_H-66),Color("#111e26ee"))
	draw_rect(Rect2(12,SettlementUILayout.TOP_H+58,220,vp.y-SettlementUILayout.TOP_H-SettlementUILayout.BOTTOM_H-66),Color("#3b5662"),false,1)
	var discovered := sim.world_simulation.get_discovered_locations()
	var site_rows := mini(discovered.size(),mini(12,int((vp.y-SettlementUILayout.TOP_H-SettlementUILayout.BOTTOM_H-97.0)/29.0)))
	for i in range(site_rows):
		var entry: Dictionary = discovered[i]
		var r := SettlementUILayout.region_site_row(vp,i)
		var selected := int(entry["id"]) == selected_world_location_id
		var risk := float(entry.get("danger",0.0))
		draw_rect(r,Color("#48252d") if selected else (Color("#22363e") if r.has_point(get_local_mouse_position()) else Color("#182931")))
		draw_rect(Rect2(r.position,Vector2(3,r.size.y)),ACCENT if selected else (BAD if risk>0.50 else GOOD))
		draw_string(ThemeDB.fallback_font,r.position+Vector2(8,17),str(entry["name"]),HORIZONTAL_ALIGNMENT_LEFT,r.size.x-44,10,TEXT if selected else MUTED)
		draw_string(ThemeDB.fallback_font,r.position+Vector2(r.size.x-34,17),"%d%%" % int(risk*100.0),HORIZONTAL_ALIGNMENT_RIGHT,28,9,WARN if risk<0.5 else BAD)
	if discovered.size()>site_rows:
		draw_string(ThemeDB.fallback_font,Vector2(22,vp.y-SettlementUILayout.BOTTOM_H-15),"%d sites visible  /  %d discovered" % [site_rows,discovered.size()],HORIZONTAL_ALIGNMENT_LEFT,200,10,WARN)
	# Normalized projection shared with _world_map_select; all nodes remain
	# within the map canvas, regardless of normal or fullscreen resolution.
	draw_rect(map,Color("#141f24"))
	for line in range(1,7):
		var gx := map.position.x+map.size.x*float(line)/7.0
		var gy := map.position.y+map.size.y*float(line)/7.0
		draw_line(Vector2(gx,map.position.y),Vector2(gx,map.end.y),Color("#263b446e"),1)
		draw_line(Vector2(map.position.x,gy),Vector2(map.end.x,gy),Color("#263b446e"),1)
	draw_rect(map,Color("#617880"),false,1)
	var home := SettlementUILayout.region_point(vp,Vector2(600,410))
	var scale_range := minf(map.size.x/1200.0,map.size.y/820.0)*sim.world_simulation.get_radio_range()
	draw_circle(home,scale_range,Color("#743a35",0.13))
	draw_arc(home,scale_range,0.0,TAU,64,Color("#ca5758",0.66),1.0)
	for location in sim.world_simulation.locations:
		var location_pos := SettlementUILayout.region_point(vp,Vector2(location["position"]))
		var discovered_site := bool(location.get("discovered",false))
		if not discovered_site:
			draw_circle(location_pos,3.5,Color("#40515b"))
			continue
		var id := int(location["id"])
		var risk := float(location.get("danger",0.0))
		var color := GOOD if str(location["type"]) in ["settlement","player_settlement"] else (BAD if risk>0.50 else WARN)
		if bool(location.get("depleted",false)):
			color = MUTED
		draw_circle(location_pos,6.0,color)
		if selected_world_location_id == id:
			draw_arc(location_pos,12.0,0.0,TAU,24,ACCENT,2.0)
		if map.size.x >= 370.0:
			draw_string(ThemeDB.fallback_font,location_pos+Vector2(10,-8),str(location["name"]),HORIZONTAL_ALIGNMENT_LEFT,115,10,TEXT)
	for expedition in sim.world_simulation.get_active_expeditions():
		var destination: Dictionary = sim.world_simulation.get_location_by_id(int(expedition["destination_id"]))
		if destination.is_empty():
			continue
		var end := SettlementUILayout.region_point(vp,Vector2(destination["position"]))
		var progress := clampf(float(expedition["progress"])/maxf(1.0,float(expedition["distance"])),0.0,1.0)
		var exp_pos := home.lerp(end,progress if str(expedition["status"]) == "outbound" else (1.0-progress if str(expedition["status"]) == "returning" else 1.0))
		draw_line(home,end,Color("#ca57586f"),1.4)
		draw_circle(exp_pos,5.0,ACCENT)
		draw_string(ThemeDB.fallback_font,exp_pos+Vector2(7,-7),"EXP %d" % int(expedition["id"]),HORIZONTAL_ALIGNMENT_LEFT,70,9,TEXT)
	_draw_ui_panel(side,ACCENT)
	var px := side.position.x+18.0
	var py := side.position.y
	draw_string(ThemeDB.fallback_font,Vector2(px,py+27),"SITE INTELLIGENCE",HORIZONTAL_ALIGNMENT_LEFT,side.size.x-38,15,TEXT)
	var loc: Dictionary = sim.world_simulation.get_location_by_id(selected_world_location_id)
	if not loc.is_empty() and bool(loc.get("discovered",false)):
		draw_string(ThemeDB.fallback_font,Vector2(px,py+59),str(loc["name"]),HORIZONTAL_ALIGNMENT_LEFT,side.size.x-38,16,TEXT)
		var risk_val := int(float(loc.get("danger",0.0))*100.0)
		var distance := Vector2(loc["position"]).distance_to(Vector2(600,410))
		draw_string(ThemeDB.fallback_font,Vector2(px,py+80),str(loc["type"]).capitalize()+"   /   Danger "+str(risk_val)+"%",HORIZONTAL_ALIGNMENT_LEFT,side.size.x-38,11,WARN if risk_val<60 else BAD)
		draw_string(ThemeDB.fallback_font,Vector2(px,py+99),"Travel distance: %.0f map units" % distance,HORIZONTAL_ALIGNMENT_LEFT,side.size.x-38,11,MUTED)
		draw_string(ThemeDB.fallback_font,Vector2(px,py+118),"Status: "+"Exhausted" if bool(loc.get("depleted",false)) else "Status: Ready to explore",HORIZONTAL_ALIGNMENT_LEFT,side.size.x-38,11,GOOD if not bool(loc.get("depleted",false)) else WARN)
		var loot_desc := "Possible salvage: "
		var goods := PackedStringArray()
		for item in loc.get("loot",{}).keys():
			goods.append(str(item).capitalize())
		loot_desc += " / ".join(goods) if not goods.is_empty() else "Not a salvage site"
		draw_string(ThemeDB.fallback_font,Vector2(px,py+143),loot_desc,HORIZONTAL_ALIGNMENT_LEFT,side.size.x-38,10,MUTED)
	else:
		draw_string(ThemeDB.fallback_font,Vector2(px,py+59),"Select a discovered site",HORIZONTAL_ALIGNMENT_LEFT,side.size.x-38,13,MUTED)
		draw_string(ThemeDB.fallback_font,Vector2(px,py+81),"Use the left list or click a map marker.",HORIZONTAL_ALIGNMENT_LEFT,side.size.x-38,11,MUTED)
	var dispatch := SettlementUILayout.region_dispatch_rect(vp)
	var can_go := _region_can_dispatch(loc)
	draw_rect(dispatch,Color("#254a40") if can_go else Color("#293339"))
	draw_rect(dispatch,GOOD if can_go else Color("#50636b"),false,1)
	draw_string(ThemeDB.fallback_font,dispatch.position+Vector2(11,21),"SEND SALVAGE TEAM [G]" if can_go else "SELECT AN AVAILABLE SALVAGE SITE",HORIZONTAL_ALIGNMENT_LEFT,dispatch.size.x-20,11,TEXT if can_go else MUTED)
	draw_string(ThemeDB.fallback_font,Vector2(px,py+253),"ACTIVE EXPEDITIONS   %d" % sim.world_simulation.get_active_expeditions().size(),HORIZONTAL_ALIGNMENT_LEFT,side.size.x-30,12,ACCENT)
	var ey := py+280.0
	for expedition in sim.world_simulation.get_active_expeditions():
		if ey>side.end.y-90:
			break
		var target := sim.world_simulation.get_location_by_id(int(expedition["destination_id"]))
		draw_string(ThemeDB.fallback_font,Vector2(px,ey),"Team %d  •  %s" % [int(expedition["id"]),str(expedition["status"]).capitalize()],HORIZONTAL_ALIGNMENT_LEFT,side.size.x-32,11,TEXT)
		draw_string(ThemeDB.fallback_font,Vector2(px,ey+17),str(target.get("name","Unknown destination")),HORIZONTAL_ALIGNMENT_LEFT,side.size.x-32,10,MUTED)
		ey += 44.0

func _world_map_select(screen_pos: Vector2) -> void:
	var vp := get_viewport_rect().size
	if not SettlementUILayout.region_map_rect(vp).has_point(screen_pos):
		return
	var nearest_id := 0
	var nearest_dist := 22.0
	for location in sim.world_simulation.get_discovered_locations():
		var projected := SettlementUILayout.region_point(vp,Vector2(location["position"]))
		var distance := projected.distance_to(screen_pos)
		if distance < nearest_dist:
			nearest_id = int(location["id"])
			nearest_dist = distance
	if nearest_id>0:
		selected_world_location_id = nearest_id

func _handle_region_click(position: Vector2) -> bool:
	var vp := get_viewport_rect().size
	var discovered := sim.world_simulation.get_discovered_locations()
	var rows := mini(discovered.size(),mini(12,int((vp.y-SettlementUILayout.TOP_H-SettlementUILayout.BOTTOM_H-97.0)/29.0)))
	for i in range(rows):
		if SettlementUILayout.region_site_row(vp,i).has_point(position):
			selected_world_location_id = int(discovered[i]["id"])
			return true
	if SettlementUILayout.region_dispatch_rect(vp).has_point(position):
		_dispatch_region()
		return true
	_world_map_select(position)
	return true

func _format_recipe_items(ingredients: Dictionary) -> String:
	var chunks := PackedStringArray()
	for resource in ingredients.keys():
		chunks.append("%s %.0f" % [str(resource).capitalize(),float(ingredients[resource])])
	return ", ".join(chunks)

func _draw_economy_panel() -> void:
	var vp := get_viewport_rect().size
	var area := SettlementUILayout.side_panel(vp,480.0)
	var x := area.position.x
	var y := area.position.y
	var w := area.size.x
	var eco := sim.economy_simulation
	var sources := eco.get_trade_sources()
	if sources.is_empty():
		economy_source_index = 0
	else:
		economy_source_index = clampi(economy_source_index,0,sources.size()-1)
	var market_name := "Local exchange" if sources.is_empty() else str(sources[economy_source_index]["name"])
	_draw_ui_panel(area,ACCENT)
	draw_rect(Rect2(x+14,y+13,4,22),ACCENT)
	draw_string(ThemeDB.fallback_font,Vector2(x+27,y+30),"INDUSTRY   /   PRODUCTION & TRADE",HORIZONTAL_ALIGNMENT_LEFT,w-38,15,TEXT)
	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+59),"Credits: %.1f      Market: %s" % [eco.credits,market_name],HORIZONTAL_ALIGNMENT_LEFT,w-30,11,GOOD)
	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+80),"Fuel: %.0f   Parts: %.0f   Tools: %.0f   Components: %.0f" % [float(eco.industry_stock["fuel"]),float(eco.industry_stock["parts"]),float(eco.industry_stock["tools"]),float(eco.industry_stock["components"])],HORIZONTAL_ALIGNMENT_LEFT,w-35,11,MUTED)
	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+101),"Warehouse: %.0f/%.0f   •   Efficiency: %.0f%%" % [eco.warehouse_used,eco.warehouse_capacity,eco.production_efficiency*100.0],HORIZONTAL_ALIGNMENT_LEFT,w-35,10,MUTED)
	if eco.bottleneck_reason != "":
		draw_string(ThemeDB.fallback_font,Vector2(x+20,y+122),"Needs attention: "+str(eco.bottleneck_reason),HORIZONTAL_ALIGNMENT_LEFT,w-36,10,WARN)
	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+149),"TRADE ITEMS  /  CLICK TO SELECT",HORIZONTAL_ALIGNMENT_LEFT,w-38,11,ACCENT)
	for i in range(ECONOMY_ITEMS.size()):
		var item := str(ECONOMY_ITEMS[i])
		var row := Rect2(x+17.0,y+158.0+float(i)*22.0,w-34.0,21.0)
		var selected := i == economy_item_index
		draw_rect(row,Color("#512a32") if selected else (Color("#273942") if row.has_point(get_local_mouse_position()) else Color("#14242e")))
		if selected:
			draw_rect(Rect2(row.position,Vector2(3,row.size.y)),ACCENT)
		draw_string(ThemeDB.fallback_font,row.position+Vector2(8,15),item.capitalize(),HORIZONTAL_ALIGNMENT_LEFT,160,11,TEXT if selected else MUTED)
		draw_string(ThemeDB.fallback_font,Vector2(row.end.x-130.0,row.position.y+15.0),"%.1f credits" % eco.get_trade_price(item,economy_source_index),HORIZONTAL_ALIGNMENT_RIGHT,124,11,GOOD if selected else MUTED)
	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+336),"CRAFTING  /  CHOOSE RECIPE, THEN QUEUE",HORIZONTAL_ALIGNMENT_LEFT,w-40,11,ACCENT)
	var recipe_name: String = str(ECONOMY_RECIPES[economy_recipe_index])
	var recipe: Dictionary = eco.recipes.get(recipe_name,{})
	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+356),recipe_name,HORIZONTAL_ALIGNMENT_LEFT,w-36,13,TEXT)
	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+376),"Requires: "+_format_recipe_items(recipe.get("input",{})),HORIZONTAL_ALIGNMENT_LEFT,w-34,10,MUTED)
	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+394),"Produces: "+_format_recipe_items(recipe.get("output",{})),HORIZONTAL_ALIGNMENT_LEFT,w-34,10,GOOD)
	draw_line(Vector2(x+16,y+404),Vector2(x+w-16,y+404),Color("#49646b"),1)
	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+424),"PRODUCTION QUEUE  /  %d BATCHES" % eco.production_queue.size(),HORIZONTAL_ALIGNMENT_LEFT,w-34,11,ACCENT)
	var last_y := area.end.y - 94.0
	var y_row := y+444.0
	for item in eco.production_queue:
		if y_row>last_y:
			break
		draw_string(ThemeDB.fallback_font,Vector2(x+20,y_row),str(item["recipe"])+"  /  "+str(item["status"]).capitalize(),HORIZONTAL_ALIGNMENT_LEFT,w-34,10,TEXT)
		y_row += 17.0

func _draw_civilization_panel() -> void:
	var vp := get_viewport_rect().size
	var bounds := SettlementUILayout.side_panel(vp,700.0)
	var x := bounds.position.x
	var y := bounds.position.y
	var w := bounds.size.x
	var h := bounds.size.y
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

	_draw_ui_panel(bounds,GOOD)
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
	var bounds := SettlementUILayout.side_panel(vp,480.0)
	var x := bounds.position.x
	var y := bounds.position.y
	var w := bounds.size.x
	var h := bounds.size.y
	var fs := sim.faction_simulation
	var visible := fs.get_visible_factions(sim)
	if faction_index >= visible.size():
		faction_index = 0

	_draw_ui_panel(bounds,BAD)
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
	var usable_height := vp.y-SettlementUILayout.TOP_H-SettlementUILayout.BOTTOM_H-18.0
	var w := minf(692.0,vp.x-32.0)
	var h := minf(492.0,usable_height)
	var x := (vp.x-w)*0.5
	var y := SettlementUILayout.TOP_H+maxf(8.0,(usable_height-h)*0.5)
	var rect := Rect2(x,y,w,h)
	_draw_ui_panel(rect,ACCENT)
	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+31),"FIELD GUIDE  /  QUICK START",HORIZONTAL_ALIGNMENT_LEFT,w-40,19,TEXT)
	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+52),"ESC or F1 to return to the live settlement",HORIZONTAL_ALIGNMENT_LEFT,w-40,11,GOOD)
	var lessons := [
		["SURVIVE","Keep an eye on FOOD, WATER, POWER and morale in the compact top row. Hover a metric for its meaning."],
		["BUILD","Press B to select a blueprint. Q/E changes structures, F rotates compatible items, click terrain to place."],
		["INSPECT","Left-click a survivor or building to open details. F3 expands the opening objectives."],
		["EXPAND","M opens the region. Select a discovered location and dispatch a salvage expedition with G."],
		["COMMAND","V governs, K opens industry, O tracks factions, J manages civilization. Use ESC to close."],
		["TIME & FILES","SPACE pauses; 1/2/3 sets time speed. S saves, L loads, F8 captures screenshots, F9 logs diagnostics."]
	]
	var line_height := minf(62.0, maxf(39.0,(h-112.0)/6.0))
	for i in range(lessons.size()):
		var ry := y+87.0+float(i)*line_height
		if ry>y+h-28.0:
			break
		var row: Array = lessons[i]
		draw_string(ThemeDB.fallback_font,Vector2(x+20,ry),str(row[0]),HORIZONTAL_ALIGNMENT_LEFT,w-40,12,ACCENT)
		draw_string(ThemeDB.fallback_font,Vector2(x+20,ry+19),str(row[1]),HORIZONTAL_ALIGNMENT_LEFT,w-40,10,MUTED)
	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+h-15),"F4  FULLSCREEN    •    F8  SCREENSHOT    •    F9  PLAYTEST REPORT",HORIZONTAL_ALIGNMENT_LEFT,w-40,10,GOOD)

func _draw_update_panel() -> void:
	var vp := get_viewport_rect().size
	var bounds := SettlementUILayout.side_panel(vp,500.0)
	var x := bounds.position.x
	var y := bounds.position.y
	var w := bounds.size.x
	var h := minf(520.0,bounds.size.y)
	var state_label := update_manager.get_state_label()
	var state_color := WARN
	if state_label in ["CURRENT","VERIFIED"]:
		state_color = GOOD
	elif state_label == "ERROR":
		state_color = BAD

	_draw_ui_panel(Rect2(x,y,w,h),state_color)
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
	var area := SettlementUILayout.side_panel(vp,480.0)
	var x := area.position.x
	var y := area.position.y
	var w := area.size.x
	var gov := sim.governance_simulation
	var leader: Dictionary = sim.get_citizen_by_id(gov.leader_id)
	var name := "Unassigned" if leader.is_empty() else str(leader["name"])
	_draw_ui_panel(area,ACCENT)
	draw_rect(Rect2(x+14,y+12,4,22),ACCENT)
	draw_string(ThemeDB.fallback_font,Vector2(x+27,y+29),"GOVERN  /  SETTLEMENT COUNCIL",HORIZONTAL_ALIGNMENT_LEFT,w-36,15,TEXT)
	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+55),"Council: "+str(gov.government_type),HORIZONTAL_ALIGNMENT_LEFT,w-38,11,MUTED)
	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+75),"Leader: "+name,HORIZONTAL_ALIGNMENT_LEFT,w-38,13,TEXT)
	_draw_meter(Vector2(x+20,y+106),w-40.0,"LEGITIMACY",float(gov.legitimacy))
	_draw_meter(Vector2(x+20,y+142),w-40.0,"COMMUNITY STABILITY",100.0-float(gov.unrest))
	_draw_meter(Vector2(x+20,y+178),w-40.0,"SAFETY",100.0-float(gov.crime_pressure))
	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+248),"SETTLEMENT LAWS  /  SELECT A ROW",HORIZONTAL_ALIGNMENT_LEFT,w-38,12,ACCENT)
	for i in range(GOVERNANCE_LAWS.size()):
		var law := str(GOVERNANCE_LAWS[i])
		var row := Rect2(x+18.0,y+263.0+float(i)*28.0,w-36.0,26.0)
		var active := i == governance_law_index
		draw_rect(row,Color("#512c33") if active else (Color("#2c3d44") if row.has_point(get_local_mouse_position()) else Color("#14242b")))
		if active:
			draw_rect(Rect2(row.position,Vector2(3,row.size.y)),ACCENT)
		draw_string(ThemeDB.fallback_font,row.position+Vector2(10,18),law.capitalize(),HORIZONTAL_ALIGNMENT_LEFT,146,11,TEXT)
		draw_string(ThemeDB.fallback_font,Vector2(row.position.x+150,row.position.y+18),str(gov.laws[law]),HORIZONTAL_ALIGNMENT_RIGHT,row.size.x-164,11,GOOD if active else MUTED)
	var selected_law := str(GOVERNANCE_LAWS[governance_law_index])
	var help_text := {
		"rationing":"Food policy affects survivors' daily lives.",
		"security":"Sets how strictly the community is protected.",
		"labor":"Changes expectations for work and service.",
		"justice":"Sets the approach to resolving offenses.",
		"speech":"Shapes residents' freedom to voice concerns."
	}
	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+423),"SELECTED  /  "+selected_law.capitalize(),HORIZONTAL_ALIGNMENT_LEFT,w-40,11,WARN)
	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+443),str(help_text[selected_law]),HORIZONTAL_ALIGNMENT_LEFT,w-40,10,MUTED)
	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+462),"Change law applies real citizen opinion effects.",HORIZONTAL_ALIGNMENT_LEFT,w-40,10,GOOD)
	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+485),"Unresolved justice cases: %d" % _open_case_count(),HORIZONTAL_ALIGNMENT_LEFT,w-40,10,MUTED)

func _open_case_count() -> int:
	var count := 0
	for case in sim.governance_simulation.active_cases:
		if case["status"] != "resolved":
			count += 1
	return count

func _active_screen_label() -> String:
	if build_mode:
		return "CONSTRUCTION"
	if world_map_mode:
		return "REGIONAL MAP"
	if governance_mode:
		return "GOVERNANCE"
	if economy_mode:
		return "INDUSTRY"
	if faction_mode:
		return "FACTIONS"
	if civilization_mode:
		return "CIVILIZATION"
	if update_mode:
		return "UPDATES"
	if help_mode:
		return "FIELD GUIDE"
	return "WORLD VIEW"

func _draw_ui_panel(rect: Rect2, edge: Color) -> void:
	draw_rect(rect, Color("#0d1418ed"), true)
	draw_rect(rect, Color("#62727a6e"), false, 1.0)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3.0)), edge)
	draw_rect(Rect2(rect.position + Vector2(0,3), Vector2(3, rect.size.y-3)), Color(edge, 0.7))

func _draw_hud() -> void:
	var vp := get_viewport_rect().size
	var top_h := SettlementUILayout.TOP_H
	draw_rect(Rect2(0, 0, vp.x, top_h), Color("#080d12f3"))
	draw_line(Vector2(0,top_h-1), Vector2(vp.x,top_h-1), ACCENT, 1.5)
	# Human-readable identity: the corporate badge stays visible, but a player
	# sees the actual game and settlement name, not internal network/site IDs.
	var identity := SettlementUILayout.identity_rect(vp)
	var is_hovered := identity.has_point(get_local_mouse_position())
	var badge := Rect2(identity.position+Vector2(5,7),Vector2(32,32))
	draw_rect(badge,Color("#662628") if is_hovered else Color("#3d2024"))
	draw_rect(badge,ACCENT,false,1.0)
	draw_string(ThemeDB.fallback_font,badge.position+Vector2(5,21),"DPN",HORIZONTAL_ALIGNMENT_LEFT,27,10,TEXT)
	draw_string(ThemeDB.fallback_font,identity.position+Vector2(43,21),"THE LAST SETTLEMENT" if vp.x>=1000 else "LAST SETTLEMENT",HORIZONTAL_ALIGNMENT_LEFT,identity.size.x-47,16 if vp.x>=1000 else 12,TEXT)
	draw_string(ThemeDB.fallback_font,identity.position+Vector2(43,37),"%s  •  Overview ›" % sim.settlement_name if vp.x>=1000 else "Overview ›",HORIZONTAL_ALIGNMENT_LEFT,identity.size.x-47,10,GOOD if is_hovered else MUTED)
	if is_hovered:
		draw_line(Vector2(identity.position.x+44,identity.end.y-2),Vector2(identity.end.x-6,identity.end.y-2),GOOD,1.0)

	var alive := sim.get_alive_citizens().size()
	var morale := sim.get_average_morale()
	var resources := [
		["POP", str(alive), float(alive)/24.0, "Survivors alive and available to manage"],
		["FOOD", "%.0f" % float(sim.resources["food"]), float(sim.resources["food"])/maxf(1.0, float(alive)*25.0), "Stored food reserves for the settlement"],
		["WATER", "%.0f" % float(sim.resources["water"]), float(sim.resources["water"])/maxf(1.0,float(alive)*24.0), "Clean water available to survivors"],
		["POWER", "%.0f%%" % float(sim.resources["power"]), float(sim.resources["power"])/100.0, "Settlement electrical power"],
		["MEALS", "%.0f" % float(sim.resources["meals"]), float(sim.resources["meals"])/maxf(1.0,float(alive)*2.0), "Prepared food ready for consumption"],
		["MORALE", "%.0f%%" % morale, morale/100.0, "Average confidence and satisfaction"]
	]
	var resource_rects := SettlementUILayout.resource_rects(vp)
	var hovered := -1
	for i in range(resources.size()):
		var rect: Rect2 = resource_rects[i]
		var item: Array = resources[i]
		var fraction := clampf(float(item[2]),0.0,1.0)
		var severity := BAD if fraction < 0.20 else (WARN if fraction < 0.40 else GOOD)
		var hovered_now := rect.has_point(get_local_mouse_position())
		if hovered_now:
			hovered = i
		draw_rect(rect, Color("#243238") if hovered_now else Color("#162229"))
		draw_rect(rect, Color(severity,0.80) if hovered_now else Color("#3b5159"), false, 1.0)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(7,14), str(item[0]), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x-12, 9, MUTED)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(7,35), str(item[1]), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x-12, 18, TEXT)
		draw_rect(Rect2(rect.position + Vector2(7,rect.size.y-5),Vector2(maxf(1.0,rect.size.x-14),2)),Color("#2d383b"))
		draw_rect(Rect2(rect.position + Vector2(7,rect.size.y-5),Vector2(maxf(1.0,(rect.size.x-14)*fraction),2)),severity)
	var battery_percent := 100.0*float(sim.utility_state["battery_charge"])/maxf(1.0,float(sim.utility_state["battery_capacity"]))
	var summary := "Day %d  •  %02d:%02d  |  Materials: %.0f  |  Building projects: %d  |  Battery: %.0f%%" % [sim.day,int(sim.hour),int((sim.hour-floor(sim.hour))*60.0),float(sim.resources["materials"]),sim.blueprints.size(),battery_percent]
	if vp.x >= 1120.0:
		summary = "Day %d  •  %02d:%02d  |  Materials: %.0f  |  Building projects: %d  |  Power: %.0f produced / %.0f needed  |  Battery: %.0f%%" % [sim.day,int(sim.hour),int((sim.hour-floor(sim.hour))*60.0),float(sim.resources["materials"]),sim.blueprints.size(),float(sim.utility_state["power_generated"]),float(sim.utility_state["power_demand"]),battery_percent]
	elif vp.x < 920.0:
		summary = "Day %d  •  %02d:%02d  |  Materials: %.0f  |  Projects: %d" % [sim.day,int(sim.hour),int((sim.hour-floor(sim.hour))*60.0),float(sim.resources["materials"]),sim.blueprints.size()]
	draw_string(ThemeDB.fallback_font,Vector2(15,69),summary,HORIZONTAL_ALIGNMENT_LEFT,vp.x-175,10,MUTED)
	var attention := _settlement_attention()
	draw_string(ThemeDB.fallback_font,Vector2(vp.x-152,69),str(attention[0]),HORIZONTAL_ALIGNMENT_RIGHT,138,10,Color(attention[1]))

	if selected_citizen.is_empty() and selected_building.is_empty():
		if incident_panel_visible:
			_draw_event_panel()
		else:
			_draw_event_toasts()

	var status := "PAUSED" if sim.paused else ("RUNNING x%.0f" % sim.speed)
	var hint := "DRAG PAN  •  ALT+DRAG ORBIT  •  SCROLL ZOOM  •  SPACE PAUSE  •  F8 SCREENSHOT"
	if build_mode:
		var definition := sim.get_build_catalog()[build_catalog_index]
		hint = "BUILDING %s  •  Q/E SELECT  •  F ROTATE  •  CLICK TO PLACE" % str(definition["name"]).to_upper()
	draw_rect(Rect2(0,vp.y-SettlementUILayout.BOTTOM_H,vp.x,SettlementUILayout.BOTTOM_H),Color("#081015f0"))
	draw_line(Vector2(0,vp.y-SettlementUILayout.BOTTOM_H),Vector2(vp.x,vp.y-SettlementUILayout.BOTTOM_H),Color("#54646b"),1)
	draw_string(ThemeDB.fallback_font,Vector2(13,vp.y-46),hint,HORIZONTAL_ALIGNMENT_LEFT,vp.x-126,10,MUTED)
	draw_string(ThemeDB.fallback_font,Vector2(vp.x-111,vp.y-46),status,HORIZONTAL_ALIGNMENT_RIGHT,97,10,WARN if sim.paused else GOOD)
	_draw_toolbar()
	if hovered >= 0:
		var source: Array = resources[hovered]
		var card: Rect2 = resource_rects[hovered]
		var tooltip_width := 300.0
		var tooltip_x := clampf(card.position.x,10.0,maxf(10.0,vp.x-tooltip_width-10))
		var tooltip := Rect2(tooltip_x,top_h+8.0,tooltip_width,48.0)
		draw_rect(tooltip,Color("#101b20f3"))
		draw_rect(tooltip,Color("#7a9297"),false,1.0)
		draw_string(ThemeDB.fallback_font,tooltip.position+Vector2(11,18),str(source[0])+"  //  "+str(source[1]),HORIZONTAL_ALIGNMENT_LEFT,tooltip_width-22,12,TEXT)
		draw_string(ThemeDB.fallback_font,tooltip.position+Vector2(11,35),str(source[3]),HORIZONTAL_ALIGNMENT_LEFT,tooltip_width-22,10,MUTED)
	if playtest_notice_seconds > 0.0:
		var width := minf(vp.x - 44.0, 650.0)
		var notice := Rect2(14,top_h+10.0,width,32)
		draw_rect(notice,PANEL_SOLID)
		draw_rect(notice,GOOD,false,1.0)
		draw_string(ThemeDB.fallback_font,notice.position+Vector2(10,21),playtest_notice,HORIZONTAL_ALIGNMENT_LEFT,width-20,11,GOOD)

func _settlement_attention() -> Array:
	# Surface the most urgent actionable risk instead of a project codename.
	var living := sim.get_alive_citizens().size()
	if living == 0:
		return ["NO SURVIVORS",BAD]
	if float(sim.resources["water"]) < float(living) * 2.0:
		return ["CHECK WATER",WARN]
	if float(sim.resources["food"]) < float(living) * 2.0:
		return ["CHECK FOOD",WARN]
	if float(sim.utility_state["power_generated"]) < float(sim.utility_state["power_demand"]):
		return ["POWER SHORTFALL",WARN]
	return [_active_screen_label(),GOOD]

func _next_settlement_goal() -> String:
	if not bool(sim.field_objectives.get("inspected",false)):
		return "Inspect a survivor: click a person to see their needs."
	if not bool(sim.field_objectives.get("blueprint",false)):
		return "Start construction: open Build, then place a blueprint."
	if not bool(sim.field_objectives.get("expedition",false)):
		return "Explore the region: open Region and send a salvage team."
	if not bool(sim.field_objectives.get("survived",false)):
		return "Keep your settlement alive until Day 2."
	return "Opening goals completed. Expand your settlement at your own pace."

func _draw_overview() -> void:
	var vp := get_viewport_rect().size
	var area := SettlementUILayout.overview_rect(vp)
	draw_rect(area,Color("#101a20f6"))
	draw_rect(area,Color("#789aa3"),false,1.5)
	draw_rect(Rect2(area.position,Vector2(area.size.x,3)),ACCENT)
	var left := area.position.x+17.0
	var full_width := area.size.x-34.0
	var top := area.position.y
	draw_string(ThemeDB.fallback_font,Vector2(left,top+29),"YOUR SETTLEMENT",HORIZONTAL_ALIGNMENT_LEFT,full_width,17,TEXT)
	draw_string(ThemeDB.fallback_font,Vector2(left,top+49),"%s  •  Home base" % sim.settlement_name,HORIZONTAL_ALIGNMENT_LEFT,full_width,11,GOOD)
	draw_string(ThemeDB.fallback_font,Vector2(left,top+68),"Day %d   |   %02d:%02d   |   %s" % [sim.day,int(sim.hour),int((sim.hour-floor(sim.hour))*60.0),"Paused" if sim.paused else "Simulation running"],HORIZONTAL_ALIGNMENT_LEFT,full_width,11,MUTED)
	draw_line(Vector2(left,top+79),Vector2(area.end.x-17,top+79),Color("#41575e"),1.0)
	var complete := 0
	for value in sim.field_objectives.values():
		if bool(value):
			complete += 1
	draw_string(ThemeDB.fallback_font,Vector2(left,top+100),"YOUR NEXT STEP  •  %d/4 goals completed" % complete,HORIZONTAL_ALIGNMENT_LEFT,full_width,11,WARN)
	draw_string(ThemeDB.fallback_font,Vector2(left,top+120),_next_settlement_goal(),HORIZONTAL_ALIGNMENT_LEFT,full_width,10,TEXT)
	draw_line(Vector2(left,top+134),Vector2(area.end.x-17,top+134),Color("#31484e"),1.0)
	draw_string(ThemeDB.fallback_font,Vector2(left,top+154),"SUPPLIES & BUILDING",HORIZONTAL_ALIGNMENT_LEFT,full_width,11,GOOD)
	draw_string(ThemeDB.fallback_font,Vector2(left,top+174),"Building materials: %.0f" % float(sim.resources["materials"]),HORIZONTAL_ALIGNMENT_LEFT,full_width,11,TEXT)
	draw_string(ThemeDB.fallback_font,Vector2(left,top+193),"Projects being built: %d    |    Rooms finished: %d" % [sim.blueprints.size(),sim.completed_rooms],HORIZONTAL_ALIGNMENT_LEFT,full_width,11,TEXT)
	draw_line(Vector2(left,top+208),Vector2(area.end.x-17,top+208),Color("#31484e"),1.0)
	draw_string(ThemeDB.fallback_font,Vector2(left,top+228),"ESSENTIAL SYSTEMS",HORIZONTAL_ALIGNMENT_LEFT,full_width,11,GOOD)
	var power_available := float(sim.utility_state["power_generated"])
	var power_needed := float(sim.utility_state["power_demand"])
	var power_ok := power_available>=power_needed
	draw_string(ThemeDB.fallback_font,Vector2(left,top+248),"Electricity: %.0f available / %.0f needed" % [power_available,power_needed],HORIZONTAL_ALIGNMENT_LEFT,full_width,11,GOOD if power_ok else WARN)
	var charge := 100.0*float(sim.utility_state["battery_charge"])/maxf(1.0,float(sim.utility_state["battery_capacity"]))
	draw_string(ThemeDB.fallback_font,Vector2(left,top+268),"Battery charge: %.0f%%    |    Sanitation: %.0f%%" % [charge,float(sim.utility_state["sanitation"])],HORIZONTAL_ALIGNMENT_LEFT,full_width,11,TEXT)
	if area.size.y>350.0:
		draw_line(Vector2(left,top+283),Vector2(area.end.x-17,top+283),Color("#31484e"),1.0)
		draw_string(ThemeDB.fallback_font,Vector2(left,top+303),"TIP: Click people or buildings to inspect them.",HORIZONTAL_ALIGNMENT_LEFT,full_width,10,MUTED)
		draw_string(ThemeDB.fallback_font,Vector2(left,top+319),"Use Space to pause or resume the settlement.",HORIZONTAL_ALIGNMENT_LEFT,full_width,10,MUTED)
	var buttons := ["OPEN BUILD", "SHOW GOALS", "CLOSE"]
	for index in range(buttons.size()):
		var rect := SettlementUILayout.overview_button_rect(vp,index)
		var over := rect.has_point(get_local_mouse_position())
		draw_rect(rect,Color("#344f55") if over else Color("#1e333a"))
		draw_rect(rect,GOOD if over else Color("#58747e"),false,1.0)
		draw_string(ThemeDB.fallback_font,rect.position+Vector2(8,19),buttons[index],HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-14,10,TEXT)

func _handle_overview_click(position: Vector2) -> bool:
	var vp := get_viewport_rect().size
	if SettlementUILayout.identity_rect(vp).has_point(position):
		overview_visible = not overview_visible
		return true
	if not overview_visible:
		return false
	for index in range(3):
		if not SettlementUILayout.overview_button_rect(vp,index).has_point(position):
			continue
		overview_visible = false
		if index == 0:
			# Reuse toolbar semantics; never trigger Civilization's treasury B.
			_handle_toolbar_click(SettlementUILayout.navbar_rect(vp,0).get_center())
		elif index == 1:
			build_mode = false
			world_map_mode = false
			governance_mode = false
			economy_mode = false
			faction_mode = false
			civilization_mode = false
			update_mode = false
			help_mode = false
			selected_citizen = {}
			selected_building = {}
			selected_blueprint = {}
			field_directives_visible = true
		return true
	# Close safely on any click outside the briefing without selecting terrain.
	# Clicks on the briefing body never leak through to gameplay.
	if not SettlementUILayout.overview_rect(vp).has_point(position):
		overview_visible = false
	return true

func _draw_directive_tab() -> void:
	var done := 0
	for value in sim.field_objectives.values():
		if bool(value):
			done += 1
	var rect := SettlementUILayout.directive_tab()
	_draw_ui_panel(rect,WARN)
	draw_string(ThemeDB.fallback_font,rect.position+Vector2(11,20),"OBJECTIVES  %d/4     [F3] SHOW" % done,HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-20,11,TEXT)

func _draw_field_objectives() -> void:
	var rect := SettlementUILayout.objective_panel()
	_draw_ui_panel(rect,WARN)
	draw_string(ThemeDB.fallback_font,rect.position+Vector2(12,24),"LAST HAVEN  //  FIELD OBJECTIVES",HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-24,12,TEXT)
	var keys := ["inspected","blueprint","expedition","survived"]
	var names := ["Inspect a survivor","Place a construction blueprint","Dispatch a salvage expedition","Survive until Day 2"]
	var done := 0
	for key in keys:
		if bool(sim.field_objectives.get(key,false)):
			done += 1
	draw_string(ThemeDB.fallback_font,rect.position+Vector2(12,45),"%d/4 COMPLETE   •   SELECT A DIRECTIVE" % done,HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-24,10,MUTED)
	for i in range(keys.size()):
		var complete := bool(sim.field_objectives.get(keys[i],false))
		var ry := rect.position.y + 75.0 + float(i)*26.0
		draw_circle(Vector2(rect.position.x+18,ry-4),5.0,GOOD if complete else Color("#43575c"))
		draw_string(ThemeDB.fallback_font,Vector2(rect.position.x+32,ry),str(names[i]),HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-42,11,GOOD if complete else TEXT)

func _handle_objective_click(position: Vector2) -> bool:
	var area := SettlementUILayout.objective_panel()
	if not area.has_point(position):
		return false
	var row := int(floor((position.y - area.position.y - 61.0)/26.0))
	if row == 0 and not sim.get_alive_citizens().is_empty():
		var citizen: Dictionary = sim.get_alive_citizens()[0]
		_focus_world_position(Vector2(citizen["position"]))
		selected_citizen = citizen
		selected_building = {}
		selected_blueprint = {}
		sim.complete_field_objective("inspected")
	elif row == 1:
		build_mode = true
	elif row == 2:
		world_map_mode = true
	elif row == 3:
		sim.paused = false
		sim.speed = 4.0
	return true

func _focus_world_position(world: Vector2) -> void:
	settlement_world.focus_game(world)

func _set_build_category(category: String) -> void:
	if not category in SettlementCommandCatalog.CATEGORIES:
		return
	build_category = category
	var indices := SettlementCommandCatalog.category_indices(sim.get_build_catalog(),build_category)
	if indices.is_empty():
		return
	if not build_catalog_index in indices:
		build_catalog_index = indices[0]
	build_rotated = false

func _cycle_build_selection(direction: int) -> void:
	build_catalog_index = SettlementCommandCatalog.selection_in_category(sim.get_build_catalog(),build_category,build_catalog_index,direction)
	build_rotated = false

func _draw_build_palette() -> void:
	var catalog := sim.get_build_catalog()
	var vp := get_viewport_rect().size
	var rect := SettlementUILayout.build_palette(vp,catalog.size())
	var indices := SettlementCommandCatalog.category_indices(catalog,build_category)
	var rows := SettlementUILayout.palette_rows(vp,indices.size())
	var active_local := maxi(0,indices.find(build_catalog_index))
	var first := SettlementUILayout.palette_first(active_local,indices.size(),rows)
	_draw_ui_panel(rect,ACCENT)
	draw_rect(Rect2(rect.position+Vector2(10,7),Vector2(4,18)),ACCENT)
	draw_string(ThemeDB.fallback_font,rect.position+Vector2(20,22),"CONSTRUCTION  /  BUILD MENU",HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-29,14,TEXT)
	draw_string(ThemeDB.fallback_font,rect.position+Vector2(12,48),"Available materials: %.0f   •   %d projects queued" % [float(sim.stockpiles["industry"].get("materials",0.0)),sim.blueprints.size()],HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-23,11,MUTED)
	for j in range(SettlementCommandCatalog.CATEGORIES.size()):
		var box := SettlementUILayout.build_category_rect(vp,j)
		var category := str(SettlementCommandCatalog.CATEGORIES[j])
		var active := category == build_category
		var hover := box.has_point(get_local_mouse_position())
		draw_rect(box,Color("#753034") if active else (Color("#293c43") if hover else Color("#18272f")))
		draw_rect(box,ACCENT if active else Color("#4c616c"),false,1.0)
		draw_string(ThemeDB.fallback_font,box.position+Vector2(7,17),category,HORIZONTAL_ALIGNMENT_LEFT,box.size.x-12,10,TEXT if active else MUTED)
	var total := indices.size()
	draw_string(ThemeDB.fallback_font,rect.position+Vector2(13,127),"%d BUILDINGS  /  Q-E OR WHEEL TO BROWSE" % total,HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-24,10,GOOD)
	for row in range(rows):
		var idx := first+row
		if idx >= indices.size():
			break
		var entry: Dictionary = catalog[indices[idx]]
		var box := SettlementUILayout.build_row_rect(vp,row)
		var active := indices[idx] == build_catalog_index
		var affordable := SettlementCommandCatalog.can_afford(entry,float(sim.stockpiles["industry"].get("materials",0.0)))
		draw_rect(box,Color("#392429") if active else (Color("#27353a") if box.has_point(get_local_mouse_position()) else Color("#121f26")))
		if active:
			draw_rect(Rect2(box.position,Vector2(3,box.size.y)),ACCENT)
		draw_string(ThemeDB.fallback_font,box.position+Vector2(9,18),str(entry["name"]),HORIZONTAL_ALIGNMENT_LEFT,box.size.x-94,12,TEXT if affordable else MUTED)
		draw_string(ThemeDB.fallback_font,box.position+Vector2(box.size.x-85,18),"%.0f MAT" % float(entry["cost"]),HORIZONTAL_ALIGNMENT_LEFT,80,10,GOOD if affordable else BAD)
	var selected: Dictionary = catalog[build_catalog_index]
	var divider_y := rect.end.y-108.0
	draw_line(Vector2(rect.position.x+12,divider_y),Vector2(rect.end.x-12,divider_y),Color("#58616a"),1)
	draw_string(ThemeDB.fallback_font,Vector2(rect.position.x+13,divider_y+20),str(selected["name"]).to_upper()+"  /  "+str(selected["capacity"])+" CAPACITY",HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-26,12,TEXT)
	draw_string(ThemeDB.fallback_font,Vector2(rect.position.x+13,divider_y+38),SettlementCommandCatalog.purpose(str(selected["type"])),HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-26,10,MUTED)
	draw_string(ThemeDB.fallback_font,Vector2(rect.position.x+13,divider_y+55),"Cost: %.0f materials   •   Build effort: %.0f" % [float(selected["cost"]),float(selected["work"])],HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-26,10,GOOD)
	for idx in range(2):
		var action_rect := SettlementUILayout.build_action_rect(vp,idx)
		var can_rotate := SettlementCommandCatalog.rotate_allowed(str(selected["type"]))
		var action_name := ("ROTATE [F]" if can_rotate else "FIXED SHAPE") if idx == 0 else "DONE [ESC]"
		var usable := idx != 0 or can_rotate
		draw_rect(action_rect,Color("#5e272e") if idx==1 else Color("#21353b"))
		draw_rect(action_rect,ACCENT if idx==1 else Color("#536a73"),false,1)
		draw_string(ThemeDB.fallback_font,action_rect.position+Vector2(9,18),action_name,HORIZONTAL_ALIGNMENT_LEFT,action_rect.size.x-18,10,TEXT if usable else MUTED)

func _handle_build_palette_click(position: Vector2) -> bool:
	var vp := get_viewport_rect().size
	var catalog := sim.get_build_catalog()
	var rect := SettlementUILayout.build_palette(vp,catalog.size())
	if not rect.has_point(position):
		return false
	for i in range(SettlementCommandCatalog.CATEGORIES.size()):
		if SettlementUILayout.build_category_rect(vp,i).has_point(position):
			_set_build_category(str(SettlementCommandCatalog.CATEGORIES[i]))
			return true
	for i in range(2):
		if not SettlementUILayout.build_action_rect(vp,i).has_point(position):
			continue
		if i == 0 and SettlementCommandCatalog.rotate_allowed(str(catalog[build_catalog_index]["type"])):
			build_rotated = not build_rotated
		elif i == 1:
			build_mode = false
		return true
	var indices := SettlementCommandCatalog.category_indices(catalog,build_category)
	var rows := SettlementUILayout.palette_rows(vp,indices.size())
	var active_local := maxi(0,indices.find(build_catalog_index))
	var first := SettlementUILayout.palette_first(active_local,indices.size(),rows)
	for row in range(rows):
		if first+row < indices.size() and SettlementUILayout.build_row_rect(vp,row).has_point(position):
			build_catalog_index = indices[first+row]
			build_rotated = false
			return true
	return true

func _draw_toolbar() -> void:
	var vp := get_viewport_rect().size
	var descriptions := ["Construction tools","Regional operations","Civic and legal policy","Production and trade","External faction relations","Civilization recovery","Save the settlement","Restore a save","Controls and objectives"]
	var selected := -1
	for i in range(TOOLBAR_NAMES.size()):
		var rect := SettlementUILayout.navbar_rect(vp,i)
		var active := false
		match i:
			0: active = build_mode
			1: active = world_map_mode
			2: active = governance_mode
			3: active = economy_mode
			4: active = faction_mode
			5: active = civilization_mode
			8: active = help_mode
		if rect.has_point(get_local_mouse_position()):
			selected = i
		var highlight := active or selected==i
		draw_rect(rect,Color("#3a3130") if active else (Color("#28383d") if selected==i else Color("#162329")))
		draw_rect(rect,WARN if active else (Color("#789ca8") if selected==i else Color("#40565e")),false,1.0)
		draw_string(ThemeDB.fallback_font,rect.position+Vector2(9,20),TOOLBAR_NAMES[i],HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-39,11,TEXT)
		draw_string(ThemeDB.fallback_font,Vector2(rect.end.x-9,rect.position.y+20),TOOLBAR_HINTS[i],HORIZONTAL_ALIGNMENT_RIGHT,21,9,WARN if highlight else MUTED)
	if selected >= 0:
		var hovered_rect := SettlementUILayout.navbar_rect(vp,selected)
		var left := clampf(hovered_rect.position.x,8.0,maxf(8.0,vp.x-240))
		var tip := Rect2(left,vp.y-87,236,25)
		draw_rect(tip,Color("#101e23e9"))
		draw_rect(tip,Color("#566a72"),false,1.0)
		draw_string(ThemeDB.fallback_font,tip.position+Vector2(9,17),descriptions[selected],HORIZONTAL_ALIGNMENT_LEFT,tip.size.x-16,10,TEXT)

func _handle_toolbar_click(position: Vector2) -> bool:
	var vp := get_viewport_rect().size
	for index in range(TOOLBAR_NAMES.size()):
		if not SettlementUILayout.navbar_rect(vp,index).has_point(position):
			continue
		if index == 0:
			# Click Build must never invoke Civilization treasury's B shortcut.
			var was_building := build_mode and not civilization_mode and not world_map_mode
			build_mode = not was_building
			world_map_mode = false
			update_mode = false
			governance_mode = false
			economy_mode = false
			faction_mode = false
			civilization_mode = false
			help_mode = false
			selected_citizen = {}
			selected_building = {}
			selected_blueprint = {}
		else:
			var action := InputEventKey.new()
			action.keycode = TOOLBAR_KEYS[index]
			action.pressed = true
			_unhandled_input(action)
		return true
	return false

func _draw_event_toasts() -> void:
	var vp := get_viewport_rect().size
	var left := vp.x - 334.0
	var y := vp.y - SettlementUILayout.BOTTOM_H - 123.0
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
	var panel_y := SettlementUILayout.TOP_H + 10.0
	_draw_ui_panel(Rect2(panel_x,panel_y,panel_w,vp.y-panel_y-SettlementUILayout.BOTTOM_H-10),ACCENT)
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
		if ey > vp.y - SettlementUILayout.BOTTOM_H - 16:
			break

func _draw_selection_panel() -> void:
	if not selected_citizen.is_empty():
		_draw_citizen_panel(selected_citizen)
	elif not selected_blueprint.is_empty():
		_draw_blueprint_panel(selected_blueprint)
	elif not selected_building.is_empty():
		_draw_building_panel(selected_building)

func _draw_citizen_panel(c: Dictionary) -> void:
	var vp := get_viewport_rect().size
	var bounds := SettlementUILayout.side_panel(vp,350.0)
	var x := bounds.position.x
	var y := bounds.position.y
	var w := bounds.size.x
	var h := minf(465.0,bounds.size.y)
	_draw_ui_panel(Rect2(x,y,w,h),ACCENT)
	draw_string(ThemeDB.fallback_font, Vector2(x + 18, y + 27), "SURVIVOR // %03d" % int(c["id"]), HORIZONTAL_ALIGNMENT_LEFT, w - 34, 11, ACCENT)
	draw_string(ThemeDB.fallback_font, Vector2(x + 18, y + 58), str(c["name"]), HORIZONTAL_ALIGNMENT_LEFT, w - 32, 21, TEXT)
	draw_string(ThemeDB.fallback_font, Vector2(x + 18, y + 80), "%s // AGE %d // %s SHIFT" % [str(c["job"]), int(c["age"]), str(c["shift"])], HORIZONTAL_ALIGNMENT_LEFT, w - 34, 11, MUTED)
	draw_string(ThemeDB.fallback_font, Vector2(x + 18, y + 100), "NOW: " + str(c["current_action"]), HORIZONTAL_ALIGNMENT_LEFT, w - 34, 12, RUST)
	var meters := [
		["HEALTH", float(c["health"])],
		["HUNGER", 100.0 - float(c["hunger"])],
		["THIRST", 100.0 - float(c["thirst"])],
		["REST", 100.0 - float(c["fatigue"])],
		["MORALE", float(c["morale"])],
		["STRESS", 100.0 - float(c["stress"])]
	]
	for i in range(meters.size()):
		_draw_meter(Vector2(x + 18, y + 126 + float(i) * 32.0), w - 36.0, str(meters[i][0]), float(meters[i][1]))
	draw_string(ThemeDB.fallback_font, Vector2(x + 18, y + 328), "TRAIT: %s" % str(c["trait"]), HORIZONTAL_ALIGNMENT_LEFT, w - 36, 11, MUTED)
	draw_string(ThemeDB.fallback_font, Vector2(x + 18, y + 346), "SKILLS   BUILD %d   MED %d   FARM %d" % [int(c["skills"]["construction"]), int(c["skills"]["medicine"]), int(c["skills"]["farming"])], HORIZONTAL_ALIGNMENT_LEFT, w - 36, 11, MUTED)
	draw_string(ThemeDB.fallback_font, Vector2(x + 18, y + 364), "ON DUTY: %s    PRIORITY: %d" % ["YES" if sim.is_selected_work_enabled(c) else "NO", int(c["work_priority"].get(c["job"], 3))], HORIZONTAL_ALIGNMENT_LEFT, w - 36, 11, GOOD if sim.is_selected_work_enabled(c) else WARN)
	var action_y := y + h - 57.0
	var labels := ["[T] SHIFT", "[P] PRIORITY", "[W] DUTY"]
	for i in range(3):
		var rx := x + 12.0 + float(i) * 112.0
		draw_rect(Rect2(rx, action_y, 106, 39), Color("#263437"))
		draw_rect(Rect2(rx, action_y, 106, 39), RUST, false, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(rx + 8, action_y + 25), labels[i], HORIZONTAL_ALIGNMENT_LEFT, 96, 12, TEXT)

func _draw_blueprint_panel(blueprint: Dictionary) -> void:
	var vp := get_viewport_rect().size
	var bounds := SettlementUILayout.side_panel(vp,350.0)
	var x := bounds.position.x
	var y := bounds.position.y
	_draw_ui_panel(Rect2(x,y,bounds.size.x,206.0),ACCENT)
	draw_string(ThemeDB.fallback_font, Vector2(x + 18, y + 27), "CONSTRUCTION IN PROGRESS", HORIZONTAL_ALIGNMENT_LEFT, 314, 12, WARN)
	draw_string(ThemeDB.fallback_font, Vector2(x + 18, y + 56), str(blueprint["name"]), HORIZONTAL_ALIGNMENT_LEFT, 314, 21, TEXT)
	var percentage := 100.0 * float(blueprint["progress"]) / maxf(1.0, float(blueprint["work_required"]))
	_draw_meter(Vector2(x + 18, y + 93), 314, "WORK COMPLETE", percentage)
	draw_string(ThemeDB.fallback_font, Vector2(x + 18, y + 137), "MATERIALS COMMITTED %.0f" % float(blueprint["material_cost"]), HORIZONTAL_ALIGNMENT_LEFT, 314, 11, MUTED)
	draw_rect(Rect2(x + 16, y + 152, 316, 37), Color("#503435"))
	draw_rect(Rect2(x + 16, y + 152, 316, 37), BAD, false, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(x + 30, y + 176), "CANCEL BLUEPRINT (75% MATERIAL REFUND)", HORIZONTAL_ALIGNMENT_LEFT, 297, 11, TEXT)

func _handle_inspector_click(position: Vector2) -> bool:
	var vp := get_viewport_rect().size
	var bounds := SettlementUILayout.side_panel(vp,350.0)
	var x := bounds.position.x
	var y := bounds.position.y
	if not selected_blueprint.is_empty():
		if Rect2(x + 16, y + 152, 316, 37).has_point(position):
			sim.cancel_blueprint(int(selected_blueprint["id"]))
			selected_blueprint = {}
			return true
		return Rect2(x, y, 350, 206).has_point(position)
	if not selected_citizen.is_empty():
		var h := minf(465.0,bounds.size.y)
		for i in range(3):
			if Rect2(x + 12 + float(i) * 112.0, y + h - 57.0, 106, 39).has_point(position):
				if i == 0:
					sim.cycle_selected_shift(selected_citizen)
				elif i == 1:
					sim.cycle_selected_priority(selected_citizen)
				else:
					sim.toggle_selected_work(selected_citizen)
				return true
		return Rect2(x, y, 350, h).has_point(position)
	if not selected_building.is_empty():
		var selected_bounds := SettlementUILayout.side_panel(vp,372.0)
		if Rect2(selected_bounds.position,Vector2(selected_bounds.size.x,minf(270.0,selected_bounds.size.y))).has_point(position):
			return true
	return false

func _draw_building_panel(b: Dictionary) -> void:
	var vp := get_viewport_rect().size
	var bounds := SettlementUILayout.side_panel(vp,372.0)
	var x := bounds.position.x
	var y := bounds.position.y
	var w := bounds.size.x
	var h := minf(270.0,bounds.size.y)
	_draw_ui_panel(Rect2(x,y,w,h),ACCENT)
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
	selected_blueprint = {}
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
		sim.complete_field_objective("inspected")
		return

	for blueprint in sim.blueprints:
		var bp_rect := Rect2(Vector2(blueprint["position"]) - Vector2(blueprint["size"])/2.0, Vector2(blueprint["size"]))
		if bp_rect.has_point(world):
			selected_blueprint = blueprint
			selected_citizen = {}
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

func _capture_game_screenshot() -> void:
	var target_folder := "user://playtest-screenshots"
	var absolute_dir := ProjectSettings.globalize_path(target_folder)
	if DirAccess.make_dir_recursive_absolute(absolute_dir) != OK:
		playtest_notice = "SCREENSHOT FAILED // CANNOT CREATE CAPTURE FOLDER"
		playtest_notice_seconds = 5.0
		return
	var screenshot := get_viewport().get_texture().get_image()
	if screenshot == null or screenshot.is_empty():
		playtest_notice = "SCREENSHOT FAILED // FRAME UNAVAILABLE"
		playtest_notice_seconds = 5.0
		return
	var capture_path := target_folder.path_join("last-settlement-%d.png" % int(Time.get_unix_time_from_system()))
	if screenshot.save_png(capture_path) == OK:
		playtest_notice = "GAME SCREENSHOT SAVED // " + capture_path.get_file()
		if OS.get_name() == "Windows":
			OS.shell_open(absolute_dir)
	else:
		playtest_notice = "SCREENSHOT FAILED // DISK WRITE ERROR"
	playtest_notice_seconds = 7.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1:
				help_mode = not help_mode
			KEY_F2:
				incident_panel_visible = not incident_panel_visible
			KEY_F3:
				field_directives_visible = not field_directives_visible
			KEY_F4:
				var mode := DisplayServer.window_get_mode()
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
			KEY_F8:
				_capture_game_screenshot()
			KEY_HOME:
				_focus_world_position(Vector2(700, 380))
			KEY_W:
				if not selected_citizen.is_empty():
					sim.toggle_selected_work(selected_citizen)
			KEY_DELETE:
				if not selected_blueprint.is_empty():
					sim.cancel_blueprint(int(selected_blueprint["id"]))
					selected_blueprint = {}
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
				playtest_notice = "SETTLEMENT SAVED" if sim.save_game() else "SAVE FAILED"
				playtest_notice_seconds = 4.5
			KEY_L:
				var success := sim.load_game()
				playtest_notice = "SETTLEMENT RESTORED" if success else "NO VALID SAVE FOUND"
				playtest_notice_seconds = 4.5
				selected_citizen = {}
				selected_building = {}
				selected_blueprint = {}
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
					_cycle_build_selection(-1)
			KEY_E:
				if civilization_mode:
					var settlements := sim.civilization_simulation.get_settlement_list()
					if not settlements.is_empty():
						var settlement:Dictionary = settlements[civilization_settlement_index]
						sim.civilization_simulation.cycle_settlement_specialization(sim,str(settlement["id"]))
				elif build_mode:
					_cycle_build_selection(1)
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
				if world_map_mode:
					_dispatch_region()
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
				if overview_visible:
					overview_visible = false
				elif help_mode:
					help_mode = false
				elif update_mode:
					update_mode = false
				elif build_mode:
					build_mode = false
				elif world_map_mode:
					world_map_mode = false
				elif governance_mode:
					governance_mode = false
				elif economy_mode:
					economy_mode = false
				elif faction_mode:
					faction_mode = false
				elif civilization_mode:
					civilization_mode = false
				else:
					selected_citizen = {}
					selected_building = {}
					selected_blueprint = {}
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if _handle_toolbar_click(event.position):
				overview_visible = false
				return
			if _handle_overview_click(event.position):
				return
			if help_mode or update_mode:
				return
			if event.position.y < SettlementUILayout.TOP_H:
				return
			if build_mode and _handle_build_palette_click(event.position):
				return
			if not build_mode and not world_map_mode and not governance_mode and not economy_mode and not faction_mode and not civilization_mode and selected_citizen.is_empty() and selected_building.is_empty() and selected_blueprint.is_empty():
				if not field_directives_visible and SettlementUILayout.directive_tab().has_point(event.position):
					field_directives_visible = true
					return
				if field_directives_visible and _handle_objective_click(event.position):
					return
			if _handle_panel_action_click(event.position):
				return
			if _handle_command_content_click(event.position):
				return
			if _handle_inspector_click(event.position):
				return
			if world_map_mode:
				_handle_region_click(event.position)
				return
			if governance_mode or economy_mode or faction_mode or civilization_mode:
				return
			if build_mode:
				if event.position.y >= get_viewport_rect().size.y - SettlementUILayout.BOTTOM_H:
					return
				var definition := sim.get_build_catalog()[build_catalog_index]
				if sim.place_blueprint(definition["type"], _screen_to_world(event.position), build_rotated):
					playtest_notice = str(definition["name"]).to_upper() + " QUEUED FOR CONSTRUCTION"
				else:
					playtest_notice = "CANNOT PLACE STRUCTURE // CHECK SPACE OR MATERIALS"
				playtest_notice_seconds = 3.0
			else:
				_select_at(event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			if build_mode and SettlementUILayout.build_palette(get_viewport_rect().size,sim.get_build_catalog().size()).has_point(event.position):
				_cycle_build_selection(-1)
			else:
				settlement_world.zoom_camera(-1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			if build_mode and SettlementUILayout.build_palette(get_viewport_rect().size,sim.get_build_catalog().size()).has_point(event.position):
				_cycle_build_selection(1)
			else:
				settlement_world.zoom_camera(1.0)
		elif event.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			dragging = event.pressed
			drag_origin = event.position
	elif event is InputEventMouseMotion:
		mouse_world = _screen_to_world(event.position)
		if dragging:
			var drag_delta: Vector2 = event.position - drag_origin
			if event.alt_pressed:
				settlement_world.orbit_camera(drag_delta)
			else:
				settlement_world.pan_screen(drag_delta)
			drag_origin = event.position
