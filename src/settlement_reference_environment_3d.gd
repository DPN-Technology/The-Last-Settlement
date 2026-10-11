class_name SettlementReferenceEnvironment3D
extends RefCounted

# THE LAST SETTLEMENT // LAST HAVEN REALISM PASS
# Design reference: weathered, lived-in wasteland compound with lit paths,
# scrappy repairs, varied ground plants and physical yard detail.
# These are draw-only meshes with no physics/nav/save-data side effects.

static func _box(parent: Node3D, name: String, p: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size=size
	var node := MeshInstance3D.new()
	node.name=name+"_"+str(parent.get_child_count())
	node.mesh=mesh
	node.position=p
	node.material_override=material
	parent.add_child(node)
	return node

static func _cylinder(parent: Node3D, name: String, p: Vector3, radius: float, h: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.height=h
	mesh.radial_segments=12
	var node := MeshInstance3D.new()
	node.name=name+"_"+str(parent.get_child_count())
	node.mesh=mesh
	node.position=p
	node.material_override=material
	parent.add_child(node)
	return node

static func _terrain_height(x: float,z: float) -> float:
	var noise := FastNoiseLite.new()
	noise.seed=114722
	noise.noise_type=FastNoiseLite.TYPE_SIMPLEX
	noise.frequency=0.015
	noise.fractal_octaves=4
	return WastelandDetail.terrain_height(x,z,noise)

static func _scatter(parent: Node3D, name: String, mesh: Mesh, material: Material, count: int, seed: int, band: int) -> void:
	var layer := MultiMeshInstance3D.new()
	layer.name=name
	var instances := MultiMesh.new()
	instances.transform_format=MultiMesh.TRANSFORM_3D
	instances.mesh=mesh
	instances.instance_count=count
	layer.multimesh=instances
	layer.material_override=material
	parent.add_child(layer)
	var rng := RandomNumberGenerator.new()
	rng.seed=seed
	for i in range(count):
		var x: float=rng.randf_range(-96.0,96.0)
		var z: float=rng.randf_range(-83.0,83.0)
		if absf(x)<39.0 and absf(z)<34.0:
			if band==0:
				x=signf(x)*rng.randf_range(41.0,91.0)
			else:
				z=signf(z)*rng.randf_range(36.0,80.0)
		var sx: float=rng.randf_range(0.35,1.70)
		var sz: float=rng.randf_range(0.36,1.55)
		var sy: float=rng.randf_range(0.48,1.22)
		var y: float=_terrain_height(x,z)
		var basis := Basis(Vector3.UP,rng.randf_range(0.0,TAU)).scaled(Vector3(sx,sy,sz))
		instances.set_instance_transform(i,Transform3D(basis,Vector3(x,y+0.12,z)))

static func _timber_walkway(parent: Node3D, from: Vector3, to: Vector3, material: Material, seed: int) -> void:
	# Each crossing is individual slatted reclaimed timber, not a solid block.
	# MultiMesh keeps ~300 plank slats inexpensive on GL Compatibility.
	var length: float=Vector2(to.x-from.x,to.z-from.z).length()
	var steps: int=maxi(1,int(ceil(length/0.57)))
	var mesh := BoxMesh.new()
	mesh.size=Vector3(2.02,0.075,0.43)
	var planks := MultiMesh.new()
	planks.transform_format=MultiMesh.TRANSFORM_3D
	planks.mesh=mesh
	planks.instance_count=steps
	var node := MultiMeshInstance3D.new()
	node.name="ReclaimedTimberBoardwalk_"+str(parent.get_child_count())
	node.multimesh=planks
	node.material_override=material
	parent.add_child(node)
	var rng := RandomNumberGenerator.new()
	rng.seed=seed
	var dir := Vector3(to.x-from.x,0,to.z-from.z).normalized()
	var yaw: float=atan2(dir.x,dir.z)
	for i in range(steps):
		var alpha: float=(float(i)+0.5)/float(steps)
		var p := from.lerp(to,alpha)
		p.y=0.145+rng.randf_range(-0.009,0.015)
		var transform := Transform3D(Basis(Vector3.UP,yaw+rng.randf_range(-0.02,0.02)),p)
		transform.basis=transform.basis.scaled(Vector3(rng.randf_range(0.89,1.02),1.0,rng.randf_range(0.91,1.02)))
		planks.set_instance_transform(i,transform)

static func _camp_light(parent: Node3D, p: Vector3, mat: Dictionary) -> void:
	var post := Node3D.new()
	post.name="WarmCampLighting_"+str(parent.get_child_count())
	post.position=p
	parent.add_child(post)
	_box(post,"Stanchion",Vector3(0,2.05,0),Vector3(0.14,4.10,0.13),mat["rust"])
	_box(post,"BentLightArm",Vector3(0.46,4.03,0),Vector3(0.93,0.11,0.12),mat["steel"])
	_box(post,"LampWeatherCap",Vector3(0.87,3.86,0),Vector3(0.65,0.21,0.47),mat["darkmetal"])
	_box(post,"WarmLanternGlass",Vector3(0.87,3.69,0),Vector3(0.46,0.11,0.32),mat["glow"])
	var light := OmniLight3D.new()
	light.name="ReferenceWorkLight"
	light.position=Vector3(0.87,3.60,0)
	light.light_color=Color("#ffc485")
	light.light_energy=0.58
	light.omni_range=9.0
	light.shadow_enabled=false
	post.add_child(light)

static func _natural_scrub(parent: Node3D, mats: Dictionary) -> void:
	# Clustered branches/shrubs in exterior scenic bands, with actual scale
	# variation. Keep all central building footprints, construction and roads clear.
	var shrub := SphereMesh.new()
	shrub.radius=0.44
	shrub.height=0.70
	shrub.radial_segments=7
	shrub.rings=4
	_scatter(parent,"ClumpedSageAndDryBrush",shrub,mats["olive"],950,602811,0)
	var gravel := PrismMesh.new()
	gravel.size=Vector3(0.78,0.41,0.74)
	_scatter(parent,"BrokenSlateRockFaces",gravel,mats["stone"],540,282371,1)
	var metal := BoxMesh.new()
	metal.size=Vector3(0.37,0.045,0.75)
	_scatter(parent,"SmallRustedSheetFragments",metal,mats["rust"],255,732101,1)

static func _salvage_camp(parent: Node3D, pos: Vector3, mats: Dictionary) -> void:
	var site := Node3D.new()
	site.name="SalvageCampCluster_"+str(parent.get_child_count())
	site.position=Vector3(pos.x,_terrain_height(pos.x,pos.z),pos.z)
	parent.add_child(site)
	for side in [-1.0,1.0]:
		_box(site,"ReclaimedSupport",Vector3(side*2.55,1.58,-1.75),Vector3(0.17,3.16,0.17),mats["rust"])
		_box(site,"TentRoofPost",Vector3(side*2.55,1.34,1.72),Vector3(0.17,2.68,0.17),mats["steel"])
		var wing := _box(site,"PatchworkCanvasAwning",Vector3(side*1.30,2.87,0),Vector3(2.82,0.11,4.5),mats["canvas"])
		wing.rotation.z=-side*0.15
		_cylinder(site,"DrumOfSupplies",Vector3(side*2.03,0.62,0.72),0.36,1.22,mats["blue"])
	for index in range(4):
		_box(site,"StackedRecoveryCrate",Vector3(-1.35+float(index)*0.92,0.46,1.12),Vector3(0.78,0.78,0.77),mats["rust"] if index%2==0 else mats["steel"])
	_box(site,"ServiceBench",Vector3(0,0.93,-1.2),Vector3(2.30,0.15,0.84),mats["roof"])
	_camp_light(site,Vector3(1.95,0,-1.4),mats)

static func build_world(parent: Node3D, mats: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name="ReferenceQualityWorldDressing"
	parent.add_child(root)
	_natural_scrub(root,mats)
	# Planked sections through the main camp, matching the reference's
	# broken timber paths and retaining all existing walkable corridors.
	_timber_walkway(root,Vector3(-24,0,8),Vector3(-12,0,8),mats["canvas"],1231)
	_timber_walkway(root,Vector3(-8,0,14),Vector3(10,0,14),mats["roof"],1232)
	_timber_walkway(root,Vector3(8,0,-9),Vector3(22,0,-9),mats["canvas"],1233)
	_timber_walkway(root,Vector3(-4,0,19),Vector3(-4,0,27),mats["roof"],1234)
	_timber_walkway(root,Vector3(28,0,13),Vector3(39,0,13),mats["canvas"],1235)
	for light_pos in [
		Vector3(-30.0,0,-14.0),Vector3(-20.0,0,12.0),
		Vector3(-2.0,0,22.0),Vector3(16.0,0,-17.0),
		Vector3(26.0,0,16.0),Vector3(48.0,0,-15.0),
		Vector3(56.0,0,18.0)
	]:
		_camp_light(root,light_pos,mats)
	_salvage_camp(root,Vector3(-50,0,-25),mats)
	_salvage_camp(root,Vector3(66,0,-34),mats)
	return root

static func _service_prop(parent: Node3D, mats: Dictionary, size: Vector2, kind: String) -> void:
	var hx: float=size.x*0.5
	var hz: float=size.y*0.5
	for side in [-1.0,1.0]:
		# Physical, imperfect salvage storage right beside the rear facade.
		var x: float=side*(hx+1.20)
		_box(parent,"DeliveryPallet",Vector3(x,0.18,hz*0.46),Vector3(1.53,0.22,1.00),mats["canvas"])
		for i in range(2):
			_box(parent,"SideCargo",Vector3(x,0.58+float(i)*0.48,hz*0.46),Vector3(1.09,0.43,0.65),mats["rust"] if i%2==0 else mats["rooflight"])
		_cylinder(parent,"SalvageWaterBarrel",Vector3(x,0.56,-hz*0.22),0.34,1.09,mats["blue"])
	if kind in ["command","industry","generator","power","storage"]:
		var conduit := _box(parent,"OverheadConduitRack",Vector3(0,2.80,hz+0.20),Vector3(size.x*0.59,0.22,0.20),mats["steel"])
		conduit.rotation.z=0.01

static func detail_facility(group: Node3D, kind: String, size: Vector2, mats: Dictionary) -> void:
	# New visual props remain distinct from the core gameplay shell so roofs,
	# doors, selection and simulation remain unchanged.
	if kind in ["wall","floor","door","pipe","power_pole","farm"]:
		return
	var scene := Node3D.new()
	scene.name="ReferenceExteriorDetail"
	group.add_child(scene)
	_service_prop(scene,mats,size,kind)
	var hz: float=size.y*0.5
	# Thin entrance stoop; clearly indicates the entry without hiding the door.
	_box(scene,"EntryStoop",Vector3(0,0.14,-hz-0.99),Vector3(2.85,0.22,1.15),mats["concrete"])
	for side in [-1.0,1.0]:
		_box(scene,"SafetyRailing",Vector3(side*1.48,0.63,-hz-1.05),Vector3(0.11,0.92,1.18),mats["steel"])
		_box(scene,"ReclaimedDoorLamp",Vector3(side*1.10,2.52,-hz-0.19),Vector3(0.27,0.14,0.22),mats["glow"])
	for index in range(3):
		# Flush horizontal corrosion bands, not huge floating wall panels.
		var x: float=(float(index)-1.0)*size.x*0.29
		_box(scene,"WeatheredLintel",Vector3(x,3.04,hz+0.18),Vector3(size.x*0.22,0.15,0.07),mats["rust"])
	if kind=="medical":
		_box(scene,"TriageCanopy",Vector3(0,2.96,-hz-1.16),Vector3(size.x*0.55,0.12,1.65),mats["clinic"])
	elif kind in ["industry","generator","power"]:
		for i in range(3):
			_cylinder(scene,"MachineFuelDrum",Vector3(-1.0+float(i)*0.92,0.59,hz+1.10),0.29,1.10,mats["blue"] if i%2==0 else mats["rust"])
