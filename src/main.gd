extends Node2D

const BG := Color("#06070a")
const GRID := Color("#2c1720")
const PANEL := Color("#111015ed")
const PANEL_SOLID := Color("#0c0b10")
const PANEL_EDGE := Color("#612932")
const TEXT := Color("#f3e9e6")
const MUTED := Color("#af9da2")
const GOOD := Color("#80cfa0")
const WARN := Color("#efb974")
const BAD := Color("#f05463")
const ACCENT := Color("#ea354d")
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
var workforce_mode := false
var workforce_page := 0
var workforce_selected_id := 0
var playtest_notice := ""
var playtest_notice_seconds := 0.0
var ui_animation_clock := 0.0
const UI_SCALE_LEVELS := [1.0,1.15,1.3]
var ui_scale_index := 0
var camera_offset := Vector2(-75, -34)
var zoom := 1.04
var dragging := false
var drag_origin := Vector2.ZERO
var selected_citizen: Dictionary = {}
var selected_building: Dictionary = {}
var pending_demolition_key := ""
var selected_blueprint: Dictionary = {}
var build_mode := false
var build_catalog_index := 0
var build_category := "ALL"
var build_rotated := false
var mouse_world := Vector2.ZERO
var utility_overlay := 0
var world_map_mode := false
var selected_world_location_id := 0
var expedition_team_size := 3
var expedition_strategy_index := 0
var region_atlas := RegionAtlas.new()
var settlement_minimap_visible := true
var governance_mode := false
var economy_mode := false
var faction_mode := false
var faction_index := 0
var civilization_tab := 0
const CIVILIZATION_TABS := ["OVERVIEW", "COLONIES", "LOGISTICS", "RECOVERY", "POLICY", "ROSTER"]
var civilization_mode := false
var civilization_settlement_index := 0
var civilization_route_index := 0
var civilization_colony_project_index := 0
var civilization_recovery_project_index := 0
var civilization_candidate_index := 0
var economy_item_index := 0
var economy_source_index := 0
var economy_recipe_index := 0
var industry_workshop_visible := false
var industry_batch_id := 0
var industry_queue_page := 0
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
	ui_animation_clock+=delta
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

# Paths are transient gameplay state and must not expand the save schema.
var citizen_paths: Dictionary = {}
var navigation_revision := ""

func _navigation_layout_revision() -> String:
	var parts := PackedStringArray()
	for building in sim.buildings:
		parts.append(str(building.get("type",""))+"@"+str(building.get("position",Vector2.ZERO))+"#"+str(building.get("size",Vector2.ZERO)))
	return "|".join(parts)

func _update_citizens(delta: float) -> void:
	var revision := _navigation_layout_revision()
	if navigation_revision != revision:
		citizen_paths.clear()
		navigation_revision = revision
	for c in sim.citizens:
		if not c["alive"] or str(c.get("home_settlement","LAST_HAVEN")) != "LAST_HAVEN" or bool(c.get("on_expedition",false)):
			continue
		var original_position := Vector2(c["position"])
		var safe_position := SettlementNavigation.resolve_walkable(original_position,sim.buildings)
		if safe_position.distance_squared_to(original_position)>0.01:
			c["position"]=safe_position
			citizen_paths.erase(int(c["id"]))
		var blueprint_id := int(c.get("target_blueprint_id",0))
		if blueprint_id>0:
			var blueprint := sim.get_blueprint_by_id(blueprint_id)
			if not blueprint.is_empty():
				c["target"] = blueprint["position"]
				_move_citizen_safely(c,25.0*delta*maxf(0.5,sim.speed))
				continue
		if c["target"] == Vector2.ZERO or Vector2(c["position"]).distance_to(Vector2(c["target"]))<8.0:
			var building := sim.get_building_by_type(str(c.get("target_building","")))
			if not building.is_empty():
				if str(building["type"])=="farm":
					c["target"] = Vector2(building["position"])+Vector2(
						sim.rng.randf_range(-float(building["size"].x)*0.34,float(building["size"].x)*0.34),
						sim.rng.randf_range(-float(building["size"].y)*0.28,float(building["size"].y)*0.28)
					)
				else:
					# Approach the visible door from outside until interiors
					# have their own traversal and cutaway representation.
					c["target"] = SettlementNavigation.exterior_entry(building)
			else:
				c["target"] = Vector2(c["position"])
		_move_citizen_safely(c,25.0*delta*maxf(0.5,sim.speed))

func _move_citizen_safely(c: Dictionary, distance: float) -> void:
	var ident := int(c["id"])
	var position := Vector2(c["position"])
	var goal := Vector2(c["target"])
	if position.distance_to(goal)<1.0:
		citizen_paths.erase(ident)
		return
	var state: Dictionary = citizen_paths.get(ident,{})
	if state.is_empty() or Vector2(state.get("goal",Vector2.ZERO)).distance_to(goal)>2.0:
		var waypoints := SettlementNavigation.route(position,goal,sim.buildings)
		if waypoints.is_empty():
			citizen_paths.erase(ident)
			return
		state={"goal":goal,"points":waypoints,"index":0}
		citizen_paths[ident]=state
	var points: PackedVector2Array = state["points"]
	var index := int(state["index"])
	while index<points.size() and position.distance_to(points[index])<maxf(1.0,distance):
		position=points[index]
		index+=1
	if index<points.size():
		var step := position.move_toward(points[index],distance)
		if SettlementNavigation.valid_step(position,step,sim.buildings):
			position=step
		else:
			# Buildings may have appeared since route selection. Re-evaluate
			# next simulation tick without passing through geometry.
			citizen_paths.erase(ident)
			return
	if index>=points.size():
		citizen_paths.erase(ident)
	else:
		state["index"]=index
		citizen_paths[ident]=state
	c["position"]=position

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
	if workforce_mode:
		_draw_workforce_panel()
	elif help_mode:
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
	if _can_draw_settlement_minimap():
		_draw_settlement_minimap()
	if overview_visible and not workforce_mode:
		_draw_overview()


# The F6 / PEOPLE command gives players direct, saved staffing control.
# Each reassignment changes the citizen job that drives the production loop.
func _toggle_workforce() -> void:
	if workforce_mode:
		workforce_mode=false
		return
	workforce_mode=true
	overview_visible=false
	build_mode=false
	world_map_mode=false
	governance_mode=false
	economy_mode=false
	faction_mode=false
	civilization_mode=false
	update_mode=false
	help_mode=false
	selected_citizen={}
	selected_building={}
	selected_blueprint={}
	var people := sim.get_settlement_citizens()
	if not people.is_empty() and sim.get_citizen_by_id(workforce_selected_id).is_empty():
		workforce_selected_id=int(people[0]["id"])
	workforce_page=0

func _workforce_person() -> Dictionary:
	var people := sim.get_settlement_citizens()
	for person in people:
		if int(person["id"])==workforce_selected_id:
			return person
	if not people.is_empty():
		workforce_selected_id=int(people[0]["id"])
		return people[0]
	return {}

func _draw_workforce_panel() -> void:
	var vp := get_viewport_rect().size
	var bounds := SettlementUILayout.workforce_panel(vp)
	var x := bounds.position.x
	var y := bounds.position.y
	var w := bounds.size.x
	var h := bounds.size.y
	var people := sim.get_settlement_citizens()
	var rows := SettlementUILayout.workforce_page_size(vp)
	var pages := maxi(1,int(ceil(float(people.size())/float(rows))))
	workforce_page=clampi(workforce_page,0,pages-1)
	_draw_ui_panel(bounds,ACCENT)
	draw_rect(Rect2(x+15,y+16,4,22),ACCENT)
	draw_string(ThemeDB.fallback_font,Vector2(x+27,y+33),"WORKFORCE  /  PERSONNEL COMMAND",HORIZONTAL_ALIGNMENT_LEFT,w-45,17,TEXT)
	draw_string(ThemeDB.fallback_font,Vector2(x+17,y+55),"%d residents on site   •   page %d / %d   •   F6 closes" % [people.size(),workforce_page+1,pages],HORIZONTAL_ALIGNMENT_LEFT,w-35,11,GOOD)
	var counts := {}
	for p in people:
		var job := str(p.get("job","Unassigned"))
		counts[job]=int(counts.get(job,0))+1
	var parts := PackedStringArray()
	for job in CitizenFactory.JOBS:
		if int(counts.get(job,0))>0:
			parts.append(job.substr(0,3).to_upper()+":"+str(counts[job]))
	draw_string(ThemeDB.fallback_font,Vector2(x+17,y+76),"ON-SITE ROLES  /  "+"  ".join(parts),HORIZONTAL_ALIGNMENT_LEFT,w-34,10,MUTED)
	draw_string(ThemeDB.fallback_font,Vector2(x+18,y+95),"SELECT SURVIVOR TO CHANGE ASSIGNMENT",HORIZONTAL_ALIGNMENT_LEFT,w-33,10,WARN)
	for i in range(rows):
		var index := workforce_page*rows+i
		if index>=people.size():
			break
		var p: Dictionary=people[index]
		var box := SettlementUILayout.workforce_row(vp,i)
		var active := int(p["id"])==workforce_selected_id
		var hovered := box.has_point(get_local_mouse_position())
		DPNUISkin.list_row(self,box,active,hovered)
		draw_string(ThemeDB.fallback_font,box.position+Vector2(9,18),str(p["name"]),HORIZONTAL_ALIGNMENT_LEFT,box.size.x*0.35,12,TEXT)
		var info := "%s  /  %s  /  %s" % [str(p["job"]),str(p["shift"]), "ON" if sim.is_selected_work_enabled(p) else "OFF"]
		draw_string(ThemeDB.fallback_font,box.position+Vector2(box.size.x*0.38,17),info,HORIZONTAL_ALIGNMENT_LEFT,box.size.x*0.36,10,GOOD if sim.is_selected_work_enabled(p) else WARN)
		# Two concise live status bars turn the roster into a readable management
		# interface, rather than a list of names and generic role labels.
		var hbar := Rect2(box.end.x-119.0,box.position.y+12.0,49.0,7.0)
		var mbar := Rect2(box.end.x-61.0,box.position.y+12.0,49.0,7.0)
		DPNUISkin.meter(self,hbar,float(p.get("health",0.0))/100.0,GOOD if float(p.get("health",0.0))>=50.0 else BAD)
		DPNUISkin.meter(self,mbar,float(p.get("morale",0.0))/100.0,GOOD if float(p.get("morale",0.0))>=45.0 else WARN)
		draw_string(ThemeDB.fallback_font,hbar.position+Vector2(0,-3),"HP",HORIZONTAL_ALIGNMENT_LEFT,20,8,MUTED)
		draw_string(ThemeDB.fallback_font,mbar.position+Vector2(0,-3),"MO",HORIZONTAL_ALIGNMENT_LEFT,20,8,MUTED)
	var chosen := _workforce_person()
	var intro_y := y+h-180
	if chosen.is_empty():
		draw_string(ThemeDB.fallback_font,Vector2(x+17,intro_y),"No survivor available for assignment.",HORIZONTAL_ALIGNMENT_LEFT,w-32,11,WARN)
	else:
		var assignable := int(chosen.get("age",0))>=18 and str(chosen["job"])!="Child" and not bool(chosen.get("on_expedition",false))
		draw_string(ThemeDB.fallback_font,Vector2(x+17,intro_y),"%s  /  %s" % [str(chosen["name"]).to_upper(),"SELECT A ROLE" if assignable else "UNAVAILABLE FOR REASSIGNMENT"],HORIZONTAL_ALIGNMENT_LEFT,w-33,11,GOOD if assignable else WARN)
	var assignable := not chosen.is_empty() and int(chosen.get("age",0))>=18 and not bool(chosen.get("on_expedition",false)) and not bool(chosen.get("incarcerated",false))
	for j in range(CitizenFactory.JOBS.size()):
		var role := str(CitizenFactory.JOBS[j])
		var rect := SettlementUILayout.workforce_job(vp,j)
		var selected := not chosen.is_empty() and role==str(chosen.get("job",""))
		DPNUISkin.button(self,rect,role.to_upper(),rect.has_point(get_local_mouse_position()),selected,false,assignable)
	var duty_labels := ["SHIFT  /  "+str(chosen.get("shift","---")) if not chosen.is_empty() else "SHIFT  /  ---",
		"DUTY  /  "+("ON" if sim.is_selected_work_enabled(chosen) else "OFF") if not chosen.is_empty() else "DUTY  /  ---"]
	for j in range(2):
		var duty_rect := SettlementUILayout.workforce_duty_control(vp,j)
		DPNUISkin.button(self,duty_rect,duty_labels[j],duty_rect.has_point(get_local_mouse_position()),j==1 and not chosen.is_empty() and sim.is_selected_work_enabled(chosen),false,assignable,true)
	if not chosen.is_empty():
		var skill := CitizenFactory.best_skill_for_job(chosen)
		draw_string(ThemeDB.fallback_font,Vector2(x+17,y+h-54),"Current skill: %s %d  •  role changes take effect in simulation" % [skill.capitalize(),int(chosen["skills"].get(skill,0))],HORIZONTAL_ALIGNMENT_LEFT,w-35,10,MUTED)
	var labels := ["PREVIOUS PAGE","NEXT PAGE","CLOSE [F6]"]
	for j in range(3):
		var button := SettlementUILayout.workforce_action(vp,j)
		DPNUISkin.button(self,button,labels[j],button.has_point(get_local_mouse_position()),false,j==2)

func _handle_workforce_click(position: Vector2) -> bool:
	if not workforce_mode:
		return false
	var vp := get_viewport_rect().size
	var bounds := SettlementUILayout.workforce_panel(vp)
	# A click outside the panel closes it, never places a building behind it.
	if not bounds.has_point(position):
		workforce_mode=false
		return true
	var people := sim.get_settlement_citizens()
	var rows := SettlementUILayout.workforce_page_size(vp)
	var pages := maxi(1,int(ceil(float(people.size())/float(rows))))
	for i in range(rows):
		var index := workforce_page*rows+i
		if index<people.size() and SettlementUILayout.workforce_row(vp,i).has_point(position):
			workforce_selected_id=int(people[index]["id"])
			return true
	for i in range(CitizenFactory.JOBS.size()):
		if SettlementUILayout.workforce_job(vp,i).has_point(position):
			var person := _workforce_person()
			var job := str(CitizenFactory.JOBS[i])
			if sim.assign_citizen_job(person,job):
				playtest_notice="ASSIGNED "+str(person["name"]).to_upper()+" TO "+job.to_upper()
			else:
				playtest_notice="ASSIGNMENT UNCHANGED  /  CHECK AGE, ROLE OR AVAILABILITY"
			playtest_notice_seconds=5.0
			return true
	for i in range(2):
		if not SettlementUILayout.workforce_duty_control(vp,i).has_point(position):
			continue
		var selected_person := _workforce_person()
		if selected_person.is_empty() or int(selected_person.get("age",0))<18 or bool(selected_person.get("on_expedition",false)) or bool(selected_person.get("incarcerated",false)):
			playtest_notice="WORKFORCE CONTROL UNAVAILABLE  /  SELECT AN ON-SITE ADULT"
		else:
			if i==0:
				sim.cycle_selected_shift(selected_person)
				playtest_notice="SHIFT UPDATED  /  "+str(selected_person["shift"])
			else:
				sim.toggle_selected_work(selected_person)
				playtest_notice="DUTY "+("ACTIVE" if sim.is_selected_work_enabled(selected_person) else "PAUSED")
		playtest_notice_seconds=4.5
		return true
	for i in range(3):
		if SettlementUILayout.workforce_action(vp,i).has_point(position):
			if i==0:
				workforce_page=posmod(workforce_page-1,pages)
			elif i==1:
				workforce_page=(workforce_page+1)%pages
			else:
				workforce_mode=false
			return true
	return true

