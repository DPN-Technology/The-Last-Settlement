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
		"status":"STABLE",
		"emergency":"",
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
var next_colony_event_hour := 48.0
var endgame_stage := "SURVIVE"
var civilization_policies := {
	"autonomy":"Balanced",
	"freight":"Balanced",
	"security":"Mutual Defense"
}
var emergency_log: Array[Dictionary] = []
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
	if sim.total_hours >= next_colony_event_hour:
		next_colony_event_hour = sim.total_hours + sim.rng.randf_range(36.0,72.0)
		_roll_colony_emergency(sim)
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
	var original_site_name := str(location["name"])
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
		"status":"STABLE",
		"emergency":"",
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
	record_history(sim,"NEW SETTLEMENT FOUNDED","%s was founded at %s with %d colonists." % [settlement_name,original_site_name,ids.size()],"expansion")
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
		var autonomy_factor := _autonomy_factor()

		res["food"] = maxf(0.0,float(res["food"]) - pop*0.035*sim_hours)
		res["water"] = maxf(0.0,float(res["water"]) - pop*0.055*sim_hours)
		match specialization:
			"Agriculture":
				res["food"] = float(res["food"]) + pop*0.075*sim_hours*autonomy_factor
			"Industry":
				res["materials"] = float(res["materials"]) + pop*0.045*sim_hours*autonomy_factor
				res["parts"] = float(res["parts"]) + pop*0.008*sim_hours*autonomy_factor
			"Medical":
				res["medicine"] = float(res["medicine"]) + pop*0.012*sim_hours*autonomy_factor
			"Logistics":
				res["fuel"] = float(res["fuel"]) + pop*0.018*sim_hours*autonomy_factor
			_:
				res["materials"] = float(res["materials"]) + pop*0.018*sim_hours*autonomy_factor

		var supply_score := 100.0
		if float(res["food"]) < pop*2.0:
			supply_score -= 35.0
		if float(res["water"]) < pop*3.0:
			supply_score -= 35.0
		settlement["morale"] = move_toward(float(settlement["morale"]),clampf(supply_score,20.0,90.0),0.12*sim_hours)
		settlement["infrastructure"] = minf(100.0,float(settlement["infrastructure"])+0.008*sim_hours)
		var security_gain := 0.005*sim_hours
		if civilization_policies["security"] == "Fortress Network":
			security_gain *= 2.4
		elif civilization_policies["security"] == "Mutual Defense":
			security_gain *= 1.6
		elif civilization_policies["security"] == "Local Defense":
			security_gain *= 0.8
		settlement["security"] = minf(100.0,float(settlement["security"])+security_gain)
		_update_colony_status(settlement)

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
		var source_key := str(route["source"])
		var destination_key := str(route["destination"])
		var source:Dictionary = settlements[source_key]
		var destination:Dictionary = settlements[destination_key]
		if not source["active"] or not destination["active"]:
			continue

		var outbound := _route_transfer(sim,source_key,destination_key,route)
		var inbound := _route_transfer(sim,destination_key,source_key,route)
		var moved := outbound + inbound
		route["last_transfer"] = moved
		route["last_day"] = sim.day
		if moved > 0.0:
			sim.add_event("REGIONAL LOGISTICS","%s ↔ %s moved %.0f units through the recovery network." % [source["name"],destination["name"],moved],"intel")

func _route_transfer(sim:SettlementSimulation, source_key:String, destination_key:String, route:Dictionary) -> float:
	var source:Dictionary = settlements[source_key]
	var destination:Dictionary = settlements[destination_key]
	var moved := 0.0
	var items := ["food","water","medicine","materials","fuel","parts"]
	var focus := str(route.get("focus","Balanced"))
	if focus == "Survival":
		items = ["food","water","medicine"]
	elif focus == "Industrial":
		items = ["materials","fuel","parts"]
	for item in items:
		var source_target := maxf(4.0,float(source["population"])*2.0)
		var dest_target := maxf(6.0,float(destination["population"])*2.5)
		var source_amount := _resource_amount(sim,source_key,item)
		var dest_amount := _resource_amount(sim,destination_key,item)
		var surplus := maxf(0.0,source_amount-source_target)
		var need := maxf(0.0,dest_target-dest_amount)
		var priority := int(route.get("priority",2))
		var freight_factor := _freight_factor()
		var transfer_cap := (6.0 + float(priority)*3.0)*freight_factor
		var transfer := minf(minf(surplus,need),transfer_cap)
		if transfer > 0.0:
			_change_resource(sim,source_key,item,-transfer)
			_change_resource(sim,destination_key,item,transfer)
			moved += transfer
	return moved

