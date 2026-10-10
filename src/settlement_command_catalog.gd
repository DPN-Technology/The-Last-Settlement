class_name SettlementCommandCatalog
extends RefCounted

# Reusable gameplay-backed presentation metadata. Never advertise a facility
# unless it has a corresponding, actually placeable SettlementSimulation entry.
const CATEGORIES := ["ALL", "HOMES", "POWER", "WATER", "SERVICES", "BASICS"]
const PURPOSE := {
	"wall":"Perimeter protection and room boundaries.",
	"floor":"Lay out additional floor or room space.",
	"door":"Add an opening to a wall or room.",
	"housing":"Beds and shelter capacity for survivors.",
	"storage":"Additional room for supplies and materials.",
	"generator":"Produces electricity, but consumes fuel.",
	"battery":"Stores surplus electricity for emergencies.",
	"power_pole":"Part of the settlement power distribution.",
	"water_pump":"Extracts raw water for treatment.",
	"purifier":"Turns raw water into clean drinking water.",
	"water_tank":"Water storage for future shortages.",
	"pipe":"Connects water and sanitation equipment.",
	"sewage":"Treats wastewater and protects sanitation.",
	"farm":"Growing food for the settlement.",
	"medical":"Medical treatment and recovery space.",
	"industry":"Industrial workstations and production."
}
const GROUPS := {
	"HOMES":["housing","storage"],
	"POWER":["generator","battery","power_pole"],
	"WATER":["water_pump","purifier","water_tank","pipe","sewage"],
	"SERVICES":["farm","medical","industry"],
	"BASICS":["wall","floor","door"]
}

static func category_indices(catalog: Array[Dictionary], category: String) -> Array[int]:
	var indices: Array[int] = []
	var accepted: Array = GROUPS.get(category, [])
	for i in range(catalog.size()):
		if category == "ALL" or str(catalog[i]["type"]) in accepted:
			indices.append(i)
	return indices

static func category_for(build_type: String) -> String:
	for group in GROUPS.keys():
		if build_type in GROUPS[group]:
			return str(group)
	return "ALL"

static func purpose(build_type: String) -> String:
	return str(PURPOSE.get(build_type, "Supports the settlement's recovery."))

static func rotate_allowed(build_type: String) -> bool:
	return build_type in ["wall", "door", "pipe"]

static func can_afford(definition: Dictionary, available: float) -> bool:
	return available >= float(definition["cost"])

static func selection_in_category(catalog: Array[Dictionary], category: String, selected: int, direction: int) -> int:
	var indices := category_indices(catalog, category)
	if indices.is_empty():
		return selected
	var current := indices.find(selected)
	if current < 0:
		return indices[0]
	return indices[posmod(current+direction, indices.size())]
