class_name CivilizationSimulation
extends RefCounted

const FOUNDING_MATERIAL_COST := 35.0
const FOUNDING_MEAL_COST := 20.0
const FOUNDING_WATER_COST := 30.0
const FOUNDING_PARTS_COST := 4.0
const FOUNDING_POPULATION := 4
const LOGISTICS_INTERVAL_HOURS := 24.0

var settlements: Dictionary = {
	"LAST_HAVEN":{
		"id":"LAST_HAVEN",
		"name":"Last Haven",
		"location_id":1,
		"founded_day":1,
		"population_ids":[],
		"population":0,
		"specialization":"Capital",
		"infrastructure":55.0,
		"morale":70.0,
		"security":45.0,
		"resources":{"food":0.0,"water":0.0,"medicine":0.0,"materials":0.0,"fuel":0.0,"parts":0.0},
		"active":true
	}
}
var logistics_routes: Array[Dictionary] = []
var history_archive: Array[Dictionary] = []
var recovery_score := 0.0
var civilization_stability := 50.0
var next_settlement_id := 2
var next_route_id := 1
var next_logistics_hour := 24.0
var endgame_stage := "SURVIVE"
var milestones := {
	"second_settlement":false,
	"regional_network":false,
	"stable_civilization":false,
	"recovery_threshold":false
}

func initialize(sim: SettlementSimulation) -> void:
	_sync_capital(sim)
	if history_archive.is_empty():
		record_history(sim,"THE FOUNDING","Last Haven established the first organized recovery settlement.","foundation")

func update(sim: SettlementSimulation, sim_hours: float) -> void:
	_sync_capital(sim)
	_update_secondary_settlements(sim,sim_hours)
	_update_recovery_score(sim)
	_update_endgame_stage(sim)
	if sim.total_hours >= next_logistics_hour:
		next_logistics_hour = sim.total_hours + LOGISTICS_INTERVAL_HOURS
		_process_logistics(sim)
		_check_milestones(sim)

func _sync_capital(sim:SettlementSimulation) -> void:
	var capital:Dictionary = settlements["LAST_HAVEN"]
	var citizens := sim.get_settlement_citizens()
	capital["population"] = citizens.size()
	capital["population_ids"] = []
	for c in citizens:
		capital["population_ids"].append(int(c["id"]))
	capital["morale"] = sim.get_average_morale()
	capital["security"] = sim.faction_simulation._settlement_defense(sim)
	capital["infrastructure"] = _capital_infrastructure(sim)
	capital["resources"] = {
		"food":float(sim.resources["food"]),
		"water":float(sim.resources["water"]),
		"medicine":float(sim.resources["medicine"]),
		"materials":float(sim.resources["materials"]),
		"fuel":float(sim.economy_simulation.industry_stock.get("fuel",0.0)),
		"parts":float(sim.economy_simulation.industry_stock.get("parts",0.0))
	}