func _panel_action_items() -> Array:
	if workforce_mode or help_mode:
		return []
	if update_mode:
		return [["DOWNLOAD",KEY_F11],["INSTALL",KEY_F12],["CLOSE",KEY_ESCAPE]]
	if governance_mode:
		return [["PREV LAW",KEY_UP],["NEXT LAW",KEY_DOWN],["CHANGE",KEY_ENTER],["CLOSE",KEY_ESCAPE]]
	if economy_mode and industry_workshop_visible:
		return []
	if economy_mode:
		return [["PREV",KEY_UP],["NEXT",KEY_DOWN],["MARKET",KEY_H],["RECIPE",KEY_N],["BUY 1",KEY_ENTER],["SELL 1",KEY_BACKSPACE],["QUEUE",KEY_C],["CLOSE",KEY_ESCAPE]]
	if faction_mode:
		if sim.faction_simulation.get_visible_factions(sim).is_empty():
			return [["FIND RELAY",KEY_M],["CLOSE",KEY_ESCAPE]]
		return [["PREV",KEY_UP],["NEXT",KEY_DOWN],["SEND AID",KEY_A],["TRADE",KEY_D],["TRUCE",KEY_Z],["CLOSE",KEY_ESCAPE]]
	if civilization_mode:
		match civilization_tab:
			0: return [["EXPLORE REGION",KEY_M],["CLOSE",KEY_ESCAPE]]
			1: return [["PREV SITE",KEY_LEFT],["NEXT SITE",KEY_RIGHT],["NEXT MODULE",KEY_N],["QUEUE",KEY_C],["REFOCUS",KEY_E],["SEND AID",KEY_A],["CLOSE",KEY_ESCAPE]]
			2: return [["PREV",KEY_UP],["NEXT",KEY_DOWN],["ON/OFF",KEY_R],["FOCUS",KEY_F],["PRIORITY",KEY_P],["CLOSE",KEY_ESCAPE]]
			3: return [["NEXT PROJECT",KEY_7],["CONTRIBUTE",KEY_8],["CLOSE",KEY_ESCAPE]]
			4: return [["AUTONOMY",KEY_4],["FREIGHT",KEY_5],["SECURITY",KEY_6],["COUNCIL",KEY_T],["CONTRIBUTE",KEY_Y],["RIGHTS",KEY_U],["RESERVE",KEY_B],["CLOSE",KEY_ESCAPE]]
			5: return [["NEXT",KEY_9],["ROSTER",KEY_0],["DEPLOY",KEY_D],["CLOSE",KEY_ESCAPE]]
		return [["CLOSE",KEY_ESCAPE]]
	if world_map_mode:
		return [["DISPATCH",KEY_G],["CLOSE",KEY_ESCAPE]]
	return []

func _action_panel_area() -> Rect2:
	var vp := get_viewport_rect().size
	if civilization_mode:
		return SettlementUILayout.side_panel(vp,620.0)
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
	draw_rect(Rect2(area.position.x+5,area.end.y-(80.0 if tall else 47.0),area.size.x-10,77.0 if tall else 44.0),Color("#100c13ef"))
	DPNUISkin.stroke(self,Vector2(area.position.x+12,area.end.y-(80.0 if tall else 47.0)),Vector2(area.end.x-12,area.end.y-(80.0 if tall else 47.0)),ACCENT,1.0)
	for i in range(actions.size()):
		var row: Array = actions[i]
		var rect := _panel_action_rect(i,actions.size())
		var hover := rect.has_point(get_local_mouse_position())
		DPNUISkin.button(self,rect,str(row[0]),hover,false,str(row[0])=="CLOSE",true,actions.size()>5)

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
		var mode_faction := faction_mode
		var mode_nation := civilization_mode
		var action_name := str(action[0])
		var previous_incident := "" if sim.events.is_empty() else str(sim.events[0].get("title",""))+" / "+str(sim.events[0].get("body",""))
		if mode_faction and action_name == "FIND RELAY":
			selected_world_location_id = 3
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
		elif mode_governance and action_name=="CHANGE":
			var current := str(sim.governance_simulation.laws[GOVERNANCE_LAWS[governance_law_index]])
			playtest_notice = "LAW UPDATED  /  "+current if current!=previous_law else "NO POLICY CHANGE"
			playtest_notice_seconds = 4.0
		elif mode_faction and action_name=="FIND RELAY":
			playtest_notice = "NORTH RIDGE RELAY SELECTED  /  SEND A SALVAGE TEAM"
			playtest_notice_seconds = 6.0
		elif (mode_faction or mode_nation) and action_name not in ["PREV","NEXT","PREV SITE","NEXT SITE","PREV ROUTE","NEXT ROUTE","NEXT MODULE","NEXT PROJECT","CLOSE","EXPLORE REGION"]:
			var latest_incident := "" if sim.events.is_empty() else str(sim.events[0].get("title",""))+" / "+str(sim.events[0].get("body",""))
			if latest_incident != previous_incident:
				playtest_notice = latest_incident
			else:
				playtest_notice = "NO CHANGE  /  CHECK SITE, SUPPLIES AND REQUIREMENTS"
			playtest_notice_seconds = 5.0
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
	if civilization_mode:
		var frame := SettlementUILayout.side_panel(vp,620.0)
		for i in range(CIVILIZATION_TABS.size()):
			if SettlementUILayout.civilization_tab_rect(vp,i).has_point(position):
				civilization_tab = i
				return true
		if civilization_tab == 3:
			for i in range(CIV_RECOVERY_PROJECTS.size()):
				var card := Rect2(frame.position+Vector2(21,164.0+float(i)*50.0),Vector2(frame.size.x-43.0,46.0))
				if card.has_point(position):
					civilization_recovery_project_index = i
					return true
		return frame.has_point(position)
	if faction_mode:
		var area := SettlementUILayout.side_panel(vp,480.0)
		var visible := sim.faction_simulation.get_visible_factions(sim)
		if not visible.is_empty():
			var gap := 5.0
			var width := (area.size.x-35.0-gap*float(visible.size()-1))/float(visible.size())
			for i in range(visible.size()):
				var box := Rect2(area.position+Vector2(17.0+float(i)*(width+gap),48.0),Vector2(width,34.0))
				if box.has_point(position):
					faction_index = i
					return true
		return area.has_point(position)
	if economy_mode:
		if industry_workshop_visible:
			return _handle_workshop_click(position)
		if SettlementUILayout.workshop_entry(vp).has_point(position):
			industry_workshop_visible=true
			industry_queue_page=0
			return true
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
				DPNUISkin.stroke(self,_world_point(a["position"]), _world_point(b["position"]), line_color, 2.0)

	for node in nodes:
		var p := _world_point(node["position"])
		var ring := WARN if mode == "POWER" else (Color("#5aa7c7") if mode == "WATER" else Color("#88924b"))
		DPNUISkin.arc(self,p, 16.0 * zoom, 0.0, TAU, 24, ring, 2.0)

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
	var strategy := str(WorldSimulation.STRATEGIES[expedition_strategy_index])
	var ok := sim.world_simulation.create_expedition(sim,selected_world_location_id,expedition_team_size,strategy)
	var event_text := ""
	if not sim.events.is_empty():
		event_text = str(sim.events[0].get("body",""))
	playtest_notice = ("EXPEDITION DISPATCHED  /  " + str(place["name"])) if ok else ("EXPEDITION BLOCKED  /  " + event_text)
	playtest_notice_seconds = 5.0
	return ok

func _can_draw_settlement_minimap() -> bool:
	return settlement_minimap_visible and not (world_map_mode or build_mode or workforce_mode or governance_mode or economy_mode or faction_mode or civilization_mode or help_mode or update_mode or overview_visible) and selected_citizen.is_empty() and selected_building.is_empty() and selected_blueprint.is_empty()

func _settlement_minimap_project(world: Vector2, plot: Rect2) -> Vector2:
	var normalized := Vector2(clampf((world.x-240.0)/1200.0,0.0,1.0),clampf((world.y-135.0)/730.0,0.0,1.0))
	return plot.position+normalized*plot.size

func _draw_settlement_minimap() -> void:
	var size := get_viewport_rect().size
	var frame := SettlementUILayout.settlement_minimap(size)
	var plot := SettlementUILayout.minimap_plot(size)
	DPNUISkin.frame(self,frame,ui_animation_clock)
	draw_string(ThemeDB.fallback_font,frame.position+Vector2(13,23),"LAST HAVEN  /  FACILITY MAP  [F5]",HORIZONTAL_ALIGNMENT_LEFT,frame.size.x-23,12,TEXT)
	draw_rect(plot,Color("#202823"))
	for i in range(1,6):
		var px := plot.position.x+plot.size.x*float(i)/6.0
		var py := plot.position.y+plot.size.y*float(i)/6.0
		DPNUISkin.stroke(self,Vector2(px,plot.position.y),Vector2(px,plot.end.y),Color("#91917a",0.11),1.0)
		DPNUISkin.stroke(self,Vector2(plot.position.x,py),Vector2(plot.end.x,py),Color("#91917a",0.11),1.0)
	for building in sim.buildings:
		var point := _settlement_minimap_project(Vector2(building["position"]),plot)
		var extent := Vector2(building["size"])*Vector2(plot.size.x/1200.0,plot.size.y/730.0)
		var footprint := Rect2(point-extent*0.5,extent)
		var type := str(building["type"])
		var tint := Color("#ad826c")
		if type=="farm":
			tint=Color("#749b60")
		elif type in ["water","sewage"]:
			tint=Color("#76aec0")
		elif type in ["power","industry"]:
			tint=Color("#e1a16d")
		elif type=="medical":
			tint=Color("#c8d1c7")
		draw_rect(footprint,Color("#0a0d10"))
		draw_rect(footprint.grow(-1.0),tint)
		draw_rect(footprint,Color("#e9decb",0.42),false,1.0)
	for blueprint in sim.blueprints:
		var ghost := _settlement_minimap_project(Vector2(blueprint["position"]),plot)
		draw_rect(Rect2(ghost-Vector2(3,3),Vector2(6,6)),Color("#f05267"),false,1.0)
	for person in sim.get_settlement_citizens():
		if bool(person.get("on_expedition",false)):
			continue
		var marker := _settlement_minimap_project(Vector2(person.get("position",Vector2(700,450))),plot)
		draw_circle(marker,1.6,Color("#f8e8d3"))
	var focus_point := _settlement_minimap_project(settlement_world.game_position(settlement_world.focus),plot)
	DPNUISkin.arc(self,focus_point,6.0,0.0,TAU,20,ACCENT,1.6)
	DPNUISkin.stroke(self,focus_point-Vector2(9,0),focus_point+Vector2(9,0),ACCENT,1.0)
	DPNUISkin.stroke(self,focus_point-Vector2(0,9),focus_point+Vector2(0,9),ACCENT,1.0)
	draw_string(ThemeDB.fallback_font,frame.position+Vector2(13,frame.size.y-5),"CLICK TO FOCUS  /  BUILDINGS + CREW",HORIZONTAL_ALIGNMENT_LEFT,frame.size.x-24,9,MUTED)

func _handle_minimap_click(position: Vector2) -> bool:
	if not _can_draw_settlement_minimap():
		return false
	var box := SettlementUILayout.settlement_minimap(get_viewport_rect().size)
	if not box.has_point(position):
		return false
	var plot := SettlementUILayout.minimap_plot(get_viewport_rect().size)
	if plot.has_point(position):
		var normalized := (position-plot.position)/plot.size
		_focus_world_position(Vector2(240.0+normalized.x*1200.0,135.0+normalized.y*730.0))
	return true

