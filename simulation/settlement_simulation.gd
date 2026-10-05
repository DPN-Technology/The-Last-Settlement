class_name SettlementSimulation
extends RefCounted

var rng := RandomNumberGenerator.new()
var citizens: Array[Dictionary] = []
var resources := {
	"food": 240.0,
	"water": 300.0,
	"power": 76.0,
	"medicine": 28.0,
	"materials": 120.0,
	"scrap": 90.0
}
var buildings: Array[Dictionary] = []
var events: Array[Dictionary] = []
var total_hours := 0.0
var day := 1
var hour := 7.0
var speed := 1.0
var paused := false
var next_citizen_id := 1
var event_director := EventDirector.new()
var settlement_name := "LAST HAVEN // SITE-01"

func _init() -> void:
	rng.randomize()
	_create_buildings()
	for i in range(12):
		add_citizen()
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

func add_citizen() -> void:
	citizens.append(CitizenFactory.create(next_citizen_id, rng))
	next_citizen_id += 1

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

	var farmers := 0
	var engineers := 0
	var builders := 0
	var medics := 0
	var scavengers := 0

	for c in alive:
		_update_citizen_needs(c, sim_hours)
		_choose_action(c)

		match c["current_action"]:
			"Work: Farming":
				farmers += 1
			"Work: Engineering":
				engineers += 1
			"Work: Construction":
				builders += 1
			"Work: Medical":
				medics += 1
			"Scavenge":
				scavengers += 1

		if c["health"] <= 0.0 and c["alive"]:
			c["alive"] = false
			add_event("SURVIVOR LOST", "%s has died." % c["name"], "critical")

	_apply_work_output(farmers, engineers, builders, medics, scavengers, sim_hours)
	event_director.update(self)

func _update_citizen_needs(c: Dictionary, sim_hours: float) -> void:
	c["hunger"] = minf(100.0, c["hunger"] + 1.15 * sim_hours)
	c["thirst"] = minf(100.0, c["thirst"] + 1.65 * sim_hours)
	c["fatigue"] = minf(100.0, c["fatigue"] + 0.90 * sim_hours)

	if c["current_action"] == "Sleep":
		c["fatigue"] = maxf(0.0, c["fatigue"] - 7.5 * sim_hours)
		c["stress"] = maxf(0.0, c["stress"] - 0.8 * sim_hours)

	if c["current_action"] == "Eat" and resources["food"] > 0.0:
		var consumed := minf(resources["food"], 0.85 * sim_hours)
		resources["food"] -= consumed
		c["hunger"] = maxf(0.0, c["hunger"] - 12.0 * sim_hours)

	if c["current_action"] == "Drink" and resources["water"] > 0.0:
		var consumed := minf(resources["water"], 1.0 * sim_hours)
		resources["water"] -= consumed
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
	if c["thirst"] >= 58.0 and resources["water"] > 0.1:
		_set_action(c, "Drink", "command")
		return
	if c["hunger"] >= 62.0 and resources["food"] > 0.1:
		_set_action(c, "Eat", "command")
		return
	if c["fatigue"] >= 72.0 or hour >= 22.0 or hour < 5.0:
		_set_action(c, "Sleep", "housing")
		return

	if hour >= 7.0 and hour < 18.0:
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
	else:
		_set_action(c, "Free Time", "housing")

func _set_action(c: Dictionary, action: String, building_type: String) -> void:
	if c["current_action"] != action:
		c["current_action"] = action
		c["target"] = Vector2.ZERO
	c["target_building"] = building_type

func _apply_work_output(farmers: int, engineers: int, builders: int, medics: int, scavengers: int, sim_hours: float) -> void:
	resources["food"] += farmers * 0.48 * sim_hours
	resources["materials"] += builders * 0.15 * sim_hours
	resources["scrap"] += scavengers * 0.10 * sim_hours
	if engineers > 0:
		resources["power"] = minf(100.0, resources["power"] + engineers * 0.05 * sim_hours)
	if medics > 0 and resources["medicine"] > 0.0:
		for c in get_alive_citizens():
			if c["health"] < 92.0:
				c["health"] = minf(100.0, c["health"] + 0.06 * medics * sim_hours)

func _power_delta(population: int) -> float:
	var engineers := 0
	for c in get_alive_citizens():
		if c["job"] == "Engineer" and c["current_action"] == "Work: Engineering":
			engineers += 1
	return (engineers * 0.05) - (population * 0.012)

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

func get_average_health() -> float:
	var alive := get_alive_citizens()
	if alive.is_empty():
		return 0.0
	var total := 0.0
	for c in alive:
		total += float(c["health"])
	return total / alive.size()

func get_job_count(job: String) -> int:
	var count := 0
	for c in get_alive_citizens():
		if c["job"] == job:
			count += 1
	return count

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