func found_settlement(sim:SettlementSimulation, location_id:int) -> bool:
	var location := sim.world_simulation.get_location_by_id(location_id)
	if location.is_empty() or not location["discovered"]:
		sim.add_event("FOUNDING BLOCKED","The selected site is not in regional intelligence.","warning")
		return false
	if str(location["type"]) not in ["ruin","signal"]:
		sim.add_event("FOUNDING BLOCKED","Only secured ruins or cleared regional sites can become player settlements.","warning")
		return false
	if not bool(location.get("depleted",false)):
		sim.add_event("FOUNDING BLOCKED","The site must be secured and cleared by an expedition first.","warning")
		return false
	for settlement_key in settlements.keys():
		if int(settlements[settlement_key]["location_id"]) == location_id:
			sim.add_event("FOUNDING BLOCKED","A player settlement already occupies this site.","warning")
			return false

	if float(sim.stockpiles["industry"].get("materials",0.0)) < FOUNDING_MATERIAL_COST:
		sim.add_event("FOUNDING BLOCKED","35 materials are required to establish a settlement.","warning")
		return false
	if float(sim.stockpiles["command"].get("meals",0.0)) < FOUNDING_MEAL_COST:
		sim.add_event("FOUNDING BLOCKED","20 prepared meals are required to establish a settlement.","warning")
		return false
	if float(sim.stockpiles["command"].get("water",0.0)) < FOUNDING_WATER_COST:
		sim.add_event("FOUNDING BLOCKED","30 clean water are required to establish a settlement.","warning")
		return false
	if float(sim.economy_simulation.industry_stock.get("parts",0.0)) < FOUNDING_PARTS_COST:
		sim.add_event("FOUNDING BLOCKED","4 machine parts are required to establish a settlement.","warning")
		return false

	var colonists := _select_colonists(sim)
	if colonists.size() < FOUNDING_POPULATION:
		sim.add_event("FOUNDING BLOCKED","Four available adult colonists are required.","warning")
		return false

	sim.stockpiles["industry"]["materials"] -= FOUNDING_MATERIAL_COST
	sim.stockpiles["command"]["meals"] -= FOUNDING_MEAL_COST
	sim.stockpiles["command"]["water"] -= FOUNDING_WATER_COST
	sim.economy_simulation.industry_stock["parts"] -= FOUNDING_PARTS_COST

	var key := "COLONY_%02d" % next_settlement_id
	var settlement_name := _settlement_name_for(location)
	var ids:Array[int] = []
	for c in colonists:
		c["home_settlement"] = key
		c["current_action"] = "Colonist // %s" % settlement_name
		c["target"] = Vector2.ZERO
		ids.append(int(c["id"]))

	settlements[key] = {
		"id":key,
		"name":settlement_name,
		"location_id":location_id,
		"founded_day":sim.day,
		"population_ids":ids,
		"population":ids.size(),
		"specialization":_specialization_for(location),
		"infrastructure":28.0,
		"morale":66.0,
		"security":22.0,
		"resources":{
			"food":18.0,
			"water":24.0,
			"medicine":3.0,
			"materials":12.0,
			"fuel":4.0,
			"parts":1.0
		},
		"active":true
	}
	next_settlement_id += 1
	location["type"] = "player_settlement"
	location["depleted"] = false
	location["player_controlled"] = true
	location["settlement_key"] = key
	location["name"] = settlement_name

	_create_route("LAST_HAVEN",key)
	record_history(sim,"NEW SETTLEMENT FOUNDED","%s was founded at %s with %d colonists." % [settlement_name,location["name"],ids.size()],"expansion")
	sim.add_event("SETTLEMENT FOUNDED","%s joined the recovery network." % settlement_name,"good")
	return true

func _select_colonists(sim:SettlementSimulation) -> Array[Dictionary]:
	var candidates:Array[Dictionary] = []
	for c in sim.get_settlement_citizens():
		if int(c["age"]) < 18 or c.get("incarcerated",false) or c.get("on_expedition",false):
			continue
		if c["job"] in ["Engineer","Builder","Farmer","Medic","Guard","Hauler"]:
			candidates.append(c)
	candidates.sort_custom(func(a:Dictionary,b:Dictionary)->bool:
		var a_score := float(a["health"])+float(a["morale"])+float(a["loyalty"])
		var b_score := float(b["health"])+float(b["morale"])+float(b["loyalty"])
		return a_score > b_score
	)
	var selected:Array[Dictionary] = []
	for c in candidates:
		if selected.size() >= FOUNDING_POPULATION:
			break
		selected.append(c)
	return selected