func _draw_world_map() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(0,SettlementUILayout.TOP_H,vp.x,vp.y-SettlementUILayout.TOP_H),Color("#08070b"))
	var side := SettlementUILayout.side_panel(vp,372.0)
	var map := SettlementUILayout.region_map_rect(vp)
	draw_string(ThemeDB.fallback_font,Vector2(17,SettlementUILayout.TOP_H+27.0),"REGION  /  EXPLORE & SALVAGE",HORIZONTAL_ALIGNMENT_LEFT,440,17,TEXT)
	draw_string(ThemeDB.fallback_font,Vector2(17,SettlementUILayout.TOP_H+45.0),"Select a discovered location to inspect it.",HORIZONTAL_ALIGNMENT_LEFT,320,11,MUTED)
	draw_rect(Rect2(12,SettlementUILayout.TOP_H+58,220,vp.y-SettlementUILayout.TOP_H-SettlementUILayout.BOTTOM_H-66),Color("#100d12ee"))
	draw_rect(Rect2(12,SettlementUILayout.TOP_H+58,220,vp.y-SettlementUILayout.TOP_H-SettlementUILayout.BOTTOM_H-66),Color("#613541"),false,1)
	var discovered := sim.world_simulation.get_discovered_locations()
	var site_rows := mini(discovered.size(),mini(12,int((vp.y-SettlementUILayout.TOP_H-SettlementUILayout.BOTTOM_H-97.0)/32.0)))
	for i in range(site_rows):
		var entry: Dictionary = discovered[i]
		var r := SettlementUILayout.region_site_row(vp,i)
		var selected := int(entry["id"]) == selected_world_location_id
		var risk := float(entry.get("danger",0.0))
		DPNUISkin.list_row(self,r,selected,r.has_point(get_local_mouse_position()),risk>0.50)
		draw_string(ThemeDB.fallback_font,r.position+Vector2(8,20),str(entry["name"]),HORIZONTAL_ALIGNMENT_LEFT,r.size.x-44,12,TEXT if selected else MUTED)
		draw_string(ThemeDB.fallback_font,r.position+Vector2(r.size.x-34,20),"%d%%" % int(risk*100.0),HORIZONTAL_ALIGNMENT_RIGHT,28,11,WARN if risk<0.5 else BAD)
	if discovered.size()>site_rows:
		draw_string(ThemeDB.fallback_font,Vector2(22,vp.y-SettlementUILayout.BOTTOM_H-15),"%d sites visible  /  %d discovered" % [site_rows,discovered.size()],HORIZONTAL_ALIGNMENT_LEFT,200,10,WARN)
	# Terrain relief, river and archival roads replace the opaque radar disk.
	# Projected site hitboxes still use SettlementUILayout.region_point.
	RegionAtlas.draw_cartography(self,map,region_atlas,sim.world_simulation.get_radio_range())
	var home := SettlementUILayout.region_point(vp,Vector2(600,410))
	var range_px := minf(map.size.x/1200.0,map.size.y/820.0)*sim.world_simulation.get_radio_range()
	# Only the thin radio boundary is drawn; it does not conceal the terrain.
	DPNUISkin.arc(self,home,range_px,0.0,TAU,80,Color("#eb566b",0.47),1.5)
	# Home -> North Ridge Relay is an actual salvage objective. Show only
	# discovered destinations here; other ruins remain secret until found.
	var relay := sim.world_simulation.get_location_by_id(3)
	if not relay.is_empty() and bool(relay.get("discovered",false)) and not bool(relay.get("restored",false)):
		var relay_pos := SettlementUILayout.region_point(vp,Vector2(relay["position"]))
		_draw_region_route_trace(home,relay_pos,Color("#efa56c",0.36))
	for location in sim.world_simulation.locations:
		var location_pos := SettlementUILayout.region_point(vp,Vector2(location["position"]))
		var discovered_site := bool(location.get("discovered",false))
		if not discovered_site:
			# Do not leak undiscovered locations as dark dots on the map.
			continue
		var id := int(location["id"])
		var risk := float(location.get("danger",0.0))
		var color := GOOD if str(location["type"]) in ["settlement","player_settlement"] else (BAD if risk>0.50 else WARN)
		if bool(location.get("depleted",false)):
			color = MUTED
		var focused := selected_world_location_id == id
		if focused:
			draw_circle(location_pos,14.0,Color("#e33950",0.22))
			DPNUISkin.arc(self,location_pos,13.0,0.0,TAU,32,ACCENT,2.5)
		draw_circle(location_pos,7.0,Color("#111016"))
		draw_circle(location_pos,5.0,color)
		if map.size.x >= 370.0:
			var label := str(location["name"])
			var label_x := clampf(location_pos.x+11.0,map.position.x+4.0,map.end.x-127.0)
			var label_y := clampf(location_pos.y-11.0,map.position.y+42.0,map.end.y-32.0)
			var caption := Rect2(label_x-3.0,label_y-13.0,123.0,20.0)
			draw_rect(caption,Color("#07090c",0.81))
			draw_rect(caption,Color("#9c3445",0.8) if focused else Color("#445355",0.43),false,1.0)
			draw_string(ThemeDB.fallback_font,Vector2(label_x+3.0,label_y+1.0),label,HORIZONTAL_ALIGNMENT_LEFT,112.0,11,TEXT)
	for expedition in sim.world_simulation.get_active_expeditions():
		var destination: Dictionary = sim.world_simulation.get_location_by_id(int(expedition["destination_id"]))
		if destination.is_empty():
			continue
		var end := SettlementUILayout.region_point(vp,Vector2(destination["position"]))
		var traveled := float(expedition["progress"])
		var distance := maxf(1.0,float(expedition["distance"]))
		var phase := str(expedition["status"])
		var return_distance := float(expedition.get("return_distance",distance))
		var recalled := bool(expedition.get("recalled",false))
		var route_end := home.lerp(end,clampf(return_distance/distance,0.0,1.0)) if recalled else end
		var fraction := clampf(traveled/distance,0.0,1.0)
		var exp_pos := home.lerp(end,fraction) if phase=="outbound" else (route_end.lerp(home,clampf(traveled/maxf(0.01,return_distance),0.0,1.0)) if phase=="returning" else end)
		_draw_region_route_trace(home,route_end,Color("#f75e70",0.9))
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
	# Planning and dispatch share one side-effect-free simulation preview.
	var strategy := str(WorldSimulation.STRATEGIES[expedition_strategy_index])
	var mission: Dictionary = sim.world_simulation.plan_expedition(sim,selected_world_location_id,expedition_team_size,strategy)
	draw_string(ThemeDB.fallback_font,Vector2(px,py+168),"MISSION PLANNER  /  %d PERSON TEAM" % expedition_team_size,HORIZONTAL_ALIGNMENT_LEFT,side.size.x-34,11,GOOD)
	var controls := ["− TEAM","+ TEAM","TACTIC: "+strategy.to_upper()+"  ›"]
	for index in range(3):
		var rect := SettlementUILayout.region_team_control(vp,index)
		var hovered := rect.has_point(get_local_mouse_position())
		DPNUISkin.button(self,rect,controls[index],hovered,false,false,true,true)
	var roster_names := PackedStringArray()
	for id in mission.get("members",[]):
		var citizen := sim.get_citizen_by_id(int(id))
		if not citizen.is_empty():
			roster_names.append(str(citizen["name"]).split(" ")[0])
	var preview := "TEAM: "+(", ".join(roster_names) if not roster_names.is_empty() else "No eligible crew")
	draw_string(ThemeDB.fallback_font,Vector2(px,py+225),preview,HORIZONTAL_ALIGNMENT_LEFT,side.size.x-36,10,MUTED)
	draw_string(ThemeDB.fallback_font,Vector2(px,py+242),"Supplies: %.0f meals  •  %.0f water  •  %.0f meds" % [float(mission["food_cost"]),float(mission["water_cost"]),float(mission["medicine_cost"])],HORIZONTAL_ALIGNMENT_LEFT,side.size.x-36,10,TEXT)
	draw_string(ThemeDB.fallback_font,Vector2(px,py+259),"One-way %.1fh  •  search %.1fh  •  hazard %.0f%%" % [float(mission["travel_hours"]),float(mission["search_hours"]),float(mission["risk"])*100.0],HORIZONTAL_ALIGNMENT_LEFT,side.size.x-36,10,WARN if float(mission["risk"])<0.45 else BAD)
	var dispatch := SettlementUILayout.region_dispatch_rect(vp)
	var can_go := bool(mission["ok"])
	DPNUISkin.button(self,dispatch,"AUTHORIZE DEPLOYMENT  [G]" if can_go else str(mission["reason"]),dispatch.has_point(get_local_mouse_position()),can_go,false,true)
	draw_string(ThemeDB.fallback_font,Vector2(px,py+340),"ACTIVE EXPEDITIONS   %d" % sim.world_simulation.get_active_expeditions().size(),HORIZONTAL_ALIGNMENT_LEFT,side.size.x-30,12,ACCENT)
	var ey := py+363.0
	var visible_expeditions := sim.world_simulation.get_active_expeditions()
	for row in range(visible_expeditions.size()):
		if ey>side.end.y-92:
			break
		var expedition: Dictionary = visible_expeditions[row]
		var target := sim.world_simulation.get_location_by_id(int(expedition["destination_id"]))
		var stage := str(expedition["status"])
		var elapsed := float(expedition.get("progress",0.0))
		var phase_target := float(expedition.get("search_hours",6.0)) if stage=="searching" else float(expedition.get("return_distance",expedition["distance"])) if stage=="returning" else float(expedition.get("distance",1.0))
		var completion := clampf(elapsed/maxf(0.01,phase_target),0.0,1.0)
		draw_string(ThemeDB.fallback_font,Vector2(px,ey),"Team %d  •  %s" % [int(expedition["id"]),stage.capitalize()],HORIZONTAL_ALIGNMENT_LEFT,side.size.x-130,11,TEXT)
		draw_string(ThemeDB.fallback_font,Vector2(px,ey+15),str(target.get("name","Unknown destination")),HORIZONTAL_ALIGNMENT_LEFT,side.size.x-130,10,MUTED)
		var recall := SettlementUILayout.region_recall_rect(vp,row)
		var can_recall := stage in ["outbound","searching"]
		DPNUISkin.button(self,recall,"RECALL" if can_recall else "RETURN",recall.has_point(get_local_mouse_position()),false,can_recall,can_recall,true)
		draw_rect(Rect2(px,ey+20,side.size.x-36,3.0),Color("#251721"))
		draw_rect(Rect2(px,ey+20,(side.size.x-36.0)*completion,3.0),GOOD)
		ey+=48.0

func _draw_region_route_trace(origin: Vector2, destination: Vector2, tint: Color) -> void:
	# Alternating direct-route segments keep the real straight-line travel
	# estimate legible on top of detailed terrain, without faking a road route.
	var distance := origin.distance_to(destination)
	if distance < 1.0:
		return
	var steps := maxi(1,int(ceil(distance/13.0)))
	for i in range(steps):
		if i%2!=0:
			continue
		var a := origin.lerp(destination,float(i)/float(steps))
		var b := origin.lerp(destination,minf(1.0,float(i+1)/float(steps)))
		DPNUISkin.stroke(self,a,b,tint,2.0)

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
	var side := SettlementUILayout.side_panel(vp,372.0)
	var active := sim.world_simulation.get_active_expeditions()
	for i in range(active.size()):
		if side.position.y+363.0+float(i)*48.0>side.end.y-92.0:
			break
		if SettlementUILayout.region_recall_rect(vp,i).has_point(position):
			var expedition: Dictionary=active[i]
			if sim.world_simulation.recall_expedition(sim,int(expedition["id"])):
				playtest_notice="TEAM %d RECALLED  /  RETURNING TO LAST HAVEN" % int(expedition["id"])
				playtest_notice_seconds=5.0
			return true
	var discovered := sim.world_simulation.get_discovered_locations()
	var rows := mini(discovered.size(),mini(12,int((vp.y-SettlementUILayout.TOP_H-SettlementUILayout.BOTTOM_H-97.0)/32.0)))
	for i in range(rows):
		if SettlementUILayout.region_site_row(vp,i).has_point(position):
			selected_world_location_id = int(discovered[i]["id"])
			return true
	for index in range(3):
		if not SettlementUILayout.region_team_control(vp,index).has_point(position):
			continue
		match index:
			0: expedition_team_size=maxi(1,expedition_team_size-1)
			1: expedition_team_size=mini(4,expedition_team_size+1)
			2: expedition_strategy_index=(expedition_strategy_index+1)%WorldSimulation.STRATEGIES.size()
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
	if industry_workshop_visible:
		_draw_workshop_panel()
		return
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
		DPNUISkin.list_row(self,row,selected,row.has_point(get_local_mouse_position()))
		draw_string(ThemeDB.fallback_font,row.position+Vector2(8,15),item.capitalize(),HORIZONTAL_ALIGNMENT_LEFT,160,11,TEXT if selected else MUTED)
		draw_string(ThemeDB.fallback_font,Vector2(row.end.x-130.0,row.position.y+15.0),"%.1f credits" % eco.get_trade_price(item,economy_source_index),HORIZONTAL_ALIGNMENT_RIGHT,124,11,GOOD if selected else MUTED)
	var workshop_link := SettlementUILayout.workshop_entry(vp)
	DPNUISkin.button(self,workshop_link,"OPEN WORKSHOP CONTROL   /   MANAGE ORDERS  >",workshop_link.has_point(get_local_mouse_position()),true)
	var recipe_name: String = str(ECONOMY_RECIPES[economy_recipe_index])
	var recipe: Dictionary = eco.recipes.get(recipe_name,{})
	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+356),recipe_name,HORIZONTAL_ALIGNMENT_LEFT,w-36,13,TEXT)
	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+376),"Requires: "+_format_recipe_items(recipe.get("input",{})),HORIZONTAL_ALIGNMENT_LEFT,w-34,10,MUTED)
	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+394),"Produces: "+_format_recipe_items(recipe.get("output",{})),HORIZONTAL_ALIGNMENT_LEFT,w-34,10,GOOD)
	DPNUISkin.stroke(self,Vector2(x+16,y+404),Vector2(x+w-16,y+404),Color("#613641"),1)
	# Operational dashboards only appear when they fit above real action keys.
	# Their telemetry is taken from the economy simulation, never fake charts.
	var live_batches := eco.get_open_batches()
	var queued := 0
	var working := 0
	for batch in live_batches:
		if str(batch.get("status",""))=="working":
			working+=1
		else:
			queued+=1
	var can_show_metrics := area.size.y>=580.0
	var queue_top := y+444.0
	if can_show_metrics:
		var metric_w := (w-47.0)/3.0
		var reports := [
			["STORAGE","%.0f%%" % (100.0*eco.warehouse_used/maxf(1.0,eco.warehouse_capacity)),"Warehouse fill"],
			["OUTPUT","%.0f%%" % (eco.production_efficiency*100.0),"Line efficiency"],
			["RUNNING",str(working),"Queued "+str(queued)]
		]
		for i in range(3):
			var report: Array=reports[i]
			DPNUISkin.metric_card(self,Rect2(x+17.0+float(i)*(metric_w+6.0),y+416.0,metric_w,61.0),str(report[0]),str(report[1]),str(report[2]),i==1 and eco.production_efficiency<0.4)
		queue_top=y+489.0
	draw_string(ThemeDB.fallback_font,Vector2(x+20,queue_top+12.0),"MANUFACTURING ORDERS   /   %d ACTIVE" % live_batches.size(),HORIZONTAL_ALIGNMENT_LEFT,w-34,12,ACCENT)
	var last_y := area.end.y - 91.0
	var y_row := queue_top+23.0
	for batch in live_batches:
		if y_row+33.0>last_y:
			break
		var row := Rect2(x+18,y_row,w-36.0,30.0)
		var status := str(batch.get("status","queued"))
		var definition: Dictionary=eco.recipes.get(str(batch.get("recipe","")),{})
		var completion := clampf(float(batch.get("progress",0.0))/maxf(1.0,float(definition.get("work",1.0))),0.0,1.0)
		DPNUISkin.list_row(self,row,false,false)
		draw_string(ThemeDB.fallback_font,row.position+Vector2(11,18),str(batch.get("recipe","Unknown")),HORIZONTAL_ALIGNMENT_LEFT,row.size.x-125.0,12,TEXT)
		draw_string(ThemeDB.fallback_font,Vector2(row.end.x-110.0,row.position.y+18.0),status.to_upper()+"  %.0f%%" % (completion*100.0),HORIZONTAL_ALIGNMENT_RIGHT,99.0,11,GOOD if status=="working" else MUTED)
		DPNUISkin.meter(self,Rect2(row.position+Vector2(8.0,row.size.y-5.0),Vector2(row.size.x-16.0,3.0)),completion,ACCENT)
		y_row+=34.0
	if live_batches.is_empty() and y_row+20.0<last_y:
		draw_string(ThemeDB.fallback_font,Vector2(x+20,y_row+14),"No active orders. Open Workshop Control to start production.",HORIZONTAL_ALIGNMENT_LEFT,w-36,11,MUTED)


func _workshop_selected_batch() -> Dictionary:
	var eco := sim.economy_simulation
	var active := eco.get_open_batches()
	for batch in active:
		if int(batch.get("id",0))==industry_batch_id:
			return batch
	if active.is_empty():
		industry_batch_id=0
		return {}
	industry_batch_id=int(active[0]["id"])
	return active[0]

func _workshop_notice(text_value: String, succeeded: bool) -> void:
	playtest_notice=text_value
	playtest_notice_seconds=5.0 if succeeded else 4.0

