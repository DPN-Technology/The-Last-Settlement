class_name SettlementNavigation
extends RefCounted

# World-plane navigation with exclusive door transitions into playable facility interiors.
# Exterior routes still treat buildings as solid. Only an actor that reached a
# specific door threshold can temporarily exclude that building's footprint.
# Furniture collisions and full NavMesh3D are future issue #8 stages.
const CLEARANCE := 6.0
const CORNER_MARGIN := 1.6
const MAX_NODES := 100

static func _is_solid(building: Dictionary) -> bool:
	return not str(building.get("type","")) in ["farm","floor","door","pipe","power_pole"]

static func collision_rects(buildings: Array[Dictionary]) -> Array[Rect2]:
	var rectangles: Array[Rect2] = []
	for building in buildings:
		if not _is_solid(building):
			continue
		var center := Vector2(building["position"])
		var size := Vector2(building["size"])
		rectangles.append(Rect2(center-size*0.5,size).grow(CLEARANCE))
	return rectangles

static func exterior_entry(building: Dictionary) -> Vector2:
	var center := Vector2(building.get("position",Vector2.ZERO))
	var size := Vector2(building.get("size",Vector2(40,40)))
	if not _is_solid(building):
		return center
	# The architecture facade's front access lies at local negative Z.
	# SettlementWorld3D maps this to decreasing Y on the 2D ground plane.
	return center+Vector2(0,-size.y*0.5-CLEARANCE-5.0)

static func _inside(point: Vector2, rectangles: Array[Rect2]) -> bool:
	for rect in rectangles:
		if rect.has_point(point):
			return true
	return false

static func resolve_walkable(point: Vector2, buildings: Array[Dictionary]) -> Vector2:
	# Existing saves may start a survivor inside a building. Correct to the
	# nearest exterior edge once rather than forcing every route through walls.
	var position := point
	var obstacles := collision_rects(buildings)
	for attempt in range(8):
		var adjusted := false
		for obstacle in obstacles:
			if not obstacle.has_point(position):
				continue
			var options := [
				Vector2(obstacle.position.x-CORNER_MARGIN,position.y),
				Vector2(obstacle.end.x+CORNER_MARGIN,position.y),
				Vector2(position.x,obstacle.position.y-CORNER_MARGIN),
				Vector2(position.x,obstacle.end.y+CORNER_MARGIN)
			]
			var nearest: Vector2 = options[0]
			for candidate in options:
				if candidate.distance_squared_to(position)<nearest.distance_squared_to(position):
					nearest = candidate
			position = nearest
			adjusted = true
			break
		if not adjusted:
			break
	return position

static func _segment_intersects_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	# Godot's Rect2 has no intersects_segment API; clip the segment to its
	# bounds using the slab interval rather than a nonexistent engine method.
	var delta := b-a
	var enter := 0.0
	var leave := 1.0
	for axis in range(2):
		var start := a.x if axis==0 else a.y
		var speed := delta.x if axis==0 else delta.y
		var lo := rect.position.x if axis==0 else rect.position.y
		var hi := rect.end.x if axis==0 else rect.end.y
		if absf(speed)<0.00001:
			if start>=lo and start<=hi:
				continue
			return false
		var first := (lo-start)/speed
		var second := (hi-start)/speed
		enter=maxf(enter,minf(first,second))
		leave=minf(leave,maxf(first,second))
		if enter>leave:
			return false
	return true

static func _visible(a: Vector2, b: Vector2, rectangles: Array[Rect2]) -> bool:
	for rect in rectangles:
		if _segment_intersects_rect(a,b,rect):
			return false
	return true

