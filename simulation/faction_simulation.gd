class_name FactionSimulation
extends RefCounted

var factions := {
	"Cedar Union":{
		"location_id":9,
		"reputation":18.0,
		"strength":38.0,
		"wealth":52.0,
		"aggression":0.14,
		"intel":28.0,
		"trade_agreement":false,
		"disposition":"NEUTRAL"
	},
	"Riverbend Collective":{
		"location_id":10,
		"reputation":12.0,
		"strength":31.0,
		"wealth":46.0,
		"aggression":0.08,
		"intel":22.0,
		"trade_agreement":false,
		"disposition":"NEUTRAL"
	},
	"Iron Pact":{
		"location_id":11,
		"reputation":-42.0,
		"strength":72.0,
		"wealth":34.0,
		"aggression":0.72,
		"intel":48.0,
		"trade_agreement":false,
		"disposition":"HOSTILE"
	},
	"Lantern Medics":{
		"location_id":12,
		"reputation":28.0,
		"strength":18.0,
		"wealth":38.0,
		"aggression":0.02,
		"intel":34.0,
		"trade_agreement":false,
		"disposition":"FRIENDLY"
	}
}

var next_strategic_hour := 48.0
var active_raid: Dictionary = {}
var raid_log: Array[Dictionary] = []
var last_espionage_hour := -999.0

func initialize(sim:SettlementSimulation) -> void:
	_sync_trade_reputation(sim)
	_refresh_dispositions()

func update(sim:SettlementSimulation, sim_hours:float) -> void:
	_sync_trade_reputation(sim)
	_refresh_dispositions()
	_update_active_raid(sim,sim_hours)

	if sim.total_hours < next_strategic_hour:
		return
	next_strategic_hour = sim.total_hours + 24.0

	for faction_name in factions.keys():
		var faction:Dictionary = factions[faction_name]
		var location := sim.world_simulation.get_location_by_id(int(faction["location_id"]))
		if location.is_empty() or not location["discovered"]:
			continue

		faction["strength"] = clampf(float(faction["strength"]) + sim.rng.randf_range(-1.2,1.8),5.0,100.0)
		faction["wealth"] = clampf(float(faction["wealth"]) + sim.rng.randf_range(-1.0,1.6),0.0,100.0)

		if str(faction["disposition"]) == "HOSTILE":
			_try_hostile_action(sim,str(faction_name),faction)
		elif str(faction["disposition"]) in ["FRIENDLY","ALLIED"]:
			_try_friendly_action(sim,str(faction_name),faction)

func _sync_trade_reputation(sim:SettlementSimulation) -> void:
	var mappings := {"Cedar Union":"9","Riverbend Collective":"10"}
	for faction_name in mappings.keys():
		if not factions.has(faction_name):
			continue
		var market_key:String = mappings[faction_name]
		if not sim.economy_simulation.regional_markets.has(market_key):
			continue
		var faction:Dictionary = factions[faction_name]
		var market:Dictionary = sim.economy_simulation.regional_markets[market_key]
		var blended := float(faction["reputation"])*0.72 + float(market["reputation"])*0.28
		faction["reputation"] = blended
		market["reputation"] = blended

func _refresh_dispositions() -> void:
	for faction_name in factions.keys():
		var faction:Dictionary = factions[faction_name]
		var rep := float(faction["reputation"])
		if rep >= 70.0:
			faction["disposition"] = "ALLIED"
		elif rep >= 30.0:
			faction["disposition"] = "FRIENDLY"
		elif rep > -20.0:
			faction["disposition"] = "NEUTRAL"
		else:
			faction["disposition"] = "HOSTILE"

func send_aid(sim:SettlementSimulation, faction_name:String) -> bool:
	if not factions.has(faction_name):
		return false
	var faction:Dictionary = factions[faction_name]
	if not _is_discovered(sim,faction):
		return false
	if float(sim.stockpiles["command"].get("food",0.0)) < 8.0 or float(sim.stockpiles["medical"].get("medicine",0.0)) < 2.0:
		sim.add_event("AID BLOCKED","Insufficient food or medicine for a diplomatic aid shipment.","warning")
		return false
	sim.stockpiles["command"]["food"] -= 8.0
	sim.stockpiles["medical"]["medicine"] -= 2.0
	faction["reputation"] = minf(100.0,float(faction["reputation"])+9.0)
	faction["wealth"] = minf(100.0,float(faction["wealth"])+4.0)
	sim.add_event("AID SENT","Last Haven sent relief supplies to %s." % faction_name,"good")
	_refresh_dispositions()
	return true

