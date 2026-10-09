class_name SettlementSimulation
extends RefCounted

const SAVE_VERSION := 14

var rng := RandomNumberGenerator.new()
var citizens: Array[Dictionary] = []
var resources := {
	"food": 240.0,
	"water": 300.0,
	"power": 76.0,
	"medicine": 28.0,
	"materials": 120.0,
	"scrap": 90.0,
	"meals": 12.0,
	"raw_water": 80.0,
	"sewage": 0.0
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
var utility_state := {
	"power_generated": 0.0,
	"power_demand": 0.0,
	"power_online": true,
	"battery_charge": 35.0,
	"battery_capacity": 100.0,
	"raw_water": 80.0,
	"clean_water_rate": 0.0,
	"water_online": true,
	"sewage": 0.0,
	"sewage_capacity": 120.0,
	"sanitation": 100.0
}
var utility_failures := {
	"generator_trip": false,
	"pump_failure": false,
	"sewage_overflow": false
}
var event_director := EventDirector.new()
var social_simulation := SocialSimulation.new()
var world_simulation := WorldSimulation.new()
var governance_simulation := GovernanceSimulation.new()
var economy_simulation := EconomySimulation.new()
var faction_simulation := FactionSimulation.new()
var civilization_simulation := CivilizationSimulation.new()
var federal_governance_simulation := FederalGovernanceSimulation.new()
var settlement_name := "LAST HAVEN // SITE-01"
# Optional v14 save field: older saves load with every directive unfinished.
var field_objectives := {
	"inspected": false,
	"blueprint": false,
	"expedition": false,
	"survived": false
}

func complete_field_objective(objective: String) -> void:
	if not field_objectives.has(objective) or bool(field_objectives[objective]):
		return
	field_objectives[objective] = true
	var titles := {
		"inspected": "Know Your People",
		"blueprint": "Rebuild the Camp",
		"expedition": "Beyond the Walls",
		"survived": "First Night"
	}
	add_event("DIRECTIVE COMPLETE", str(titles.get(objective, "Field Command")) + " completed.", "good")

func check_field_objectives() -> void:
	if day >= 2:
		complete_field_objective("survived")


func _init() -> void:
	rng.randomize()
	_create_buildings()
	world_simulation.initialize(rng)
	for i in range(12):
		add_citizen()
	_seed_work_orders()
	governance_simulation.initialize(self)
	economy_simulation.initialize(self)
	faction_simulation.initialize(self)
	civilization_simulation.initialize(self)
	federal_governance_simulation.initialize(self)
	add_event("SETTLEMENT ONLINE", "Twelve survivors have established a temporary command camp.", "good")

func _create_buildings() -> void:
	buildings = [
		{"name":"Command","type":"command","position":Vector2(700,380),"size":Vector2(170,100),"condition":100.0,"capacity":12},
		{"name":"Shelter A","type":"housing","position":Vector2(465,295),"size":Vector2(150,90),"condition":86.0,"capacity":8},
		{"name":"Shelter B","type":"housing","position":Vector2(470,500),"size":Vector2(150,90),"condition":81.0,"capacity":8},
		{"name":"Workshop","type":"industry","position":Vector2(930,300),"size":Vector2(180,100),"condition":78.0,"capacity":6},
		{"name":"Clinic","type":"medical","position":Vector2(930,515),"size":Vector2(150,95),"condition":91.0,"capacity":4},
		{"name":"Farm","type":"farm","position":Vector2(705,620),"size":Vector2(250,105),"condition":74.0,"capacity":8},
		{"name":"Generator","type":"power","position":Vector2(1190,430),"size":Vector2(135,100),"condition":69.0,"capacity":4,"utility":"generator","output":28.0,"demand":0.0},
		{"name":"Water Pump","type":"water","position":Vector2(1180,600),"size":Vector2(110,80),"condition":82.0,"capacity":2,"utility":"water_pump","output":12.0,"demand":4.0},
		{"name":"Purifier","type":"water","position":Vector2(1040,650),"size":Vector2(120,80),"condition":88.0,"capacity":2,"utility":"purifier","output":9.0,"demand":5.0},
		{"name":"Sewage Plant","type":"sewage","position":Vector2(1260,690),"size":Vector2(130,85),"condition":76.0,"capacity":3,"utility":"sewage","output":14.0,"demand":3.0}
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
		{"type":"storage","name":"Storage Module","size":Vector2(120,80),"cost":20.0,"work":70.0,"capacity":10},
		{"type":"generator","name":"Generator","size":Vector2(120,90),"cost":34.0,"work":110.0,"capacity":3},
		{"type":"battery","name":"Battery Bank","size":Vector2(100,70),"cost":26.0,"work":75.0,"capacity":2},
		{"type":"power_pole","name":"Power Pole","size":Vector2(28,28),"cost":5.0,"work":16.0,"capacity":0},
		{"type":"water_pump","name":"Water Pump","size":Vector2(100,70),"cost":24.0,"work":80.0,"capacity":2},
		{"type":"purifier","name":"Water Purifier","size":Vector2(110,75),"cost":28.0,"work":88.0,"capacity":2},
		{"type":"water_tank","name":"Water Tank","size":Vector2(95,95),"cost":22.0,"work":70.0,"capacity":0},
		{"type":"pipe","name":"Utility Pipe","size":Vector2(40,10),"cost":3.0,"work":12.0,"capacity":0},
		{"type":"sewage","name":"Sewage Processor","size":Vector2(120,80),"cost":30.0,"work":95.0,"capacity":2}
	]

func get_build_definition(build_type: String) -> Dictionary:
	for item in get_build_catalog():
		if item["type"] == build_type:
			return item
	return get_build_catalog()[0]

func place_blueprint(build_type: String, world_position: Vector2, rotated: bool = false) -> bool:
	var definition := get_build_definition(build_type)
	var snapped := Vector2(round(world_position.x / 20.0) * 20.0, round(world_position.y / 20.0) * 20.0)
	var placement_size: Vector2 = definition["size"]
	if rotated and (build_type == "wall" or build_type == "door" or build_type == "pipe"):
		placement_size = Vector2(placement_size.y, placement_size.x)
	if not can_place_blueprint(snapped, placement_size):
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
		"size": placement_size,
		"rotated": rotated,
		"progress": 0.0,
		"work_required": float(definition["work"]),
		"material_cost": cost,
		"capacity": int(definition["capacity"]),
		"assigned_builder": 0
	})
	next_blueprint_id += 1
	complete_field_objective("blueprint")
	add_event("BLUEPRINT PLACED", "%s queued for construction." % definition["name"], "intel")
	return true

