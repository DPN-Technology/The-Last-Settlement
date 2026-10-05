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

func _init() -> void:
	rng.randomize()
	_create_buildings()
	for i in range(12):
		add_citizen()
	add_event("SETTLEMENT ONLINE", "Twelve survivors have established a temporary command camp.", "good")

func _create_buildings() -> void:
	buildings = [
		{"name":"Command","type":"command","position":Vector2(700,380),"size":Vector2(170,100),"condition":100.0},
		{"name":"Shelter A","type":"housing","position":Vector2(465,295),"size":Vector2(150,90),"condition":86.0},
		{"name":"Shelter B","type":"housing","position":Vector2(470,500),"size":Vector2(150,90),"condition":81.0},
		{"name":"Workshop","type":"industry","position":Vector2(930,300),"size":Vector2(180,100),"condition":78.0},
		{"name":"Clinic","type":"medical","position":Vector2(930,515),"size":Vector2(150,95),"condition":91.0},
		{"name":"Farm","type":"farm","position":Vector2(705,620),"size":Vector2(250,105),"condition":74.0},
		{"name":"Generator","type":"power","position":Vector2(1190,430),"size":Vector2(135,100),"condition":69.0}
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
	resources["food"] = maxf(0.0, resources["food"] - population * 0.020 * sim_hours)
	resources["water"] = maxf(0.0, resources["water"] - population * 0.032 * sim_hours)
	resources["power"] = clampf(resources["power"] + _power_delta(population) * sim_hours, 0.0, 100.0)

	var farmers := 0
	var engineers := 0
	var medics := 0
	for c in alive:
		match c["job"]:
			"Farmer": farmers += 1
			"Engineer": engineers += 1
			"Medic": medics += 1
		c["hunger"] = minf(100.0, c["hunger"] + 0.075 * sim_hours)
		c["thirst"] = minf(100.0, c["thirst"] + 0.11 * sim_hours)
		c["fatigue"] = fmod(c["fatigue"] + 0.055 * sim_hours, 100.0)
		if resources["food"] <= 0.1:
			c["hunger"] = minf(100.0, c["hunger"] + 0.65 * sim_hours)
		if resources["water"] <= 0.1:
			c["thirst"] = minf(100.0, c["thirst"] + 1.1 * sim_hours)
		if c["hunger"] > 85.0 or c["thirst"] > 85.0:
			c["health"] = maxf(0.0, c["health"] - 0.4 * sim_hours)
		if c["health"] <= 0.0 and c["alive"]:
			c["alive"] = false
			add_event("SURVIVOR LOST", "%s has died." % c["name"], "critical")

	resources["food"] += farmers * 0.055 * sim_hours
	resources["materials"] += engineers * 0.018 * sim_hours
	if medics > 0:
		for c in alive:
			if c["health"] < 92.0:
				c["health"] = minf(100.0, c["health"] + 0.045 * medics * sim_hours)

	event_director.update(self)

func _power_delta(population: int) -> float:
	var engineers := 0
	for c in get_alive_citizens():
		if c["job"] == "Engineer":
			engineers += 1
	return (engineers * 0.035) - (population * 0.0075)

func get_alive_citizens() -> Array[Dictionary]:
	var alive: Array[Dictionary] = []
	for c in citizens:
		if c["alive"]:
			alive.append(c)
	return alive

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

func add_event(title: String, body: String, severity: String) -> void:
	events.push_front({
		"title": title,
		"body": body,
		"severity": severity,
		"day": day,
		"hour": hour
	})
	if events.size() > 10:
		events.resize(10)