func _draw_workshop_panel() -> void:
	var vp := get_viewport_rect().size
	var frame := SettlementUILayout.workshop_panel(vp)
	var x := frame.position.x
	var y := frame.position.y
	var w := frame.size.x
	var h := frame.size.y
	var eco := sim.economy_simulation
	var crew := 0
	for person in sim.get_settlement_citizens():
		if str(person.get("job","")) in ["Engineer","Builder"] and sim.is_selected_work_enabled(person) and sim._is_shift_active(person) and not bool(person.get("incarcerated",false)) and float(person.get("health",0))>=30.0:
			crew+=1
	_draw_ui_panel(frame,ACCENT)
	draw_rect(Rect2(x+15,y+12,4,22),ACCENT)
	draw_string(ThemeDB.fallback_font,Vector2(x+28,y+30),"WORKSHOP CONTROL  /  INDUSTRIAL PRODUCTION",HORIZONTAL_ALIGNMENT_LEFT,w-48,15,TEXT)
	draw_string(ThemeDB.fallback_font,Vector2(x+18,y+52),"Active shift workers: %d   •   Line efficiency: %.0f%%   •   %s" % [crew,100.0*eco.production_efficiency,"PAUSED" if eco.production_paused else "RUNNING"],HORIZONTAL_ALIGNMENT_LEFT,w-36,11,WARN if eco.production_paused or crew==0 else GOOD)
	var bottleneck := "Awaiting next production cycle" if str(eco.bottleneck_reason)=="" else str(eco.bottleneck_reason)
	draw_string(ThemeDB.fallback_font,Vector2(x+18,y+72),"STATUS: "+bottleneck,HORIZONTAL_ALIGNMENT_LEFT,w-36,10,WARN if str(eco.bottleneck_reason)!="" else MUTED)
	draw_string(ThemeDB.fallback_font,Vector2(x+18,y+90),"SELECT RECIPE  /  THEN QUEUE",HORIZONTAL_ALIGNMENT_LEFT,w-36,10,ACCENT)
	for i in range(ECONOMY_RECIPES.size()):
		var recipe_name := str(ECONOMY_RECIPES[i])
		var box := SettlementUILayout.workshop_recipe(vp,i)
		var active := i==economy_recipe_index
		DPNUISkin.button(self,box,recipe_name,box.has_point(get_local_mouse_position()),active,false,true,true)
	var selected_recipe := str(ECONOMY_RECIPES[economy_recipe_index])
	var recipe: Dictionary=eco.recipes[selected_recipe]
	draw_string(ThemeDB.fallback_font,Vector2(x+18,y+193),"Requires: "+_format_recipe_items(recipe["input"]),HORIZONTAL_ALIGNMENT_LEFT,w-36,10,TEXT)
	draw_string(ThemeDB.fallback_font,Vector2(x+18,y+209),"Yields: "+_format_recipe_items(recipe["output"])+"   •   "+eco.get_recipe_readiness(sim,selected_recipe),HORIZONTAL_ALIGNMENT_LEFT,w-36,10,GOOD if eco.get_recipe_readiness(sim,selected_recipe)=="INPUTS READY" else WARN)
	var active_batches := eco.get_open_batches()
	var page_rows := SettlementUILayout.workshop_visible_rows(vp)
	var pages := maxi(1,int(ceil(float(active_batches.size())/float(page_rows))))
	industry_queue_page=clampi(industry_queue_page,0,pages-1)
	DPNUISkin.stroke(self,Vector2(x+16,y+219),Vector2(x+w-16,y+219),Color("#49626c"),1)
	draw_string(ThemeDB.fallback_font,Vector2(x+18,y+238),"PRODUCTION ORDERS  /  %d ACTIVE  /  PAGE %d OF %d" % [active_batches.size(),industry_queue_page+1,pages],HORIZONTAL_ALIGNMENT_LEFT,w-36,11,ACCENT)
	var selected_batch := _workshop_selected_batch()
	for i in range(page_rows):
		var index := industry_queue_page*page_rows+i
		if index>=active_batches.size():
			break
		var batch: Dictionary=active_batches[index]
		var rect := SettlementUILayout.workshop_queue_row(vp,i)
		var active := int(batch["id"])==industry_batch_id
		var status := str(batch.get("status","queued"))
		var definition: Dictionary=eco.recipes.get(str(batch.get("recipe","")),{})
		var total := maxf(1.0,float(definition.get("work",1.0)))
		var progress := clampf(float(batch.get("progress",0.0))/total,0.0,1.0)
		DPNUISkin.list_row(self,rect,active,rect.has_point(get_local_mouse_position()))
		draw_string(ThemeDB.fallback_font,rect.position+Vector2(10,17),"#%d  %s" % [int(batch["id"]),str(batch["recipe"])],HORIZONTAL_ALIGNMENT_LEFT,rect.size.x*0.57,11,TEXT)
		draw_string(ThemeDB.fallback_font,rect.position+Vector2(rect.size.x*0.57,17),"%s  %.0f%%" % [status.to_upper(),progress*100.0],HORIZONTAL_ALIGNMENT_RIGHT,rect.size.x*0.40,10,GOOD if status=="working" else MUTED)
		draw_rect(Rect2(rect.position.x+9,rect.end.y-4,rect.size.x-18.0,2.0),Color("#281e26"))
		if progress>0.0:
			draw_rect(Rect2(rect.position.x+9,rect.end.y-4,(rect.size.x-18.0)*progress,2.0),GOOD)
	if active_batches.is_empty():
		draw_string(ThemeDB.fallback_font,Vector2(x+20,y+280),"No pending jobs. Select a recipe and queue a batch.",HORIZONTAL_ALIGNMENT_LEFT,w-34,11,MUTED)
	elif not selected_batch.is_empty() and str(selected_batch.get("status",""))=="working":
		draw_string(ThemeDB.fallback_font,Vector2(x+18,frame.end.y-96),"Selected order is in progress; consumed inputs cannot be recovered.",HORIZONTAL_ALIGNMENT_LEFT,w-36,10,WARN)
	var actions := ["QUEUE 1","QUEUE 5","MOVE UP","MOVE DOWN","CANCEL","RESUME" if eco.production_paused else "PAUSE","PREV PAGE","NEXT PAGE","TRADE","CLOSE"]
	for i in range(actions.size()):
		var button := SettlementUILayout.workshop_action(vp,i)
		var hover := button.has_point(get_local_mouse_position())
		var blocked := false
		if i in [2,3,4]:
			blocked=selected_batch.is_empty() or str(selected_batch.get("status",""))!="queued"
		DPNUISkin.button(self,button,actions[i],hover,false,i==4 or i==9,not blocked,true)

func _handle_workshop_click(position: Vector2) -> bool:
	if not industry_workshop_visible:
		return false
	var vp := get_viewport_rect().size
	var frame := SettlementUILayout.workshop_panel(vp)
	if not frame.has_point(position):
		return true
	var eco := sim.economy_simulation
	for i in range(ECONOMY_RECIPES.size()):
		if SettlementUILayout.workshop_recipe(vp,i).has_point(position):
			economy_recipe_index=i
			return true
	var active := eco.get_open_batches()
	var rows := SettlementUILayout.workshop_visible_rows(vp)
	for i in range(rows):
		var index := industry_queue_page*rows+i
		if index<active.size() and SettlementUILayout.workshop_queue_row(vp,i).has_point(position):
			industry_batch_id=int(active[index]["id"])
			return true
	for i in range(10):
		if not SettlementUILayout.workshop_action(vp,i).has_point(position):
			continue
		var chosen := _workshop_selected_batch()
		var ok := false
		match i:
			0,1:
				ok=eco.queue_recipe(sim,str(ECONOMY_RECIPES[economy_recipe_index]),1 if i==0 else 5)
				_workshop_notice("PRODUCTION JOBS QUEUED" if ok else "QUEUE LIMIT REACHED",ok)
			2,3:
				ok=eco.move_queued_batch(sim,int(chosen.get("id",0)),-1 if i==2 else 1)
				_workshop_notice("ORDER PRIORITY UPDATED" if ok else "CANNOT MOVE THIS ORDER",ok)
			4:
				ok=eco.cancel_queued_batch(sim,int(chosen.get("id",0)))
				if ok:
					industry_batch_id=0
				_workshop_notice("UNSTARTED JOB CANCELLED" if ok else "WORKING ORDERS CANNOT BE CANCELLED",ok)
			5:
				eco.set_production_paused(sim,not eco.production_paused)
				_workshop_notice("WORKSHOP ON HOLD" if eco.production_paused else "WORKSHOP RESUMED",true)
			6,7:
				var pages := maxi(1,int(ceil(float(active.size())/float(rows))))
				industry_queue_page=posmod(industry_queue_page+(-1 if i==6 else 1),pages)
			8:
				industry_workshop_visible=false
			9:
				industry_workshop_visible=false
				economy_mode=false
		return true
	return true

