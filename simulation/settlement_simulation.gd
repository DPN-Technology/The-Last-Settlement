class_name SettlementSimulation
extends RefCounted

const SAVE_VERSION := 1

var rng := RandomNumberGenerator.new()
var citizens: Array[Dictionary] = []
var resources := {
	"food": 240.0,
	"water": 300.0,
	"power": 76.0,
	"medicine": 28.0,
	"materials": 120.0,
	"scrap": 90.0,
	"meals": 12.0
}
var stockpiles := {
	"command": {"food": 100.0, "water": 120.0, "medicine": 18.0, "meals": 12.0},
	"industry": {"materials": 70.0, "scrap": 65.0},
	"farm": {"food": 140.0},
	"medical": {"medicine": 10.0}
}
var work_orders: Array[Dictionary] = []
var blueprints: Array[Dictionary] = []
var buildings: Array[Dictionary] = []
var events: Array[Dictionary] = []
var total_hours := 0.0
var day := 1
var hour := 7.0
var speed := 1.0
var paused := false
var next_citizen_id := 1
var next_work_order_id := 1
var next_blueprint_id := 1
var completed_rooms := 0
var event_director := EventDirector.new()
var settlement_name := "LAST HAVEN // SITE-01"

func _init() -> void:
	rng.randomize()
	_create_buildings()
	for i in range(12):
		add_citizen()
	_seed_work_orders()
	add_event("SETTLEMENT ONLINE", "Twelve survivors have established a temporary command camp.", "good")

func _create_buildings() -> void:
	buildings = [
		{"name":"Command","type":"command","position":Vector2(700,380),"size":Vector2(170,100),"condition":100.0,"capacity":12},
		{"name":"Shelter A","type":"housing","position":Vector2(465,295),"size":Vector2(150,90),"condition":86.0,"capacity":8},
		{"name":"Shelter B","type":"housing","position":Vector2(470,500),"size":Vector2(150,90),"condition":81.0,"capacity":8},
		{"name":"Workshop","type":"industry","position":Vector2(930,300),"size":Vector2(180,100),"condition":78.0,"capacity":6},
		{"name":"Clinic","type":"medical","position":Vector2(930,515),"size":Vector2(150,95),"condition":91.0,"capacity":4},
		{"name":"Farm","type":"farm","position":Vector2(705,620),"size":Vector2(250,105),"condition":74.0,"capacity":8},
		{"name":"Generator","type":"power","position":Vector2(1190,430),"size":Vector2(135,100),"condition":69.0,"capacity":4}
	]

func _seed_work_orders() -> void:
	add_work_order("Prepare emergency meals", "Cook", 35.0, 2)
	add_work_order("Sort salvage stock", "Hauler", 45.0, 3)
	add_work_order("Repair workshop benches", "Builder", 60.0, 2)

func add_work_order(title: String, job: String, work_required: float, priority: int = 3) -> void:
	work_orders.append({
		"id": next_work_order_id,
		"title": title,
		"job": job,
		"priority": priority,
		"progress": 0.0,
		"work_required": work_required,
		"complete": false
	})
	next_work_order_id += 1

func add_citizen() -> void:
	citizens.append(CitizenFactory.create(next_citizen_id, rng))
	next_citizen_id += 1

func get_build_catalog() -> Array[Dictionary]:
	return [
		{"type":"wall","name":"Wall","size":Vector2(40,12),"cost":4.0,"work":20.0,"capacity":0},
		{"type":"floor","name":"Floor","size":Vector2(40,40),"cost":3.0,"work":14.0,"capacity":0},
		{"type":"door","name":"Door","size":Vector2(40,12),"cost":5.0,"work":18.0,"capacity":0},
		{"type":"housing","name":"Shelter Module","size":Vector2(120,80),"cost":24.0,"work":85.0,"capacity":6},
		{"type":"storage","name":"Storage Module","size":Vector2(120,80),"cost":20.0,"work":70.0,"capacity":10}
	]

func get_build_definition(build_type: String) -> Dictionary:
	for item in get_build_catalog():
		if item["type"] == build_type:
			return item
	return get_build_catalog()[0]

