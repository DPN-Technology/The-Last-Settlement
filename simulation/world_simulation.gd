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
		{"id":3,"name":"North Ridge Relay","type":"relay","position":Vector2(520,180),"danger":0.30,"loot":{"scrap":12.0,"materials":8.0},"discovered":false,"depleted":false,"restored":false},
		{"id":4,"name":"Old County Clinic","type":"ruin","position":Vector2(360,290),"danger":0.46,"loot":{"medicine":12.0,"scrap":8.0},"discovered":false,"depleted":false},
		{"id":5,"name":"Blackwater Farm","type":"ruin","position":Vector2(870,560),"danger":0.18,"loot":{"food":42.0,"materials":6.0},"discovered":false,"depleted":false},
		{"id":6,"name":"East Freight Yard","type":"ruin","position":Vector2(1020,370),"danger":0.58,"loot":{"scrap":54.0,"materials":28.0},"discovered":false,"depleted":false},
		{"id":7,"name":"Unknown Signal","type":"signal","position":Vector2(260,610),"danger":0.65,"loot":{"medicine":5.0,"scrap":20.0},"discovered":false,"depleted":false},
		{"id":8,"name":"Collapsed Subdivision","type":"ruin","position":Vector2(690,690),"danger":0.36,"loot":{"food":18.0,"materials":18.0,"scrap":12.0},"discovered":false,"depleted":false},
		{"id":9,"name":"Cedar Junction","type":"trade_hub","position":Vector2(930,180),"danger":0.24,"loot":{},"discovered":false,"depleted":false,"faction":"Cedar Union"},
		{"id":10,"name":"Riverbend Enclave","type":"trade_hub","position":Vector2(190,420),"danger":0.32,"loot":{},"discovered":false,"depleted":false,"faction":"Riverbend Collective"},
		{"id":11,"name":"Ironwood Hold","type":"faction_settlement","position":Vector2(1080,650),"danger":0.74,"loot":{},"discovered":false,"depleted":false,"faction":"Iron Pact"},
		{"id":12,"name":"Lantern Station","type":"faction_settlement","position":Vector2(315,145),"danger":0.18,"loot":{},"discovered":false,"depleted":false,"faction":"Lantern Medics"}
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
		if location["type"] == "relay" and location["discovered"] and bool(location.get("restored",false)):
			relay_bonus += 140.0
	return RADIO_BASE_RANGE + relay_bonus

func get_discovered_locations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for location in locations:
		if location["discovered"]:
			result.append(location)
	return result

# Planning is side-effect free. UI, mouse input, and the actual dispatch use the
# exact same validation so an unavailable expedition cannot look actionable.
const STRATEGIES := ["balanced","cautious","rapid"]

static func strategy_speed(strategy: String) -> float:
	match strategy:
		"cautious": return 32.0
		"rapid": return 53.0
		_: return 42.0

static func strategy_search_hours(strategy: String) -> float:
	match strategy:
		"cautious": return 8.0
		"rapid": return 4.5
		_: return 6.0

func plan_expedition(sim: SettlementSimulation, location_id: int, requested_members: int = 3, strategy: String = "balanced") -> Dictionary:
	var plan := {"ok":false,"reason":"","members":[],"food_cost":0.0,"water_cost":0.0,"medicine_cost":0.0,"risk":0.0,"distance":0.0,"travel_hours":0.0,"search_hours":0.0,"strategy":strategy}
	if not STRATEGIES.has(strategy):
		plan["reason"]="Unknown mission strategy."
		return plan
	var destination := get_location_by_id(location_id)
	if destination.is_empty() or not bool(destination.get("discovered",false)):
		plan["reason"]="Choose a discovered location."
		return plan
	if location_id<=1 or bool(destination.get("depleted",false)) or str(destination.get("type","")) in ["settlement","player_settlement","trade_hub","faction_settlement"]:
		plan["reason"]="This site cannot be salvaged."
		return plan
	for expedition in get_active_expeditions():
		if int(expedition.get("destination_id",-1))==location_id:
			plan["reason"]="A team is already working at this site."
			return plan
	var candidates: Array[Dictionary] = []
	for citizen in sim.get_settlement_citizens():
		if int(citizen.get("age",0))<18 or bool(citizen.get("incarcerated",false)) or float(citizen.get("health",0.0))<30.0:
			continue
		var role := str(citizen.get("job",""))
		var role_bonus := 0.0
		match role:
			"Scavenger": role_bonus=75.0
			"Guard": role_bonus=65.0
			"Medic": role_bonus=45.0
			"Engineer": role_bonus=35.0
		var score := role_bonus+float(citizen["skills"].get("security",0))*0.2+float(citizen["health"])*0.08
		candidates.append({"id":int(citizen["id"]),"score":score})
	# Stable ordering makes the briefing honest and repeatable until staff change.
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if is_equal_approx(float(a["score"]),float(b["score"])):
			return int(a["id"])<int(b["id"])
		return float(a["score"])>float(b["score"])
	)
	var members: Array[int] = []
	var target_count := clampi(requested_members,1,4)
	for candidate in candidates:
		if members.size()>=target_count:
			break
		members.append(int(candidate["id"]))
	if members.size()<target_count:
		plan["reason"]="Only %d / %d fit adults available. Lower team size." % [members.size(),target_count]
		plan["members"]=members
		return plan
	var meal_per_member := 4.0 if strategy=="rapid" else 3.0
	var water_per_member := 5.0 if strategy=="cautious" else 4.0
	var food_cost := meal_per_member*members.size()
	var water_cost := water_per_member*members.size()
	var medicine_cost := 1.0 if float(sim.stockpiles["medical"].get("medicine",0.0))>=1.0 else 0.0
	var distance := Vector2(destination["position"]).distance_to(Vector2(600,410))
	var security := 0.0
	for id in members:
		var member := sim.get_citizen_by_id(id)
		security+=float(member["skills"].get("security",20))/100.0
	var strategy_risk := 0.72 if strategy=="cautious" else (1.3 if strategy=="rapid" else 1.0)
	var risk := clampf(maxf(0.05,float(destination["danger"])-security*0.08)*strategy_risk,0.02,0.95)
	plan["members"]=members
	plan["food_cost"]=food_cost
	plan["water_cost"]=water_cost
	plan["medicine_cost"]=medicine_cost
	plan["risk"]=risk
	plan["distance"]=distance
	plan["travel_hours"]=distance/strategy_speed(strategy)
	plan["search_hours"]=strategy_search_hours(strategy)
	if float(sim.stockpiles["command"].get("meals",0.0))<food_cost:
		plan["reason"]="Need %.0f prepared meals to provision the team." % food_cost
	elif float(sim.stockpiles["command"].get("water",0.0))<water_cost:
		plan["reason"]="Need %.0f clean water to provision the team." % water_cost
	else:
		plan["ok"]=true
		plan["reason"]="Ready for dispatch"
	return plan