func can_place_blueprint(position: Vector2, size: Vector2) -> bool:
	var candidate := Rect2(position - size / 2.0, size)
	for b in buildings:
		var rect := Rect2(b["position"] - b["size"] / 2.0, b["size"])
		if candidate.intersects(rect):
			return false
	for bp in blueprints:
		var rect := Rect2(bp["position"] - bp["size"] / 2.0, bp["size"])
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
		if c.get("on_expedition", false):
			continue
		if c.get("incarcerated", false):
			c["sentence_hours"] = maxf(0.0, float(c.get("sentence_hours",0.0)) - sim_hours)
			c["current_action"] = "Incarcerated"
			c["stress"] = minf(100.0,float(c["stress"])+0.08*sim_hours)
			if float(c["sentence_hours"]) <= 0.0:
				c["incarcerated"] = false
				add_event("SENTENCE COMPLETE","%s was released from custody." % c["name"],"intel")
			continue
		_update_citizen_needs(c, sim_hours)
		_choose_action(c)
		_apply_citizen_work(c, sim_hours)
		_update_injury(c, sim_hours)
		if c["health"] <= 0.0 and c["alive"]:
			c["alive"] = false
			add_event("SURVIVOR LOST", "%s has died." % c["name"], "critical")

	_update_utilities(sim_hours)
	_apply_utility_consequences(sim_hours)
	social_simulation.update(self, sim_hours)
	world_simulation.update(self, sim_hours)
	governance_simulation.update(self, sim_hours)
	economy_simulation.update(self, sim_hours)
	faction_simulation.update(self, sim_hours)
	federal_governance_simulation.update(self, sim_hours)
	civilization_simulation.update(self, sim_hours)
	_sync_resource_totals()
	event_director.update(self)

