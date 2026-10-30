extends SceneTree

var failures := 0

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("SAVE IO: "+message)
		failures+=1

func _write(path: String, text: String) -> bool:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file==null:
		_check(false,"cannot create fixture: "+error_string(FileAccess.get_open_error()))
		return false
	file.store_string(text)
	file.close()
	return true

func _snapshot(sim: SettlementSimulation) -> Dictionary:
	return {
		"day":sim.day, "hour":sim.hour, "name":sim.settlement_name,
		"resources":sim.resources.duplicate(true), "citizens":sim.citizens.duplicate(true),
		"buildings":sim.buildings.duplicate(true), "laws":sim.governance_simulation.laws.duplicate(true)
	}

func _resources_match(a: Dictionary, b: Dictionary) -> bool:
	if a.size()!=b.size():
		return false
	for key in a:
		if not b.has(key) or absf(float(a[key])-float(b[key]))>0.001:
			return false
	return true

func _remove(path: String) -> void:
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
		DirAccess.remove_absolute(path)

func _initialize() -> void:
	var sim := SettlementSimulation.new()
	sim.speed=12.0
	for i in 400:
		sim.update(0.25)
	var path := "user://save_io_test_%d.json" % Time.get_ticks_usec()
	var temp_path := path+SettlementSimulation.SAVE_TEMP_SUFFIX
	var backup_path := path+SettlementSimulation.SAVE_BACKUP_SUFFIX
	_check(not sim.load_game(path),"missing file accepted")
	_check(str(sim.events[0]["title"])=="LOAD FAILED","missing file feedback absent")
	_check(not sim.save_game(path+"/missing/save.json"),"invalid destination accepted")
	_check(str(sim.events[0]["title"])=="SAVE FAILED","write failure feedback absent")
	var before := _snapshot(sim)
	for invalid in ["", "{\"day\":99,", "[]", "null", "42"]:
		if not _write(path,invalid):
			break
		_check(not sim.load_game(path),"invalid JSON/root accepted: "+invalid)
		_check(str(sim.events[0]["title"])=="LOAD FAILED","invalid save feedback absent")
		_check(_snapshot(sim)==before,"failed load changed campaign state: "+invalid)
	# "day" comes first so the previous loader would have applied it before
	# hitting the damaged field.
	for damaged in [
		{"day":99,"resources":[]},
		{"day":"ninety-nine"},
		{"day":99,"citizens":[1]},
		{"day":99,"buildings":[{"position":{"__vector2":true,"x":"a","y":1}}]},
		{"day":99,"stockpiles":{"command":{"food":"lots"}}},
		{"day":99,"field_objectives":{"inspected":"yes"}},
		{"day":99,"governance":{"laws":[]}},
		{"day":99,"economy":{"production_paused":"yes"}},
		{"day":99,"civilization":{"settlements":{"LAST_HAVEN":3}}},
		{"day":99,"weather":null},
		{"day":99,"version":SettlementSimulation.SAVE_VERSION+1}
	]:
		var text := JSON.stringify(damaged)
		if not _write(path,text):
			break
		_check(not sim.load_game(path),"damaged save accepted: "+text)
		_check(str(sim.events[0]["body"]).begins_with("Save data is damaged"),"damaged save feedback absent: "+text)
		_check(_snapshot(sim)==before,"damaged save changed campaign state: "+text)
	_remove(path)
	_check(sim.save_game(path),"valid save failed")
	_check(str(sim.events[0]["title"])=="SAVE COMPLETE","valid save feedback absent")
	_check(not FileAccess.file_exists(temp_path),"temp file left after first save")
	_check(not FileAccess.file_exists(backup_path),"backup created without a previous save")
	sim.day=99
	_check(sim.load_game(path),"valid round trip failed")
	_check(sim.day==int(before["day"]) and _resources_match(sim.resources,before["resources"]) and sim.citizens.size()==before["citizens"].size(),"round trip changed day/resources/citizens")
	var first_day := sim.day
	sim.day=first_day+5
	_check(sim.save_game(path),"overwrite save failed")
	_check(FileAccess.file_exists(backup_path),"previous save not kept as backup")
	_check(not FileAccess.file_exists(temp_path),"temp file left after overwrite")
	var live_text := FileAccess.get_file_as_string(path)
	# A directory squatting on the temp name forces the write itself to fail.
	DirAccess.make_dir_absolute(temp_path)
	sim.day=first_day+9
	_check(not sim.save_game(path),"save accepted with unwritable temp file")
	_check(str(sim.events[0]["title"])=="SAVE FAILED","temp write failure feedback absent")
	_check(FileAccess.get_file_as_string(path)==live_text,"failed temp write changed the live save")
	_remove(temp_path)
	# A directory squatting on the backup name forces the swap to fail.
	_remove(backup_path)
	DirAccess.make_dir_absolute(backup_path)
	_check(not sim.save_game(path),"save accepted with blocked backup")
	_check(str(sim.events[0]["title"])=="SAVE FAILED","backup failure feedback absent")
	_check(FileAccess.get_file_as_string(path)==live_text,"failed swap changed the live save")
	_check(not FileAccess.file_exists(temp_path),"temp file left after failed swap")
	_remove(backup_path)
	# Crash between moving the live save aside and installing the new one.
	sim.day=first_day+7
	_check(sim.save_game(path),"save before recovery test failed")
	_remove(path)
	_write(temp_path,"{\"day\":")
	sim.day=1234
	_check(sim.load_game(path),"interrupted save could not be recovered from backup")
	_check(str(sim.events[0]["title"])=="LOAD RECOVERED","backup recovery feedback absent")
	_check(sim.day==first_day+5,"backup recovery restored the wrong campaign day")
	# Older saves without optional sections or a version field still load.
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(backup_path))
	for key in ["version","weather","field_objectives","civilization","federal_governance"]:
		legacy.erase(key)
	_write(path,JSON.stringify(legacy))
	sim.day=1234
	_check(sim.load_game(path),"legacy-shaped save rejected")
	_check(sim.day==first_day+5,"legacy-shaped save restored the wrong campaign day")
	for leftover in [path,temp_path,backup_path]:
		_remove(leftover)
		_check(not FileAccess.file_exists(leftover) and not DirAccess.dir_exists_absolute(leftover),"fixture cleanup failed: "+leftover)
	if failures==0:
		print("SAVE IO PASS: failure feedback, damaged-save rejection without partial restore, atomic replace with backup recovery and legacy compatibility")
	quit(0 if failures==0 else 1)
