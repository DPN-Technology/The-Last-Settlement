class_name SettlementIncidentUI
extends RefCounted

# Single geometry and presentation-data contract for the F2 event console.
# The event history belongs to SettlementSimulation, and is never mutated by
# filters, acknowledgement, or grouping in the view.
const FILTERS := ["ALL","ALERTS","OPERATIONS","UNREAD"]

static func panel_rect(screen: Vector2) -> Rect2:
	var width := minf(screen.x-24.0,clampf(screen.x*0.40,430.0,610.0))
	var y := SettlementUILayout.TOP_H+9.0
	return Rect2(screen.x-width-12.0,y,width,maxf(370.0,screen.y-y-SettlementUILayout.BOTTOM_H-9.0))

static func close_rect(screen: Vector2) -> Rect2:
	var rect := panel_rect(screen)
	return Rect2(rect.end.x-46.0,rect.position.y+8.0,34.0,30.0)

static func tab_rect(screen: Vector2, index: int) -> Rect2:
	var rect := panel_rect(screen)
	var gap := 6.0
	var width := (rect.size.x-34.0-gap*3.0)/4.0
	return Rect2(rect.position+Vector2(17.0+float(index)*(width+gap),118.0),Vector2(width,32.0))

static func page_rect(screen: Vector2, index: int) -> Rect2:
	var rect := panel_rect(screen)
	return Rect2(rect.end.x-111.0+float(index)*47.0,rect.position.y+158.0,42.0,25.0)

static func visible_rows(screen: Vector2) -> int:
	return clampi(int(floor((panel_rect(screen).size.y-358.0)/54.0)),1,9)

static func row_rect(screen: Vector2, index: int) -> Rect2:
	var rect := panel_rect(screen)
	return Rect2(rect.position+Vector2(16.0,188.0+float(index)*54.0),Vector2(rect.size.x-32.0,51.0))

static func details_rect(screen: Vector2) -> Rect2:
	var rect := panel_rect(screen)
	return Rect2(rect.position.x+16.0,rect.end.y-161.0,rect.size.x-32.0,111.0)

static func action_rect(screen: Vector2, index: int) -> Rect2:
	var rect := panel_rect(screen)
	var gap := 6.0
	var width := (rect.size.x-34.0-3.0*gap)/4.0
	return Rect2(rect.position.x+17.0+float(index)*(width+gap),rect.end.y-41.0,width,31.0)

static func signature(event: Dictionary) -> String:
	return "%s|%s|%s|%s" % [str(event.get("day",0)),str(event.get("title","")),str(event.get("body","")),str(event.get("severity","intel"))]

static func groups(events: Array[Dictionary], filter_id: int, acknowledged: Dictionary) -> Array[Dictionary]:
	var grouped: Array[Dictionary]=[]
	var positions: Dictionary={}
	for event in events:
		var key := signature(event)
		if filter_id==1 and str(event.get("severity","intel")) not in ["warning","critical"]:
			continue
		if filter_id==2 and str(event.get("severity","intel")) in ["warning","critical"]:
			continue
		if filter_id==3 and acknowledged.has(key):
			continue
		if positions.has(key):
			var existing: Dictionary=grouped[int(positions[key])]
			existing["occurrences"]=int(existing["occurrences"])+1
			continue
		var row := event.duplicate(true)
		row["occurrences"]=1
		row["signature"]=key
		row["read"]=acknowledged.has(key)
		positions[key]=grouped.size()
		grouped.append(row)
	return grouped

static func route_for_event(event: Dictionary) -> String:
	var content := (str(event.get("title",""))+" "+str(event.get("body",""))).to_upper()
	for term in ["EXPEDITION","SCOUT","RELAY","REGION","SALVAGE TEAM","SITE DISCOVERED"]:
		if content.contains(term):
			return "REGION"
	for term in ["PRODUCTION","WORKSHOP","MARKET","MACHINE PARTS","COMPONENTS","MANUFACTUR","TRADE","WAREHOUSE"]:
		if content.contains(term):
			return "INDUSTRY"
	for term in ["COUNCIL","LAW","CRIME","SENTENCE","JUSTICE","CIVIC","POLICY"]:
		if content.contains(term):
			return "GOVERN"
	for term in ["FACTION","DIPLOMACY","NEIGHBOR","TRUCE"]:
		if content.contains(term):
			return "FACTIONS"
	for term in ["SURVIVOR","SHIFT","DUTY","PATIENT","INJURY","WORKFORCE"]:
		if content.contains(term):
			return "WORKFORCE"
	for term in ["GRID","POWER","WATER","SEWAGE","BUILD","STRUCTURE","CONSTRUCTION","FARM"]:
		if content.contains(term):
			return "BUILD"
	return ""