func _resource_amount(sim:SettlementSimulation, settlement_key:String, item:String) -> float:
	if settlement_key != "LAST_HAVEN":
		return float(settlements[settlement_key]["resources"].get(item,0.0))
	match item:
		"food":
			return float(sim.resources["food"])
		"water":
			return float(sim.resources["water"])
		"medicine":
			return float(sim.resources["medicine"])
		"materials":
			return float(sim.resources["materials"])
		"fuel":
			return float(sim.economy_simulation.industry_stock.get("fuel",0.0))
		"parts":
			return float(sim.economy_simulation.industry_stock.get("parts",0.0))
	return 0.0

func _change_resource(sim:SettlementSimulation, settlement_key:String, item:String, delta:float) -> void:
	if settlement_key != "LAST_HAVEN":
		var resources:Dictionary = settlements[settlement_key]["resources"]
		resources[item] = maxf(0.0,float(resources.get(item,0.0))+delta)
		return
	match item:
		"food":
			var command_food := float(sim.stockpiles["command"].get("food",0.0))
			if delta < 0.0:
				var from_command := minf(command_food,-delta)
				sim.stockpiles["command"]["food"] = command_food-from_command
				var remaining := -delta-from_command
				if remaining > 0.0:
					sim.stockpiles["farm"]["food"] = maxf(0.0,float(sim.stockpiles["farm"].get("food",0.0))-remaining)
			else:
				sim.stockpiles["command"]["food"] = command_food+delta
		"water":
			sim.stockpiles["command"]["water"] = maxf(0.0,float(sim.stockpiles["command"].get("water",0.0))+delta)
		"medicine":
			sim.stockpiles["medical"]["medicine"] = maxf(0.0,float(sim.stockpiles["medical"].get("medicine",0.0))+delta)
		"materials":
			sim.stockpiles["industry"]["materials"] = maxf(0.0,float(sim.stockpiles["industry"].get("materials",0.0))+delta)
		"fuel":
			sim.economy_simulation.industry_stock["fuel"] = maxf(0.0,float(sim.economy_simulation.industry_stock.get("fuel",0.0))+delta)
		"parts":
			sim.economy_simulation.industry_stock["parts"] = maxf(0.0,float(sim.economy_simulation.industry_stock.get("parts",0.0))+delta)

func _create_route(source:String,destination:String) -> void:
	logistics_routes.append({
		"id":next_route_id,
		"source":source,
		"destination":destination,
		"active":true,
		"priority":2,
		"focus":"Balanced",
		"last_transfer":0.0,
		"last_day":0
	})
	next_route_id += 1


func toggle_route(route_id:int) -> bool:
	for route in logistics_routes:
		if int(route["id"]) == route_id:
			route["active"] = not bool(route["active"])
			return true
	return false

func cycle_route_priority(route_id:int) -> bool:
	for route in logistics_routes:
		if int(route["id"]) == route_id:
			var priority := int(route.get("priority",2)) + 1
			if priority > 3:
				priority = 1
			route["priority"] = priority
			return true
	return false

func cycle_route_focus(route_id:int) -> bool:
	var focuses := ["Balanced","Survival","Industrial"]
	for route in logistics_routes:
		if int(route["id"]) == route_id:
			var current := str(route.get("focus","Balanced"))
			var idx := focuses.find(current)
			route["focus"] = focuses[(idx+1)%focuses.size()]
			return true
	return false

