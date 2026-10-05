class_name WorldSimulation
extends RefCounted

const REGION_SIZE := Vector2(1200, 820)
const RADIO_BASE_RANGE := 360.0

var locations: Array[Dictionary] = []
var expeditions: Array[Dictionary] = []
var discovered_location_ids: Array[int] = []
var next_expedition_id := 1

func initialize(rng: RandomNumberGenerator) -> void:
	if not locations.is_empty():
		return
	locations = [
		{"id":1,"name":"Last Haven","type":"settlement","position":Vector2(600,410),"danger":0.0,"loot":{},"discovered":true,"depleted":false},
		{"id":2,"name":"Ash Creek Service Station","type":"ruin","position":Vector2(780,310),"danger":0.22,"loot":{"scrap":24.0,"materials":10.0,"medicine":2.0},"discovered":false,"depleted":false},
		{"id":3,"name":"North Ridge Relay","type":"relay","position":Vector2(520,180),"danger":0.30,"loot":{"scrap":12.0,"materials":8.0},"discovered":false,"depleted":false},
		{"id":4,"name":"Old County Clinic","type":"ruin","position":Vector2(360,290),"danger":0.46,"loot":{"medicine":12.0,"scrap":8.0},"discovered":false,"depleted":false},
		{"id":5,"name":"Blackwater Farm","type":"ruin","position":Vector2(870,560),"danger":0.18,"loot":{"food":42.0,"materials":6.0},"discovered":false,"depleted":false},
		{"id":6,"name":"East Freight Yard","type":"ruin","position":Vector2(1020,370),"danger":0.58,"loot":{"scrap":54.0,"materials":28.0},"discovered":false,"depleted":false},
		{"id":7,"name":"Unknown Signal","type":"signal","position":Vector2(260,610),"danger":0.65,"loot":{"medicine":5.0,"scrap":20.0},"discovered":false,"depleted":false},
		{"id":8,"name":"Collapsed Subdivision","type":"ruin","position":Vector2(690,690),"danger":0.36,"loot":{"food":18.0,"materials":18.0,"scrap":12.0},"discovered":false,"depleted":false},
		{"id":9,"name":"Cedar Junction","type":"trade_hub","position":Vector2(930,180),"danger":0.24,"loot":{},"discovered":false,"depleted":false,"faction":"Cedar Union"},
		{"id":10,"name":"Riverbend Enclave","type":"trade_hub","position":Vector2(190,420),"danger":0.32,"loot":{},"discovered":false,"depleted":false,"faction":"Riverbend Collective"}
	]
	discovered_location_ids = [1]
	_update_fog_of_war()

func update(sim: SettlementSimulation, sim_hours: float) -> void:
	_update_fog_of_war()
	for expedition in expeditions:
		if expedition["status"] in ["returned","lost"]:
			continue
		expedition["elapsed_hours"] = float(expedition["elapsed_hours"]) + sim_hours
		match expedition["status"]:
			"outbound":
				_update_outbound(sim, expedition, sim_hours)
			"searching":
				_update_searching(sim, expedition, sim_hours)
			"returning":
				_update_returning(sim, expedition, sim_hours)

func _update_fog_of_war() -> void:
	for location in locations:
		if location["discovered"]:
			continue
		if Vector2(location["position"]).distance_to(Vector2(600,410)) <= get_radio_range():
			location["discovered"] = true
			discovered_location_ids.append(int(location["id"]))

func get_radio_range() -> float:
	var relay_bonus := 0.0
	for location in locations:
		if location["type"] == "relay" and location["discovered"] and not location["depleted"]:
			relay_bonus += 140.0
	return RADIO_BASE_RANGE + relay_bonus

func get_discovered_locations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for location in locations:
		if location["discovered"]:
			result.append(location)
	return result

func create_expedition(sim: SettlementSimulation, location_id: int, max_members: int = 3) -> bool:
	var destination := get_location_by_id(location_id)
	if destination.is_empty() or not destination["discovered"] or destination["depleted"]:
		return false
	var members: Array[int] = []
	for citizen in sim.get_alive_citizens():
		if members.size() >= max_members:
			break
		if int(citizen["age"]) < 18:
			continue
		if citizen.get("on_expedition", false):
			continue
		if citizen["job"] in ["Scavenger","Guard","Medic","Engineer"]:
			members.append(int(citizen["id"]))
	if members.is_empty():
		sim.add_event("EXPEDITION BLOCKED", "No suitable adult survivors are available.", "warning")
		return false
	var food_cost := 3.0 * members.size()
	var water_cost := 4.0 * members.size()
	var med_cost := 1.0
	if float(sim.stockpiles["command"].get("meals",0.0)) < food_cost or float(sim.stockpiles["command"].get("water",0.0)) < water_cost:
		sim.add_event("EXPEDITION BLOCKED", "Insufficient expedition food or water.", "warning")
		return false
	sim.stockpiles["command"]["meals"] -= food_cost
	sim.stockpiles["command"]["water"] -= water_cost
	if float(sim.stockpiles["medical"].get("medicine",0.0)) >= med_cost:
		sim.stockpiles["medical"]["medicine"] -= med_cost
	for id in members:
		var member := sim.get_citizen_by_id(id)
		member["on_expedition"] = true
		member["current_action"] = "Expedition"
	var distance := Vector2(destination["position"]).distance_to(Vector2(600,410))
	expeditions.append({
		"id":next_expedition_id,
		"destination_id":location_id,
		"members":members,
		"status":"outbound",
		"distance":distance,
		"progress":0.0,
		"elapsed_hours":0.0,
		"cargo":{"food":0.0,"water":0.0,"medicine":0.0,"materials":0.0,"scrap":0.0},
		"radio_contact":distance <= get_radio_range(),
		"encounter_resolved":false
	})
	next_expedition_id += 1
	sim.add_event("EXPEDITION DEPARTED", "%d survivors departed for %s." % [members.size(), destination["name"]], "intel")
	return true