func _draw_civilization_panel() -> void:
	var vp := get_viewport_rect().size
	var panel := SettlementUILayout.side_panel(vp,620.0)
	var x := panel.position.x
	var y := panel.position.y
	var w := panel.size.x
	var civ := sim.civilization_simulation
	var fed := sim.federal_governance_simulation
	var settlements := civ.get_settlement_list()
	var candidates := civ.get_founding_candidates(sim)
	civilization_settlement_index = clampi(civilization_settlement_index,0,maxi(0,settlements.size()-1))
	civilization_route_index = clampi(civilization_route_index,0,maxi(0,civ.logistics_routes.size()-1))
	civilization_candidate_index = clampi(civilization_candidate_index,0,maxi(0,candidates.size()-1))
	civilization_recovery_project_index = clampi(civilization_recovery_project_index,0,CIV_RECOVERY_PROJECTS.size()-1)
	civilization_colony_project_index = clampi(civilization_colony_project_index,0,CIV_COLONY_PROJECTS.size()-1)
	_draw_ui_panel(panel,ACCENT)
	draw_rect(Rect2(x+13,y+12,4,24),ACCENT)
	draw_string(ThemeDB.fallback_font,Vector2(x+27,y+29),"NATION  /  CIVILIZATION RECOVERY",HORIZONTAL_ALIGNMENT_LEFT,w-50,17,TEXT)
	draw_string(ThemeDB.fallback_font,Vector2(x+16,y+51),"Build settlements, establish supply routes and rebuild the region.",HORIZONTAL_ALIGNMENT_LEFT,w-32,11,MUTED)
	for idx in range(CIVILIZATION_TABS.size()):
		var box := SettlementUILayout.civilization_tab_rect(vp,idx)
		var active := civilization_tab==idx
		DPNUISkin.button(self,box,str(CIVILIZATION_TABS[idx]),box.has_point(get_local_mouse_position()),active,false,true,true)
	var left := x+21.0
	var max_width := w-43.0
	var top := y+122.0
	match civilization_tab:
		0:
			draw_string(ThemeDB.fallback_font,Vector2(left,top),"YOUR RECOVERY NETWORK",HORIZONTAL_ALIGNMENT_LEFT,max_width,15,TEXT)
			draw_string(ThemeDB.fallback_font,Vector2(left,top+24),"Stage: %s    |    Communities: %d    |    Trade routes: %d" % [str(civ.endgame_stage).capitalize(),settlements.size(),civ.logistics_routes.size()],HORIZONTAL_ALIGNMENT_LEFT,max_width,12,MUTED)
			_draw_meter(Vector2(left,top+51),max_width,"REGIONAL RECOVERY",civ.recovery_score)
			_draw_meter(Vector2(left,top+92),max_width,"CIVILIZATION STABILITY",civ.civilization_stability)
			DPNUISkin.stroke(self,Vector2(left,top+128),Vector2(panel.end.x-18,top+128),Color("#643845"),1.0)
			draw_string(ThemeDB.fallback_font,Vector2(left,top+150),"YOUR NEXT OBJECTIVE",HORIZONTAL_ALIGNMENT_LEFT,max_width,12,ACCENT)
			var foundable := civ.get_foundable_locations(sim)
			var next_step := "Explore the region and salvage an abandoned site."
			var second_step := "A secured ruin can become a second settlement."
			if not foundable.is_empty():
				next_step = "%d cleared site(s) are ready for a new settlement." % foundable.size()
				second_step = "Open Region, choose a cleared ruin, then press I."
			elif settlements.size()>1:
				next_step = "Keep colonies supplied and grow regional recovery."
				second_step = "Use Colonies, Logistics and Recovery tabs for real orders."
			draw_string(ThemeDB.fallback_font,Vector2(left,top+176),next_step,HORIZONTAL_ALIGNMENT_LEFT,max_width,12,TEXT)
			draw_string(ThemeDB.fallback_font,Vector2(left,top+197),second_step,HORIZONTAL_ALIGNMENT_LEFT,max_width,11,GOOD)
			draw_string(ThemeDB.fallback_font,Vector2(left,top+242),"FOUNDED COMMUNITIES",HORIZONTAL_ALIGNMENT_LEFT,max_width,13,ACCENT)
			var ry := top+263.0
			for settlement in settlements:
				if ry>panel.end.y-112:
					break
				draw_string(ThemeDB.fallback_font,Vector2(left,ry),str(settlement["name"])+"  •  "+str(settlement["status"]).capitalize()+"  •  Population "+str(settlement["population"]),HORIZONTAL_ALIGNMENT_LEFT,max_width,12,TEXT)
				ry += 24.0
			# Fill formerly unused space with actual regional intelligence.
			# Omit on small screens rather than colliding with action buttons.
			if panel.size.y>=535.0 and ry<top+323.0:
				var metrics_y := top+323.0
				var metric_w := (max_width-16.0)/3.0
				var metrics := [
					["DISCOVERED",str(sim.world_simulation.get_discovered_locations().size()),"Regional sites"],
					["READY TO FOUND",str(foundable.size()),"Secured locations"],
					["FIELD TEAMS",str(sim.world_simulation.get_active_expeditions().size()),"Active expeditions"]
				]
				for metric_i in range(metrics.size()):
					var metric: Array=metrics[metric_i]
					DPNUISkin.metric_card(self,Rect2(left+float(metric_i)*(metric_w+8.0),metrics_y,metric_w,62.0),str(metric[0]),str(metric[1]),str(metric[2]),metric_i==1 and foundable.is_empty())
			if panel.size.y>=690.0:
				draw_string(ThemeDB.fallback_font,Vector2(left,top+423),"LATEST SETTLEMENT OPERATIONS",HORIZONTAL_ALIGNMENT_LEFT,max_width,13,ACCENT)
				for event_i in range(mini(3,sim.events.size())):
					var event: Dictionary=sim.events[event_i]
					var event_y := top+455.0+float(event_i)*45.0
					if event_y>panel.end.y-96.0:
						break
					DPNUISkin.list_row(self,Rect2(left,event_y-19.0,max_width,41.0),false,false)
					draw_string(ThemeDB.fallback_font,Vector2(left+12,event_y),str(event.get("title","System event")),HORIZONTAL_ALIGNMENT_LEFT,max_width-24,12,TEXT)
					draw_string(ThemeDB.fallback_font,Vector2(left+12,event_y+16),str(event.get("body","")),HORIZONTAL_ALIGNMENT_LEFT,max_width-24,10,MUTED)
		1:
			draw_string(ThemeDB.fallback_font,Vector2(left,top),"SETTLEMENT MANAGEMENT",HORIZONTAL_ALIGNMENT_LEFT,max_width,15,TEXT)
			if not settlements.is_empty():
				var settlement: Dictionary = settlements[civilization_settlement_index]
				var key := str(settlement["id"])
				draw_string(ThemeDB.fallback_font,Vector2(left,top+30),"%d/%d  •  %s" % [civilization_settlement_index+1,settlements.size(),str(settlement["name"])],HORIZONTAL_ALIGNMENT_LEFT,max_width,16,GOOD)
				draw_string(ThemeDB.fallback_font,Vector2(left,top+54),"Status: %s    |    Focus: %s" % [str(settlement["status"]),str(settlement["specialization"])],HORIZONTAL_ALIGNMENT_LEFT,max_width,12,MUTED)
				draw_string(ThemeDB.fallback_font,Vector2(left,top+80),"People %d   •   Infrastructure %.0f%%   •   Morale %.0f%%" % [int(settlement["population"]),float(settlement["infrastructure"]),float(settlement["morale"])],HORIZONTAL_ALIGNMENT_LEFT,max_width,12,TEXT)
				var resources: Dictionary = settlement["resources"]
				draw_string(ThemeDB.fallback_font,Vector2(left,top+107),"Food %.0f   Water %.0f   Materials %.0f   Parts %.0f" % [float(resources["food"]),float(resources["water"]),float(resources["materials"]),float(resources["parts"])],HORIZONTAL_ALIGNMENT_LEFT,max_width,11,MUTED)
				var modules: Dictionary = settlement.get("modules",{})
				draw_string(ThemeDB.fallback_font,Vector2(left,top+134),"Housing %d   Farms %d   Clinics %d   Workshops %d" % [int(modules.get("housing",0)),int(modules.get("farm",0)),int(modules.get("clinic",0)),int(modules.get("workshop",0))],HORIZONTAL_ALIGNMENT_LEFT,max_width,11,TEXT)
				DPNUISkin.stroke(self,Vector2(left,top+155),Vector2(panel.end.x-18,top+155),Color("#643845"),1.0)
				if key == "LAST_HAVEN":
					draw_string(ThemeDB.fallback_font,Vector2(left,top+181),"LAST HAVEN IS YOUR CAPITAL",HORIZONTAL_ALIGNMENT_LEFT,max_width,13,ACCENT)
					draw_string(ThemeDB.fallback_font,Vector2(left,top+208),"Use Build to add facilities to the capital.",HORIZONTAL_ALIGNMENT_LEFT,max_width,12,TEXT)
					draw_string(ThemeDB.fallback_font,Vector2(left,top+231),"To create a colony: salvage a ruin in Region, then press I.",HORIZONTAL_ALIGNMENT_LEFT,max_width,11,MUTED)
					draw_string(ThemeDB.fallback_font,Vector2(left,top+257),"Needs: 35 materials, 20 meals, 30 water, 4 parts, 4 adults.",HORIZONTAL_ALIGNMENT_LEFT,max_width,11,WARN)
				else:
					var name := str(CIV_COLONY_PROJECTS[civilization_colony_project_index])
					var catalog: Dictionary = civ.COLONY_PROJECT_CATALOG[name]
					draw_string(ThemeDB.fallback_font,Vector2(left,top+182),"SELECTED COLONY PROJECT",HORIZONTAL_ALIGNMENT_LEFT,max_width,12,ACCENT)
					draw_string(ThemeDB.fallback_font,Vector2(left,top+205),name,HORIZONTAL_ALIGNMENT_LEFT,max_width,15,TEXT)
					draw_string(ThemeDB.fallback_font,Vector2(left,top+226),"Cost: %.0f materials  •  %.0f parts  •  %.0f medicine" % [float(catalog["materials"]),float(catalog["parts"]),float(catalog["medicine"])],HORIZONTAL_ALIGNMENT_LEFT,max_width,11,MUTED)
					var project: Dictionary = civ.get_active_colony_project(key)
					draw_string(ThemeDB.fallback_font,Vector2(left,top+257),"Active: None" if project.is_empty() else "Active: %s  •  %.0f%%" % [str(project["project"]),100.0*float(project["progress"])/maxf(1.0,float(project["work"]))],HORIZONTAL_ALIGNMENT_LEFT,max_width,12,GOOD)
					draw_string(ThemeDB.fallback_font,Vector2(left,top+283),"Aid requires 8 food, 12 water and 2 medicine.",HORIZONTAL_ALIGNMENT_LEFT,max_width,11,MUTED)
		2:
			draw_string(ThemeDB.fallback_font,Vector2(left,top),"SUPPLY ROUTES",HORIZONTAL_ALIGNMENT_LEFT,max_width,15,TEXT)
			draw_string(ThemeDB.fallback_font,Vector2(left,top+26),"Routes move resources between your communities.",HORIZONTAL_ALIGNMENT_LEFT,max_width,11,MUTED)
			if civ.logistics_routes.is_empty():
				draw_string(ThemeDB.fallback_font,Vector2(left,top+71),"NO SUPPLY ROUTES ESTABLISHED",HORIZONTAL_ALIGNMENT_LEFT,max_width,13,WARN)
				draw_string(ThemeDB.fallback_font,Vector2(left,top+98),"A route is created when you found a second settlement.",HORIZONTAL_ALIGNMENT_LEFT,max_width,12,TEXT)
				draw_string(ThemeDB.fallback_font,Vector2(left,top+123),"Explore Region, salvage a ruin, and establish a colony.",HORIZONTAL_ALIGNMENT_LEFT,max_width,11,MUTED)
			else:
				var route: Dictionary = civ.logistics_routes[civilization_route_index]
				var source: Dictionary = civ.settlements[str(route["source"])]
				var dest: Dictionary = civ.settlements[str(route["destination"])]
				draw_string(ThemeDB.fallback_font,Vector2(left,top+72),"%d/%d  •  %s → %s" % [civilization_route_index+1,civ.logistics_routes.size(),str(source["name"]),str(dest["name"])],HORIZONTAL_ALIGNMENT_LEFT,max_width,15,TEXT)
				draw_string(ThemeDB.fallback_font,Vector2(left,top+102),"Status: %s" % ("Active" if bool(route.get("active",true)) else "Paused"),HORIZONTAL_ALIGNMENT_LEFT,max_width,12,GOOD if bool(route.get("active",true)) else WARN)
				draw_string(ThemeDB.fallback_font,Vector2(left,top+132),"Priority: %d   •   Freight focus: %s" % [int(route.get("priority",2)),str(route.get("focus","Balanced"))],HORIZONTAL_ALIGNMENT_LEFT,max_width,12,MUTED)
				draw_string(ThemeDB.fallback_font,Vector2(left,top+170),"Use the controls below to change routing behavior.",HORIZONTAL_ALIGNMENT_LEFT,max_width,11,TEXT)
		3:
			draw_string(ThemeDB.fallback_font,Vector2(left,top),"REGIONAL RECONSTRUCTION",HORIZONTAL_ALIGNMENT_LEFT,max_width,15,TEXT)
			draw_string(ThemeDB.fallback_font,Vector2(left,top+25),"Spend real supplies to restore essential infrastructure.",HORIZONTAL_ALIGNMENT_LEFT,max_width,11,MUTED)
			for i in range(CIV_RECOVERY_PROJECTS.size()):
				var pname := str(CIV_RECOVERY_PROJECTS[i])
				var card := Rect2(left,top+42.0+float(i)*50.0,max_width,46.0)
				var current := i==civilization_recovery_project_index
				DPNUISkin.list_row(self,card,current,card.has_point(get_local_mouse_position()))
				draw_string(ThemeDB.fallback_font,card.position+Vector2(10,19),pname,HORIZONTAL_ALIGNMENT_LEFT,card.size.x-100,12,TEXT)
				draw_string(ThemeDB.fallback_font,Vector2(card.end.x-89,card.position.y+19),"%.0f%%" % civ.get_recovery_project_progress(pname),HORIZONTAL_ALIGNMENT_RIGHT,80,12,GOOD if civ._recovery_project_complete(pname) else WARN)
				draw_rect(Rect2(card.position+Vector2(10,33),Vector2(card.size.x-20,3)),Color("#38212b"))
				draw_rect(Rect2(card.position+Vector2(10,33),Vector2((card.size.x-20)*civ.get_recovery_project_progress(pname)/100.0,3)),GOOD)
			var selected_name := str(CIV_RECOVERY_PROJECTS[civilization_recovery_project_index])
			var project: Dictionary = civ.recovery_projects[selected_name]
			draw_string(ThemeDB.fallback_font,Vector2(left,top+263),"Selected: "+selected_name,HORIZONTAL_ALIGNMENT_LEFT,max_width,12,GOOD)
			var needs := PackedStringArray()
			for item in project["cost"].keys():
				needs.append(str(item).capitalize()+" "+str(project["contributed"].get(item,0))+"/"+str(project["cost"][item]))
			draw_string(ThemeDB.fallback_font,Vector2(left,top+289),"Contributed: "+", ".join(needs),HORIZONTAL_ALIGNMENT_LEFT,max_width,11,MUTED)
			draw_string(ThemeDB.fallback_font,Vector2(left,top+314),"Select a project above, then click Contribute.",HORIZONTAL_ALIGNMENT_LEFT,max_width,11,TEXT)
		4:
			draw_string(ThemeDB.fallback_font,Vector2(left,top),"REGIONAL GOVERNMENT POLICY",HORIZONTAL_ALIGNMENT_LEFT,max_width,15,TEXT)
			draw_string(ThemeDB.fallback_font,Vector2(left,top+27),"These rules affect all future communities.",HORIZONTAL_ALIGNMENT_LEFT,max_width,11,MUTED)
			var labels := ["Autonomy","Freight","Security"]
			var keys := ["autonomy","freight","security"]
			for i in range(3):
				var py := top+64.0+float(i)*44.0
				draw_rect(Rect2(left,py-15.0,max_width,37),Color("#21151e"))
				draw_string(ThemeDB.fallback_font,Vector2(left+11,py+1),labels[i],HORIZONTAL_ALIGNMENT_LEFT,170,12,TEXT)
				draw_string(ThemeDB.fallback_font,Vector2(left+190,py+1),str(civ.civilization_policies[keys[i]]),HORIZONTAL_ALIGNMENT_LEFT,max_width-206,12,GOOD)
			draw_string(ThemeDB.fallback_font,Vector2(left,top+211),"FEDERAL COUNCIL  /  ACTUAL NETWORK",HORIZONTAL_ALIGNMENT_LEFT,max_width,12,ACCENT)
			draw_string(ThemeDB.fallback_font,Vector2(left,top+239),"Legitimacy %.0f%%  •  Cohesion %.0f%%  •  Reserve %.0f credits" % [fed.federal_legitimacy,fed.network_cohesion,fed.federal_treasury],HORIZONTAL_ALIGNMENT_LEFT,max_width,11,TEXT)
			draw_string(ThemeDB.fallback_font,Vector2(left,top+266),"Representation: "+str(fed.charter["representation"]),HORIZONTAL_ALIGNMENT_LEFT,max_width,11,MUTED)
			draw_string(ThemeDB.fallback_font,Vector2(left,top+286),"Contributions: "+str(fed.charter["contribution"]),HORIZONTAL_ALIGNMENT_LEFT,max_width,11,MUTED)
			draw_string(ThemeDB.fallback_font,Vector2(left,top+306),"Citizen rights: "+str(fed.charter["rights"]),HORIZONTAL_ALIGNMENT_LEFT,max_width,11,MUTED)
			draw_string(ThemeDB.fallback_font,Vector2(left,top+329),"Federal reserve is for communities in emergencies only.",HORIZONTAL_ALIGNMENT_LEFT,max_width,11,WARN)
		5:
			draw_string(ThemeDB.fallback_font,Vector2(left,top),"SURVIVOR MIGRATION ROSTER",HORIZONTAL_ALIGNMENT_LEFT,max_width,15,TEXT)
			draw_string(ThemeDB.fallback_font,Vector2(left,top+25),"Choose four adults to settle a cleared regional site.",HORIZONTAL_ALIGNMENT_LEFT,max_width,11,MUTED)
			draw_string(ThemeDB.fallback_font,Vector2(left,top+58),"Roster: %d / %d  •  Eligible residents: %d" % [civ.founding_roster.size(),civ.FOUNDING_POPULATION,candidates.size()],HORIZONTAL_ALIGNMENT_LEFT,max_width,13,GOOD)
			if candidates.is_empty():
				draw_string(ThemeDB.fallback_font,Vector2(left,top+94),"No eligible residents. Keep adults safe and at home.",HORIZONTAL_ALIGNMENT_LEFT,max_width,12,WARN)
			else:
				var candidate: Dictionary = candidates[civilization_candidate_index]
				var is_rostered := civ.founding_roster.has(int(candidate["id"]))
				draw_rect(Rect2(left,top+78,max_width,102),Color("#1e151e"))
				draw_string(ThemeDB.fallback_font,Vector2(left+12,top+108),"%d/%d  •  %s" % [civilization_candidate_index+1,candidates.size(),str(candidate["name"])],HORIZONTAL_ALIGNMENT_LEFT,max_width-24,15,TEXT)
				draw_string(ThemeDB.fallback_font,Vector2(left+12,top+131),"Job: %s    •    Age %d" % [str(candidate["job"]),int(candidate["age"])],HORIZONTAL_ALIGNMENT_LEFT,max_width-24,11,MUTED)
				draw_string(ThemeDB.fallback_font,Vector2(left+12,top+157),"Status: "+("SELECTED FOR MIGRATION" if is_rostered else "AVAILABLE"),HORIZONTAL_ALIGNMENT_LEFT,max_width-24,12,GOOD if is_rostered else WARN)
			draw_string(ThemeDB.fallback_font,Vector2(left,top+211),"After founding a colony, select it under Colonies.",HORIZONTAL_ALIGNMENT_LEFT,max_width,12,TEXT)
			draw_string(ThemeDB.fallback_font,Vector2(left,top+234),"Use Deploy to transfer the selected adult to that colony.",HORIZONTAL_ALIGNMENT_LEFT,max_width,11,MUTED)
			draw_string(ThemeDB.fallback_font,Vector2(left,top+269),"Founding supply cost: 35 materials, 20 meals, 30 water,",HORIZONTAL_ALIGNMENT_LEFT,max_width,11,WARN)
			draw_string(ThemeDB.fallback_font,Vector2(left,top+287),"4 machine parts and 4 available adults.",HORIZONTAL_ALIGNMENT_LEFT,max_width,11,WARN)

