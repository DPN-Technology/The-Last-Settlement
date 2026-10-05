class_name SaveMigration
extends RefCounted

const CURRENT_VERSION := 15
const MIN_SUPPORTED_VERSION := 1

var last_report: Array[String] = []

func migrate(raw: Dictionary) -> Dictionary:
	last_report.clear()
	var data: Dictionary = raw.duplicate(true)
	var version := int(data.get("version", 1))
	if version < MIN_SUPPORTED_VERSION:
		version = MIN_SUPPORTED_VERSION
	if version > CURRENT_VERSION:
		last_report.append("Save schema %d is newer than supported schema %d." % [version, CURRENT_VERSION])
		return {}
	while version < CURRENT_VERSION:
		var next_version := version + 1
		data = _migrate_step(data, version, next_version)
		if data.is_empty():
			last_report.append("Migration %d -> %d failed." % [version, next_version])
			return {}
		version = next_version
		data["version"] = version
		last_report.append("Migrated save schema %d -> %d." % [version - 1, version])
	_normalize_current(data)
	return data

func _migrate_step(data: Dictionary, from_version: int, to_version: int) -> Dictionary:
	# Historical schemas relied on load-time defaults. Preserve that behavior for
	# v1-v14, then make v15 the first explicit migration checkpoint.
	if to_version <= 14:
		return data
	if from_version == 14 and to_version == 15:
		var metadata: Dictionary = data.get("save_metadata", {})
		metadata["migrated_from"] = 14
		metadata["schema"] = 15
		data["save_metadata"] = metadata
		_ensure_civilization_state(data)
		_ensure_federal_state(data)
		return data
	return {}

func _normalize_current(data: Dictionary) -> void:
	data["version"] = CURRENT_VERSION
	var metadata: Dictionary = data.get("save_metadata", {})
	metadata["schema"] = CURRENT_VERSION
	data["save_metadata"] = metadata
	_ensure_civilization_state(data)
	_ensure_federal_state(data)

func _ensure_civilization_state(data: Dictionary) -> void:
	var civilization: Dictionary = data.get("civilization", {})
	if not civilization.has("settlements"):
		civilization["settlements"] = {}
	if not civilization.has("logistics_routes"):
		civilization["logistics_routes"] = []
	if not civilization.has("history_archive"):
		civilization["history_archive"] = []
	if not civilization.has("civilization_policies"):
		civilization["civilization_policies"] = {}
	if not civilization.has("emergency_log"):
		civilization["emergency_log"] = []
	if not civilization.has("colony_projects"):
		civilization["colony_projects"] = []
	if not civilization.has("recovery_projects"):
		civilization["recovery_projects"] = {}
	if not civilization.has("founding_roster"):
		civilization["founding_roster"] = []
	data["civilization"] = civilization

func _ensure_federal_state(data: Dictionary) -> void:
	var federal: Dictionary = data.get("federal_governance", {})
	if not federal.has("charter"):
		federal["charter"] = {}
	if not federal.has("representatives"):
		federal["representatives"] = {}
	if not federal.has("council_history"):
		federal["council_history"] = []
	data["federal_governance"] = federal
