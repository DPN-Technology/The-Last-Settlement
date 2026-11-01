class_name SettlementCommandPalette
extends RefCounted

# Session-only, read-only command discovery. Each destination opens an existing
# gameplay system or a real blueprint; the palette itself never changes saves.
const COMMANDS := [
	{"id":"COMMAND","title":"Settlement Command","detail":"Four-page executive briefing and recovery priorities","keywords":"home dashboard overview intelligence settlement"},
	{"id":"BUILD","title":"Construction Planner","detail":"Place facilities, utilities, shelters, rooms and defenses","keywords":"build blueprints structure"},
	{"id":"REGION","title":"Region & Expeditions","detail":"Explore ruins, manage teams and recover supplies","keywords":"map scout exploration salvage missions"},
	{"id":"GOVERN","title":"Governance Council","detail":"Review laws, policy impacts and public stability","keywords":"council government politics laws justice"},
	{"id":"INDUSTRY","title":"Industry & Trade","detail":"Check stock, markets and production chains","keywords":"economy warehouse trade manufacturing"},
	{"id":"WORKSHOP","title":"Production Workshop","detail":"Open the live manufacturing queue and recipe controls","keywords":"industry factory jobs recipes orders"},
	{"id":"WORKFORCE","title":"Survivor Workforce","detail":"Manage survivors, jobs, shifts and duty assignments","keywords":"people roster workers citizens personnel staffing"},
	{"id":"INCIDENTS","title":"Incident Command","detail":"Filter, acknowledge and investigate settlement events","keywords":"alerts emergency notifications events security"},
	{"id":"FACTIONS","title":"Factions & Diplomacy","detail":"Inspect neighbors, treaties, threats and trade relations","keywords":"allies rival reputation conflict politics"},
	{"id":"NATION","title":"Civilization Network","detail":"Oversee colonies, logistics, policy and recovery","keywords":"colonies settlements federal nation logistics"},
	{"id":"GUIDE","title":"Interactive Field Guide","detail":"Open six playable tutorials and system shortcuts","keywords":"help tutorial onboarding instructions"},
	{"id":"BUILD_FARM","title":"Build Food Farm","detail":"Select the farm blueprint to restore food production","keywords":"emergency hunger crops farming construction"},
	{"id":"BUILD_WATER","title":"Build Water Purifier","detail":"Select purification equipment for drinking water","keywords":"emergency thirst pump clean water construction"},
	{"id":"BUILD_POWER","title":"Build Generator","detail":"Select the power generator blueprint","keywords":"emergency electricity outage grid construction"},
	{"id":"BUILD_MEDICAL","title":"Build Medical Clinic","detail":"Select the medical facility blueprint","keywords":"healthcare patient injuries treatment hospital construction"}
]

static func panel_rect(view: Vector2) -> Rect2:
	var width := minf(710.0,view.x-36.0)
	var usable := maxf(330.0,view.y-SettlementUILayout.TOP_H-SettlementUILayout.BOTTOM_H-18.0)
	var height := minf(540.0,usable)
	return Rect2((view.x-width)*0.5,SettlementUILayout.TOP_H+maxf(8.0,(usable-height)*0.5),width,height)

static func close_rect(view: Vector2) -> Rect2:
	var panel := panel_rect(view)
	return Rect2(panel.end.x-48.0,panel.position.y+11.0,33.0,30.0)

static func search_rect(view: Vector2) -> Rect2:
	var panel := panel_rect(view)
	return Rect2(panel.position+Vector2(17.0,66.0),Vector2(panel.size.x-34.0,39.0))

static func visible_rows(view: Vector2) -> int:
	return clampi(int(floor((panel_rect(view).size.y-190.0)/48.0)),1,7)

static func row_rect(view: Vector2, index: int) -> Rect2:
	var panel := panel_rect(view)
	return Rect2(panel.position+Vector2(17.0,124.0+48.0*float(index)),Vector2(panel.size.x-34.0,44.0))

static func results(query: String) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	var normalized := query.to_lower().strip_edges()
	var words := normalized.split(" ",false)
	for entry in COMMANDS:
		var command: Dictionary = entry
		if normalized.is_empty():
			matches.append(command)
			continue
		var haystack := ("%s %s %s %s" % [command["title"],command["detail"],command["keywords"],command["id"]]).to_lower()
		var all_found := true
		for word in words:
			if not haystack.contains(word):
				all_found=false
				break
		if all_found:
			matches.append(command)
	return matches

static func first_visible(selected: int, count: int, capacity: int) -> int:
	return clampi(selected-capacity+1,0,maxi(0,count-capacity))
