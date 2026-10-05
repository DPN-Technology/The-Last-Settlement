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
		"job": job,
		"trait": TRAITS[rng.randi_range(0, TRAITS.size() - 1)],
		"health": rng.randf_range(78.0, 100.0),
		"morale": rng.randf_range(55.0, 90.0),
		"loyalty": rng.randf_range(50.0, 95.0),
		"hunger": rng.randf_range(0.0, 18.0),
		"thirst": rng.randf_range(0.0, 12.0),
		"fatigue": rng.randf_range(0.0, 20.0),
		"stress": rng.randf_range(5.0, 32.0),
		"current_action": "Idle",
		"shift": "DAY",
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
		"target_building": ""
	}

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