func create_expedition(sim: SettlementSimulation, location_id: int, max_members: int = 3, strategy: String = "balanced") -> bool:
	var plan := plan_expedition(sim,location_id,max_members,strategy)
	if not bool(plan["ok"]):
		sim.add_event("EXPEDITION BLOCKED",str(plan["reason"]),"warning")
		return false
	var destination := get_location_by_id(location_id)
	var members: Array[int] = []
	for id in plan["members"]:
		members.append(int(id))
	# Debit supplies only after the complete plan was accepted; a rejected
	# dispatch never changes stockpiles or survivor assignments.
	sim.stockpiles["command"]["meals"]-=float(plan["food_cost"])
	sim.stockpiles["command"]["water"]-=float(plan["water_cost"])
	if float(plan["medicine_cost"])>0.0:
		sim.stockpiles["medical"]["medicine"]-=float(plan["medicine_cost"])
	for id in members:
		var member := sim.get_citizen_by_id(id)
		if str(member.get("job",""))=="Builder":
			for blueprint in sim.blueprints:
				if int(blueprint.get("assigned_builder",0))==id:
					blueprint["assigned_builder"]=0
		member["target_blueprint_id"]=0
		member["on_expedition"]=true
		member["target"]=Vector2.ZERO
		member["current_action"]="Expedition"
	var distance := float(plan["distance"])
	expeditions.append({
		"id":next_expedition_id,
		"destination_id":location_id,
		"members":members,
		"status":"outbound",
		"distance":distance,
		"progress":0.0,
		"elapsed_hours":0.0,
		"cargo":{"food":0.0,"water":0.0,"medicine":0.0,"materials":0.0,"scrap":0.0},
		"radio_contact":distance<=get_radio_range(),
		"encounter_resolved":false,
		"strategy":strategy,
		"estimated_risk":float(plan["risk"]),
		"search_hours":float(plan["search_hours"]),
		"travel_speed":strategy_speed(strategy)
	})
	next_expedition_id+=1
	sim.complete_field_objective("expedition")
	sim.add_event("EXPEDITION DEPARTED","%d survivors departed for %s (%s route)." % [members.size(),str(destination["name"]),strategy],"intel")
	return true

func _update_outbound(sim: SettlementSimulation, expedition: Dictionary, sim_hours: float) -> void:
	expedition["progress"] = float(expedition["progress"]) + float(expedition.get("travel_speed",42.0)) * sim_hours
	if float(expedition["progress"]) >= float(expedition["distance"]):
		expedition["status"] = "searching"
		expedition["progress"] = 0.0
		var location := get_location_by_id(int(expedition["destination_id"]))
		sim.add_event("EXPEDITION ARRIVED", "Team reached %s." % location["name"], "intel")

func _update_searching(sim: SettlementSimulation, expedition: Dictionary, sim_hours: float) -> void:
	expedition["progress"] = float(expedition["progress"]) + sim_hours
	if not expedition["encounter_resolved"]:
		_resolve_encounter(sim, expedition)
	if float(expedition["progress"]) >= float(expedition.get("search_hours",6.0)):
		_collect_loot(sim, expedition)
		expedition["status"] = "returning"
		expedition["progress"] = 0.0

func _update_returning(sim: SettlementSimulation, expedition: Dictionary, sim_hours: float) -> void:
	expedition["progress"] = float(expedition["progress"]) + float(expedition.get("travel_speed",42.0)) * sim_hours
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
	risk = float(expedition.get("estimated_risk",maxf(0.05, risk - security * 0.08)))
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
		var strategy := str(expedition.get("strategy","balanced"))
		var minimum := 0.70 if strategy=="cautious" else (0.40 if strategy=="rapid" else 0.55)
		var maximum := 1.0 if strategy!="rapid" else 0.85
		var recovered := amount * sim.rng.randf_range(minimum,maximum)
		cargo[key] = float(cargo.get(key,0.0)) + recovered
	location["depleted"] = true
	if location["type"] == "relay":
		location["restored"] = true
		sim.add_event("RADIO RELAY RESTORED", "The expedition restored a regional relay and permanently extended radio range.", "good")
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
