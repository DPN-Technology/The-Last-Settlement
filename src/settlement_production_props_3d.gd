class_name SettlementProductionProps3D
extends RefCounted

# Reference fidelity: physical geometry, not flat billboards or UI pictures.
# No collision and no gameplay state. GL Compatibility-safe primitives.

static func _box(parent: Node3D, title: String, p: Vector3, dimensions: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size=dimensions
	var part := MeshInstance3D.new()
	part.name=title+"_"+str(parent.get_child_count())
	part.mesh=mesh
	part.material_override=mat
	part.position=p
	parent.add_child(part)
	return part

static func _cylinder(parent: Node3D, title: String, p: Vector3, radius: float, h: float, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.height=h
	mesh.radial_segments=16
	var part := MeshInstance3D.new()
	part.name=title+"_"+str(parent.get_child_count())
	part.mesh=mesh
	part.material_override=mat
	part.position=p
	parent.add_child(part)
	return part

static func _tube(parent: Node3D, title: String, start: Vector3, end: Vector3, radius: float, mat: Material) -> void:
	var path: Vector3=end-start
	if path.length()<0.01:
		return
	var tube := _cylinder(parent,title,(start+end)*0.5,radius,path.length(),mat)
	tube.quaternion=Quaternion(Vector3.UP,path.normalized())

static func _barrel(parent: Node3D, p: Vector3, mats: Dictionary, blue: bool) -> void:
	var shell: Material=mats["blue"] if blue else mats["rust"]
	_cylinder(parent,"DrumBody",p+Vector3(0,0.61,0),0.39,1.12,shell)
	for offset in [-0.39,0.0,0.39]:
		_cylinder(parent,"DrumRolledRim",p+Vector3(0,0.61+offset,0),0.42,0.065,mats["steel"])
	_cylinder(parent,"SteelDrumLid",p+Vector3(0,1.19,0),0.38,0.05,mats["darkmetal"])
	_cylinder(parent,"DrumLidBung",p+Vector3(0.19,1.23,0.11),0.085,0.046,mats["rooflight"])

static func _crate(parent: Node3D, p: Vector3, mats: Dictionary) -> void:
	_box(parent,"CrateRoughWoodCore",p+Vector3(0,0.43,0),Vector3(0.88,0.85,0.89),mats["wood"])
	for side in [-1.0,1.0]:
		for y in [0.19,0.64]:
			_box(parent,"CrateStrapHorizontal",p+Vector3(0,y,side*0.46),Vector3(0.96,0.085,0.08),mats["rust"])
		for x in [-0.38,0.38]:
			_box(parent,"CrateEdgeReinforcement",p+Vector3(x,0.43,side*0.46),Vector3(0.08,0.88,0.08),mats["steel"])
	for x in [-0.38,0.38]:
		_box(parent,"CrateCrossGrain",p+Vector3(x,0.86,0),Vector3(0.10,0.08,0.85),mats["roof"])
	_box(parent,"CrateLid",p+Vector3(0,0.90,0),Vector3(0.98,0.10,0.97),mats["wood"])

static func _sandbag(parent: Node3D, p: Vector3, mats: Dictionary) -> void:
	var bag_mesh := CapsuleMesh.new()
	bag_mesh.radius=0.29
	bag_mesh.height=0.94
	bag_mesh.radial_segments=8
	bag_mesh.rings=3
	var piece := MeshInstance3D.new()
	piece.name="DrapedSandbag_"+str(parent.get_child_count())
	piece.mesh=bag_mesh
	piece.material_override=mats["cloth"]
	piece.rotation.z=PI*0.5
	piece.scale=Vector3(1.0,1.1,0.65)
	piece.position=p
	parent.add_child(piece)

static func _crate_group(parent: Node3D, origin: Vector3, mats: Dictionary) -> void:
	for i in range(3):
		_crate(parent,origin+Vector3(float(i-1)*1.0,0,0),mats)
	_barrel(parent,origin+Vector3(-1.43,0,-0.78),mats,true)
	_barrel(parent,origin+Vector3(1.43,0,-0.78),mats,false)

static func _wall_station(parent: Node3D, at: Vector3, mats: Dictionary) -> void:
	_box(parent,"WallMountedEnclosure",at+Vector3(0,1.26,0),Vector3(1.08,1.18,0.35),mats["darkmetal"])
	_box(parent,"InspectionPort",at+Vector3(0,1.49,-0.20),Vector3(0.82,0.40,0.035),mats["glass"])
	for x in [-0.32,-0.12,0.13,0.34]:
		_box(parent,"StatusBeacon",at+Vector3(x,1.10,-0.24),Vector3(0.09,0.07,0.035),mats["glow"] if x<0.0 else mats["olive"])

static func _barricade(parent: Node3D, origin: Vector3, mats: Dictionary) -> void:
	for row in range(2):
		for i in range(4-row):
			_sandbag(parent,origin+Vector3(-1.42+float(i)*0.93+float(row)*0.46,0.28+float(row)*0.38,0),mats)

static func _medical(parent: Node3D, size: Vector2, mats: Dictionary) -> void:
	var hz: float=size.y*0.5
	var hx: float=size.x*0.5
	# Small exterior triage station as seen in the reference.
	_box(parent,"FieldTreatmentTrolley",Vector3(-hx*0.44,0.89,-hz-1.36),Vector3(1.64,0.12,0.67),mats["clinic"])
	for x in [-hx*0.44-0.59,-hx*0.44+0.59]:
		_box(parent,"TrolleyLeg",Vector3(x,0.43,-hz-1.36),Vector3(0.08,0.85,0.09),mats["steel"])
	for j in range(2):
		_cylinder(parent,"ClinicOxygenCylinder",Vector3(hx*0.40+float(j)*0.44,0.91,-hz-1.15),0.20,1.73,mats["blue"])
		_cylinder(parent,"ClinicOxygenRegulator",Vector3(hx*0.40+float(j)*0.44,1.78,-hz-1.15),0.24,0.13,mats["rooflight"])

static func _generator(parent: Node3D, size: Vector2, mats: Dictionary) -> void:
	var hz: float=size.y*0.5
	# A recognizable diesel generator enclosure and routed exhaust stack.
	var p := Vector3(0.0,0.0,hz+1.55)
	_box(parent,"DieselGeneratorChassis",p+Vector3(0,0.39,0),Vector3(3.30,0.34,1.45),mats["darkmetal"])
	_box(parent,"DieselEngineHousing",p+Vector3(0,1.18,0),Vector3(2.40,1.37,1.22),mats["rust"])
	for i in range(7):
		_box(parent,"RadiatorGrilleFin",p+Vector3(-0.95+float(i)*0.32,1.23,-0.64),Vector3(0.10,0.94,0.06),mats["steel"])
	_tube(parent,"ExhaustStack",p+Vector3(0.77,1.72,0),p+Vector3(0.77,3.48,0),0.15,mats["steel"])
	_cylinder(parent,"ExhaustCowl",p+Vector3(0.77,3.45,0),0.32,0.12,mats["rust"])

static func _water(parent: Node3D, size: Vector2, mats: Dictionary) -> void:
	var hz: float=size.y*0.5
	# Pipes and valve fittings extend from the true utility building.
	var z: float=hz+1.14
	for x in [-1.50,1.50]:
		_tube(parent,"PressurizedSupplyPipe",Vector3(x,0.52,z),Vector3(x,1.64,z),0.19,mats["pipe"])
		_cylinder(parent,"OutdoorValveHead",Vector3(x,1.63,z),0.40,0.12,mats["steel"])
		_box(parent,"PressureSensor",Vector3(x,1.90,z),Vector3(0.22,0.18,0.12),mats["darkmetal"])
	_tube(parent,"HorizontalDistributionPipe",Vector3(-1.50,0.61,z),Vector3(1.50,0.61,z),0.13,mats["pipe"])

static func _workshop(parent: Node3D, size: Vector2, mats: Dictionary) -> void:
	var hz: float=size.y*0.5
	_box(parent,"SalvageWorkbench",Vector3(0,0.94,hz+1.57),Vector3(2.52,0.12,1.0),mats["wood"])
	for x in [-1.0,1.0]:
		_box(parent,"WorkbenchFrame",Vector3(x,0.47,hz+1.57),Vector3(0.13,0.92,0.87),mats["steel"])
	for i in range(5):
		_box(parent,"ScavengedTool",Vector3(-0.92+float(i)*0.47,1.055,hz+1.57),Vector3(0.14,0.07,0.37),mats["steel"])
	_crate_group(parent,Vector3(-size.x*0.42-1.0,0,hz+1.30),mats)

static func _shelter(parent: Node3D, size: Vector2, mats: Dictionary) -> void:
	var hz: float=size.y*0.5
	_barricade(parent,Vector3(-size.x*0.24,0,hz+0.85),mats)
	_crate(parent,Vector3(size.x*0.24,0,hz+0.84),mats)
	_box(parent,"ShelterWindowShade",Vector3(0,2.32,hz+0.26),Vector3(size.x*0.46,0.16,0.53),mats["rust"])

static func decorate_facility(group: Node3D, kind: String, size: Vector2, mats: Dictionary) -> void:
	if kind in ["wall","floor","door","pipe","power_pole","farm"]:
		return
	var root := Node3D.new()
	root.name="DetailedPhysicalEquipment"
	group.add_child(root)
	match kind:
		"medical":
			_medical(root,size,mats)
		"command":
			_wall_station(root,Vector3(0,0,size.y*0.5+0.30),mats)
			_crate_group(root,Vector3(size.x*0.48+1.7,0,size.y*0.27),mats)
		"industry","storage":
			_workshop(root,size,mats)
		"generator","power","battery":
			_generator(root,size,mats)
		"water","water_pump","purifier","water_tank","sewage":
			_water(root,size,mats)
		"housing":
			_shelter(root,size,mats)
		_:
			_crate(root,Vector3(size.x*0.5+1.35,0,0),mats)