func _update_utilities(sim_hours: float) -> void:
	var power_nodes: Array[Dictionary] = []
	var water_nodes: Array[Dictionary] = []
	var generated := 0.0
	var demand := 0.0
	var pump_capacity := 0.0
	var purifier_capacity := 0.0
	var sewage_capacity := 0.0
	var battery_capacity := 0.0
	var generator_count := 0

	for b in buildings:
		var utility := str(b.get("utility", ""))
		if utility == "":
			match str(b.get("type","")):
				"generator": utility = "generator"
				"battery": utility = "battery"
				"power_pole": utility = "power_pole"
				"water_pump": utility = "water_pump"
				"purifier": utility = "purifier"
				"water_tank": utility = "water_tank"
				"pipe": utility = "pipe"
				"sewage": utility = "sewage"
		if utility in ["generator","battery","power_pole","water_pump","purifier","sewage"]:
			power_nodes.append(b)
		if utility in ["water_pump","purifier","water_tank","pipe","sewage"]:
			water_nodes.append(b)

		var efficiency := clampf(float(b.get("condition",100.0)) / 100.0, 0.0, 1.0)
		match utility:
			"generator":
				if efficiency > 0.20 and not utility_failures["generator_trip"]:
					generator_count += 1
					generated += 28.0 * efficiency
			"battery":
				battery_capacity += 40.0
			"water_pump":
				demand += 4.0
				if efficiency > 0.25 and not utility_failures["pump_failure"]:
					pump_capacity += 12.0 * efficiency
			"purifier":
				demand += 5.0
				if efficiency > 0.25:
					purifier_capacity += 9.0 * efficiency
			"sewage":
				demand += 3.0
				if efficiency > 0.25:
					sewage_capacity += 14.0 * efficiency

	for b in buildings:
		match str(b.get("type","")):
			"command": demand += 4.0
			"housing": demand += 1.4
			"industry": demand += 5.0
			"medical": demand += 6.0
			"storage": demand += 1.0

	var fuel_factor := economy_simulation.consume_generator_fuel(self, sim_hours, generator_count)
	generated *= fuel_factor
	if fuel_factor < 0.2 and generator_count > 0:
		utility_state["power_online"] = false
	utility_state["battery_capacity"] = maxf(100.0, battery_capacity)
	utility_state["power_generated"] = generated
	utility_state["power_demand"] = demand

	var battery := float(utility_state["battery_charge"])
	if generated >= demand:
		var surplus := generated - demand
		battery = minf(float(utility_state["battery_capacity"]), battery + surplus * 0.18 * sim_hours)
		utility_state["power_online"] = true
	else:
		var deficit := demand - generated
		var draw := deficit * 0.30 * sim_hours
		if battery >= draw:
			battery -= draw
			utility_state["power_online"] = true
		else:
			battery = 0.0
			utility_state["power_online"] = false
	utility_state["battery_charge"] = battery

	if rng.randf() < 0.00018 * sim_hours:
		utility_failures["generator_trip"] = true
		add_event("GRID TRIP", "Primary generator protective relay opened.", "critical")
	if utility_failures["generator_trip"] and get_active_engineers() > 0 and rng.randf() < 0.015 * sim_hours:
		utility_failures["generator_trip"] = false
		add_event("GRID RESTORED", "Engineering reset the generator and re-energized the bus.", "good")
	if utility_failures["pump_failure"] and get_active_engineers() > 0 and rng.randf() < 0.012 * sim_hours:
		utility_failures["pump_failure"] = false
		add_event("WATER SERVICE RESTORED", "Engineering returned the extraction pump to service.", "good")

	var power_factor := 1.0 if utility_state["power_online"] else 0.12
	var extracted := pump_capacity * power_factor * sim_hours
	utility_state["raw_water"] = minf(300.0, float(utility_state["raw_water"]) + extracted)
	var raw_available := float(utility_state["raw_water"])
	var clean_rate := minf(purifier_capacity * power_factor, raw_available / maxf(sim_hours, 0.001))
	var cleaned := clean_rate * sim_hours
	utility_state["raw_water"] = maxf(0.0, raw_available - cleaned)
	stockpiles["command"]["water"] = minf(420.0, float(stockpiles["command"].get("water",0.0)) + cleaned)
	utility_state["clean_water_rate"] = clean_rate
	utility_state["water_online"] = clean_rate > 0.05

	var sewage_added := get_settlement_citizens().size() * 0.22 * sim_hours
	utility_state["sewage"] = float(utility_state["sewage"]) + sewage_added
	var treated := sewage_capacity * power_factor * sim_hours
	utility_state["sewage"] = maxf(0.0, float(utility_state["sewage"]) - treated)
	utility_state["sewage_capacity"] = maxf(120.0, sewage_capacity * 8.0)

	if float(utility_state["sewage"]) > float(utility_state["sewage_capacity"]):
		if not utility_failures["sewage_overflow"]:
			utility_failures["sewage_overflow"] = true
			add_event("SEWAGE OVERFLOW", "Waste processing capacity has been exceeded.", "critical")
	else:
		utility_failures["sewage_overflow"] = false

	var sanitation_target := 100.0
	if not utility_state["water_online"]:
		sanitation_target -= 35.0
	if utility_failures["sewage_overflow"]:
		sanitation_target -= 45.0
	if not utility_state["power_online"]:
		sanitation_target -= 10.0
	utility_state["sanitation"] = move_toward(float(utility_state["sanitation"]), clampf(sanitation_target, 0.0, 100.0), 2.0 * sim_hours)