func cycle_settlement_specialization(sim:SettlementSimulation, settlement_key:String) -> bool:
	if settlement_key == "LAST_HAVEN" or not settlements.has(settlement_key):
		return false
	var options := ["General","Agriculture","Industry","Medical","Logistics"]
	var settlement:Dictionary = settlements[settlement_key]
	var current := str(settlement["specialization"])
	var idx := options.find(current)
	var next: String = str(options[(idx+1)%options.size()])
	if float(sim.stockpiles["industry"].get("materials",0.0)) < 8.0 or float(sim.economy_simulation.industry_stock.get("parts",0.0)) < 1.0:
		sim.add_event("COLONY REFOCUS BLOCKED","8 materials and 1 machine part are required.","warning")
		return false
	sim.stockpiles["industry"]["materials"] -= 8.0
	sim.economy_simulation.industry_stock["parts"] -= 1.0
	settlement["specialization"] = next
	settlement["infrastructure"] = maxf(10.0,float(settlement["infrastructure"])-2.0)
	record_history(sim,"COLONY REORGANIZED","%s changed specialization from %s to %s." % [settlement["name"],current,next],"policy")
	sim.add_event("COLONY REFOCUSED","%s specialization changed to %s." % [settlement["name"],next],"intel")
	return true

func send_emergency_aid(sim:SettlementSimulation, settlement_key:String) -> bool:
	if settlement_key == "LAST_HAVEN" or not settlements.has(settlement_key):
		return false
	if float(sim.stockpiles["command"].get("food",0.0)) < 8.0 or float(sim.stockpiles["command"].get("water",0.0)) < 12.0 or float(sim.stockpiles["medical"].get("medicine",0.0)) < 2.0:
		sim.add_event("AID BLOCKED","Emergency aid requires 8 food, 12 water and 2 medicine.","warning")
		return false
	sim.stockpiles["command"]["food"] -= 8.0
	sim.stockpiles["command"]["water"] -= 12.0
	sim.stockpiles["medical"]["medicine"] -= 2.0
	var settlement:Dictionary = settlements[settlement_key]
	var res:Dictionary = settlement["resources"]
	res["food"] = float(res["food"])+8.0
	res["water"] = float(res["water"])+12.0
	res["medicine"] = float(res["medicine"])+2.0
	settlement["morale"] = minf(100.0,float(settlement["morale"])+8.0)
	settlement["infrastructure"] = minf(100.0,float(settlement["infrastructure"])+4.0)
	var old_emergency := str(settlement.get("emergency",""))
	settlement["emergency"] = ""
	settlement["status"] = "RECOVERING"
	record_history(sim,"EMERGENCY AID","Last Haven stabilized %s after %s." % [settlement["name"],old_emergency if old_emergency != "" else "a supply crisis"],"aid")
	sim.add_event("EMERGENCY AID DELIVERED","%s received emergency recovery supplies." % settlement["name"],"good")
	return true

func cycle_policy(sim:SettlementSimulation, policy_key:String) -> bool:
	var options := {
		"autonomy":["Centralized","Balanced","Autonomous"],
		"freight":["Conservative","Balanced","Aggressive"],
		"security":["Local Defense","Mutual Defense","Fortress Network"]
	}
	if not options.has(policy_key):
		return false
	var values:Array = options[policy_key]
	var current := str(civilization_policies[policy_key])
	var idx := values.find(current)
	civilization_policies[policy_key] = values[(idx+1)%values.size()]
	record_history(sim,"CIVILIZATION POLICY","%s policy changed to %s." % [policy_key.capitalize(),civilization_policies[policy_key]],"policy")
	sim.add_event("NETWORK POLICY","%s policy set to %s." % [policy_key.capitalize(),civilization_policies[policy_key]],"intel")
	return true

func _autonomy_factor() -> float:
	match str(civilization_policies["autonomy"]):
		"Autonomous":
			return 1.12
		"Centralized":
			return 0.92
		_:
			return 1.0

