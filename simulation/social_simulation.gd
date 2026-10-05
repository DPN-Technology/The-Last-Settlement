class_name SocialSimulation
extends RefCounted

const HOURS_PER_YEAR := 8760.0
const PREGNANCY_HOURS := 6480.0
const SOCIAL_TICK_HOURS := 1.0

var next_social_tick := 1.0

func update(sim: SettlementSimulation, sim_hours: float) -> void:
	_update_aging_and_family(sim, sim_hours)
	if sim.total_hours < next_social_tick:
		return
	next_social_tick = sim.total_hours + SOCIAL_TICK_HOURS

	var alive := sim.get_settlement_citizens()
	for citizen in alive:
		citizen["social_need"] = minf(100.0, float(citizen.get("social_need", 20.0)) + 1.6)
		if int(citizen["age"]) < 3:
			continue
		var partner := _find_social_partner(citizen, alive)
		if partner.is_empty():
			continue
		_interact(sim, citizen, partner)

	_evaluate_relationships(sim, alive)

func _find_social_partner(citizen: Dictionary, alive: Array[Dictionary]) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for other in alive:
		if int(other["id"]) == int(citizen["id"]):
			continue
		if citizen["position"].distance_to(other["position"]) <= 180.0:
			candidates.append(other)
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return citizen["position"].distance_to(a["position"]) < citizen["position"].distance_to(b["position"])
	)
	return candidates[0]

func _interact(sim: SettlementSimulation, a: Dictionary, b: Dictionary) -> void:
	var compatibility := _compatibility(a, b)
	var stress_penalty := (float(a["stress"]) + float(b["stress"])) / 200.0
	var change := compatibility - stress_penalty
	change += sim.rng.randf_range(-0.6, 0.8)

	_change_relationship(a, b, change)
	_change_relationship(b, a, change)
	a["social_need"] = maxf(0.0, float(a["social_need"]) - 7.0)
	b["social_need"] = maxf(0.0, float(b["social_need"]) - 5.0)

	if change > 0.55:
		a["morale"] = minf(100.0, float(a["morale"]) + 0.35)
		b["morale"] = minf(100.0, float(b["morale"]) + 0.25)
	elif change < -0.45:
		a["stress"] = minf(100.0, float(a["stress"]) + 0.5)
		b["stress"] = minf(100.0, float(b["stress"]) + 0.4)

	var score := _relationship_score(a, b)
	if score >= 70.0 and sim.rng.randf() < 0.04:
		_add_memory(a, "Shared a meaningful conversation with %s." % b["name"], "social", sim)
		_add_memory(b, "Felt understood by %s." % a["name"], "social", sim)
	elif score <= -35.0 and sim.rng.randf() < 0.05:
		_add_memory(a, "Had a serious argument with %s." % b["name"], "conflict", sim)
		_add_memory(b, "Clashed with %s." % a["name"], "conflict", sim)

func _compatibility(a: Dictionary, b: Dictionary) -> float:
	var trait_a := str(a.get("trait",""))
	var trait_b := str(b.get("trait",""))
	if trait_a == trait_b:
		return 0.65
	var positive_pairs := [
		["Protective","Empathetic"], ["Optimist","Stoic"], ["Curious","Resourceful"],
		["Cautious","Protective"], ["Empathetic","Optimist"]
	]
	for pair in positive_pairs:
		if (trait_a == pair[0] and trait_b == pair[1]) or (trait_a == pair[1] and trait_b == pair[0]):
			return 0.85
	if (trait_a == "Stubborn" and trait_b == "Stubborn"):
		return -0.45
	return 0.25

func _change_relationship(a: Dictionary, b: Dictionary, amount: float) -> void:
	var key := str(int(b["id"]))
	var relationships: Dictionary = a["relationships"]
	var score := float(relationships.get(key, 0.0))
	relationships[key] = clampf(score + amount, -100.0, 100.0)

func _relationship_score(a: Dictionary, b: Dictionary) -> float:
	return float(a["relationships"].get(str(int(b["id"])), 0.0))

