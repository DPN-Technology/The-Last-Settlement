class_name GovernanceSimulation
extends RefCounted

const ELECTION_INTERVAL_HOURS := 720.0
const GOVERNMENT_TYPES := ["Emergency Council","Representative Council","Technocracy","Security Directorate","Communal Assembly"]
const LAW_OPTIONS := {
	"rationing":["Open","Standard","Strict"],
	"security":["Minimal","Balanced","Heavy"],
	"labor":["Voluntary","Directed","Mandatory"],
	"justice":["Restorative","Balanced","Punitive"],
	"speech":["Protected","Regulated","Restricted"]
}

var government_type := "Emergency Council"
var laws := {
	"rationing":"Standard",
	"security":"Balanced",
	"labor":"Voluntary",
	"justice":"Restorative",
	"speech":"Protected"
}
var leader_id := 0
var council_ids: Array[int] = []
var factions := {
	"Rebuilders":{"support":0.0,"priority":"Industry"},
	"Common Voice":{"support":0.0,"priority":"Welfare"},
	"Watchkeepers":{"support":0.0,"priority":"Security"},
	"Free Settlers":{"support":0.0,"priority":"Liberty"}
}
var unrest := 8.0
var legitimacy := 62.0
var crime_pressure := 5.0
var active_cases: Array[Dictionary] = []
var next_case_id := 1
var next_election_hour := 720.0
var last_protest_hour := -999.0
var last_crisis_hour := -999.0

func initialize(sim: SettlementSimulation) -> void:
	if leader_id != 0:
		return
	var adults := _eligible_adults(sim)
	if adults.is_empty():
		return
	adults.sort_custom(func(a:Dictionary,b:Dictionary)->bool:
		return _leadership_score(a) > _leadership_score(b)
	)
	leader_id = int(adults[0]["id"])
	for i in range(mini(3, adults.size())):
		council_ids.append(int(adults[i]["id"]))
	sim.add_event("CIVIC COUNCIL FORMED","%s appointed as interim settlement leader." % adults[0]["name"],"intel")

func update(sim: SettlementSimulation, sim_hours: float) -> void:
	if leader_id == 0:
		initialize(sim)
	_update_factions(sim)
	_update_legitimacy(sim, sim_hours)
	_update_crime(sim, sim_hours)
	_update_courts(sim, sim_hours)
	_update_unrest(sim, sim_hours)
	if sim.total_hours >= next_election_hour:
		_run_election(sim)

func next_law_option(law_key: String) -> String:
	if not LAW_OPTIONS.has(law_key):
		return ""
	var values: Array=LAW_OPTIONS[law_key]
	return str(values[(values.find(str(laws[law_key]))+1)%values.size()])

func _reaction_for(citizen: Dictionary, law_key: String, option: String) -> float:
	var liberty := float(citizen.get("liberty_value",50.0))
	var order := float(citizen.get("order_value",50.0))
	match law_key:
		"security":
			return (order-liberty)*0.035 if option=="Heavy" else (liberty-order)*0.02
		"labor":
			return -absf(liberty-50.0)*0.02 if option=="Mandatory" else 0.4
		"speech":
			return -liberty*0.03 if option=="Restricted" else liberty*0.01
		"justice":
			return (order-50.0)*0.02 if option=="Punitive" else 0.2
		"rationing":
			return 0.6 if option=="Standard" else -0.2
	return 0.0

# Read-only citizen reaction preview: use exactly the same formula and
# clamped loyalty that cycle_law applies to its next legislative option.
func preview_next_law(sim: SettlementSimulation, law_key: String) -> Dictionary:
	var next := next_law_option(law_key)
	if next.is_empty():
		return {}
	var delta := 0.0
	var residents := 0
	var opposition := 0
	for citizen in sim.get_settlement_citizens():
		var loyalty := float(citizen.get("loyalty",50.0))
		var projected := clampf(loyalty+_reaction_for(citizen,law_key,next),0.0,100.0)
		var change := projected-loyalty
		delta+=change
		residents+=1
		if change<-0.001:
			opposition+=1
	return {"current":str(laws[law_key]),"proposed":next,"loyalty_delta":delta/maxf(1.0,float(residents)),"residents":residents,"negative_residents":opposition}