func _apply_utility_consequences(sim_hours: float) -> void:
	if not utility_state["power_online"]:
		for c in get_alive_citizens():
			c["stress"] = minf(100.0, float(c["stress"]) + 0.20 * sim_hours)
			c["morale"] = maxf(0.0, float(c["morale"]) - 0.15 * sim_hours)
	if not utility_state["water_online"]:
		for c in get_alive_citizens():
			c["thirst"] = minf(100.0, float(c["thirst"]) + 0.25 * sim_hours)
	var sanitation := float(utility_state["sanitation"])
	if sanitation < 45.0:
		for c in get_alive_citizens():
			c["health"] = maxf(0.0, float(c["health"]) - (45.0 - sanitation) * 0.002 * sim_hours)

func get_active_engineers() -> int:
	var count := 0
	for c in get_alive_citizens():
		if c["job"] == "Engineer" and _is_shift_active(c):
			count += 1
	return count

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
	if int(c["age"]) < 16:
		if c["thirst"] >= 58.0 and float(stockpiles["command"].get("water", 0.0)) > 0.1:
			_set_action(c, "Drink", "command")
		elif c["hunger"] >= 62.0 and float(stockpiles["command"].get("meals", 0.0)) > 0.1:
			_set_action(c, "Eat", "command")
		elif c["fatigue"] >= 60.0:
			_set_action(c, "Sleep", "housing")
		else:
			_set_action(c, "Play / Learn", "housing")
		return
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
	if _needs_stress_recovery(c):
		_set_action(c, "Decompress", "housing")
		return
	if not is_selected_work_enabled(c):
		_set_action(c, "Off Duty", "housing")
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

func _needs_stress_recovery(c: Dictionary) -> bool:
	var stress_limit := 82.0
	var morale_limit := 24.0
	match str(c.get("trait", "")):
		"Stoic":
			stress_limit = 90.0
		"Optimist":
			morale_limit = 16.0
		"Empathetic":
			stress_limit = 86.0
		"Stubborn":
			stress_limit = 88.0
	return float(c.get("stress", 0.0)) >= stress_limit or float(c.get("morale", 100.0)) <= morale_limit

