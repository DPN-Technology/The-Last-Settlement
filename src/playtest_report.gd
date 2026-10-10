class_name PlaytestReporter
extends RefCounted

# Deliberately records game state only. Never captures accounts, files or system identifiers.
const REPORT_DIRECTORY := "user://playtest-reports"
const MAX_EVENTS := 8

static func capture(sim: SettlementSimulation) -> String:
	var directory := ProjectSettings.globalize_path(REPORT_DIRECTORY)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(directory)
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		return ""

	var recent_events: Array[Dictionary] = []
	for index in range(mini(MAX_EVENTS, sim.events.size())):
		var incident: Dictionary = sim.events[index]
		recent_events.append({
			"title": str(incident.get("title", "")),
			"day": int(incident.get("day", 0)),
			"severity": str(incident.get("severity", "")),
			"body": str(incident.get("body", ""))
		})

	var resources: Dictionary = {}
	for key in ["food", "water", "medicine", "materials", "scrap", "meals", "power"]:
		resources[key] = float(sim.resources.get(key, 0.0))

	var report := {
		"format_version": 1,
		"game_version": str(ProjectSettings.get_setting("application/config/version", "unknown")),
		"save_schema": SettlementSimulation.SAVE_VERSION,
		"captured_utc": Time.get_datetime_string_from_system(true),
		"settlement": sim.settlement_name,
		"day": sim.day,
		"hour": sim.hour,
		"paused": sim.paused,
		"simulation_speed": sim.speed,
		"survivors_alive": sim.get_alive_citizens().size(),
		"survivors_total": sim.citizens.size(),
		"building_count": sim.buildings.size(),
		"active_blueprints": sim.blueprints.size(),
		"resources": resources,
		"recent_events": recent_events
	}

	var filename := "settlement-playtest-%d.json" % int(Time.get_unix_time_from_system())
	var report_path := REPORT_DIRECTORY.path_join(filename)
	var output := FileAccess.open(report_path, FileAccess.WRITE)
	if output == null:
		return ""
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	return ProjectSettings.globalize_path(report_path)
