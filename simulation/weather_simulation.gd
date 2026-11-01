class_name WeatherSimulation
extends RefCounted

# Weather fronts use simulation hours and the game's seeded RNG. That keeps
# hazard durations independent from FPS and makes the state save-compatible.
const CLEAR := "CLEAR"
const DUST_STORM := "DUST STORM"

var condition := CLEAR
var intensity := 0.0
var front_ends_at := 0.0
var next_front_at := 46.0
var shelter_in_place := false

func begin_storm(sim: SettlementSimulation, strength: float = 0.75, duration_hours: float = 8.0) -> bool:
	if condition==DUST_STORM or duration_hours<=0.0:
		return false
	condition=DUST_STORM
	intensity=clampf(strength,0.25,1.0)
	front_ends_at=sim.total_hours+duration_hours
	shelter_in_place=false
	sim.add_event("DUST STORM APPROACHING","Airborne grit is cutting generator and water-filter performance. Issue a shelter order to protect outdoor crews.","warning")
	return true

func set_shelter_order(sim: SettlementSimulation, enabled: bool) -> bool:
	if condition!=DUST_STORM or shelter_in_place==enabled:
		return false
	shelter_in_place=enabled
	sim.add_event("SHELTER ORDER" if enabled else "OUTDOOR DUTY RESUMED",
		"Nonessential field crews are taking cover until the storm passes." if enabled else "Nonessential field crews may resume outdoor duties.",
		"warning" if enabled else "intel")
	return true

func update(sim: SettlementSimulation, sim_hours: float) -> void:
	if condition==DUST_STORM:
		if sim.total_hours>=front_ends_at:
			condition=CLEAR
			intensity=0.0
			shelter_in_place=false
			front_ends_at=0.0
			next_front_at=sim.total_hours+36.0+sim.rng.randf_range(0.0,36.0)
			sim.add_event("SKIES CLEAR","The dust front passed. Normal field operations have resumed.","good")
		else:
			_apply_exposure(sim,sim_hours)
	elif sim.total_hours>=next_front_at:
		begin_storm(sim,sim.rng.randf_range(0.56,0.94),sim.rng.randf_range(5.0,10.0))

func is_outdoor_work(citizen: Dictionary) -> bool:
	var action := str(citizen.get("current_action",""))
	return action=="Work: Farming" or action=="Work: Construction" or action=="Scavenge" or action=="Patrol" or action=="Haul Supplies" or action.begins_with("Build: ")

func should_shelter(citizen: Dictionary) -> bool:
	return condition==DUST_STORM and shelter_in_place and str(citizen.get("job","")) in ["Farmer","Builder","Scavenger","Hauler","Guard"]

func power_factor() -> float:
	return 1.0-0.20*intensity if condition==DUST_STORM else 1.0

func water_factor() -> float:
	return 1.0-0.36*intensity if condition==DUST_STORM else 1.0

func remaining_hours(sim: SettlementSimulation) -> float:
	return maxf(0.0,front_ends_at-sim.total_hours) if condition==DUST_STORM else maxf(0.0,next_front_at-sim.total_hours)

func _apply_exposure(sim: SettlementSimulation, sim_hours: float) -> void:
	for citizen in sim.get_settlement_citizens():
		if not is_outdoor_work(citizen) or bool(citizen.get("incarcerated",false)):
			continue
		citizen["fatigue"]=minf(100.0,float(citizen.get("fatigue",0.0))+0.65*intensity*sim_hours)
		citizen["stress"]=minf(100.0,float(citizen.get("stress",0.0))+0.55*intensity*sim_hours)
		if intensity>=0.72:
			citizen["health"]=maxf(0.0,float(citizen.get("health",100.0))-0.13*intensity*sim_hours)