func _draw_faction_panel() -> void:
	var vp := get_viewport_rect().size
	var panel := SettlementUILayout.side_panel(vp,480.0)
	var x := panel.position.x
	var y := panel.position.y
	var w := panel.size.x
	var factions := sim.faction_simulation
	var visible := factions.get_visible_factions(sim)
	faction_index = clampi(faction_index,0,maxi(0,visible.size()-1))
	_draw_ui_panel(panel,ACCENT)
	draw_rect(Rect2(x+14,y+12,4,22),ACCENT)
	draw_string(ThemeDB.fallback_font,Vector2(x+26,y+30),"FACTIONS   /   REGIONAL DIPLOMACY",HORIZONTAL_ALIGNMENT_LEFT,w-39,17,TEXT)
	if visible.is_empty():
		var relay := sim.world_simulation.get_location_by_id(3)
		var restored := bool(relay.get("restored",false))
		var known := sim.world_simulation.get_discovered_locations().size()
		draw_rect(Rect2(x+17,y+54,w-34,94),Color("#1c151f"))
		draw_rect(Rect2(x+17,y+54,4,94),WARN)
		draw_string(ThemeDB.fallback_font,Vector2(x+30,y+79),"NO NEIGHBORS IN RADIO RANGE",HORIZONTAL_ALIGNMENT_LEFT,w-60,14,WARN)
		draw_string(ThemeDB.fallback_font,Vector2(x+30,y+103),"Diplomacy begins after contact with other communities.",HORIZONTAL_ALIGNMENT_LEFT,w-62,11,TEXT)
		draw_string(ThemeDB.fallback_font,Vector2(x+30,y+125),"%d sites discovered  •  Radio range %.0f" % [known,sim.world_simulation.get_radio_range()],HORIZONTAL_ALIGNMENT_LEFT,w-60,11,MUTED)
		draw_string(ThemeDB.fallback_font,Vector2(x+20,y+188),"HOW TO MAKE CONTACT",HORIZONTAL_ALIGNMENT_LEFT,w-40,13,ACCENT)
		draw_string(ThemeDB.fallback_font,Vector2(x+22,y+224),"01    Open Region and select North Ridge Relay.",HORIZONTAL_ALIGNMENT_LEFT,w-44,12,TEXT)
		draw_string(ThemeDB.fallback_font,Vector2(x+22,y+255),"02    Dispatch a salvage team to restore the relay.",HORIZONTAL_ALIGNMENT_LEFT,w-44,12,TEXT)
		draw_string(ThemeDB.fallback_font,Vector2(x+22,y+286),"03    Wait for the team to finish its mission.",HORIZONTAL_ALIGNMENT_LEFT,w-44,12,TEXT)
		DPNUISkin.stroke(self,Vector2(x+20,y+313),Vector2(panel.end.x-18,y+313),Color("#673b47"),1.0)
		draw_string(ThemeDB.fallback_font,Vector2(x+21,y+344),"RELAY STATUS",HORIZONTAL_ALIGNMENT_LEFT,w-40,12,ACCENT)
		draw_string(ThemeDB.fallback_font,Vector2(x+21,y+370),"North Ridge Relay: "+("ONLINE" if restored else "AWAITING REPAIRS"),HORIZONTAL_ALIGNMENT_LEFT,w-40,13,GOOD if restored else WARN)
		draw_string(ThemeDB.fallback_font,Vector2(x+21,y+393),"The restored relay extends radio coverage by 140 units.",HORIZONTAL_ALIGNMENT_LEFT,w-40,11,MUTED)
		draw_string(ThemeDB.fallback_font,Vector2(x+21,y+432),"Use FIND RELAY below to select the actual site.",HORIZONTAL_ALIGNMENT_LEFT,w-40,12,GOOD)
		# Read-only live radio status fills the unused command canvas.
		if panel.size.y>=550.0:
			var card_y := y+449.0
			var card_w := (w-47.0)/3.0
			var active_teams := sim.world_simulation.get_active_expeditions().size()
			var readings := [
				["SITES",str(known),"Mapped"],
				["FIELD TEAMS",str(active_teams),"Deployed"],
				["RELAY","ONLINE" if restored else "OFFLINE","North Ridge"]
			]
			for metric_i in range(readings.size()):
				var reading: Array=readings[metric_i]
				DPNUISkin.metric_card(self,Rect2(x+17.0+float(metric_i)*(card_w+6.0),card_y,card_w,52.0),str(reading[0]),str(reading[1]),str(reading[2]),metric_i==2 and not restored)
		return
	var count := visible.size()
	var gap := 5.0
	var tab_width := (w-35.0-gap*float(count-1))/float(count)
	for idx in range(count):
		var box := Rect2(x+17.0+float(idx)*(tab_width+gap),y+48.0,tab_width,34.0)
		var active := idx==faction_index
		DPNUISkin.button(self,box,str(visible[idx]),box.has_point(get_local_mouse_position()),active,false,true,true)
	var faction_name := str(visible[faction_index])
	var info: Dictionary = factions.factions[faction_name]
	var location: Dictionary = sim.world_simulation.get_location_by_id(int(info["location_id"]))
	var disposition := str(info["disposition"])
	var friendly := disposition in ["FRIENDLY","ALLIED"]
	var attitude := GOOD if friendly else (BAD if disposition=="HOSTILE" else WARN)
	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+112),faction_name,HORIZONTAL_ALIGNMENT_LEFT,w-42,19,TEXT)
	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+135),str(location.get("name","Regional community"))+"  •  "+disposition.capitalize(),HORIZONTAL_ALIGNMENT_LEFT,w-43,12,attitude)
	_draw_meter(Vector2(x+20,y+161),w-40.0,"REPUTATION",clampf((float(info["reputation"])+100.0)*0.5,0.0,100.0))
	_draw_meter(Vector2(x+20,y+202),w-40.0,"STRENGTH",float(info["strength"]))
	_draw_meter(Vector2(x+20,y+243),w-40.0,"INFLUENCE / WEALTH",float(info["wealth"]))
	DPNUISkin.stroke(self,Vector2(x+20,y+282),Vector2(panel.end.x-18,y+282),Color("#673b47"),1)
	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+307),"TRADE AGREEMENT: "+("ACTIVE" if bool(info["trade_agreement"]) else "NOT SIGNED"),HORIZONTAL_ALIGNMENT_LEFT,w-40,12,GOOD if bool(info["trade_agreement"]) else MUTED)
	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+333),"SEND AID: 8 food + 2 medicine  •  +9 reputation",HORIZONTAL_ALIGNMENT_LEFT,w-40,11,TEXT)
	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+354),"TRADE: needs reputation 30 or higher.",HORIZONTAL_ALIGNMENT_LEFT,w-40,11,MUTED)
	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+375),"TRUCE: hostile factions only, costs 25 credits.",HORIZONTAL_ALIGNMENT_LEFT,w-40,11,MUTED)
	if not factions.active_raid.is_empty():
		draw_string(ThemeDB.fallback_font,Vector2(x+20,y+413),"ACTIVE RAID: "+str(factions.active_raid.get("faction","Unknown")),HORIZONTAL_ALIGNMENT_LEFT,w-40,12,BAD)
	else:
		draw_string(ThemeDB.fallback_font,Vector2(x+20,y+413),"NO CURRENT RAID ALERT",HORIZONTAL_ALIGNMENT_LEFT,w-40,12,GOOD)

func _draw_help_panel() -> void:
	var vp := get_viewport_rect().size
	var rect := SettlementUILayout.guide_rect(vp)
	var w := rect.size.x
	var h := rect.size.y
	var x := rect.position.x
	var y := rect.position.y
	_draw_ui_panel(rect,ACCENT)
	draw_string(ThemeDB.fallback_font,Vector2(x+23,y+29),"FIELD GUIDE   /   HOW TO PLAY",HORIZONTAL_ALIGNMENT_LEFT,w-48,18,TEXT)
	draw_string(ThemeDB.fallback_font,Vector2(x+23,y+51),"Every command below works through a real simulation system.",HORIZONTAL_ALIGNMENT_LEFT,w-46,12,GOOD)
	var lessons := [
		["01  SURVIVE","Food and water sustain your people.","Power shortages drain the battery."],
		["02  CONSTRUCT","Build opens categorized facility plans.","Click terrain to build. Q/E browse; F rotates."],
		["03  EXPLORE","Region shows discovered sites and their risks.","Select a site and dispatch a salvage team."],
		["04  GOVERN & ALLIES","Change real civic laws in Govern.","Factions appear after radio contact."],
		["05  PRODUCE","Industry trades actual goods and credits.","Choose recipes and add workshop orders."],
		["06  EXPAND THE NATION","Six tabs manage colonies, routes and policy.","Salvage a ruin before founding a settlement."]
	]
	for i in range(lessons.size()):
		var box := SettlementUILayout.guide_lesson_rect(vp,i)
		var hover := box.has_point(get_local_mouse_position())
		DPNUISkin.list_row(self,box,false,hover)
		draw_string(ThemeDB.fallback_font,box.position+Vector2(12,24),str(lessons[i][0]),HORIZONTAL_ALIGNMENT_LEFT,box.size.x-24,13,TEXT)
		draw_string(ThemeDB.fallback_font,box.position+Vector2(12,50),str(lessons[i][1]),HORIZONTAL_ALIGNMENT_LEFT,box.size.x-24,11,MUTED)
		draw_string(ThemeDB.fallback_font,box.position+Vector2(12,72),str(lessons[i][2]),HORIZONTAL_ALIGNMENT_LEFT,box.size.x-24,11,GOOD)
		draw_string(ThemeDB.fallback_font,box.position+Vector2(12,box.size.y-7),"CLICK TO OPEN  ›",HORIZONTAL_ALIGNMENT_LEFT,box.size.x-22,9,GOOD if hover else MUTED)
	draw_rect(Rect2(x+17,y+h-46,w-34,31),DPNUISkin.SURFACE)
	DPNUISkin.stroke(self,Vector2(x+18,y+h-46),Vector2(x+w-18,y+h-46),ACCENT,1)
	draw_string(ThemeDB.fallback_font,Vector2(x+27,y+h-25),"SPACE PAUSE   F7 UI ZOOM   S SAVE   L LOAD   F8 CAPTURE   ESC CLOSE",HORIZONTAL_ALIGNMENT_LEFT,w-54,11,TEXT)

func _open_guide_section(index: int) -> void:
	# Tutorial modules are entry points into live gameplay, not passive text.
	help_mode=false
	update_mode=false
	overview_visible=false
	build_mode=false
	world_map_mode=false
	governance_mode=false
	economy_mode=false
	faction_mode=false
	civilization_mode=false
	selected_citizen={}
	selected_building={}
	selected_blueprint={}
	match index:
		0:
			overview_visible=true
		1:
			build_mode=true
			_set_build_category("ALL")
		2:
			world_map_mode=true
		3:
			governance_mode=true
		4:
			economy_mode=true
		5:
			civilization_mode=true
			civilization_tab=0
	playtest_notice="OPENED "+["SURVIVAL OVERVIEW","CONSTRUCTION","REGION MAP","GOVERNANCE","INDUSTRY","NATION"][index]
	playtest_notice_seconds=4.0

func _handle_guide_click(point: Vector2) -> bool:
	var vp := get_viewport_rect().size
	if not SettlementUILayout.guide_rect(vp).has_point(point):
		return true
	for index in range(6):
		if SettlementUILayout.guide_lesson_rect(vp,index).has_point(point):
			_open_guide_section(index)
			return true
	return true

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
		DPNUISkin.list_row(self,row,active,row.has_point(get_local_mouse_position()))
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
	draw_string(ThemeDB.fallback_font,Vector2(x+20,y+485),"Unresolved justice cases: %d" % _open_case_count(),HORIZONTAL_ALIGNMENT_LEFT,w-40,11,MUTED)
	# An actual council breakdown, based on survivor civic affiliations, fills
	# the command canvas that used to be empty under the law list.
	if area.size.y>=670.0:
		draw_string(ThemeDB.fallback_font,Vector2(x+20,y+517),"COUNCIL REPRESENTATION  /  ACTIVE RESIDENTS",HORIZONTAL_ALIGNMENT_LEFT,w-40,12,ACCENT)
		var faction_names := ["Rebuilders","Common Voice","Watchkeepers","Free Settlers"]
		var represented := 0.0
		for faction_name in faction_names:
			represented+=float(gov.factions[faction_name].get("support",0.0))
		for i in range(faction_names.size()):
			var key := str(faction_names[i])
			var rect := Rect2(x+18.0+float(i%2)*(w-31.0)*0.5,y+533.0+float(int(i/2))*45.0,(w-45.0)*0.5,41.0)
			DPNUISkin.list_row(self,rect,false,false)
			var supporters := int(gov.factions[key].get("support",0.0))
			draw_string(ThemeDB.fallback_font,rect.position+Vector2(9,16),key,HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-18.0,11,TEXT)
			draw_string(ThemeDB.fallback_font,Vector2(rect.end.x-10.0,rect.position.y+16.0),str(supporters),HORIZONTAL_ALIGNMENT_RIGHT,26.0,12,GOOD)
			DPNUISkin.meter(self,Rect2(rect.position+Vector2(10.0,rect.size.y-8.0),Vector2(rect.size.x-20.0,4.0)),float(supporters)/maxf(1.0,represented),ACCENT)

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
	# Every gameplay menu is built on this shared real DPN panel surface.
	DPNUISkin.frame(self,rect,ui_animation_clock,edge==ACCENT)

func _display_settlement_name() -> String:
	# Old saves may contain internal SITE-01 tags. Only present the readable
	# name without rewriting the original persisted value.
	return str(sim.settlement_name).split(" // ")[0].to_lower().capitalize()