func _update_secondary_settlements(sim:SettlementSimulation, sim_hours:float) -> void:
	for key in settlements.keys():
		if key == "LAST_HAVEN":
			continue
		var settlement:Dictionary = settlements[key]
		if not settlement["active"]:
			continue
		_sync_colony_population(sim,settlement)
		var pop := float(settlement["population"])
		var res:Dictionary = settlement["resources"]
		var specialization := str(settlement["specialization"])

		res["food"] = maxf(0.0,float(res["food"]) - pop*0.035*sim_hours)
		res["water"] = maxf(0.0,float(res["water"]) - pop*0.055*sim_hours)
		match specialization:
			"Agriculture":
				res["food"] = float(res["food"]) + pop*0.075*sim_hours
			"Industry":
				res["materials"] = float(res["materials"]) + pop*0.045*sim_hours
				res["parts"] = float(res["parts"]) + pop*0.008*sim_hours
			"Medical":
				res["medicine"] = float(res["medicine"]) + pop*0.012*sim_hours
			"Logistics":
				res["fuel"] = float(res["fuel"]) + pop*0.018*sim_hours
			_:
				res["materials"] = float(res["materials"]) + pop*0.018*sim_hours

		var supply_score := 100.0
		if float(res["food"]) < pop*2.0:
			supply_score -= 35.0
		if float(res["water"]) < pop*3.0:
			supply_score -= 35.0
		settlement["morale"] = move_toward(float(settlement["morale"]),clampf(supply_score,20.0,90.0),0.12*sim_hours)
		settlement["infrastructure"] = minf(100.0,float(settlement["infrastructure"])+0.008*sim_hours)
		settlement["security"] = minf(100.0,float(settlement["security"])+0.005*sim_hours)

func _sync_colony_population(sim:SettlementSimulation, settlement:Dictionary) -> void:
	var live_ids:Array[int] = []
	for id in settlement["population_ids"]:
		var c := sim.get_citizen_by_id(int(id))
		if not c.is_empty() and c["alive"]:
			live_ids.append(int(id))
	settlement["population_ids"] = live_ids
	settlement["population"] = live_ids.size()

func _process_logistics(sim:SettlementSimulation) -> void:
	for route in logistics_routes:
		if not route["active"]:
			continue
		var source:Dictionary = settlements[str(route["source"])]
		var destination:Dictionary = settlements[str(route["destination"])]
		if not source["active"] or not destination["active"]:
			continue
		var moved := _route_transfer(source,destination)
		route["last_transfer"] = moved
		route["last_day"] = sim.day
		if moved > 0.0:
			sim.add_event("REGIONAL LOGISTICS","Route %s → %s moved %.0f units of surplus." % [source["name"],destination["name"],moved],"intel")

func _route_transfer(source:Dictionary, destination:Dictionary) -> float:
	var moved := 0.0
	var source_res:Dictionary = source["resources"]
	var dest_res:Dictionary = destination["resources"]
	for item in ["food","water","medicine","materials","fuel","parts"]:
		var source_target := maxf(4.0,float(source["population"])*2.0)
		var dest_target := maxf(6.0,float(destination["population"])*2.5)
		var surplus := maxf(0.0,float(source_res.get(item,0.0))-source_target)
		var need := maxf(0.0,dest_target-float(dest_res.get(item,0.0)))
		var transfer := minf(surplus,need,12.0)
		if transfer > 0.0:
			source_res[item] = float(source_res.get(item,0.0))-transfer
			dest_res[item] = float(dest_res.get(item,0.0))+transfer
			moved += transfer
	return moved

func _create_route(source:String,destination:String) -> void:
	logistics_routes.append({
		"id":next_route_id,
		"source":source,
		"destination":destination,
		"active":true,
		"last_transfer":0.0,
		"last_day":0
	})
	next_route_id += 1

func _update_recovery_score(sim:SettlementSimulation) -> void:
	var settlement_count := settlements.size()
	var population := 0
	var infrastructure_total := 0.0
	var morale_total := 0.0
	for key in settlements.keys():
		var s:Dictionary = settlements[key]
		if not s["active"]:
			continue
		population += int(s["population"])
		infrastructure_total += float(s["infrastructure"])
		morale_total += float(s["morale"])
	var avg_infrastructure := infrastructure_total/maxf(1.0,float(settlement_count))
	var avg_morale := morale_total/maxf(1.0,float(settlement_count))
	var allied := 0
	for faction_name in sim.faction_simulation.factions.keys():
		if str(sim.faction_simulation.factions[faction_name]["disposition"]) == "ALLIED":
			allied += 1
	recovery_score = clampf(
		float(settlement_count-1)*14.0 +
		minf(25.0,float(population)*0.65) +
		avg_infrastructure*0.24 +
		avg_morale*0.18 +
		float(allied)*6.0,
		0.0,100.0
	)
	civilization_stability = clampf(
		avg_morale*0.35 +
		avg_infrastructure*0.30 +
		(100.0-float(sim.governance_simulation.unrest))*0.20 +
		float(sim.governance_simulation.legitimacy)*0.15,
		0.0,100.0
	)

