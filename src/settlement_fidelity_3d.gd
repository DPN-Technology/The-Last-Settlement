class_name SettlementFidelity3D
extends RefCounted

# Actual 3D art accents. Decorative until navigation colliders are authored.
# Keeping this separate preserves the world, simulation, and existing saves.
static func box(parent: Node3D, title: String, pos: Vector3, dims: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name=title
	var mesh := BoxMesh.new()
	mesh.size=dims
	node.mesh=mesh
	node.position=pos
	node.material_override=mat
	parent.add_child(node)
	return node

static func cylinder(parent: Node3D, title: String, pos: Vector3, radius: float, h: float, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name=title
	var mesh := CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.height=h
	mesh.radial_segments=12
	node.mesh=mesh
	node.position=pos
	node.material_override=mat
	parent.add_child(node)
	return node

# Draw-call-friendly ground vegetation, rubble and rocks beyond playable roads.
static func _multi(parent: Node3D, title: String, mesh: Mesh, mat: Material, amount: int, seed: int) -> void:
	var layer := MultiMeshInstance3D.new()
	layer.name=title
	var instances := MultiMesh.new()
	instances.transform_format=MultiMesh.TRANSFORM_3D
	instances.mesh=mesh
	instances.instance_count=amount
	layer.multimesh=instances
	layer.material_override=mat
	parent.add_child(layer)
	var rng := RandomNumberGenerator.new()
	rng.seed=seed
	var height_noise := FastNoiseLite.new()
	height_noise.seed=114722
	height_noise.noise_type=FastNoiseLite.TYPE_SIMPLEX
	height_noise.frequency=0.015
	height_noise.fractal_octaves=4
	for index in range(amount):
		var x: float=rng.randf_range(-126.0,126.0)
		var z: float=rng.randf_range(-115.0,115.0)
		# Do not block entrance, farm, roads or existing future build plots.
		if absf(x)<73.0 and absf(z)<49.0:
			if absf(x)<absf(z):
				x=signf(x)*rng.randf_range(76.0,123.0)
			else:
				z=signf(z)*rng.randf_range(52.0,111.0)
		var yaw: float=rng.randf_range(0.0,TAU)
		var scale := Vector3(rng.randf_range(0.35,2.00),rng.randf_range(0.20,0.68),rng.randf_range(0.35,1.95))
		var basis := WastelandDetail.terrain_basis(x,z,height_noise,yaw,scale)
		var y: float=WastelandDetail.terrain_height(x,z,height_noise)+mesh.get_aabb().size.y*scale.y*0.35
		instances.set_instance_transform(index,Transform3D(basis,Vector3(x,y,z)))

static func terrain(parent: Node3D, mats: Dictionary) -> Node3D:
	var layer := Node3D.new()
	layer.name="FidelityTerrainDressing"
	parent.add_child(layer)
	var rock := SphereMesh.new()
	rock.radius=0.48
	rock.height=0.92
	rock.radial_segments=7
	rock.rings=4
	_multi(layer,"InstancedWastelandRocks",rock,mats["stone"],700,219721)
	var scrap := BoxMesh.new()
	scrap.size=Vector3(0.90,0.10,0.47)
	_multi(layer,"InstancedRustedScrap",scrap,mats["rust"],250,819114)
	var scrub := SphereMesh.new()
	scrub.radius=0.44
	scrub.height=0.85
	scrub.radial_segments=6
	scrub.rings=3
	_multi(layer,"InstancedDryScrub",scrub,mats["olive"],480,911327)
	var ruins_noise := FastNoiseLite.new()
	ruins_noise.seed=114722
	ruins_noise.noise_type=FastNoiseLite.TYPE_SIMPLEX
	ruins_noise.frequency=0.015
	ruins_noise.fractal_octaves=4
	for at in [Vector3(-78,0,-46),Vector3(78,0,-43),Vector3(-82,0,46)]:
		var post := Node3D.new()
		post.name="AbandonedSalvagePoint_"+str(layer.get_child_count())
		post.position=Vector3(at.x,WastelandDetail.terrain_height(at.x,at.z,ruins_noise),at.z)
		layer.add_child(post)
		box(post,"ShatteredPad",Vector3(0,0.22,0),Vector3(6.8,0.37,5.5),mats["concrete"])
		for side in [-1.0,1.0]:
			box(post,"RustSupport",Vector3(side*2.6,1.45,0),Vector3(0.22,2.7,0.22),mats["rust"])
			cylinder(post,"ScrapDrum",Vector3(side*1.3,0.62,-1.2),0.45,1.16,mats["blue"])
		box(post,"PatchworkShadedWorkArea",Vector3(0,2.88,0),Vector3(6.3,0.15,4.1),mats["canvas"])
	return layer

static func exterior(group: Node3D, kind: String, size: Vector2, h: float, condition: float, mats: Dictionary) -> void:
	var detail := Node3D.new()
	detail.name="FidelityExterior"
	group.add_child(detail)
	var half_x := size.x*0.5
	var half_z := size.y*0.5
	var trim: Material=mats["rust"] if kind in ["industry","storage","generator","power"] else mats["rooflight"]
	var accent: Material=mats["cross"] if kind=="medical" else (mats["blue"] if kind in ["water","water_pump","purifier","sewage","water_tank"] else mats["olive"])
	for side in [-1.0,1.0]:
		for i in range(5):
			var z: float=-half_z*0.70+float(i)*half_z*0.35
			box(detail,"CorrodedSidePanel",Vector3(side*(half_x+0.21),h*0.72,z),Vector3(0.085,0.76,size.y*0.12),trim if i%3==0 else mats["foundation"])
			box(detail,"PanelWeld",Vector3(side*(half_x+0.26),h*0.72,z),Vector3(0.035,0.62,0.055),mats["steel"])
		box(detail,"RainDownpipe",Vector3(side*(half_x-0.35),h*0.48,half_z+0.32),Vector3(0.17,h*0.88,0.19),mats["pipe"])
		box(detail,"SideElectricConduit",Vector3(side*(half_x+0.24),0.96,0),Vector3(0.14,0.16,size.y*0.72),mats["darkmetal"])
		box(detail,"EntryBollard",Vector3(side*1.57,0.90,-half_z-0.76),Vector3(0.20,1.80,0.20),mats["steel"])
		box(detail,"SuppliesPallet",Vector3(side*(half_x+1.05),0.14,half_z*0.19),Vector3(1.37,0.17,1.10),mats["canvas"])
		box(detail,"SupplyCrate",Vector3(side*(half_x+1.05),0.56,half_z*0.19),Vector3(0.97,0.69,0.80),accent if side<0.0 else trim)
	for i in range(5):
		var x: float=-half_x*0.70+float(i)*size.x*0.35
		box(detail,"RearWeatherPlate",Vector3(x,h*0.75,half_z+0.23),Vector3(size.x*0.22,0.64,0.08),trim if i%2==0 else mats["foundation"])
	if condition<70.0:
		box(detail,"DamagedRearPatch",Vector3(-half_x*0.37,1.45,half_z+0.31),Vector3(1.20,0.66,0.08),mats["rust"])
	var roof := Node3D.new()
	roof.name="FidelityRoofDetail"
	roof.set_meta("cutaway_roof",true)
	group.add_child(roof)
	if kind=="housing":
		for side in [-1.0,1.0]:
			box(roof,"PatchedGutter",Vector3(side*(half_x+0.38),h+0.25,0),Vector3(0.19,0.16,size.y*0.85),mats["rust"])
	else:
		for i in range(4):
			var z: float=-half_z*0.66+float(i)*half_z*0.44
			box(roof,"SheetMetalRoofRib",Vector3(0,h+0.53,z),Vector3(size.x*0.85,0.10,0.13),mats["steel"])
		box(roof,"RoofMaintenanceHatch",Vector3(half_x*0.41,h+0.56,half_z*0.32),Vector3(1.33,0.11,1.03),mats["darkmetal"])
		cylinder(roof,"VentChimney",Vector3(-half_x*0.57,h+1.02,-half_z*0.42),0.29,1.34,mats["rust"])

static func interior(room: Node3D, kind: String, size: Vector2, mats: Dictionary) -> void:
	var props := Node3D.new()
	props.name="FidelityInteriorDetails"
	room.add_child(props)
	var hx := size.x*0.5
	var hz := size.y*0.5
	for i in range(1,6):
		var x: float=-hx+float(i)*size.x/6.0
		box(props,"FloorTileJoint",Vector3(x,0.311,0),Vector3(0.025,0.014,size.y*0.85),mats["rooflight"])
	for i in range(1,5):
		var z: float=-hz+float(i)*size.y/5.0
		box(props,"CrossFloorJoint",Vector3(0,0.310,z),Vector3(size.x*0.84,0.014,0.025),mats["rooflight"])
	for side in [-1.0,1.0]:
		box(props,"PartialRoomPartition",Vector3(side*hx*0.37,1.02,hz*0.18),Vector3(hx*0.24,1.50,0.12),mats["foundation"])
		box(props,"WallUtilityTrunk",Vector3(side*(hx-0.29),1.59,0),Vector3(0.12,0.15,size.y*0.71),mats["pipe"])
		box(props,"WallTaskFixture",Vector3(side*(hx-0.30),2.22,hz*0.24),Vector3(0.29,0.16,0.39),mats["glow"])
	match kind:
		"housing":
			for side in [-1.0,1.0]:
				box(props,"HouseFootlocker",Vector3(side*hx*0.67,0.64,-hz*0.29),Vector3(1.1,0.84,0.70),mats["olive"])
				box(props,"DiningChair",Vector3(side*hx*0.27,0.50,hz*0.44),Vector3(0.75,0.17,0.64),mats["canvas"])
			box(props,"FoodShelf",Vector3(0,1.19,hz*0.77),Vector3(2.1,0.13,0.53),mats["rust"])
		"medical":
			for side in [-1.0,1.0]:
				cylinder(props,"MedicalOxygenCylinder",Vector3(side*hx*0.68,0.93,-hz*0.43),0.28,1.72,mats["blue"])
				box(props,"OxygenValve",Vector3(side*hx*0.68,1.82,-hz*0.43),Vector3(0.48,0.14,0.48),mats["steel"])
			box(props,"TriageCounter",Vector3(0,0.97,hz*0.62),Vector3(2.3,0.16,0.82),mats["clinic"])
		"command":
			for side in [-1.0,1.0]:
				box(props,"OperationsStatusScreen",Vector3(side*hx*0.42,1.60,hz*0.66),Vector3(1.45,0.82,0.12),mats["glass"])
			box(props,"CentralCommandTable",Vector3(0,1.05,hz*0.43),Vector3(2.58,0.15,1.15),mats["steel"])
		"industry","storage":
			for side in [-1.0,1.0]:
				box(props,"ProductionSafetyBoard",Vector3(side*hx*0.45,1.37,-hz*0.62),Vector3(1.35,1.17,0.14),mats["rust"])
				box(props,"LoadedPartsCrate",Vector3(side*hx*0.56,0.64,hz*0.51),Vector3(1.28,0.94,0.88),mats["steel"])
		_:
			for side in [-1.0,1.0]:
				box(props,"SwitchGearCabinet",Vector3(side*hx*0.53,1.07,hz*0.50),Vector3(1.23,1.48,0.54),mats["darkmetal"])
				box(props,"MaintenanceScreen",Vector3(side*hx*0.53,1.54,hz*0.20),Vector3(0.83,0.49,0.10),mats["glass"])
	for side in [-1.0,1.0]:
		var lamp := OmniLight3D.new()
		lamp.name="WorkTaskLamp"
		lamp.position=Vector3(side*hx*0.52,2.42,0)
		lamp.light_color=Color("#f5d6a9")
		lamp.light_energy=0.34
		lamp.omni_range=5.3
		lamp.shadow_enabled=false
		props.add_child(lamp)