func cycle_law(sim: SettlementSimulation, law_key: String) -> void:
	var next := next_law_option(law_key)
	if next.is_empty():
		return
	laws[law_key]=next
	sim.add_event("LAW CHANGED","%s policy changed to %s." % [law_key.capitalize(),laws[law_key]],"intel")
	for citizen in sim.get_settlement_citizens():
		_apply_law_reaction(citizen,law_key)

func _apply_law_reaction(citizen: Dictionary, law_key: String) -> void:
	var reaction := _reaction_for(citizen,law_key,str(laws.get(law_key,"")))
	citizen["loyalty"]=clampf(float(citizen["loyalty"])+reaction,0.0,100.0)

func _update_factions(sim:SettlementSimulation) -> void:
	for name in factions.keys():
		factions[name]["support"] = 0.0
	for c in sim.get_settlement_citizens():
		if int(c["age"]) < 16:
			continue
		var faction := str(c.get("faction",""))
		if faction == "":
			faction = _choose_faction(c)
			c["faction"] = faction
		if factions.has(faction):
			factions[faction]["support"] = float(factions[faction]["support"]) + 1.0

func _choose_faction(c:Dictionary) -> String:
	var liberty := float(c.get("liberty_value",50.0))
	var order := float(c.get("order_value",50.0))
	var welfare := float(c.get("welfare_value",50.0))
	if order > 68.0:
		return "Watchkeepers"
	if liberty > 68.0:
		return "Free Settlers"
	if welfare > 62.0:
		return "Common Voice"
	return "Rebuilders"

func _update_legitimacy(sim:SettlementSimulation, sim_hours:float) -> void:
	var morale := sim.get_average_morale()
	var resource_health := minf(100.0,(float(sim.resources["food"])+float(sim.resources["water"]))*0.15)
	var target := morale*0.45 + resource_health*0.25 + (100.0-unrest)*0.30
	legitimacy = move_toward(legitimacy,clampf(target,0.0,100.0),0.18*sim_hours)

func _update_crime(sim:SettlementSimulation, sim_hours:float) -> void:
	var scarcity := 0.0
	if float(sim.resources["meals"]) < sim.get_settlement_citizens().size()*1.5:
		scarcity += 20.0
	if float(sim.resources["water"]) < sim.get_settlement_citizens().size()*4.0:
		scarcity += 18.0
	var stress := 0.0
	var adults := 0
	var guards := 0
	for c in sim.get_settlement_citizens():
		if int(c["age"]) >= 16:
			adults += 1
			stress += float(c["stress"])
			if c["job"] == "Guard":
				guards += 1
	var avg_stress := stress/maxf(1.0,float(adults))
	var security_effect := guards*5.0
	if laws["security"] == "Heavy":
		security_effect += 12.0
	elif laws["security"] == "Minimal":
		security_effect -= 6.0
	crime_pressure = clampf(scarcity + avg_stress*0.32 - security_effect,0.0,100.0)
	if sim.rng.randf() < (crime_pressure/100.0)*0.008*sim_hours:
		_create_crime(sim)

func _create_crime(sim:SettlementSimulation) -> void:
	var suspects:Array[Dictionary] = []
	for c in sim.get_settlement_citizens():
		if int(c["age"]) >= 16 and not c.get("incarcerated",false):
			suspects.append(c)
	if suspects.is_empty():
		return
	var suspect := suspects[sim.rng.randi_range(0,suspects.size()-1)]
	var kind: String = str(["Theft","Assault","Sabotage"][sim.rng.randi_range(0,2)])
	var severity := 1 if kind == "Theft" else (2 if kind == "Assault" else 3)
	active_cases.append({"id":next_case_id,"type":kind,"suspect_id":int(suspect["id"]),"severity":severity,"progress":0.0,"status":"investigating"})
	next_case_id += 1
	suspect["criminal_record"] = int(suspect.get("criminal_record",0)) + 1
	if kind == "Theft":
		sim.stockpiles["command"]["meals"] = maxf(0.0,float(sim.stockpiles["command"]["meals"])-4.0)
	elif kind == "Sabotage":
		var generator := sim.get_building_by_type("power")
		generator["condition"] = maxf(20.0,float(generator["condition"])-8.0)
	sim.add_event("CRIME REPORTED","%s under investigation: %s." % [suspect["name"],kind],"warning")