func _draw_hud() -> void:
	var vp := get_viewport_rect().size
	var top_h := SettlementUILayout.TOP_H
	draw_rect(Rect2(0,0,vp.x,top_h),Color("#07070cf5"))
	draw_rect(Rect2(0,0,vp.x,3),Color("#771927"))
	DPNUISkin.stroke(self,Vector2(0,top_h-1),Vector2(vp.x,top_h-1),ACCENT,1.5)
	DPNUISkin.stroke(self,Vector2(0,top_h-4),Vector2(vp.x,top_h-4),Color("#4b1b2a",0.8),1.0)
	var identity := SettlementUILayout.identity_rect(vp)
	var is_hovered := identity.has_point(get_local_mouse_position())
	var badge := Rect2(identity.position+Vector2(3,6),Vector2(37,38))
	DPNUISkin.button(self,badge,"",is_hovered,false,false,true,true)
	# Red-lightning signature is real vector art, not an emoji or stock icon.
	var bolt := PackedVector2Array([badge.position+Vector2(24,4),badge.position+Vector2(14,17),badge.position+Vector2(23,17),badge.position+Vector2(12,33),badge.position+Vector2(16,21),badge.position+Vector2(10,21)])
	for part in range(bolt.size()-1):
		DPNUISkin.stroke(self,bolt[part],bolt[part+1],ACCENT,2.0)
	draw_string(ThemeDB.fallback_font,badge.position+Vector2(4,35),"01",HORIZONTAL_ALIGNMENT_LEFT,16,8,MUTED)
	draw_string(ThemeDB.fallback_font,identity.position+Vector2(46,22),"DPN // THE LAST SETTLEMENT" if vp.x>=1100 else "DPN // LAST SETTLEMENT",HORIZONTAL_ALIGNMENT_LEFT,identity.size.x-50,14 if vp.x>=1100 else 11,TEXT)
	draw_string(ThemeDB.fallback_font,identity.position+Vector2(46,39),"LAST HAVEN   /   COMMAND" if vp.x>=1000 else "RECOVERY COMMAND",HORIZONTAL_ALIGNMENT_LEFT,identity.size.x-50,10,ACCENT if is_hovered else MUTED)
	if is_hovered:
		DPNUISkin.stroke(self,Vector2(identity.position.x+45,identity.end.y-2),Vector2(identity.end.x-6,identity.end.y-2),ACCENT,1.0)

	var alive := sim.get_alive_citizens().size()
	var morale := sim.get_average_morale()
	var resources := [
		["PEOPLE", str(alive), float(alive)/24.0, "Click to assign jobs, shifts and duties in Workforce."],
		["FOOD", "%.0f" % float(sim.resources["food"]), float(sim.resources["food"])/maxf(1.0, float(alive)*25.0), "Stored food. Click to build a crop field."],
		["WATER", "%.0f" % float(sim.resources["water"]), float(sim.resources["water"])/maxf(1.0,float(alive)*24.0), "Clean water available. Click to build a purifier."],
		["POWER", "%.0f / %.0f" % [float(sim.utility_state["power_generated"]),float(sim.utility_state["power_demand"])], float(sim.utility_state["power_generated"])/maxf(1.0,float(sim.utility_state["power_demand"])), "Actual power supply vs demand. Click to build a generator."],
		["MEALS", "%.0f" % float(sim.resources["meals"]), float(sim.resources["meals"])/maxf(1.0,float(alive)*2.0), "Prepared food ready for consumption"],
		["MORALE", "%.0f%%" % morale, morale/100.0, "Average confidence and satisfaction"]
	]
	var resource_rects := SettlementUILayout.resource_rects(vp)
	var hovered := -1
	for i in range(resources.size()):
		var rect: Rect2 = resource_rects[i]
		var item: Array = resources[i]
		var fraction := clampf(float(item[2]),0.0,1.0)
		var severity := (WARN if fraction >= 0.85 else BAD) if i == 3 and fraction < 1.0 else (BAD if fraction < 0.20 else (WARN if fraction < 0.40 else GOOD))
		var hovered_now := rect.has_point(get_local_mouse_position())
		if hovered_now:
			hovered=i
		DPNUISkin.resource(self,rect,str(item[0]),str(item[1]),fraction,severity,hovered_now)
	var battery_percent := 100.0*float(sim.utility_state["battery_charge"])/maxf(1.0,float(sim.utility_state["battery_capacity"]))
	var weather_name := sim.weather_simulation.condition
	var summary := "Day %d  •  %02d:%02d  |  Weather: %s  |  Materials: %.0f  |  Projects: %d  |  Battery: %.0f%%" % [sim.day,int(sim.hour),int((sim.hour-floor(sim.hour))*60.0),weather_name,float(sim.resources["materials"]),sim.blueprints.size(),battery_percent]
	if vp.x >= 1120.0:
		summary = "Day %d  •  %02d:%02d  |  Weather: %s  |  Materials: %.0f  |  Projects: %d  |  Power: %.0f / %.0f  |  Battery: %.0f%%" % [sim.day,int(sim.hour),int((sim.hour-floor(sim.hour))*60.0),weather_name,float(sim.resources["materials"]),sim.blueprints.size(),float(sim.utility_state["power_generated"]),float(sim.utility_state["power_demand"]),battery_percent]
	elif vp.x < 920.0:
		summary = "Day %d  •  %02d:%02d  |  %s  |  Projects: %d" % [sim.day,int(sim.hour),int((sim.hour-floor(sim.hour))*60.0),weather_name,sim.blueprints.size()]
	draw_string(ThemeDB.fallback_font,Vector2(15,69),summary,HORIZONTAL_ALIGNMENT_LEFT,vp.x-175,11,MUTED)
	var attention := _settlement_attention()
	var warning := Rect2(vp.x-158,54.0,154.0,24.0)
	DPNUISkin.button(self,warning,str(attention[0]),warning.has_point(get_local_mouse_position()),false,str(attention[0]) in ["STORM: TAKE COVER","NO SURVIVORS","POWER SHORTFALL","CHECK FOOD","CHECK WATER"],true,true)

	if selected_citizen.is_empty() and selected_building.is_empty() and not build_mode and not world_map_mode and not governance_mode and not economy_mode and not faction_mode and not civilization_mode and not help_mode and not update_mode:
		if incident_panel_visible:
			_draw_event_panel()
		else:
			_draw_event_toasts()

	var hint := "DRAG PAN  •  ALT+DRAG ORBIT  •  SCROLL ZOOM  •  SPACE PAUSE  •  F8 SCREENSHOT"
	var hover_help := ["Build real structures", "Select sites and dispatch salvage teams", "Set laws for your people", "Trade and manage production", "Talk to discovered neighbors", "Manage regional expansion", "Save your progress", "Load your progress", "Learn how to play"]
	for index in range(TOOLBAR_NAMES.size()):
		if SettlementUILayout.navbar_rect(vp,index).has_point(get_local_mouse_position()):
			hint = hover_help[index]
			break
	if build_mode and not SettlementUILayout.navbar_rect(vp,0).has_point(get_local_mouse_position()):
		var definition := sim.get_build_catalog()[build_catalog_index]
		hint = "BUILDING %s  •  Q/E SELECT  •  F ROTATE  •  CLICK TO PLACE" % str(definition["name"]).to_upper()
	draw_rect(Rect2(0,vp.y-SettlementUILayout.BOTTOM_H,vp.x,SettlementUILayout.BOTTOM_H),Color("#08080deb"))
	DPNUISkin.stroke(self,Vector2(0,vp.y-SettlementUILayout.BOTTOM_H),Vector2(vp.x,vp.y-SettlementUILayout.BOTTOM_H),ACCENT,1.4)
	DPNUISkin.backdrop(self,vp,ui_animation_clock)
	draw_string(ThemeDB.fallback_font,Vector2(13,vp.y-45),hint,HORIZONTAL_ALIGNMENT_LEFT,vp.x-270,11,MUTED)
	_draw_time_controls()
	_draw_toolbar()
	if hovered >= 0:
		var source: Array = resources[hovered]
		var card: Rect2 = resource_rects[hovered]
		var tooltip_width := 300.0
		var tooltip_x := clampf(card.position.x,10.0,maxf(10.0,vp.x-tooltip_width-10))
		var tooltip := Rect2(tooltip_x,top_h+8.0,tooltip_width,48.0)
		DPNUISkin.frame(self,tooltip,ui_animation_clock,false)
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
	# A storm can directly cause the power warning. Keep shelter reachable
	# instead of hiding the player decision behind the consequence.
	if sim.weather_simulation.condition==WeatherSimulation.DUST_STORM:
		return ["SHELTER ACTIVE" if sim.weather_simulation.shelter_in_place else "STORM: TAKE COVER", WARN if sim.weather_simulation.shelter_in_place else BAD]
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
	_draw_ui_panel(area,ACCENT)
	var left := area.position.x+17.0
	var full_width := area.size.x-34.0
	var top := area.position.y
	draw_string(ThemeDB.fallback_font,Vector2(left,top+29),"YOUR SETTLEMENT",HORIZONTAL_ALIGNMENT_LEFT,full_width,17,TEXT)
	draw_string(ThemeDB.fallback_font,Vector2(left,top+49),"%s  •  Home base" % _display_settlement_name(),HORIZONTAL_ALIGNMENT_LEFT,full_width,11,GOOD)
	draw_string(ThemeDB.fallback_font,Vector2(left,top+68),"Day %d   |   %02d:%02d   |   %s" % [sim.day,int(sim.hour),int((sim.hour-floor(sim.hour))*60.0),"Paused" if sim.paused else "Simulation running"],HORIZONTAL_ALIGNMENT_LEFT,full_width,11,MUTED)
	DPNUISkin.stroke(self,Vector2(left,top+79),Vector2(area.end.x-17,top+79),Color("#603644"),1.0)
	var complete := 0
	for value in sim.field_objectives.values():
		if bool(value):
			complete += 1
	draw_string(ThemeDB.fallback_font,Vector2(left,top+100),"YOUR NEXT STEP  •  %d/4 goals completed" % complete,HORIZONTAL_ALIGNMENT_LEFT,full_width,11,WARN)
	draw_string(ThemeDB.fallback_font,Vector2(left,top+120),_next_settlement_goal(),HORIZONTAL_ALIGNMENT_LEFT,full_width,10,TEXT)
	DPNUISkin.stroke(self,Vector2(left,top+134),Vector2(area.end.x-17,top+134),Color("#432734"),1.0)
	draw_string(ThemeDB.fallback_font,Vector2(left,top+154),"SUPPLIES & BUILDING",HORIZONTAL_ALIGNMENT_LEFT,full_width,11,GOOD)
	draw_string(ThemeDB.fallback_font,Vector2(left,top+174),"Building materials: %.0f" % float(sim.resources["materials"]),HORIZONTAL_ALIGNMENT_LEFT,full_width,11,TEXT)
	draw_string(ThemeDB.fallback_font,Vector2(left,top+193),"Projects being built: %d    |    Rooms finished: %d" % [sim.blueprints.size(),sim.completed_rooms],HORIZONTAL_ALIGNMENT_LEFT,full_width,11,TEXT)
	DPNUISkin.stroke(self,Vector2(left,top+208),Vector2(area.end.x-17,top+208),Color("#432734"),1.0)
	draw_string(ThemeDB.fallback_font,Vector2(left,top+228),"ESSENTIAL SYSTEMS",HORIZONTAL_ALIGNMENT_LEFT,full_width,11,GOOD)
	var power_available := float(sim.utility_state["power_generated"])
	var power_needed := float(sim.utility_state["power_demand"])
	var power_ok := power_available>=power_needed
	draw_string(ThemeDB.fallback_font,Vector2(left,top+248),"Electricity: %.0f available / %.0f needed" % [power_available,power_needed],HORIZONTAL_ALIGNMENT_LEFT,full_width,11,GOOD if power_ok else WARN)
	var charge := 100.0*float(sim.utility_state["battery_charge"])/maxf(1.0,float(sim.utility_state["battery_capacity"]))
	draw_string(ThemeDB.fallback_font,Vector2(left,top+268),"Battery charge: %.0f%%    |    Sanitation: %.0f%%" % [charge,float(sim.utility_state["sanitation"])],HORIZONTAL_ALIGNMENT_LEFT,full_width,11,TEXT)
	if area.size.y>350.0:
		DPNUISkin.stroke(self,Vector2(left,top+283),Vector2(area.end.x-17,top+283),Color("#432734"),1.0)
		var weather := sim.weather_simulation
		if weather.condition==WeatherSimulation.DUST_STORM:
			draw_string(ThemeDB.fallback_font,Vector2(left,top+303),"DUST FRONT: %.1fh remaining  /  %.0f%% strength" % [weather.remaining_hours(sim),weather.intensity*100.0],HORIZONTAL_ALIGNMENT_LEFT,full_width,11,WARN)
			draw_string(ThemeDB.fallback_font,Vector2(left,top+319),"Click upper-right STORM alert to toggle shelter order.",HORIZONTAL_ALIGNMENT_LEFT,full_width,10,GOOD if weather.shelter_in_place else WARN)
		else:
			draw_string(ThemeDB.fallback_font,Vector2(left,top+303),"Weather: clear  /  forecast front in %.0fh" % weather.remaining_hours(sim),HORIZONTAL_ALIGNMENT_LEFT,full_width,10,MUTED)
			draw_string(ThemeDB.fallback_font,Vector2(left,top+319),"Select people and structures to inspect them.",HORIZONTAL_ALIGNMENT_LEFT,full_width,10,MUTED)
	var buttons := ["OPEN BUILD", "SHOW GOALS", "CLOSE"]
	for index in range(buttons.size()):
		var rect := SettlementUILayout.overview_button_rect(vp,index)
		var over := rect.has_point(get_local_mouse_position())
		DPNUISkin.button(self,rect,buttons[index],over,false,index==2,true,true)

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
	draw_string(ThemeDB.fallback_font,rect.position+Vector2(20,23),"CONSTRUCTION  /  BUILD MENU",HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-29,16,TEXT)
	draw_string(ThemeDB.fallback_font,rect.position+Vector2(12,48),"Available materials: %.0f   •   %d projects queued" % [float(sim.stockpiles["industry"].get("materials",0.0)),sim.blueprints.size()],HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-23,11,MUTED)
	for j in range(SettlementCommandCatalog.CATEGORIES.size()):
		var box := SettlementUILayout.build_category_rect(vp,j)
		var category := str(SettlementCommandCatalog.CATEGORIES[j])
		var active := category == build_category
		var hover := box.has_point(get_local_mouse_position())
		DPNUISkin.button(self,box,category,hover,active,false,true,true)
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
		DPNUISkin.list_row(self,box,active,box.has_point(get_local_mouse_position()))
		draw_string(ThemeDB.fallback_font,box.position+Vector2(11,21),str(entry["name"]),HORIZONTAL_ALIGNMENT_LEFT,box.size.x-94,13,TEXT if affordable else MUTED)
		draw_string(ThemeDB.fallback_font,box.position+Vector2(box.size.x-85,21),"%.0f MAT" % float(entry["cost"]),HORIZONTAL_ALIGNMENT_LEFT,80,12,GOOD if affordable else BAD)
	var selected: Dictionary = catalog[build_catalog_index]
	var divider_y := rect.end.y-108.0
	DPNUISkin.stroke(self,Vector2(rect.position.x+12,divider_y),Vector2(rect.end.x-12,divider_y),Color("#58616a"),1)
	draw_string(ThemeDB.fallback_font,Vector2(rect.position.x+13,divider_y+20),str(selected["name"]).to_upper()+"  /  "+str(selected["capacity"])+" CAPACITY",HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-26,12,TEXT)
	draw_string(ThemeDB.fallback_font,Vector2(rect.position.x+13,divider_y+38),SettlementCommandCatalog.purpose(str(selected["type"])),HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-26,10,MUTED)
	draw_string(ThemeDB.fallback_font,Vector2(rect.position.x+13,divider_y+55),"Cost: %.0f materials   •   Build effort: %.0f" % [float(selected["cost"]),float(selected["work"])],HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-26,10,GOOD)
	for idx in range(2):
		var action_rect := SettlementUILayout.build_action_rect(vp,idx)
		var can_rotate := SettlementCommandCatalog.rotate_allowed(str(selected["type"]))
		var action_name := ("ROTATE [F]" if can_rotate else "FIXED SHAPE") if idx == 0 else "DONE [ESC]"
		var usable := idx != 0 or can_rotate
		DPNUISkin.button(self,action_rect,action_name,action_rect.has_point(get_local_mouse_position()),false,idx==1,usable,true)

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

func _open_building_from_status(build_type: String) -> void:
	if not build_mode:
		_handle_toolbar_click(SettlementUILayout.navbar_rect(get_viewport_rect().size,0).get_center())
	var catalog := sim.get_build_catalog()
	for i in range(catalog.size()):
		if str(catalog[i]["type"])==build_type:
			_set_build_category(SettlementCommandCatalog.category_for(build_type))
			build_catalog_index = i
			break
	playtest_notice = "BUILD MENU OPEN  /  SELECT TERRAIN TO PLACE "+str(catalog[build_catalog_index]["name"]).to_upper()
	playtest_notice_seconds = 5.0

func _handle_resource_chip_click(position: Vector2) -> bool:
	var vp := get_viewport_rect().size
	# The actual warning strip is also interactive: power shortage opens a
	# generator blueprint; the player never has to guess which menu to use.
	if Rect2(vp.x-158,54.0,154.0,24.0).has_point(position):
		match str(_settlement_attention()[0]):
			"CHECK WATER":
				_open_building_from_status("purifier")
			"CHECK FOOD":
				_open_building_from_status("farm")
			"POWER SHORTFALL":
				_open_building_from_status("generator")
			"NO SURVIVORS":
				_toggle_workforce()
			"STORM: TAKE COVER","SHELTER ACTIVE":
				var storm := sim.weather_simulation
				if storm.set_shelter_order(sim,not storm.shelter_in_place):
					playtest_notice="SHELTER ORDER ISSUED  /  FIELD TEAMS TAKE COVER" if storm.shelter_in_place else "SHELTER ORDER RELEASED"
					playtest_notice_seconds=5.0
			_:
				return false
		return true
	var cards := SettlementUILayout.resource_rects(vp)
	for i in range(cards.size()):
		if not cards[i].has_point(position):
			continue
		match i:
			0:
				_toggle_workforce()
			4:
				overview_visible = true
			1:
				_open_building_from_status("farm")
			2:
				_open_building_from_status("purifier")
			3:
				_open_building_from_status("generator")
			5:
				if not governance_mode:
					_handle_toolbar_click(SettlementUILayout.navbar_rect(vp,2).get_center())
		return true
	return false