func _freight_factor() -> float:
	match str(civilization_policies["freight"]):
		"Aggressive":
			return 1.35
		"Conservative":
			return 0.75
		_:
			return 1.0

func _roll_colony_emergency(sim:SettlementSimulation) -> void:
	var candidates:Array[String] = []
	for key in settlements.keys():
		if key != "LAST_HAVEN" and settlements[key]["active"]:
			candidates.append(str(key))
	if candidates.is_empty():
		return
	var key := candidates[sim.rng.randi_range(0,candidates.size()-1)]
	var settlement:Dictionary = settlements[key]
	if str(settlement.get("emergency","")) != "":
		return

	var res:Dictionary = settlement["resources"]
	var pop := maxf(1.0,float(settlement["population"]))
	var risks:Array[String] = []
	if float(res["food"]) < pop*2.5:
		risks.append("Food Shortage")
	if float(res["water"]) < pop*3.5:
		risks.append("Water Crisis")
	if float(settlement["infrastructure"]) < 45.0:
		risks.append("Infrastructure Failure")
	if float(settlement["security"]) < 35.0:
		risks.append("Security Incident")
	if risks.is_empty() and sim.rng.randf() < 0.35:
		risks.append(["Storm Damage","Disease Cluster","Equipment Failure"][sim.rng.randi_range(0,2)])
	if risks.is_empty():
		return

	var emergency := risks[sim.rng.randi_range(0,risks.size()-1)]
	settlement["emergency"] = emergency
	settlement["status"] = "EMERGENCY"
	match emergency:
		"Food Shortage":
			settlement["morale"] = maxf(0.0,float(settlement["morale"])-8.0)
		"Water Crisis":
			settlement["morale"] = maxf(0.0,float(settlement["morale"])-10.0)
		"Infrastructure Failure":
			settlement["infrastructure"] = maxf(5.0,float(settlement["infrastructure"])-12.0)
		"Security Incident":
			settlement["security"] = maxf(5.0,float(settlement["security"])-10.0)
		"Storm Damage":
			settlement["infrastructure"] = maxf(5.0,float(settlement["infrastructure"])-9.0)
		"Disease Cluster":
			res["medicine"] = maxf(0.0,float(res["medicine"])-3.0)
			settlement["morale"] = maxf(0.0,float(settlement["morale"])-6.0)
		"Equipment Failure":
			res["parts"] = maxf(0.0,float(res["parts"])-2.0)
			settlement["infrastructure"] = maxf(5.0,float(settlement["infrastructure"])-6.0)
	emergency_log.push_front({"day":sim.day,"settlement":settlement["name"],"emergency":emergency})
	if emergency_log.size() > 30:
		emergency_log.resize(30)
	sim.add_event("COLONY EMERGENCY","%s reports %s." % [settlement["name"],emergency],"critical")

func _update_colony_status(settlement:Dictionary) -> void:
	if str(settlement.get("emergency","")) != "":
		settlement["status"] = "EMERGENCY"
	elif float(settlement["morale"]) < 40.0 or float(settlement["infrastructure"]) < 35.0:
		settlement["status"] = "DEGRADED"
	elif str(settlement.get("status","")) == "RECOVERING":
		if float(settlement["morale"]) >= 55.0 and float(settlement["infrastructure"]) >= 50.0:
			settlement["status"] = "STABLE"
	else:
		settlement["status"] = "STABLE"

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


func normalize_loaded_state() -> void:
	for key in settlements.keys():
		var settlement:Dictionary = settlements[key]
		if not settlement.has("status"):
			settlement["status"] = "STABLE"
		if not settlement.has("emergency"):
			settlement["emergency"] = ""
		if not settlement.has("specialization"):
			settlement["specialization"] = "General" if key != "LAST_HAVEN" else "Capital"
	for route in logistics_routes:
		if not route.has("priority"):
			route["priority"] = 2
		if not route.has("focus"):
			route["focus"] = "Balanced"
		if not route.has("active"):
			route["active"] = true

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
