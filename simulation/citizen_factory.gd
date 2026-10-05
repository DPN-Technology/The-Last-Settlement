class_name CitizenFactory
extends RefCounted

const FIRST_NAMES := [
	"Mara", "Eli", "June", "Caleb", "Nora", "Silas", "Rhea", "Jonah",
	"Avery", "Mason", "Tessa", "Isaac", "Lena", "Rowan", "Dahlia", "Owen"
]
const LAST_NAMES := [
	"Kane", "Mercer", "Vale", "Hart", "Reed", "Cross", "Stone", "Voss",
	"Rivers", "Hale", "Ward", "Quinn"
]
const JOBS := ["Farmer", "Engineer", "Builder", "Medic", "Scavenger", "Guard", "Cook", "Hauler"]
const TRAITS := ["Protective", "Optimist", "Cautious", "Resourceful", "Stoic", "Curious", "Stubborn", "Empathetic"]

static func create(id: int, rng: RandomNumberGenerator) -> Dictionary:
	var job: String = JOBS[rng.randi_range(0, JOBS.size() - 1)]
	return {
		"id": id,
		"name": "%s %s" % [
			FIRST_NAMES[rng.randi_range(0, FIRST_NAMES.size() - 1)],
			LAST_NAMES[rng.randi_range(0, LAST_NAMES.size() - 1)]
		],
		"age": rng.randi_range(18, 58),
		"sex": "Female" if rng.randf() < 0.5 else "Male",
		"job": job,
		"trait": TRAITS[rng.randi_range(0, TRAITS.size() - 1)],
		"health": rng.randf_range(78.0, 100.0),
		"morale": rng.randf_range(55.0, 90.0),
		"loyalty": rng.randf_range(50.0, 95.0),
		"hunger": rng.randf_range(0.0, 18.0),
		"thirst": rng.randf_range(0.0, 12.0),
		"fatigue": rng.randf_range(0.0, 20.0),
		"stress": rng.randf_range(5.0, 32.0),
		"injury": "",
		"treatment_progress": 0.0,
		"current_action": "Idle",
		"shift": "DAY",
		"work_priority": {
			"Farmer": 3,
			"Engineer": 3,
			"Builder": 3,
			"Medic": 3,
			"Scavenger": 3,
			"Guard": 3,
			"Cook": 3,
			"Hauler": 3
		},
		"skills": {
			"construction": rng.randi_range(10, 80),
			"medicine": rng.randi_range(5, 80),
			"farming": rng.randi_range(8, 80),
			"engineering": rng.randi_range(5, 80),
			"security": rng.randi_range(5, 80)
		},
		"inventory": {
			"food_ration": 0,
			"water_ration": 0,
			"medicine": 0,
			"scrap": 0
		},
		"alive": true,
		"position": Vector2(rng.randf_range(360, 1120), rng.randf_range(210, 700)),
		"target": Vector2.ZERO,
		"target_building": "",
		"target_blueprint_id": 0,
		"social_need": rng.randf_range(10.0, 35.0),
		"relationships": {},
		"partner_id": 0,
		"parent_ids": [],
		"children_ids": [],
		"family_name": "",
		"memories": [],
		"pregnancy_hours": 0.0,
		"birthday_progress": 0.0
	}

static func skill_multiplier(citizen: Dictionary, skill: String) -> float:
	return 0.65 + (float(citizen["skills"].get(skill, 25)) / 100.0)

static func best_skill_for_job(citizen: Dictionary) -> String:
	match citizen["job"]:
		"Farmer":
			return "farming"
		"Engineer":
			return "engineering"
		"Builder":
			return "construction"
		"Medic":
			return "medicine"
		"Guard":
			return "security"
		_:
			return "construction"


static func create_child(id: int, rng: RandomNumberGenerator, mother: Dictionary, partner: Dictionary) -> Dictionary:
	var family_name := str(mother.get("family_name",""))
	if family_name == "":
		family_name = str(mother["name"]).split(" ")[-1]
	var child := create(id, rng)
	child["name"] = "%s %s" % [FIRST_NAMES[rng.randi_range(0, FIRST_NAMES.size() - 1)], family_name]
	child["age"] = 0
	child["job"] = "Child"
	child["health"] = rng.randf_range(86.0, 100.0)
	child["morale"] = 75.0
	child["loyalty"] = 80.0
	child["hunger"] = 8.0
	child["thirst"] = 6.0
	child["fatigue"] = 12.0
	child["stress"] = 2.0
	child["position"] = mother["position"] + Vector2(rng.randf_range(-8.0,8.0), rng.randf_range(-8.0,8.0))
	child["target"] = child["position"]
	child["family_name"] = family_name
	child["relationships"] = {}
	child["partner_id"] = 0
	child["parent_ids"] = []
	child["children_ids"] = []
	child["memories"] = [{"text":"Born into the settlement.","kind":"family","day":0,"hour":0.0}]
	child["pregnancy_hours"] = 0.0
	child["birthday_progress"] = 0.0
	if not partner.is_empty():
		child["relationships"][str(int(partner["id"]))] = 65.0
	child["relationships"][str(int(mother["id"]))] = 75.0
	return child
