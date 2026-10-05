class_name EventDirector
extends RefCounted

var next_event_hour := 9.0

func update(sim: SettlementSimulation) -> void:
	if sim.total_hours < next_event_hour:
		return

	var roll := sim.rng.randf()
	if roll < 0.18:
		sim.add_event("SCOUT REPORT", "Distant smoke spotted beyond the northern ridge.", "intel")
	elif roll < 0.36:
		sim.resources["scrap"] += 6.0
		sim.add_event("SALVAGE FOUND", "Workers recovered usable scrap from nearby ruins.", "good")
	elif roll < 0.53:
		sim.resources["water"] = maxf(0.0, sim.resources["water"] - 12.0)
		sim.add_event("PIPE LEAK", "A cracked line dumped part of the clean-water reserve.", "warning")
	elif roll < 0.70:
		sim.resources["medicine"] = maxf(0.0, sim.resources["medicine"] - 2.0)
		sim.add_event("CLINIC LOAD", "Several survivors required treatment supplies.", "warning")
	elif roll < 0.86:
		for citizen in sim.citizens:
			if citizen["alive"]:
				citizen["morale"] = minf(100.0, citizen["morale"] + 2.0)
		sim.add_event("COMMUNITY NIGHT", "A shared meal raised spirits across the settlement.", "good")
	else:
		var alive := sim.get_alive_citizens()
		if not alive.is_empty():
			var target: Dictionary = alive[sim.rng.randi_range(0, alive.size() - 1)]
			target["stress"] = minf(100.0, target["stress"] + 12.0)
			sim.add_event("NIGHTMARES", "%s struggled through a severe trauma episode." % target["name"], "warning")

	next_event_hour = sim.total_hours + sim.rng.randf_range(6.0, 14.0)
