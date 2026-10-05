class_name FederalGovernanceSimulation
extends RefCounted

const COUNCIL_INTERVAL_HOURS := 168.0

var charter := {
	"representation":"Delegated Councils",
	"contribution":"Balanced Tithe",
	"rights":"Common Charter"
}
var representatives: Dictionary = {}
var federal_legitimacy := 62.0
var network_cohesion := 58.0
var federal_treasury := 0.0
var next_council_hour := 168.0
var council_history: Array[Dictionary] = []
var last_dispute_hour := -999.0

func initialize(sim:SettlementSimulation) -> void:
	_refresh_representatives(sim)
	next_council_hour = maxf(next_council_hour,sim.total_hours+COUNCIL_INTERVAL_HOURS)

func update(sim:SettlementSimulation, sim_hours:float) -> void:
	_refresh_representatives(sim)
	_update_cohesion(sim,sim_hours)
	_update_legitimacy(sim,sim_hours)
	_collect_contributions(sim,sim_hours)
	if sim.total_hours >= next_council_hour:
		next_council_hour = sim.total_hours+COUNCIL_INTERVAL_HOURS
		_hold_council(sim)

func _refresh_representatives(sim:SettlementSimulation) -> void:
	for settlement_key in sim.civilization_simulation.settlements.keys():
		var settlement:Dictionary = sim.civilization_simulation.settlements[settlement_key]
		if not settlement.get("active",true):
			continue
		var representative := _select_representative(sim,str(settlement_key),settlement)
		if representative.is_empty():
			representatives.erase(str(settlement_key))
		else:
			representatives[str(settlement_key)] = int(representative["id"])

func _select_representative(sim:SettlementSimulation, settlement_key:String, settlement:Dictionary) -> Dictionary:
	var candidates:Array[Dictionary] = []
	if settlement_key == "LAST_HAVEN":
		for citizen in sim.get_settlement_citizens():
			if _eligible_representative(citizen):
				candidates.append(citizen)
	else:
		for citizen_id in settlement.get("population_ids",[]):
			var citizen := sim.get_citizen_by_id(int(citizen_id))
			if not citizen.is_empty() and _eligible_representative(citizen):
				candidates.append(citizen)
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a:Dictionary,b:Dictionary)->bool:
		return _representative_score(a)>_representative_score(b)
	)
	return candidates[0]

func _eligible_representative(citizen:Dictionary) -> bool:
	return bool(citizen.get("alive",false)) and int(citizen.get("age",0))>=18 and not bool(citizen.get("incarcerated",false)) and not bool(citizen.get("on_expedition",false))

func _representative_score(citizen:Dictionary) -> float:
	var skills:Dictionary = citizen.get("skills",{})
	return (
		float(citizen.get("loyalty",50.0))*0.34+
		float(citizen.get("morale",50.0))*0.22+
		float(skills.get("security",20.0))*0.18+
		float(skills.get("engineering",20.0))*0.14+
		float(skills.get("medicine",20.0))*0.12
	)

func cycle_charter(sim:SettlementSimulation, key:String) -> bool:
	var options := {
		"representation":["Capital Authority","Delegated Councils","Federation"],
		"contribution":["Low Tithe","Balanced Tithe","Recovery Levy"],
		"rights":["Emergency Powers","Common Charter","Settlement Rights"]
	}
	if not options.has(key):
		return false
	var values:Array = options[key]
	var current:String = str(charter[key])
	var index:int = values.find(current)
	charter[key] = values[(index+1)%values.size()]
	_apply_charter_reaction(sim,key)
	sim.civilization_simulation.record_history(sim,"FEDERAL CHARTER","%s changed to %s." % [key.capitalize(),charter[key]],"government")
	sim.add_event("FEDERAL CHARTER","%s policy changed to %s." % [key.capitalize(),charter[key]],"intel")
	return true

func _apply_charter_reaction(sim:SettlementSimulation,key:String) -> void:
	for settlement_key in sim.civilization_simulation.settlements.keys():
		if str(settlement_key)=="LAST_HAVEN":
			continue
		var settlement:Dictionary = sim.civilization_simulation.settlements[settlement_key]
		var morale_delta := 0.0
		match key:
			"representation":
				if charter["representation"]=="Federation":
					morale_delta = 2.5
				elif charter["representation"]=="Capital Authority":
					morale_delta = -2.5
			"contribution":
				if charter["contribution"]=="Recovery Levy":
					morale_delta = -2.0
				elif charter["contribution"]=="Low Tithe":
					morale_delta = 1.0
			"rights":
				if charter["rights"]=="Settlement Rights":
					morale_delta = 2.0
				elif charter["rights"]=="Emergency Powers":
					morale_delta = -3.0
		settlement["morale"] = clampf(float(settlement["morale"])+morale_delta,0.0,100.0)