func _update_endgame_stage(sim:SettlementSimulation) -> void:
	var old_stage := endgame_stage
	if recovery_score >= 85.0 and settlements.size() >= 3:
		endgame_stage = "REBUILD CIVILIZATION"
	elif recovery_score >= 65.0:
		endgame_stage = "REGIONAL POWER"
	elif settlements.size() >= 2:
		endgame_stage = "EXPAND"
	elif sim.day >= 20:
		endgame_stage = "STABILIZE"
	else:
		endgame_stage = "SURVIVE"
	if old_stage != endgame_stage:
		record_history(sim,"RECOVERY PHASE // %s" % endgame_stage,"Civilization recovery advanced from %s to %s." % [old_stage,endgame_stage],"milestone")
		sim.add_event("RECOVERY PHASE","Civilization directive advanced to %s." % endgame_stage,"good")

func _check_milestones(sim:SettlementSimulation) -> void:
	if settlements.size() >= 2 and not milestones["second_settlement"]:
		milestones["second_settlement"] = true
		record_history(sim,"THE SECOND SETTLEMENT","The recovery network became a multi-settlement civilization.","milestone")
	if logistics_routes.size() >= 2 and not milestones["regional_network"]:
		milestones["regional_network"] = true
		record_history(sim,"THE REGIONAL NETWORK","Permanent logistics routes connected multiple settlements.","milestone")
	if civilization_stability >= 75.0 and not milestones["stable_civilization"]:
		milestones["stable_civilization"] = true
		record_history(sim,"THE STABLE YEARS","The recovery network achieved sustained regional stability.","milestone")
	if recovery_score >= 85.0 and not milestones["recovery_threshold"]:
		milestones["recovery_threshold"] = true
		record_history(sim,"CIVILIZATION RESTORED","The regional network crossed the civilization recovery threshold.","endgame")

func record_history(sim:SettlementSimulation,title:String,body:String,kind:String) -> void:
	history_archive.push_front({
		"day":sim.day,
		"hour":sim.hour,
		"title":title,
		"body":body,
		"kind":kind
	})
	if history_archive.size() > 80:
		history_archive.resize(80)

func get_settlement_list() -> Array[Dictionary]:
	var result:Array[Dictionary] = []
	for key in settlements.keys():
		result.append(settlements[key])
	return result

func get_foundable_locations(sim:SettlementSimulation) -> Array[Dictionary]:
	var result:Array[Dictionary] = []
	for location in sim.world_simulation.locations:
		if not location["discovered"] or not bool(location.get("depleted",false)):
			continue
		if str(location["type"]) in ["ruin","signal"]:
			var occupied := false
			for key in settlements.keys():
				if int(settlements[key]["location_id"]) == int(location["id"]):
					occupied = true
					break
			if not occupied:
				result.append(location)
	return result

func _capital_infrastructure(sim:SettlementSimulation) -> float:
	if sim.buildings.is_empty():
		return 0.0
	var total := 0.0
	for b in sim.buildings:
		total += float(b.get("condition",100.0))
	return total/float(sim.buildings.size())

func _settlement_name_for(location:Dictionary) -> String:
	var source := str(location["name"])
	if source.contains("Farm"):
		return "New Harvest"
	if source.contains("Clinic"):
		return "Mercy Point"
	if source.contains("Freight"):
		return "Foundry Junction"
	if source.contains("Subdivision"):
		return "Hearthside"
	if source.contains("Signal"):
		return "Signal Watch"
	return "Recovery Site %02d" % next_settlement_id

func _specialization_for(location:Dictionary) -> String:
	var source := str(location["name"])
	if source.contains("Farm"):
		return "Agriculture"
	if source.contains("Clinic"):
		return "Medical"
	if source.contains("Freight"):
		return "Industry"
	if source.contains("Service"):
		return "Logistics"
	return "General"