func _update_courts(sim:SettlementSimulation, sim_hours:float) -> void:
	var guards := 0
	for c in sim.get_settlement_citizens():
		if c["job"] == "Guard":
			guards += 1
	for case in active_cases:
		if case["status"] != "investigating":
			continue
		case["progress"] = float(case["progress"]) + guards*2.5*sim_hours
		if float(case["progress"]) >= 100.0:
			_resolve_case(sim,case)

func _resolve_case(sim:SettlementSimulation, case:Dictionary) -> void:
	case["status"] = "resolved"
	var suspect := sim.get_citizen_by_id(int(case["suspect_id"]))
	if suspect.is_empty():
		return
	var punishment := str(laws["justice"])
	if punishment == "Punitive":
		suspect["incarcerated"] = true
		suspect["sentence_hours"] = 72.0*float(case["severity"])
		suspect["loyalty"] = maxf(0.0,float(suspect["loyalty"])-8.0)
	elif punishment == "Restorative":
		suspect["loyalty"] = minf(100.0,float(suspect["loyalty"])+2.0)
		suspect["stress"] = minf(100.0,float(suspect["stress"])+3.0)
	else:
		suspect["incarcerated"] = true
		suspect["sentence_hours"] = 24.0*float(case["severity"])
	sim.add_event("CASE RESOLVED","%s case resolved under %s justice." % [case["type"],punishment],"intel")

func _update_unrest(sim:SettlementSimulation, sim_hours:float) -> void:
	var low_loyalty := 0
	var adults := 0
	for c in sim.get_settlement_citizens():
		if int(c["age"]) < 16:
			continue
		adults += 1
		if float(c["loyalty"]) < 35.0:
			low_loyalty += 1
	var discontent := 100.0*float(low_loyalty)/maxf(1.0,float(adults))
	var target := discontent*0.6 + crime_pressure*0.25 + (100.0-legitimacy)*0.35
	unrest = move_toward(unrest,clampf(target,0.0,100.0),0.14*sim_hours)
	if unrest > 62.0 and sim.total_hours-last_protest_hour > 48.0:
		last_protest_hour = sim.total_hours
		sim.add_event("PROTEST","Residents gathered near command demanding policy changes.","warning")
		for c in sim.get_settlement_citizens():
			if float(c["loyalty"]) < 40.0:
				c["current_action"] = "Protest"
	if unrest > 88.0 and sim.total_hours-last_crisis_hour > 24.0:
		last_crisis_hour = sim.total_hours
		sim.add_event("GOVERNANCE CRISIS","Settlement authority is close to collapse.","critical")

func _run_election(sim:SettlementSimulation) -> void:
	next_election_hour = sim.total_hours + ELECTION_INTERVAL_HOURS
	var candidates := _eligible_adults(sim)
	if candidates.is_empty():
		return
	candidates.sort_custom(func(a:Dictionary,b:Dictionary)->bool:
		return _candidate_score(a,sim) > _candidate_score(b,sim)
	)
	var winner := candidates[0]
	var old_leader := sim.get_citizen_by_id(leader_id)
	leader_id = int(winner["id"])
	council_ids.clear()
	for i in range(mini(3,candidates.size())):
		council_ids.append(int(candidates[i]["id"]))
	legitimacy = minf(100.0,legitimacy+10.0)
	var old_name: String = "none" if old_leader.is_empty() else str(old_leader["name"])
	sim.add_event("ELECTION RESULT","%s replaced %s as settlement leader." % [winner["name"],old_name],"good")

func _eligible_adults(sim:SettlementSimulation) -> Array[Dictionary]:
	var result:Array[Dictionary] = []
	for c in sim.get_settlement_citizens():
		if int(c["age"]) >= 18 and not c.get("incarcerated",false):
			result.append(c)
	return result

func _candidate_score(c:Dictionary, sim:SettlementSimulation) -> float:
	return _leadership_score(c)+float(c["loyalty"])*0.25+float(c["morale"])*0.15+sim.rng.randf_range(0.0,12.0)

func _leadership_score(c:Dictionary) -> float:
	return float(c["skills"].get("security",20))*0.25+float(c["skills"].get("engineering",20))*0.2+float(c["loyalty"])*0.25+float(c["morale"])*0.2