func _update_cohesion(sim:SettlementSimulation,sim_hours:float) -> void:
	var civ := sim.civilization_simulation
	var active_count := 0
	var morale_total := 0.0
	var emergency_count := 0
	for settlement_key in civ.settlements.keys():
		var settlement:Dictionary = civ.settlements[settlement_key]
		if not settlement.get("active",true):
			continue
		active_count += 1
		morale_total += float(settlement.get("morale",50.0))
		if str(settlement.get("status","STABLE"))=="EMERGENCY":
			emergency_count += 1
	var average_morale := morale_total/maxf(1.0,float(active_count))
	var target := average_morale*0.60 + float(sim.governance_simulation.legitimacy)*0.25 + 15.0
	if charter["representation"]=="Federation":
		target += 7.0
	elif charter["representation"]=="Capital Authority" and active_count>1:
		target -= 8.0
	if charter["rights"]=="Settlement Rights":
		target += 4.0
	elif charter["rights"]=="Emergency Powers":
		target -= 5.0
	target -= float(emergency_count)*8.0
	network_cohesion = move_toward(network_cohesion,clampf(target,0.0,100.0),0.10*sim_hours)

	if network_cohesion<30.0 and sim.total_hours-last_dispute_hour>72.0:
		last_dispute_hour = sim.total_hours
		sim.add_event("FEDERAL DISPUTE","Colony representatives are openly challenging recovery-network authority.","warning")
		civ.record_history(sim,"FEDERAL DISPUTE","Network cohesion fell below 30%.","government")

func _update_legitimacy(sim:SettlementSimulation,sim_hours:float) -> void:
	var represented := representatives.size()
	var active_settlements := 0
	for settlement_key in sim.civilization_simulation.settlements.keys():
		if sim.civilization_simulation.settlements[settlement_key].get("active",true):
			active_settlements += 1
	var representation_score := 100.0*float(represented)/maxf(1.0,float(active_settlements))
	var target := network_cohesion*0.48 + representation_score*0.30 + float(sim.governance_simulation.legitimacy)*0.22
	federal_legitimacy = move_toward(federal_legitimacy,clampf(target,0.0,100.0),0.10*sim_hours)

func _collect_contributions(sim:SettlementSimulation,sim_hours:float) -> void:
	if sim.civilization_simulation.settlements.size()<2:
		return
	var hourly_rate := 0.0025
	match str(charter["contribution"]):
		"Low Tithe":
			hourly_rate = 0.0012
		"Recovery Levy":
			hourly_rate = 0.0045
	for settlement_key in sim.civilization_simulation.settlements.keys():
		if str(settlement_key)=="LAST_HAVEN":
			continue
		var settlement:Dictionary = sim.civilization_simulation.settlements[settlement_key]
		if not settlement.get("active",true):
			continue
		var contribution := float(settlement.get("population",0))*hourly_rate*sim_hours
		federal_treasury += contribution
	if federal_treasury>250.0:
		federal_treasury = 250.0

func spend_reserve_for_emergency(sim:SettlementSimulation,settlement_key:String) -> bool:
	if federal_treasury<10.0 or not sim.civilization_simulation.settlements.has(settlement_key):
		return false
	var settlement:Dictionary = sim.civilization_simulation.settlements[settlement_key]
	if str(settlement.get("status","STABLE"))!="EMERGENCY":
		return false
	federal_treasury -= 10.0
	settlement["morale"] = minf(100.0,float(settlement["morale"])+6.0)
	settlement["infrastructure"] = minf(100.0,float(settlement["infrastructure"])+3.0)
	settlement["security"] = minf(100.0,float(settlement["security"])+3.0)
	sim.add_event("FEDERAL RESERVE","Emergency reserve released to %s." % settlement["name"],"good")
	return true

func _hold_council(sim:SettlementSimulation) -> void:
	var outcome := "COUNCIL DIVIDED"
	if network_cohesion>=70.0 and federal_legitimacy>=65.0:
		outcome = "COUNCIL ACCORD"
		network_cohesion = minf(100.0,network_cohesion+3.0)
	elif network_cohesion<40.0:
		outcome = "COUNCIL DEADLOCK"
		federal_legitimacy = maxf(0.0,federal_legitimacy-4.0)
	else:
		outcome = "COUNCIL SESSION"
	council_history.push_front({
		"day":sim.day,
		"outcome":outcome,
		"cohesion":network_cohesion,
		"legitimacy":federal_legitimacy,
		"representatives":representatives.size()
	})
	if council_history.size()>24:
		council_history.resize(24)
	sim.civilization_simulation.record_history(sim,outcome,"Federal representatives convened with cohesion %.0f%% and legitimacy %.0f%%." % [network_cohesion,federal_legitimacy],"government")
	sim.add_event(outcome,"Recovery-network representatives completed a federal council session.","intel")

func get_representative_name(sim:SettlementSimulation,settlement_key:String) -> String:
	if not representatives.has(settlement_key):
		return "VACANT"
	var citizen := sim.get_citizen_by_id(int(representatives[settlement_key]))
	return "VACANT" if citizen.is_empty() else str(citizen["name"])