func _evaluate_relationships(sim: SettlementSimulation, alive: Array[Dictionary]) -> void:
	for citizen in alive:
		if int(citizen["age"]) < 18:
			continue
		var current_partner_id := int(citizen.get("partner_id", 0))
		if current_partner_id > 0:
			var partner := sim.get_citizen_by_id(current_partner_id)
			if partner.is_empty() or not partner["alive"]:
				citizen["partner_id"] = 0
				_add_memory(citizen, "Lost their partner.", "loss", sim)
				continue
			if _relationship_score(citizen, partner) < -45.0:
				citizen["partner_id"] = 0
				if int(partner.get("partner_id",0)) == int(citizen["id"]):
					partner["partner_id"] = 0
				_add_memory(citizen, "Ended a relationship with %s." % partner["name"], "relationship", sim)
				sim.add_event("RELATIONSHIP ENDED", "%s and %s separated." % [citizen["name"], partner["name"]], "intel")
			continue

		var best: Dictionary = {}
		var best_score := 76.0
		for other in alive:
			if int(other["id"]) == int(citizen["id"]) or int(other["age"]) < 18 or int(other.get("partner_id",0)) != 0:
				continue
			var score := _relationship_score(citizen, other)
			if score > best_score:
				best = other
				best_score = score
		if not best.is_empty() and sim.rng.randf() < 0.025:
			citizen["partner_id"] = int(best["id"])
			best["partner_id"] = int(citizen["id"])
			var family := str(citizen["name"]).split(" ")[-1]
			citizen["family_name"] = family
			best["family_name"] = family
			_add_memory(citizen, "Began a partnership with %s." % best["name"], "relationship", sim)
			_add_memory(best, "Began a partnership with %s." % citizen["name"], "relationship", sim)
			sim.add_event("NEW PARTNERSHIP", "%s and %s became partners." % [citizen["name"], best["name"]], "good")

func _update_aging_and_family(sim: SettlementSimulation, sim_hours: float) -> void:
	var alive := sim.get_alive_citizens()
	for citizen in alive:
		citizen["birthday_progress"] = float(citizen.get("birthday_progress",0.0)) + sim_hours
		while float(citizen["birthday_progress"]) >= HOURS_PER_YEAR:
			citizen["birthday_progress"] = float(citizen["birthday_progress"]) - HOURS_PER_YEAR
			citizen["age"] = int(citizen["age"]) + 1
			_add_memory(citizen, "Turned %d years old." % int(citizen["age"]), "life", sim)
			if int(citizen["age"]) == 16 and citizen["job"] == "Child":
				citizen["job"] = CitizenFactory.JOBS[sim.rng.randi_range(0, CitizenFactory.JOBS.size()-1)]
				sim.add_event("COMING OF AGE", "%s entered the settlement workforce as a %s." % [citizen["name"], citizen["job"]], "good")

		if float(citizen.get("pregnancy_hours",0.0)) > 0.0:
			citizen["pregnancy_hours"] = float(citizen["pregnancy_hours"]) + sim_hours
			if float(citizen["pregnancy_hours"]) >= PREGNANCY_HOURS:
				_birth_child(sim, citizen)
			continue

		if str(citizen.get("sex","")) != "Female":
			continue
		if int(citizen["age"]) < 18 or int(citizen["age"]) > 42:
			continue
		var partner_id := int(citizen.get("partner_id",0))
		if partner_id == 0:
			continue
		var partner := sim.get_citizen_by_id(partner_id)
		if partner.is_empty() or int(partner["age"]) < 18:
			continue
		if _relationship_score(citizen, partner) < 55.0:
			continue
		if sim.rng.randf() < 0.00002 * sim_hours:
			citizen["pregnancy_hours"] = 1.0
			_add_memory(citizen, "Learned they are expecting a child.", "family", sim)
			_add_memory(partner, "Learned their family is growing.", "family", sim)
			sim.add_event("FAMILY NEWS", "%s and %s are expecting a child." % [citizen["name"], partner["name"]], "good")

func _birth_child(sim: SettlementSimulation, mother: Dictionary) -> void:
	var partner := sim.get_citizen_by_id(int(mother.get("partner_id",0)))
	var child := CitizenFactory.create_child(sim.next_citizen_id, sim.rng, mother, partner)
	sim.next_citizen_id += 1
	sim.citizens.append(child)
	mother["children_ids"].append(int(child["id"]))
	child["parent_ids"].append(int(mother["id"]))
	if not partner.is_empty():
		partner["children_ids"].append(int(child["id"]))
		child["parent_ids"].append(int(partner["id"]))
	mother["pregnancy_hours"] = 0.0
	_add_memory(mother, "Gave birth to %s." % child["name"], "family", sim)
	if not partner.is_empty():
		_add_memory(partner, "%s was born." % child["name"], "family", sim)
	sim.add_event("BIRTH", "%s was born into the settlement." % child["name"], "good")

func _add_memory(citizen: Dictionary, text: String, kind: String, sim: SettlementSimulation) -> void:
	var memories: Array = citizen["memories"]
	memories.push_front({
		"text": text,
		"kind": kind,
		"day": sim.day,
		"hour": sim.hour
	})
	if memories.size() > 16:
		memories.resize(16)