func _update_outbound(sim: SettlementSimulation, expedition: Dictionary, sim_hours: float) -> void:
	expedition["progress"] = float(expedition["progress"]) + 42.0 * sim_hours
	if float(expedition["progress"]) >= float(expedition["distance"]):
		expedition["status"] = "searching"
		expedition["progress"] = 0.0
		var location := get_location_by_id(int(expedition["destination_id"]))
		sim.add_event("EXPEDITION ARRIVED", "Team reached %s." % location["name"], "intel")

func _update_searching(sim: SettlementSimulation, expedition: Dictionary, sim_hours: float) -> void:
	expedition["progress"] = float(expedition["progress"]) + sim_hours
	if not expedition["encounter_resolved"]:
		_resolve_encounter(sim, expedition)
	if float(expedition["progress"]) >= 6.0:
		_collect_loot(sim, expedition)
		expedition["status"] = "returning"
		expedition["progress"] = 0.0

func _update_returning(sim: SettlementSimulation, expedition: Dictionary, sim_hours: float) -> void:
	expedition["progress"] = float(expedition["progress"]) + 42.0 * sim_hours
	if float(expedition["progress"]) >= float(expedition["distance"]):
		_return_home(sim, expedition)

func _resolve_encounter(sim: SettlementSimulation, expedition: Dictionary) -> void:
	expedition["encounter_resolved"] = true
	var location := get_location_by_id(int(expedition["destination_id"]))
	var risk := float(location["danger"])
	var security := 0.0
	for id in expedition["members"]:
		var member := sim.get_citizen_by_id(int(id))
		if member.is_empty() or not member["alive"]:
			continue
		security += float(member["skills"].get("security",20)) / 100.0
	risk = maxf(0.05, risk - security * 0.08)
	var roll := sim.rng.randf()
	if roll < risk * 0.18:
		var victim := _random_live_member(sim, expedition)
		if not victim.is_empty():
			victim["alive"] = false
			victim["health"] = 0.0
			sim.add_event("EXPEDITION CASUALTY", "%s was killed near %s." % [victim["name"], location["name"]], "critical")
	elif roll < risk * 0.55:
		var injured := _random_live_member(sim, expedition)
		if not injured.is_empty():
			injured["injury"] = "Expedition Trauma"
			injured["health"] = maxf(10.0, float(injured["health"]) - 28.0)
			sim.add_event("EXPEDITION INJURY", "%s was injured at %s." % [injured["name"], location["name"]], "warning")
	else:
		sim.add_event("AREA SECURED", "Expedition secured %s without major losses." % location["name"], "good")

func _collect_loot(sim: SettlementSimulation, expedition: Dictionary) -> void:
	var location := get_location_by_id(int(expedition["destination_id"]))
	var cargo: Dictionary = expedition["cargo"]
	for key in location["loot"].keys():
		var amount := float(location["loot"][key])
		var recovered := amount * sim.rng.randf_range(0.55, 1.0)
		cargo[key] = float(cargo.get(key,0.0)) + recovered
	location["depleted"] = true
	if location["type"] == "relay":
		sim.add_event("RADIO RELAY RESTORED", "The expedition restored a regional relay and extended radio range.", "good")
	else:
		sim.add_event("SALVAGE SECURED", "Expedition recovered supplies from %s." % location["name"], "good")

func _return_home(sim: SettlementSimulation, expedition: Dictionary) -> void:
	expedition["status"] = "returned"
	for id in expedition["members"]:
		var member := sim.get_citizen_by_id(int(id))
		if member.is_empty():
			continue
		member["on_expedition"] = false
		if member["alive"]:
			member["current_action"] = "Returned from expedition"
			member["stress"] = minf(100.0, float(member["stress"]) + 4.0)
	var cargo: Dictionary = expedition["cargo"]
	sim.stockpiles["command"]["food"] = float(sim.stockpiles["command"].get("food",0.0)) + float(cargo.get("food",0.0))
	sim.stockpiles["command"]["water"] = float(sim.stockpiles["command"].get("water",0.0)) + float(cargo.get("water",0.0))
	sim.stockpiles["medical"]["medicine"] = float(sim.stockpiles["medical"].get("medicine",0.0)) + float(cargo.get("medicine",0.0))
	sim.stockpiles["industry"]["materials"] = float(sim.stockpiles["industry"].get("materials",0.0)) + float(cargo.get("materials",0.0))
	sim.stockpiles["industry"]["scrap"] = float(sim.stockpiles["industry"].get("scrap",0.0)) + float(cargo.get("scrap",0.0))
	var location := get_location_by_id(int(expedition["destination_id"]))
	sim.add_event("EXPEDITION RETURNED", "Team returned from %s with recovered supplies." % location["name"], "good")

func get_location_by_id(id: int) -> Dictionary:
	for location in locations:
		if int(location["id"]) == id:
			return location
	return {}

func get_active_expeditions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for expedition in expeditions:
		if expedition["status"] not in ["returned","lost"]:
			result.append(expedition)
	return result

func _random_live_member(sim: SettlementSimulation, expedition: Dictionary) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for id in expedition["members"]:
		var member := sim.get_citizen_by_id(int(id))
		if not member.is_empty() and member["alive"]:
			candidates.append(member)
	if candidates.is_empty():
		expedition["status"] = "lost"
		return {}
	return candidates[sim.rng.randi_range(0,candidates.size()-1)]