func place_blueprint(build_type: String, world_position: Vector2) -> bool:
	var definition := get_build_definition(build_type)
	var snapped := Vector2(round(world_position.x / 20.0) * 20.0, round(world_position.y / 20.0) * 20.0)
	if not can_place_blueprint(snapped, definition["size"]):
		add_event("BUILD BLOCKED", "Construction site overlaps an existing structure.", "warning")
		return false
	var cost := float(definition["cost"])
	if float(stockpiles["industry"].get("materials", 0.0)) < cost:
		add_event("MATERIAL SHORTAGE", "Not enough construction materials for %s." % definition["name"], "warning")
		return false
	stockpiles["industry"]["materials"] -= cost
	blueprints.append({
		"id": next_blueprint_id,
		"type": build_type,
		"name": definition["name"],
		"position": snapped,
		"size": definition["size"],
		"progress": 0.0,
		"work_required": float(definition["work"]),
		"material_cost": cost,
		"capacity": int(definition["capacity"]),
		"assigned_builder": 0
	})
	next_blueprint_id += 1
	add_event("BLUEPRINT PLACED", "%s queued for construction." % definition["name"], "intel")
	return true

func can_place_blueprint(position: Vector2, size: Vector2) -> bool:
	var candidate := Rect2(position - size / 2.0, size).grow(4.0)
	for b in buildings:
		var rect := Rect2(b["position"] - b["size"] / 2.0, b["size"]).grow(4.0)
		if candidate.intersects(rect):
			return false
	for bp in blueprints:
		var rect := Rect2(bp["position"] - bp["size"] / 2.0, bp["size"]).grow(4.0)
		if candidate.intersects(rect):
			return false
	return true

func get_blueprint_by_id(id: int) -> Dictionary:
	for bp in blueprints:
		if int(bp["id"]) == id:
			return bp
	return {}

func get_available_blueprint() -> Dictionary:
	for bp in blueprints:
		if int(bp["assigned_builder"]) == 0:
			return bp
	return {}

func cancel_blueprint(id: int) -> bool:
	for i in range(blueprints.size()):
		if int(blueprints[i]["id"]) == id:
			var refund := float(blueprints[i]["material_cost"]) * 0.75
			stockpiles["industry"]["materials"] += refund
			blueprints.remove_at(i)
			add_event("BLUEPRINT CANCELED", "Recovered %.0f construction materials." % refund, "intel")
			return true
	return false

func demolish_building(building: Dictionary) -> bool:
	if building.is_empty():
		return false
	if str(building.get("type","")) == "command":
		add_event("DEMOLITION DENIED", "Command cannot be demolished.", "warning")
		return false
	var recovered := maxf(2.0, float(building["size"].x * building["size"].y) / 900.0)
	stockpiles["industry"]["materials"] += recovered
	stockpiles["industry"]["scrap"] += recovered * 0.5
	buildings.erase(building)
	add_event("STRUCTURE SALVAGED", "%s demolished; materials recovered." % building["name"], "good")
	completed_rooms = detect_rooms()
	return true

func queue_repair(building: Dictionary) -> void:
	if building.is_empty() or float(building["condition"]) >= 99.5:
		return
	add_work_order("Repair %s" % building["name"], "Builder", maxf(20.0, 100.0 - float(building["condition"])), 1)
	add_event("REPAIR QUEUED", "%s added to builder work queue." % building["name"], "intel")

func detect_rooms() -> int:
	var floor_tiles: Array[Dictionary] = []
	var wall_tiles: Array[Dictionary] = []
	for b in buildings:
		if b["type"] == "floor":
			floor_tiles.append(b)
		elif b["type"] == "wall":
			wall_tiles.append(b)
	var rooms := 0
	for floor in floor_tiles:
		var p: Vector2 = floor["position"]
		var enclosed := true
		for dir in [Vector2(40,0), Vector2(-40,0), Vector2(0,40), Vector2(0,-40)]:
			var found := false
			for wall in wall_tiles:
				if wall["position"].distance_to(p + dir) <= 12.0:
					found = true
					break
			if not found:
				enclosed = false
				break
		if enclosed:
			rooms += 1
	return rooms