static func route(origin: Vector2, destination: Vector2, buildings: Array[Dictionary]) -> PackedVector2Array:
	var obstacles := collision_rects(buildings)
	var start := resolve_walkable(origin,buildings)
	var goal := resolve_walkable(destination,buildings)
	if start.distance_squared_to(goal)<1.0:
		return PackedVector2Array([goal])
	if _visible(start,goal,obstacles):
		return PackedVector2Array([goal])
	var nodes: Array[Vector2] = [start,goal]
	for rect in obstacles:
		var corners := [
			rect.position-Vector2(CORNER_MARGIN,CORNER_MARGIN),
			Vector2(rect.end.x+CORNER_MARGIN,rect.position.y-CORNER_MARGIN),
			rect.end+Vector2(CORNER_MARGIN,CORNER_MARGIN),
			Vector2(rect.position.x-CORNER_MARGIN,rect.end.y+CORNER_MARGIN)
		]
		for corner in corners:
			if not _inside(corner,obstacles):
				nodes.append(corner)
			if nodes.size()>=MAX_NODES:
				break
		if nodes.size()>=MAX_NODES:
			break
	var best: Array[float] = []
	var previous: Array[int] = []
	var visited: Array[bool] = []
	for index in range(nodes.size()):
		best.append(INF)
		previous.append(-1)
		visited.append(false)
	best[0] = 0.0
	for step in range(nodes.size()):
		var current := -1
		for i in range(nodes.size()):
			if not visited[i] and (current<0 or best[i]<best[current]):
				current = i
		if current<0 or best[current]==INF:
			break
		if current==1:
			break
		visited[current] = true
		for next in range(1,nodes.size()):
			if visited[next] or current==next:
				continue
			if not _visible(nodes[current],nodes[next],obstacles):
				continue
			var candidate := best[current]+nodes[current].distance_to(nodes[next])
			if candidate<best[next]:
				best[next]=candidate
				previous[next]=current
	if best[1]==INF:
		return PackedVector2Array()
	var reverse: Array[Vector2] = []
	var node := 1
	while node>0 and reverse.size()<=MAX_NODES:
		reverse.append(nodes[node])
		node=previous[node]
		if node<0:
			return PackedVector2Array()
	reverse.reverse()
	return PackedVector2Array(reverse)

static func valid_step(origin: Vector2, destination: Vector2, buildings: Array[Dictionary]) -> bool:
	return _visible(origin,destination,collision_rects(buildings))

# No save data is added: door metadata is derived from footprint and stable ID.
static func building_key(building: Dictionary) -> String:
	return "%s|%s|%s|%s" % [str(building.get("type","")),str(building.get("name","")),str(building.get("position",Vector2.ZERO)),str(building.get("size",Vector2.ZERO))]

static func access_points(building: Dictionary, citizen_id: int) -> Dictionary:
	var center := Vector2(building["position"])
	var size := Vector2(building["size"])
	var threshold := center+Vector2(0.0,-size.y*0.5)
	var col := posmod(citizen_id,3)-1
	var row := posmod(int(floor(float(citizen_id)/3.0)),3)
	# 3x3 work positions sit clear of the door's center aisle and of walls.
	var work := center+Vector2(float(col)*size.x*0.28,(-0.10+float(row)*0.17)*size.y)
	return {
		"key":building_key(building),
		"outside":exterior_entry(building),
		"threshold":threshold,
		"arrival":center+Vector2(0.0,-size.y*0.5+minf(20.0,size.y*0.25)),
		"work":work
	}

static func without_building(buildings: Array[Dictionary], access_building: Dictionary) -> Array[Dictionary]:
	var filtered: Array[Dictionary]=[]
	var exempt := building_key(access_building)
	for building in buildings:
		if building_key(building)!=exempt:
			filtered.append(building)
	return filtered

static func doorway_segment_allowed(from: Vector2, to: Vector2, building: Dictionary, others: Array[Dictionary]) -> bool:
	# The only legitimate crossing is the front opening, aligned with -Y.
	var door_x := Vector2(building["position"]).x
	if absf(from.x-door_x)>11.5 or absf(to.x-door_x)>11.5:
		return false
	if to.y<from.y and from.y>Vector2(building["position"]).y:
		return false
	return valid_step(from,to,without_building(others,building))