func _draw_time_controls() -> void:
	var vp := get_viewport_rect().size
	var labels := ["RESUME" if sim.paused else "PAUSE","1x","4x","12x"]
	for i in range(4):
		var rect := SettlementUILayout.time_control(vp,i)
		var active := (i==0 and sim.paused) or (i>0 and not sim.paused and is_equal_approx(sim.speed,[0.0,1.0,4.0,12.0][i]))
		var hover := rect.has_point(get_local_mouse_position())
		DPNUISkin.button(self,rect,str(labels[i]),hover,active,false,true,true)

func _handle_time_control_click(position: Vector2) -> bool:
	var vp := get_viewport_rect().size
	for i in range(4):
		if not SettlementUILayout.time_control(vp,i).has_point(position):
			continue
		if i==0:
			sim.paused=not sim.paused
		else:
			sim.speed=[0.0,1.0,4.0,12.0][i]
			sim.paused=false
		return true
	return false

func _draw_toolbar() -> void:
	var vp := get_viewport_rect().size
	for i in range(TOOLBAR_NAMES.size()):
		var rect := SettlementUILayout.navbar_rect(vp,i)
		var active := false
		match i:
			0: active=build_mode
			1: active=world_map_mode
			2: active=governance_mode
			3: active=economy_mode
			4: active=faction_mode
			5: active=civilization_mode
			8: active=help_mode
		DPNUISkin.nav_station(self,rect,i,TOOLBAR_NAMES[i],TOOLBAR_HINTS[i],active,rect.has_point(get_local_mouse_position()))

func _handle_toolbar_click(position: Vector2) -> bool:
	var vp := get_viewport_rect().size
	for index in range(TOOLBAR_NAMES.size()):
		if not SettlementUILayout.navbar_rect(vp,index).has_point(position):
			continue
		workforce_mode = false
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
	DPNUISkin.frame(self,Rect2(left,y,309,106),ui_animation_clock)
	draw_string(ThemeDB.fallback_font, Vector2(left + 13, y + 23), "DPN  /  LIVE SETTLEMENT FEED    [F2]", HORIZONTAL_ALIGNMENT_LEFT, 289, 11, TEXT)
	for i in range(mini(2, sim.events.size())):
		var incident: Dictionary = sim.events[i]
		var color := GOOD if str(incident.get("severity", "")) == "good" else WARN
		if str(incident.get("severity", "")) == "critical":
			color = BAD
		var row_y := y + 39.0 + float(i) * 30.0
		draw_rect(Rect2(left+9,row_y-10,290,30),Color("#19131c"))
		draw_rect(Rect2(left+9,row_y-10,3,30),color)
		draw_circle(Vector2(left + 20, row_y), 2.5, color)
		draw_string(ThemeDB.fallback_font, Vector2(left + 29, row_y + 3), str(incident.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, 263, 11, TEXT)
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
	draw_string(ThemeDB.fallback_font,Vector2(x+18,y+385),"Manage job roles: PEOPLE metric or F6",HORIZONTAL_ALIGNMENT_LEFT,w-36,10,GOOD)
	var action_y := y + h - 57.0
	var labels := ["[T] SHIFT", "[P] PRIORITY", "[W] DUTY"]
	for i in range(3):
		var rx := x + 12.0 + float(i) * 112.0
		var assignment_rect := Rect2(rx,action_y,106,39)
		DPNUISkin.button(self,assignment_rect,labels[i],assignment_rect.has_point(get_local_mouse_position()),false,false,true,true)

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
	var cancel_project := Rect2(x+16,y+152,316,37)
	DPNUISkin.button(self,cancel_project,"CANCEL BLUEPRINT   /   75% REFUND",cancel_project.has_point(get_local_mouse_position()),false,true)

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
		for index in range(3):
			if SettlementUILayout.facility_action(vp,index).has_point(position):
				_apply_facility_action(index)
				return true
		return SettlementUILayout.facility_inspector(vp).has_point(position)
	return false

func _facility_repair_queued(b: Dictionary) -> bool:
	var name := "Repair "+str(b.get("name",""))
	for work in sim.work_orders:
		if str(work.get("title",""))==name and not bool(work.get("complete",false)):
			return true
	return false

func _facility_key(b: Dictionary) -> String:
	return str(b.get("name",""))+"@"+str(b.get("position",Vector2.ZERO))

func _apply_facility_action(index: int) -> bool:
	if selected_building.is_empty():
		return false
	var b := selected_building
	if index==0:
		pending_demolition_key = ""
		if float(b.get("condition",100.0))>=99.5:
			playtest_notice="FACILITY IS ALREADY IN GOOD CONDITION"
		elif _facility_repair_queued(b):
			playtest_notice="REPAIR REQUEST ALREADY IN WORK QUEUE"
		else:
			sim.queue_repair(b)
			playtest_notice="REPAIR REQUEST SENT TO BUILDERS"
		playtest_notice_seconds=5.0
		return true
	if index==1:
		if str(b.get("type",""))=="command":
			playtest_notice="COMMAND CENTER IS PROTECTED FROM DEMOLITION"
		elif pending_demolition_key!=_facility_key(b):
			pending_demolition_key=_facility_key(b)
			playtest_notice="CONFIRM SALVAGE BY CLICKING SALVAGE AGAIN"
		else:
			var name := str(b.get("name","Facility"))
			if sim.demolish_building(b):
				selected_building={}
				playtest_notice=name.to_upper()+" SALVAGED  /  MATERIALS RECOVERED"
			else:
				playtest_notice="SALVAGE COULD NOT BE COMPLETED"
			pending_demolition_key=""
		playtest_notice_seconds=6.0
		return true
	if index==2:
		selected_building={}
		pending_demolition_key=""
		return true
	return false

func _draw_building_panel(b: Dictionary) -> void:
	var vp := get_viewport_rect().size
	var bounds := SettlementUILayout.facility_inspector(vp)
	var x := bounds.position.x
	var y := bounds.position.y
	var w := bounds.size.x
	var h := bounds.size.y
	var condition := float(b.get("condition",100.0))
	var utility := str(b.get("utility",""))
	if utility=="":
		utility=str(b.get("type",""))
	var workers := 0
	for citizen in sim.get_settlement_citizens():
		if str(citizen.get("target_building",""))==str(b.get("type","")) and bool(citizen.get("alive",false)):
			workers += 1
	_draw_ui_panel(bounds,ACCENT)
	draw_rect(Rect2(x+14,y+13,4,21),ACCENT)
	draw_string(ThemeDB.fallback_font,Vector2(x+27,y+29),"FACILITY  /  BUILDING MANAGEMENT",HORIZONTAL_ALIGNMENT_LEFT,w-43,14,TEXT)
	draw_string(ThemeDB.fallback_font,Vector2(x+17,y+60),str(b["name"]),HORIZONTAL_ALIGNMENT_LEFT,w-34,20,TEXT)
	draw_string(ThemeDB.fallback_font,Vector2(x+18,y+83),"Type: "+str(b["type"]).capitalize()+"   •   Capacity: "+str(b.get("capacity",0)),HORIZONTAL_ALIGNMENT_LEFT,w-38,11,MUTED)
	_draw_meter(Vector2(x+18,y+111),w-36.0,"BUILDING CONDITION",condition)
	var is_damaged := condition<65.0
	draw_string(ThemeDB.fallback_font,Vector2(x+18,y+149),"Status: "+("Repairs needed" if is_damaged else "Operating"),HORIZONTAL_ALIGNMENT_LEFT,w-35,12,WARN if is_damaged else GOOD)
	draw_string(ThemeDB.fallback_font,Vector2(x+18,y+170),"Workers assigned: "+str(workers),HORIZONTAL_ALIGNMENT_LEFT,w-38,11,TEXT)
	var description := SettlementCommandCatalog.purpose(str(b["type"]))
	draw_string(ThemeDB.fallback_font,Vector2(x+18,y+193),description,HORIZONTAL_ALIGNMENT_LEFT,w-36,10,MUTED)
	var type_name := str(b["type"])
	if type_name in ["generator","power"]:
		draw_string(ThemeDB.fallback_font,Vector2(x+18,y+221),"Power supply: %.0f  /  Demand: %.0f" % [float(sim.utility_state["power_generated"]),float(sim.utility_state["power_demand"])],HORIZONTAL_ALIGNMENT_LEFT,w-36,10,GOOD if bool(sim.utility_state["power_online"]) else WARN)
	elif type_name in ["water","water_pump","purifier","water_tank"]:
		draw_string(ThemeDB.fallback_font,Vector2(x+18,y+221),"Clean water rate: %.1f per hour" % float(sim.utility_state["clean_water_rate"]),HORIZONTAL_ALIGNMENT_LEFT,w-36,10,TEXT)
	elif type_name=="sewage":
		draw_string(ThemeDB.fallback_font,Vector2(x+18,y+221),"Sanitation: %.0f%%" % float(sim.utility_state["sanitation"]),HORIZONTAL_ALIGNMENT_LEFT,w-36,10,TEXT)
	else:
		draw_string(ThemeDB.fallback_font,Vector2(x+18,y+221),"Facility supports settlement work and survival.",HORIZONTAL_ALIGNMENT_LEFT,w-36,10,TEXT)
	DPNUISkin.stroke(self,Vector2(x+15,y+238),Vector2(x+w-15,y+238),Color("#4f636b"),1)
	draw_string(ThemeDB.fallback_font,Vector2(x+18,y+260),"Maintenance: "+("REPAIR ORDER QUEUED" if _facility_repair_queued(b) else ("NEEDS ATTENTION" if condition<99.5 else "NO REPAIRS NEEDED")),HORIZONTAL_ALIGNMENT_LEFT,w-36,11,WARN if condition<70.0 else GOOD)
	if pending_demolition_key==_facility_key(b):
		draw_string(ThemeDB.fallback_font,Vector2(x+18,y+289),"CONFIRM SALVAGE  /  click again to demolish",HORIZONTAL_ALIGNMENT_LEFT,w-35,11,BAD)
	else:
		draw_string(ThemeDB.fallback_font,Vector2(x+18,y+289),"Manage this facility using the actions below.",HORIZONTAL_ALIGNMENT_LEFT,w-35,10,MUTED)
	var labels := ["REPAIR [R]","CONFIRM" if pending_demolition_key==_facility_key(b) else "SALVAGE [X]","CLOSE"]
	for index in range(3):
		var button := SettlementUILayout.facility_action(vp,index)
		var highlight := button.has_point(get_local_mouse_position())
		DPNUISkin.button(self,button,labels[index],highlight,pending_demolition_key==_facility_key(b) and index==1,index==1,true,true)

func _draw_meter(pos: Vector2, width: float, label: String, value: float) -> void:
	draw_string(ThemeDB.fallback_font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, 150, 10, MUTED)
	draw_string(ThemeDB.fallback_font, pos + Vector2(width-42,0), "%d%%" % int(clampf(value,0.0,100.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, TEXT)
	var bar_y := pos.y + 10.0
	DPNUISkin.meter(self,Rect2(pos.x,bar_y,width,8),value/100.0,ACCENT if value < 45.0 else GOOD)

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
	var capture_id := "last-settlement-%d" % int(Time.get_unix_time_from_system())
	var capture_path := target_folder.path_join(capture_id+"-FULL.png")
	if screenshot.save_png(capture_path) == OK:
		# A raw camera-pass capture isolates all 3D rendering from the DPN
		# canvas UI. If the streak is ONLY in FULL, isolate UI; if in both,
		# isolate engine/GPU. If neither, check Windows display/camera path.
		var world_saved := false
		if settlement_viewport!=null:
			var scene_img: Image=settlement_viewport.get_texture().get_image()
			if scene_img!=null and not scene_img.is_empty():
				world_saved=scene_img.save_png(target_folder.path_join(capture_id+"-3D.png"))==OK
		var record := FileAccess.open(target_folder.path_join(capture_id+"-GRAPHICS.txt"),FileAccess.WRITE)
		if record!=null:
			record.store_string("THE LAST SETTLEMENT // DISPLAY ARTIFACT DIAGNOSTIC\n"+
				"Default rendering method: "+str(ProjectSettings.get_setting("rendering/renderer/rendering_method","unknown"))+"\n"+
				"OS: "+OS.get_name()+"\n"+
				"Game frame: "+str(screenshot.get_size())+"\n"+
				"3D pass separately captured: "+str(world_saved)+"\n"+
				"FULL=3D+UI. 3D=scene-only. Check whether streaks exist in either PNG.\n")
		playtest_notice = "2 GRAPHICS CAPTURES SAVED [F8]" if world_saved else "GRAPHICS CAPTURE SAVED [F8]"
		if OS.get_name() == "Windows":
			OS.shell_open(absolute_dir)
	else:
		playtest_notice = "SCREENSHOT FAILED // DISK WRITE ERROR"
	playtest_notice_seconds = 7.0

# Scales Godot's canvas and its matching input coordinates together. A
# minimum usable logical viewport prevents zoom from breaking command menus.
func _cycle_ui_scale() -> void:
	var window := get_window()
	var physical := Vector2(DisplayServer.window_get_size())
	var next := (ui_scale_index+1)%UI_SCALE_LEVELS.size()
	var target := float(UI_SCALE_LEVELS[next])
	if physical.x/target<960.0 or physical.y/target<600.0:
		next=0
		target=1.0
	window.content_scale_factor=target
	ui_scale_index=next
	playtest_notice="INTERFACE SCALE  /  %d%%   [F7 CHANGE]" % int(round(target*100.0))
	playtest_notice_seconds=5.0
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# Workforce is modal: keyboard shortcuts cannot change hidden panels.
		if workforce_mode and event.keycode not in [KEY_F5,KEY_F6,KEY_F7,KEY_ESCAPE,KEY_F8,KEY_SPACE]:
			return
		match event.keycode:
			KEY_F6:
				_toggle_workforce()
			KEY_F7:
				_cycle_ui_scale()
			KEY_F5:
				settlement_minimap_visible=not settlement_minimap_visible
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
				world_map_mode = false
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
					var was_building := build_mode
					build_mode = not was_building
					world_map_mode = false
					governance_mode = false
					economy_mode = false
					faction_mode = false
					civilization_mode = false
					help_mode = false
					update_mode = false
					selected_citizen = {}
					selected_building = {}
					selected_blueprint = {}
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
				world_map_mode = false
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
					_apply_facility_action(0)
			KEY_X:
				if not selected_building.is_empty():
					_apply_facility_action(1)
			KEY_ESCAPE:
				if workforce_mode:
					workforce_mode=false
				elif pending_demolition_key!="":
					pending_demolition_key=""
				elif overview_visible:
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
				elif economy_mode and industry_workshop_visible:
					industry_workshop_visible = false
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
			if _handle_time_control_click(event.position):
				return
			if workforce_mode:
				_handle_workforce_click(event.position)
				return
			if _handle_overview_click(event.position):
				return
			if help_mode:
				_handle_guide_click(event.position)
				return
			if update_mode:
				return
			if _handle_resource_chip_click(event.position):
				return
			if _handle_minimap_click(event.position):
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
