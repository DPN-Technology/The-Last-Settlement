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
	"barrier": "concrete_road_barrier_02/concrete_road_barrier_02_1k.gltf",
	"shelf": "Shelf_01/Shelf_01_1k.gltf",
	"portable_generator": "portable_generator/portable_generator_1k.gltf",
	"rack": "worn_metal_rack/worn_metal_rack_1k.gltf",
	"tool_cart": "tool_cart/tool_cart_1k.gltf",
	"vintage_bed": "vintage_day_bed/vintage_day_bed_1k.gltf",
	"medical_bed": "old_bed_frame/old_bed_frame_1k.gltf",
	"office_desk": "metal_office_desk/metal_office_desk_1k.gltf",
	"storage_cart": "industrial_storage_cart/industrial_storage_cart_1k.gltf"
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
			var bed_replacements := 0
			for side in [-1.0,1.0]:
				for depth in [-0.24,0.25]:
					if add(site,"vintage_bed","RealLivedInShelterBed",Vector3(side*size.x*0.30,0.31,depth*size.y),1.92,0.0)!=null:
						bed_replacements+=1
			if bed_replacements==4:
				for primitive in room.get_children():
					if str(primitive.name) in ["BedFrame","Mattress","Blanket","Pillow","BedLeg"]:
						primitive.visible=false
			for side in [-1.0,1.0]:
				add(site,"shelf","RealShelterSupplyShelves",Vector3(side*size.x*0.35,0.31,hz*0.68),1.16,side*0.24)
		"command":
			if add(site,"table","RealOperationsPlanningTable",Vector3(0,0.31,hz*0.51),2.24,PI)!=null:
				_hide_named(room,["CommandPlanningDesk","CommandMapSurface","CommandTableMap"])
			add(site,"bench","RealCommandStationSeat",Vector3(0,0.31,-hz*0.15),1.18)
			for side in [-1.0,1.0]:
				add(site,"rack","RealCommandSupplyEquipmentRack",Vector3(side*size.x*0.37,0.31,hz*0.60),1.45,side*0.12)
				add(site,"office_desk","RealEngineeringOperatorDesk",Vector3(side*size.x*0.25,0.31,-hz*0.21),1.73,PI if side>0.0 else 0.0)
		"medical":
			add(site,"bench","RealClinicVisitorsBench",Vector3(0,0.31,hz*0.67),1.23)
			add(site,"tool_cart","RealClinicMedicalTrolley",Vector3(-size.x*0.27,0.31,hz*0.51),1.12,0.30)
			for side in [-1.0,1.0]:
				add(site,"medical_bed","RealClinicTreatmentFrame",Vector3(side*size.x*0.28,0.31,0),2.0)
			add(site,"storage_cart","RealClinicSupplyCart",Vector3(size.x*0.33,0.31,hz*0.44),1.26)
			add(site,"shelf","RealMedicalSuppliesShelves",Vector3(size.x*0.31,0.31,hz*0.69),1.24)
		"industry","storage":
			add(site,"table","RealFabricationWorkSurface",Vector3(0,0.31,hz*0.45),2.22)
			for side in [-1.0,1.0]:
				add(site,"rack","RealFabricationStorageRack",Vector3(side*size.x*0.34,0.31,hz*0.65),1.48)
			add(site,"tool_cart","RealMaintenanceToolCart",Vector3(-size.x*0.21,0.31,-hz*0.23),1.18)
			add(site,"storage_cart","RealWorkshopWornSteelCart",Vector3(size.x*0.30,0.31,hz*0.20),1.40)
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
	if kind in ["generator","power","battery"]:
		add(site,"portable_generator","RealPortableGenerator",Vector3(-hx*0.42,0.31,hz+1.70),1.35)
	if kind in ["medical","command"]:
		add(site,"rack","RealExternalSupplyRack",Vector3(hx+1.92,0.31,hz*0.24),1.36)
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