func propose_trade_agreement(sim:SettlementSimulation, faction_name:String) -> bool:
	if not factions.has(faction_name):
		return false
	var faction:Dictionary = factions[faction_name]
	if not _is_discovered(sim,faction):
		return false
	if float(faction["reputation"]) < 30.0:
		sim.add_event("AGREEMENT REJECTED","%s does not trust Last Haven enough for a trade agreement." % faction_name,"warning")
		return false
	faction["trade_agreement"] = true
	faction["reputation"] = minf(100.0,float(faction["reputation"])+3.0)
	for market_key in sim.economy_simulation.regional_markets.keys():
		var market:Dictionary = sim.economy_simulation.regional_markets[market_key]
		if str(market["faction"]) == faction_name:
			market["agreement"] = true
			market["reputation"] = faction["reputation"]
	sim.add_event("TRADE AGREEMENT","Last Haven signed a trade agreement with %s." % faction_name,"good")
	return true

func request_truce(sim:SettlementSimulation, faction_name:String) -> bool:
	if not factions.has(faction_name):
		return false
	var faction:Dictionary = factions[faction_name]
	if not _is_discovered(sim,faction) or str(faction["disposition"]) != "HOSTILE":
		return false
	if sim.economy_simulation.credits < 25.0:
		sim.add_event("TRUCE BLOCKED","A 25-credit diplomatic concession is required.","warning")
		return false
	sim.economy_simulation.credits -= 25.0
	faction["reputation"] = minf(100.0,float(faction["reputation"])+16.0)
	sim.add_event("TRUCE OFFERED","Last Haven opened a truce channel with %s." % faction_name,"intel")
	_refresh_dispositions()
	return true

func _try_hostile_action(sim:SettlementSimulation, faction_name:String, faction:Dictionary) -> void:
	if active_raid.is_empty() and sim.rng.randf() < float(faction["aggression"])*0.11:
		_schedule_raid(sim,faction_name,faction)
		return
	if sim.total_hours-last_espionage_hour > 72.0 and sim.rng.randf() < float(faction["intel"])*0.0006:
		last_espionage_hour = sim.total_hours
		_resolve_espionage(sim,faction_name,faction)

func _schedule_raid(sim:SettlementSimulation, faction_name:String, faction:Dictionary) -> void:
	active_raid = {
		"faction":faction_name,
		"eta_hours":sim.rng.randf_range(18.0,36.0),
		"attack_strength":float(faction["strength"])*sim.rng.randf_range(0.55,0.85)
	}
	sim.add_event("RAID WARNING","Radio intercepts indicate %s forces are moving toward Last Haven." % faction_name,"critical")

func _update_active_raid(sim:SettlementSimulation, sim_hours:float) -> void:
	if active_raid.is_empty():
		return
	active_raid["eta_hours"] = maxf(0.0,float(active_raid["eta_hours"])-sim_hours)
	if float(active_raid["eta_hours"]) <= 0.0:
		_resolve_raid(sim)
		active_raid = {}