func update(delta: float) -> void:
	if paused:
		return
	var sim_hours := delta * speed * 0.32
	total_hours += sim_hours
	hour += sim_hours
	while hour >= 24.0:
		hour -= 24.0
		day += 1
		add_event("NEW DAY", "Day %d begins." % day, "intel")

	var alive := get_alive_citizens()
	var population := alive.size()
	resources["power"] = clampf(resources["power"] + _power_delta(population) * sim_hours, 0.0, 100.0)

	for c in alive:
		_update_citizen_needs(c, sim_hours)
		_choose_action(c)
		_apply_citizen_work(c, sim_hours)
		_update_injury(c, sim_hours)
		if c["health"] <= 0.0 and c["alive"]:
			c["alive"] = false
			add_event("SURVIVOR LOST", "%s has died." % c["name"], "critical")

	_sync_resource_totals()
	event_director.update(self)

func _update_citizen_needs(c: Dictionary, sim_hours: float) -> void:
	c["hunger"] = minf(100.0, c["hunger"] + 1.15 * sim_hours)
	c["thirst"] = minf(100.0, c["thirst"] + 1.65 * sim_hours)
	c["fatigue"] = minf(100.0, c["fatigue"] + 0.90 * sim_hours)

	if c["current_action"] == "Sleep":
		c["fatigue"] = maxf(0.0, c["fatigue"] - 7.5 * sim_hours)
		c["stress"] = maxf(0.0, c["stress"] - 0.8 * sim_hours)

	if c["current_action"] == "Eat":
		var source: Dictionary = stockpiles["command"]
		if float(source.get("meals", 0.0)) > 0.0:
			var used := minf(float(source["meals"]), 0.65 * sim_hours)
			source["meals"] -= used
			c["hunger"] = maxf(0.0, c["hunger"] - 14.0 * sim_hours)

	if c["current_action"] == "Drink":
		var source: Dictionary = stockpiles["command"]
		if float(source.get("water", 0.0)) > 0.0:
			var used := minf(float(source["water"]), 0.9 * sim_hours)
			source["water"] -= used
			c["thirst"] = maxf(0.0, c["thirst"] - 18.0 * sim_hours)

	if c["hunger"] > 75.0:
		c["stress"] = minf(100.0, c["stress"] + 0.5 * sim_hours)
		c["morale"] = maxf(0.0, c["morale"] - 0.35 * sim_hours)
	if c["thirst"] > 75.0:
		c["stress"] = minf(100.0, c["stress"] + 0.75 * sim_hours)
		c["morale"] = maxf(0.0, c["morale"] - 0.45 * sim_hours)
	if c["fatigue"] > 85.0:
		c["health"] = maxf(0.0, c["health"] - 0.18 * sim_hours)
	if c["hunger"] > 92.0 or c["thirst"] > 92.0:
		c["health"] = maxf(0.0, c["health"] - 1.1 * sim_hours)

func _choose_action(c: Dictionary) -> void:
	if c["injury"] != "" and c["health"] < 72.0:
		_set_action(c, "Seek Treatment", "medical")
		return
	if c["thirst"] >= 58.0 and float(stockpiles["command"].get("water", 0.0)) > 0.1:
		_set_action(c, "Drink", "command")
		return
	if c["hunger"] >= 62.0 and float(stockpiles["command"].get("meals", 0.0)) > 0.1:
		_set_action(c, "Eat", "command")
		return
	if c["fatigue"] >= 72.0 or not _is_shift_active(c):
		_set_action(c, "Sleep" if c["fatigue"] >= 60.0 else "Free Time", "housing")
		return

	if c["job"] == "Builder":
		var blueprint := get_blueprint_by_id(int(c.get("target_blueprint_id", 0)))
		if blueprint.is_empty():
			blueprint = get_available_blueprint()
			if not blueprint.is_empty():
				blueprint["assigned_builder"] = int(c["id"])
				c["target_blueprint_id"] = int(blueprint["id"])
		if not blueprint.is_empty():
			_set_action(c, "Build: %s" % blueprint["name"], "industry")
			c["target"] = blueprint["position"]
			return

	var order := _best_work_order_for(c)
	if not order.is_empty():
		_set_action(c, "Order: %s" % order["title"], _building_for_job(order["job"]))
		return

	match c["job"]:
		"Farmer":
			_set_action(c, "Work: Farming", "farm")
		"Engineer":
			_set_action(c, "Work: Engineering", "power")
		"Builder":
			_set_action(c, "Work: Construction", "industry")
		"Medic":
			_set_action(c, "Work: Medical", "medical")
		"Scavenger":
			_set_action(c, "Scavenge", "industry")
		"Guard":
			_set_action(c, "Patrol", "command")
		"Cook":
			_set_action(c, "Prepare Meals", "command")
		"Hauler":
			_set_action(c, "Haul Supplies", "industry")
		_:
			_set_action(c, "Idle", "command")