func _work_readiness(c: Dictionary) -> float:
	var stress_penalty := clampf((float(c.get("stress", 0.0)) - 45.0) / 100.0, 0.0, 0.35)
	var morale_penalty := clampf((40.0 - float(c.get("morale", 100.0))) / 100.0, 0.0, 0.25)
	var fatigue_penalty := clampf((float(c.get("fatigue", 0.0)) - 55.0) / 120.0, 0.0, 0.20)
	return clampf(1.0 - stress_penalty - morale_penalty - fatigue_penalty, 0.45, 1.0)

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
	var output := sim_hours * _work_readiness(c)

	if action == "Decompress":
		c["stress"] = maxf(0.0, float(c["stress"]) - 3.2 * sim_hours)
		c["morale"] = minf(100.0, float(c["morale"]) + 1.1 * sim_hours)
		c["fatigue"] = maxf(0.0, float(c["fatigue"]) - 0.7 * sim_hours)
		return

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
	output *= economy_simulation.get_logistics_multiplier(output)
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
	match str(blueprint["type"]):
		"generator":
			new_building["utility"] = "generator"
			new_building["output"] = 28.0
			new_building["demand"] = 0.0
		"battery":
			new_building["utility"] = "battery"
		"power_pole":
			new_building["utility"] = "power_pole"
		"water_pump":
			new_building["utility"] = "water_pump"
		"purifier":
			new_building["utility"] = "purifier"
		"water_tank":
			new_building["utility"] = "water_tank"
		"pipe":
			new_building["utility"] = "pipe"
		"sewage":
			new_building["utility"] = "sewage"
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
			var target_name := str(order["title"]).trim_prefix("Repair ")
			var target := get_building_by_name(target_name)
			if target.is_empty():
				target = get_building_by_type("industry")
			target["condition"] = minf(100.0, float(target["condition"]) + maxf(8.0, float(order["work_required"])))

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
	resources["raw_water"] = float(utility_state["raw_water"])
	resources["sewage"] = float(utility_state["sewage"])
	resources["power"] = 100.0 * minf(1.0, (float(utility_state["power_generated"]) + float(utility_state["battery_charge"]) * 0.05) / maxf(1.0, float(utility_state["power_demand"])))

func get_alive_citizens() -> Array[Dictionary]:
	var alive: Array[Dictionary] = []
	for c in citizens:
		if c["alive"]:
			alive.append(c)
	return alive

func get_settlement_citizens() -> Array[Dictionary]:
	var present: Array[Dictionary] = []
	for c in citizens:
		if c["alive"] and not c.get("on_expedition", false) and str(c.get("home_settlement","LAST_HAVEN")) == "LAST_HAVEN":
			present.append(c)
	return present

func get_building_by_type(building_type: String) -> Dictionary:
	for b in buildings:
		if b["type"] == building_type:
			return b
	return buildings[0]

func get_citizen_by_id(id: int) -> Dictionary:
	for c in citizens:
		if int(c["id"]) == id:
			return c
	return {}

func get_building_by_name(building_name: String) -> Dictionary:
	for b in buildings:
		if str(b["name"]) == building_name:
			return b
	return {}

func get_average_morale() -> float:
	var alive := get_settlement_citizens()
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
	if current <= 0:
		current = 1
	else:
		current += 1
		if current > 4:
			current = 1
	c["work_priority"][c["job"]] = current
	add_event("WORK PRIORITY", "%s %s priority set to %d." % [c["name"], c["job"], current], "intel")

func is_selected_work_enabled(c: Dictionary) -> bool:
	return int(c.get("work_priority", {}).get(c.get("job", ""), 3)) > 0

func toggle_selected_work(c: Dictionary) -> void:
	var job := str(c.get("job", ""))
	if job == "" or job == "Child":
		return
	var current := int(c["work_priority"].get(job, 3))
	if current > 0:
		c["work_priority"][job] = 0
		c["target_blueprint_id"] = 0
		c["target"] = Vector2.ZERO
		_set_action(c, "Off Duty", "housing")
		add_event("DUTY PAUSED", "%s removed from %s duty." % [c["name"], job], "warning")
	else:
		c["work_priority"][job] = 3
		add_event("DUTY RESTORED", "%s returned to %s duty." % [c["name"], job], "good")

