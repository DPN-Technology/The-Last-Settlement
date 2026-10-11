class_name SettlementAuthenticModel3D
extends RefCounted

# Authentic CC0, texture-backed glTF scenes. Models are additive and visual-only:
# save schema, click picking, pathfinding, doors and HUD remain unaffected.
const PATH := "res://assets/3d/photoreal/"
const MODELS := {
	"barrel": "barrel_03/barrel_03_1k.gltf",
	"table": "painted_wooden_table/painted_wooden_table_1k.gltf",
	"bench": "painted_wooden_bench/painted_wooden_bench_1k.gltf",
	"car": "covered_car/covered_car_1k.gltf",
	"barrier": "concrete_road_barrier_02/concrete_road_barrier_02_1k.gltf"
}
static var _cached: Dictionary={}

static func _get_scene(asset: String) -> PackedScene:
	if _cached.has(asset):
		return _cached[asset] as PackedScene
	var path: String=PATH+str(MODELS.get(asset,""))
	if not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	if scene!=null:
		_cached[asset]=scene
	return scene

static func _bounds(model: Node3D) -> AABB:
	# Calculate bounds in the parent-model local space, handling nested nodes.
	var aabb := AABB(Vector3.INF,Vector3.ZERO)
	var seen := false
	for child in model.find_children("*","MeshInstance3D",true,false):
		var item := child as MeshInstance3D
		if item.mesh==null:
			continue
		var bounds := item.get_aabb()
		for ix in [0,1]:
			for iy in [0,1]:
				for iz in [0,1]:
					var v := bounds.position+Vector3(bounds.size.x*float(ix),bounds.size.y*float(iy),bounds.size.z*float(iz))
					var local := model.to_local(item.to_global(v))
					if not seen:
						aabb=AABB(local,Vector3.ZERO)
						seen=true
					else:
						aabb=aabb.expand(local)
	return aabb

static func add(parent: Node3D, asset: String, name: String, p: Vector3, width: float, yaw: float=0.0) -> Node3D:
	var scene := _get_scene(asset)
	if scene==null:
		return null
	var instance := scene.instantiate() as Node3D
	if instance==null:
		return null
	var holder := Node3D.new()
	holder.name=name
	holder.position=p
	holder.rotation.y=yaw
	parent.add_child(holder)
	holder.add_child(instance)
	instance.name="PhotogrammetricPBRModel"
	var bounds := _bounds(instance)
	var horizontal: float=maxf(bounds.size.x,bounds.size.z)
	if horizontal<0.01:
		holder.queue_free()
		return null
	var target_scale: float=width/horizontal
	instance.scale=Vector3.ONE*target_scale
	instance.position=Vector3(-bounds.get_center().x*target_scale,-bounds.position.y*target_scale,-bounds.get_center().z*target_scale)
	holder.set_meta("real_model",asset)
	holder.set_meta("source","polyhaven CC0 1k gltf")
	return holder

static func _hide_named(room: Node3D, names: Array[String]) -> void:
	for name in names:
		var item := room.find_child(name,true,false)
		if item!=null:
			item.visible=false

static func build_interiors(structure: Node3D, kind: String, size: Vector2) -> void:
	var room := structure.get_node_or_null("InteriorFurnishings") as Node3D
	if room==null:
		return
	var site := Node3D.new()
	site.name="RealReferenceInteriorAssets"
	room.add_child(site)
	var hz: float=size.y*0.5
	match kind:
		"housing":
			if add(site,"table","RealWeatheredCommunalTable",Vector3(0,0.31,hz*0.52),1.89,PI)!=null:
				_hide_named(room,["SharedDiningTable","SharedShelterTable","CommandPlanningDesk"])
			add(site,"bench","RealShelterSeat",Vector3(0,0.31,hz*0.23),1.18)
		"command":
			if add(site,"table","RealOperationsPlanningTable",Vector3(0,0.31,hz*0.51),2.24,PI)!=null:
				_hide_named(room,["CommandPlanningDesk","CommandMapSurface","CommandTableMap"])
			add(site,"bench","RealCommandStationSeat",Vector3(0,0.31,-hz*0.15),1.18)
		"medical":
			add(site,"bench","RealClinicVisitorsBench",Vector3(0,0.31,hz*0.67),1.23)
		"industry","storage":
			add(site,"table","RealFabricationWorkSurface",Vector3(0,0.31,hz*0.45),2.22)
		_:
			pass

static func build_facility(structure: Node3D, kind: String, size: Vector2) -> void:
	var site := Node3D.new()
	site.name="RealReferenceExteriorAssets"
	structure.add_child(site)
	var hz: float=size.y*0.5
	var hx: float=size.x*0.5
	for side in [-1.0,1.0]:
		add(site,"barrel","RealWeatheredBarrel_"+str(side),Vector3(side*(hx+1.35),0.31,hz*0.15),0.76,side*PI*0.34)
	if kind in ["industry","generator","storage"]:
		add(site,"barrier","RealBatteredConcreteRoadBarrier",Vector3(0,0.31,hz+2.70),1.70,PI*0.5)
	build_interiors(structure,kind,size)

static func build_world(parent: Node3D) -> void:
	var yard := Node3D.new()
	yard.name="RealCC0SettlementScans"
	parent.add_child(yard)
	# Atmospheric, licensed real-world wreckage beyond player access roads.
	add(yard,"car","AbandonedClothCoveredVehicle",Vector3(-54.0,0.03,25.0),4.55,-0.51)
	add(yard,"car","PerimeterScavengedVehicle",Vector3(62.0,0.03,-38.0),4.38,0.96)
	for x in [-44.0,-40.7,-37.4]:
		add(yard,"barrier","DamagedPerimeterDivider",Vector3(x,0.05,-38.5),1.76,0.09)