func _is_shift_active(c: Dictionary) -> bool:
	if c["shift"] == "NIGHT":
		return hour >= 19.0 or hour < 7.0
	return hour >= 7.0 and hour < 19.0

func _best_work_order_for(c: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_priority := 999
	for order in work_orders:
		if order["complete"] or order["job"] != c["job"]:
			continue
		var citizen_priority := int(c["work_priority"].get(c["job"], 3))
		var effective := int(order["priority"]) + citizen_priority
		if effective < best_priority:
			best = order
			best_priority = effective
	return best

func _apply_citizen_work(c: Dictionary, sim_hours: float) -> void:
	var action: String = c["current_action"]
	var output := sim_hours

	if action.begins_with("Build: "):
		var blueprint := get_blueprint_by_id(int(c.get("target_blueprint_id", 0)))
		if blueprint.is_empty():
			c["target_blueprint_id"] = 0
			return
		if c["position"].distance_to(blueprint["position"]) <= 18.0:
			blueprint["progress"] += output * 10.0 * CitizenFactory.skill_multiplier(c, "construction")
			if blueprint["progress"] >= blueprint["work_required"]:
				_complete_blueprint(blueprint)
				c["target_blueprint_id"] = 0
				c["target"] = Vector2.ZERO
		return

	if action.begins_with("Order: "):
		var order := _best_work_order_for(c)
		if not order.is_empty():
			var skill := CitizenFactory.best_skill_for_job(c)
			order["progress"] += output * 8.0 * CitizenFactory.skill_multiplier(c, skill)
			if order["progress"] >= order["work_required"]:
				order["complete"] = true
				add_event("WORK ORDER COMPLETE", order["title"], "good")
				_complete_order(order)
		return

	match action:
		"Work: Farming":
			stockpiles["farm"]["food"] += 0.48 * output * CitizenFactory.skill_multiplier(c, "farming")
		"Work: Engineering":
			resources["power"] = minf(100.0, resources["power"] + 0.08 * output * CitizenFactory.skill_multiplier(c, "engineering"))
		"Work: Construction":
			stockpiles["industry"]["materials"] += 0.15 * output * CitizenFactory.skill_multiplier(c, "construction")
		"Scavenge":
			stockpiles["industry"]["scrap"] += 0.12 * output
			if rng.randf() < 0.003 * sim_hours:
				_assign_injury(c, "Laceration", 9.0)
		"Prepare Meals":
			if float(stockpiles["command"].get("food", 0.0)) >= 0.4:
				stockpiles["command"]["food"] -= 0.4 * output
				stockpiles["command"]["meals"] += 0.32 * output
		"Haul Supplies":
			_haul_tick(c, output)
		"Work: Medical":
			_treat_patients(c, output)

func _haul_tick(_c: Dictionary, output: float) -> void:
	var farm_food := float(stockpiles["farm"].get("food", 0.0))
	if farm_food > 20.0:
		var moved := minf(farm_food - 20.0, 0.9 * output)
		stockpiles["farm"]["food"] -= moved
		stockpiles["command"]["food"] += moved
	var industry_scrap := float(stockpiles["industry"].get("scrap", 0.0))
	if industry_scrap > 40.0:
		var moved_scrap := minf(industry_scrap - 40.0, 0.6 * output)
		stockpiles["industry"]["scrap"] -= moved_scrap
		cast_to_dictionary(stockpiles["command"])["scrap"] = float(stockpiles["command"].get("scrap", 0.0)) + moved_scrap

func cast_to_dictionary(value: Variant) -> Dictionary:
	return value

func _treat_patients(medic: Dictionary, output: float) -> void:
	for patient in get_alive_citizens():
		if patient["injury"] == "":
			continue
		if float(stockpiles["medical"].get("medicine", 0.0)) <= 0.0:
			return
		var skill := CitizenFactory.skill_multiplier(medic, "medicine")
		patient["treatment_progress"] += 9.0 * output * skill
		stockpiles["medical"]["medicine"] = maxf(0.0, float(stockpiles["medical"]["medicine"]) - 0.035 * output)
		if patient["treatment_progress"] >= 100.0:
			add_event("PATIENT STABILIZED", "%s recovered from %s." % [patient["name"], patient["injury"]], "good")
			patient["injury"] = ""
			patient["treatment_progress"] = 0.0
			patient["health"] = minf(100.0, patient["health"] + 12.0)
		break

func _update_injury(c: Dictionary, sim_hours: float) -> void:
	if c["injury"] == "":
		return
	c["health"] = maxf(0.0, c["health"] - 0.10 * sim_hours)
	c["stress"] = minf(100.0, c["stress"] + 0.12 * sim_hours)

func _assign_injury(c: Dictionary, injury: String, damage: float) -> void:
	if c["injury"] != "":
		return
	c["injury"] = injury
	c["health"] = maxf(0.0, c["health"] - damage)
	c["treatment_progress"] = 0.0
	add_event("INJURY", "%s suffered a %s." % [c["name"], injury], "warning")

func _complete_blueprint(blueprint: Dictionary) -> void:
	var new_building := {
		"name": blueprint["name"],
		"type": blueprint["type"],
		"position": blueprint["position"],
		"size": blueprint["size"],
		"condition": 100.0,
		"capacity": blueprint["capacity"]
	}
	buildings.append(new_building)
	blueprints.erase(blueprint)
	completed_rooms = detect_rooms()
	add_event("CONSTRUCTION COMPLETE", "%s entered service." % new_building["name"], "good")

func _complete_order(order: Dictionary) -> void:
	match order["job"]:
		"Cook":
			stockpiles["command"]["meals"] += 8.0
		"Hauler":
			stockpiles["command"]["food"] += 6.0
		"Builder":
			var workshop := get_building_by_type("industry")
			workshop["condition"] = minf(100.0, float(workshop["condition"]) + 8.0)

func _building_for_job(job: String) -> String:
	match job:
		"Farmer":
			return "farm"
		"Engineer":
			return "power"
		"Medic":
			return "medical"
		"Guard":
			return "command"
		_:
			return "industry"

func _set_action(c: Dictionary, action: String, building_type: String) -> void:
	if c["current_action"] != action:
		c["current_action"] = action
		c["target"] = Vector2.ZERO
	c["target_building"] = building_type

func _power_delta(population: int) -> float:
	var engineers := 0
	for c in get_alive_citizens():
		if c["job"] == "Engineer" and c["current_action"] == "Work: Engineering":
			engineers += 1
	return (engineers * 0.05) - (population * 0.012)

func _sync_resource_totals() -> void:
	resources["food"] = float(stockpiles["command"].get("food", 0.0)) + float(stockpiles["farm"].get("food", 0.0))
	resources["water"] = float(stockpiles["command"].get("water", 0.0))
	resources["medicine"] = float(stockpiles["command"].get("medicine", 0.0)) + float(stockpiles["medical"].get("medicine", 0.0))
	resources["materials"] = float(stockpiles["industry"].get("materials", 0.0))
	resources["scrap"] = float(stockpiles["industry"].get("scrap", 0.0)) + float(stockpiles["command"].get("scrap", 0.0))
	resources["meals"] = float(stockpiles["command"].get("meals", 0.0))

func get_alive_citizens() -> Array[Dictionary]:
	var alive: Array[Dictionary] = []
	for c in citizens:
		if c["alive"]:
			alive.append(c)
	return alive

func get_building_by_type(building_type: String) -> Dictionary:
	for b in buildings:
		if b["type"] == building_type:
			return b
	return buildings[0]

func get_average_morale() -> float:
	var alive := get_alive_citizens()
	if alive.is_empty():
		return 0.0
	var total := 0.0
	for c in alive:
		total += float(c["morale"])
	return total / alive.size()

func cycle_selected_shift(c: Dictionary) -> void:
	c["shift"] = "NIGHT" if c["shift"] == "DAY" else "DAY"
	add_event("SHIFT UPDATED", "%s assigned to %s shift." % [c["name"], c["shift"]], "intel")

func cycle_selected_priority(c: Dictionary) -> void:
	var current := int(c["work_priority"].get(c["job"], 3))
	current += 1
	if current > 4:
		current = 1
	c["work_priority"][c["job"]] = current
	add_event("WORK PRIORITY", "%s %s priority set to %d." % [c["name"], c["job"], current], "intel")

func save_game(path: String = "user://settlement_save.json") -> bool:
	var data := {
		"version": SAVE_VERSION,
		"day": day,
		"hour": hour,
		"total_hours": total_hours,
		"settlement_name": settlement_name,
		"resources": resources,
		"stockpiles": stockpiles,
		"work_orders": work_orders,
		"blueprints": _serialize_vector_dicts(blueprints),
		"buildings": _serialize_vector_dicts(buildings),
		"citizens": _serialize_vector_dicts(citizens),
		"next_citizen_id": next_citizen_id,
		"next_work_order_id": next_work_order_id,
		"next_blueprint_id": next_blueprint_id,
		"completed_rooms": completed_rooms
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	add_event("SAVE COMPLETE", "Settlement state written to disk.", "good")
	return true

func load_game(path: String = "user://settlement_save.json") -> bool:
	if not FileAccess.file_exists(path):
		add_event("LOAD FAILED", "No settlement save exists yet.", "warning")
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed
	day = int(data.get("day", 1))
	hour = float(data.get("hour", 7.0))
	total_hours = float(data.get("total_hours", 0.0))
	settlement_name = str(data.get("settlement_name", settlement_name))
	resources = data.get("resources", resources)
	stockpiles = data.get("stockpiles", stockpiles)
	work_orders = data.get("work_orders", work_orders)
	blueprints = _restore_vector_dicts(data.get("blueprints", []))
	buildings = _restore_vector_dicts(data.get("buildings", []))
	citizens = _restore_vector_dicts(data.get("citizens", []))
	next_citizen_id = int(data.get("next_citizen_id", citizens.size() + 1))
	next_work_order_id = int(data.get("next_work_order_id", work_orders.size() + 1))
	next_blueprint_id = int(data.get("next_blueprint_id", blueprints.size() + 1))
	completed_rooms = int(data.get("completed_rooms", detect_rooms()))
	add_event("LOAD COMPLETE", "Settlement state restored.", "good")
	return true

func _serialize_vector_dicts(items: Array) -> Array:
	var output: Array = []
	for item in items:
		var copy: Dictionary = item.duplicate(true)
		for key in ["position", "target", "size"]:
			if copy.has(key) and copy[key] is Vector2:
				var v: Vector2 = copy[key]
				copy[key] = {"x":v.x,"y":v.y,"__vector2":true}
		output.append(copy)
	return output

func _restore_vector_dicts(items: Array) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for item in items:
		var copy: Dictionary = item
		for key in ["position", "target", "size"]:
			if copy.has(key) and copy[key] is Dictionary and copy[key].get("__vector2", false):
				copy[key] = Vector2(float(copy[key]["x"]), float(copy[key]["y"]))
		output.append(copy)
	return output

func add_event(title: String, body: String, severity: String) -> void:
	events.push_front({
		"title": title,
		"body": body,
		"severity": severity,
		"day": day,
		"hour": hour
	})
	if events.size() > 12:
		events.resize(12)