func save_game(path: String = "user://settlement_save.json") -> bool:
	var data := {
		"version": SAVE_VERSION,
		"day": day,
		"hour": hour,
		"total_hours": total_hours,
		"settlement_name": settlement_name,
		"field_objectives": field_objectives,
		"resources": resources,
		"stockpiles": stockpiles,
		"work_orders": work_orders,
		"blueprints": _serialize_vector_dicts(blueprints),
		"buildings": _serialize_vector_dicts(buildings),
		"citizens": _serialize_vector_dicts(citizens),
		"next_citizen_id": next_citizen_id,
		"next_work_order_id": next_work_order_id,
		"next_blueprint_id": next_blueprint_id,
		"completed_rooms": completed_rooms,
		"utility_state": utility_state,
		"utility_failures": utility_failures,
		"world_locations": _serialize_vector_dicts(world_simulation.locations),
		"expeditions": world_simulation.expeditions,
		"discovered_location_ids": world_simulation.discovered_location_ids,
		"next_expedition_id": world_simulation.next_expedition_id,
		"governance": {
			"government_type": governance_simulation.government_type,
			"laws": governance_simulation.laws,
			"leader_id": governance_simulation.leader_id,
			"council_ids": governance_simulation.council_ids,
			"factions": governance_simulation.factions,
			"unrest": governance_simulation.unrest,
			"legitimacy": governance_simulation.legitimacy,
			"crime_pressure": governance_simulation.crime_pressure,
			"active_cases": governance_simulation.active_cases,
			"next_case_id": governance_simulation.next_case_id,
			"next_election_hour": governance_simulation.next_election_hour,
			"last_protest_hour": governance_simulation.last_protest_hour,
			"last_crisis_hour": governance_simulation.last_crisis_hour
		},
		"economy": {
			"credits": economy_simulation.credits,
			"market_index": economy_simulation.market_index,
			"industry_stock": economy_simulation.industry_stock,
			"production_queue": economy_simulation.production_queue,
			"next_batch_id": economy_simulation.next_batch_id,
			"price_update_hour": economy_simulation.price_update_hour,
			"trade_log": economy_simulation.trade_log,
			"vehicles": economy_simulation.vehicles,
			"trade_pressure": economy_simulation.trade_pressure,
			"warehouse_capacity": economy_simulation.warehouse_capacity,
			"warehouse_used": economy_simulation.warehouse_used,
			"warehouse_pressure": economy_simulation.warehouse_pressure,
			"production_efficiency": economy_simulation.production_efficiency,
			"bottleneck_reason": economy_simulation.bottleneck_reason,
			"fuel_consumed_today": economy_simulation.fuel_consumed_today,
			"next_warehouse_check_hour": economy_simulation.next_warehouse_check_hour,
			"repair_kits": economy_simulation.repair_kits,
			"regional_markets": economy_simulation.regional_markets,
			"trade_caravans": economy_simulation.trade_caravans,
			"next_caravan_id": economy_simulation.next_caravan_id
		},
		"factions": {
			"factions": faction_simulation.factions,
			"next_strategic_hour": faction_simulation.next_strategic_hour,
			"active_raid": faction_simulation.active_raid,
			"raid_log": faction_simulation.raid_log,
			"last_espionage_hour": faction_simulation.last_espionage_hour
		},
		"civilization": {
			"settlements": civilization_simulation.settlements,
			"logistics_routes": civilization_simulation.logistics_routes,
			"history_archive": civilization_simulation.history_archive,
			"recovery_score": civilization_simulation.recovery_score,
			"civilization_stability": civilization_simulation.civilization_stability,
			"next_settlement_id": civilization_simulation.next_settlement_id,
			"next_route_id": civilization_simulation.next_route_id,
			"next_logistics_hour": civilization_simulation.next_logistics_hour,
			"next_colony_event_hour": civilization_simulation.next_colony_event_hour,
			"endgame_stage": civilization_simulation.endgame_stage,
			"milestones": civilization_simulation.milestones,
			"civilization_policies": civilization_simulation.civilization_policies,
			"emergency_log": civilization_simulation.emergency_log,
			"colony_projects": civilization_simulation.colony_projects,
			"next_colony_project_id": civilization_simulation.next_colony_project_id,
			"recovery_projects": civilization_simulation.recovery_projects,
			"founding_roster": civilization_simulation.founding_roster
		},
		"federal_governance": {
			"charter": federal_governance_simulation.charter,
			"representatives": federal_governance_simulation.representatives,
			"federal_legitimacy": federal_governance_simulation.federal_legitimacy,
			"network_cohesion": federal_governance_simulation.network_cohesion,
			"federal_treasury": federal_governance_simulation.federal_treasury,
			"next_council_hour": federal_governance_simulation.next_council_hour,
			"council_history": federal_governance_simulation.council_history,
			"last_dispute_hour": federal_governance_simulation.last_dispute_hour
		}
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
	var loaded_objectives: Dictionary = data.get("field_objectives", {})
	for objective in field_objectives.keys():
		field_objectives[objective] = bool(loaded_objectives.get(objective, false))
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
	utility_state = data.get("utility_state", utility_state)
	utility_failures = data.get("utility_failures", utility_failures)
	world_simulation.locations = _restore_vector_dicts(data.get("world_locations", world_simulation.locations))
	world_simulation.expeditions = data.get("expeditions", world_simulation.expeditions)
	world_simulation.discovered_location_ids = data.get("discovered_location_ids", world_simulation.discovered_location_ids)
	world_simulation.next_expedition_id = int(data.get("next_expedition_id", world_simulation.next_expedition_id))
	var governance: Dictionary = data.get("governance", {})
	if not governance.is_empty():
		governance_simulation.government_type = str(governance.get("government_type", governance_simulation.government_type))
		governance_simulation.laws = governance.get("laws", governance_simulation.laws)
		governance_simulation.leader_id = int(governance.get("leader_id", governance_simulation.leader_id))
		governance_simulation.council_ids = governance.get("council_ids", governance_simulation.council_ids)
		governance_simulation.factions = governance.get("factions", governance_simulation.factions)
		governance_simulation.unrest = float(governance.get("unrest", governance_simulation.unrest))
		governance_simulation.legitimacy = float(governance.get("legitimacy", governance_simulation.legitimacy))
		governance_simulation.crime_pressure = float(governance.get("crime_pressure", governance_simulation.crime_pressure))
		governance_simulation.active_cases = governance.get("active_cases", governance_simulation.active_cases)
		governance_simulation.next_case_id = int(governance.get("next_case_id", governance_simulation.next_case_id))
		governance_simulation.next_election_hour = float(governance.get("next_election_hour", governance_simulation.next_election_hour))
		governance_simulation.last_protest_hour = float(governance.get("last_protest_hour", governance_simulation.last_protest_hour))
		governance_simulation.last_crisis_hour = float(governance.get("last_crisis_hour", governance_simulation.last_crisis_hour))
	var economy: Dictionary = data.get("economy", {})
	if not economy.is_empty():
		economy_simulation.credits = float(economy.get("credits", economy_simulation.credits))
		economy_simulation.market_index = economy.get("market_index", economy_simulation.market_index)
		economy_simulation.industry_stock = economy.get("industry_stock", economy_simulation.industry_stock)
		economy_simulation.production_queue = economy.get("production_queue", economy_simulation.production_queue)
		economy_simulation.next_batch_id = int(economy.get("next_batch_id", economy_simulation.next_batch_id))
		economy_simulation.price_update_hour = float(economy.get("price_update_hour", economy_simulation.price_update_hour))
		economy_simulation.trade_log = economy.get("trade_log", economy_simulation.trade_log)
		economy_simulation.vehicles = economy.get("vehicles", economy_simulation.vehicles)
		economy_simulation.trade_pressure = economy.get("trade_pressure", economy_simulation.trade_pressure)
		economy_simulation.warehouse_capacity = float(economy.get("warehouse_capacity", economy_simulation.warehouse_capacity))
		economy_simulation.warehouse_used = float(economy.get("warehouse_used", economy_simulation.warehouse_used))
		economy_simulation.warehouse_pressure = float(economy.get("warehouse_pressure", economy_simulation.warehouse_pressure))
		economy_simulation.production_efficiency = float(economy.get("production_efficiency", economy_simulation.production_efficiency))
		economy_simulation.bottleneck_reason = str(economy.get("bottleneck_reason", economy_simulation.bottleneck_reason))
		economy_simulation.fuel_consumed_today = float(economy.get("fuel_consumed_today", economy_simulation.fuel_consumed_today))
		economy_simulation.next_warehouse_check_hour = float(economy.get("next_warehouse_check_hour", economy_simulation.next_warehouse_check_hour))
		economy_simulation.repair_kits = float(economy.get("repair_kits", economy_simulation.repair_kits))
		economy_simulation.regional_markets = economy.get("regional_markets", economy_simulation.regional_markets)
		economy_simulation.trade_caravans = economy.get("trade_caravans", economy_simulation.trade_caravans)
		economy_simulation.next_caravan_id = int(economy.get("next_caravan_id", economy_simulation.next_caravan_id))
	var faction_state: Dictionary = data.get("factions", {})
	if not faction_state.is_empty():
		faction_simulation.factions = faction_state.get("factions", faction_simulation.factions)
		faction_simulation.next_strategic_hour = float(faction_state.get("next_strategic_hour", faction_simulation.next_strategic_hour))
		faction_simulation.active_raid = faction_state.get("active_raid", faction_simulation.active_raid)
		faction_simulation.raid_log = faction_state.get("raid_log", faction_simulation.raid_log)
		faction_simulation.last_espionage_hour = float(faction_state.get("last_espionage_hour", faction_simulation.last_espionage_hour))
	var civilization_state: Dictionary = data.get("civilization", {})
	if not civilization_state.is_empty():
		civilization_simulation.settlements = civilization_state.get("settlements", civilization_simulation.settlements)
		civilization_simulation.logistics_routes = civilization_state.get("logistics_routes", civilization_simulation.logistics_routes)
		civilization_simulation.history_archive = civilization_state.get("history_archive", civilization_simulation.history_archive)
		civilization_simulation.recovery_score = float(civilization_state.get("recovery_score", civilization_simulation.recovery_score))
		civilization_simulation.civilization_stability = float(civilization_state.get("civilization_stability", civilization_simulation.civilization_stability))
		civilization_simulation.next_settlement_id = int(civilization_state.get("next_settlement_id", civilization_simulation.next_settlement_id))
		civilization_simulation.next_route_id = int(civilization_state.get("next_route_id", civilization_simulation.next_route_id))
		civilization_simulation.next_logistics_hour = float(civilization_state.get("next_logistics_hour", civilization_simulation.next_logistics_hour))
		civilization_simulation.next_colony_event_hour = float(civilization_state.get("next_colony_event_hour", civilization_simulation.next_colony_event_hour))
		civilization_simulation.civilization_policies = civilization_state.get("civilization_policies", civilization_simulation.civilization_policies)
		civilization_simulation.emergency_log = civilization_state.get("emergency_log", civilization_simulation.emergency_log)
		civilization_simulation.colony_projects = civilization_state.get("colony_projects", civilization_simulation.colony_projects)
		civilization_simulation.next_colony_project_id = int(civilization_state.get("next_colony_project_id", civilization_simulation.next_colony_project_id))
		civilization_simulation.recovery_projects = civilization_state.get("recovery_projects", civilization_simulation.recovery_projects)
		civilization_simulation.founding_roster = civilization_state.get("founding_roster", civilization_simulation.founding_roster)
		civilization_simulation.endgame_stage = str(civilization_state.get("endgame_stage", civilization_simulation.endgame_stage))
		civilization_simulation.milestones = civilization_state.get("milestones", civilization_simulation.milestones)
		civilization_simulation.normalize_loaded_state()
	var federal_state: Dictionary = data.get("federal_governance", {})
	if not federal_state.is_empty():
		federal_governance_simulation.charter = federal_state.get("charter", federal_governance_simulation.charter)
		federal_governance_simulation.representatives = federal_state.get("representatives", federal_governance_simulation.representatives)
		federal_governance_simulation.federal_legitimacy = float(federal_state.get("federal_legitimacy", federal_governance_simulation.federal_legitimacy))
		federal_governance_simulation.network_cohesion = float(federal_state.get("network_cohesion", federal_governance_simulation.network_cohesion))
		federal_governance_simulation.federal_treasury = float(federal_state.get("federal_treasury", federal_governance_simulation.federal_treasury))
		federal_governance_simulation.next_council_hour = float(federal_state.get("next_council_hour", federal_governance_simulation.next_council_hour))
		federal_governance_simulation.council_history = federal_state.get("council_history", federal_governance_simulation.council_history)
		federal_governance_simulation.last_dispute_hour = float(federal_state.get("last_dispute_hour", federal_governance_simulation.last_dispute_hour))
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
	if severity == "critical" and civilization_simulation != null:
		civilization_simulation.record_history(self,title,body,"critical")
	events.push_front({
		"title": title,
		"body": body,
		"severity": severity,
		"day": day,
		"hour": hour
	})
	if events.size() > 12:
		events.resize(12)