func _resolve_raid(sim:SettlementSimulation) -> void:
	var faction_name := str(active_raid["faction"])
	var attack_strength := float(active_raid["attack_strength"])
	var defense := _settlement_defense(sim)
	var victory := defense >= attack_strength
	var record := {
		"day":sim.day,
		"faction":faction_name,
		"attack":attack_strength,
		"defense":defense,
		"victory":victory
	}
	raid_log.push_front(record)
	if raid_log.size() > 20:
		raid_log.resize(20)

	if victory:
		sim.add_event("RAID REPELLED","Last Haven repelled %s. Defense %.0f vs attack %.0f." % [faction_name,defense,attack_strength],"good")
		for c in sim.get_settlement_citizens():
			c["morale"] = minf(100.0,float(c["morale"])+2.0)
		var faction:Dictionary = factions[faction_name]
		faction["strength"] = maxf(5.0,float(faction["strength"])-8.0)
		faction["reputation"] = maxf(-100.0,float(faction["reputation"])-4.0)
	else:
		var stolen_food := minf(float(sim.stockpiles["command"].get("food",0.0)),12.0)
		var stolen_materials := minf(float(sim.stockpiles["industry"].get("materials",0.0)),10.0)
		sim.stockpiles["command"]["food"] -= stolen_food
		sim.stockpiles["industry"]["materials"] -= stolen_materials
		var target := _random_damageable_building(sim)
		if not target.is_empty():
			target["condition"] = maxf(15.0,float(target["condition"])-sim.rng.randf_range(8.0,20.0))
		_injure_defender(sim)
		sim.governance_simulation.unrest = minf(100.0,float(sim.governance_simulation.unrest)+9.0)
		sim.add_event("RAID BREACH","%s breached Last Haven and stole supplies." % faction_name,"critical")

func _settlement_defense(sim:SettlementSimulation) -> float:
	var defense := 8.0
	for c in sim.get_settlement_citizens():
		if c["job"] == "Guard" and not c.get("incarcerated",false):
			defense += 5.0 + float(c["skills"].get("security",20))*0.12
	for building in sim.buildings:
		if building["type"] == "wall":
			defense += 1.8*clampf(float(building["condition"])/100.0,0.2,1.0)
		elif building["type"] == "command":
			defense += 5.0*clampf(float(building["condition"])/100.0,0.2,1.0)
	defense += sim.get_average_morale()*0.08
	return defense

func _resolve_espionage(sim:SettlementSimulation, faction_name:String, faction:Dictionary) -> void:
	var roll := sim.rng.randf()
	if roll < 0.5:
		var stolen := minf(float(sim.stockpiles["industry"].get("scrap",0.0)),6.0)
		sim.stockpiles["industry"]["scrap"] -= stolen
		sim.add_event("ESPIONAGE","Agents linked to %s stole industrial stock." % faction_name,"warning")
	else:
		var generator := sim.get_building_by_type("power")
		generator["condition"] = maxf(20.0,float(generator["condition"])-7.0)
		sim.add_event("SABOTAGE","A suspected %s operation damaged power infrastructure." % faction_name,"critical")
	faction["intel"] = minf(100.0,float(faction["intel"])+1.0)

func _try_friendly_action(sim:SettlementSimulation, faction_name:String, faction:Dictionary) -> void:
	if sim.rng.randf() > 0.05:
		return
	if str(faction["disposition"]) == "ALLIED":
		var medicine := 3.0
		sim.stockpiles["medical"]["medicine"] = float(sim.stockpiles["medical"].get("medicine",0.0))+medicine
		sim.add_event("ALLY SUPPORT","%s delivered emergency medicine to Last Haven." % faction_name,"good")
	else:
		sim.add_event("DIPLOMATIC SIGNAL","%s transmitted a friendly status update." % faction_name,"intel")

func _injure_defender(sim:SettlementSimulation) -> void:
	var guards:Array[Dictionary] = []
	for c in sim.get_settlement_citizens():
		if c["job"] == "Guard":
			guards.append(c)
	if guards.is_empty():
		return
	var guard := guards[sim.rng.randi_range(0,guards.size()-1)]
	guard["injury"] = "Raid Wounds"
	guard["health"] = maxf(15.0,float(guard["health"])-22.0)

func _random_damageable_building(sim:SettlementSimulation) -> Dictionary:
	var options:Array[Dictionary] = []
	for building in sim.buildings:
		if building["type"] not in ["floor","pipe","power_pole"]:
			options.append(building)
	if options.is_empty():
		return {}
	return options[sim.rng.randi_range(0,options.size()-1)]

func _is_discovered(sim:SettlementSimulation, faction:Dictionary) -> bool:
	var location := sim.world_simulation.get_location_by_id(int(faction["location_id"]))
	return not location.is_empty() and bool(location["discovered"])

func get_visible_factions(sim:SettlementSimulation) -> Array[String]:
	var result:Array[String] = []
	for faction_name in factions.keys():
		if _is_discovered(sim,factions[faction_name]):
			result.append(str(faction_name))
	return result
