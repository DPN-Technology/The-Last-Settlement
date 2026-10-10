class_name SettlementInteriors3D
extends RefCounted

# Procedural, furnished 3D rooms. These are *actual world-space meshes*.
# Sim occupant positions are driven by SettlementNavigation, not decorations.
# Props do not yet act as physics barriers; issue #8 includes furniture/navmesh.
static func box(parent: Node3D, name: String, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name=name
	var mesh := BoxMesh.new()
	mesh.size=size
	item.mesh=mesh
	item.position=pos
	item.material_override=material
	parent.add_child(item)
	return item

static func cylinder(parent: Node3D, name: String, pos: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name=name
	var mesh := CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.height=height
	item.mesh=mesh
	item.position=pos
	item.material_override=material
	parent.add_child(item)
	return item

static func _bed(room: Node3D, pos: Vector3, mats: Dictionary) -> void:
	box(room,"BedFrame",pos+Vector3(0,0.40,0),Vector3(1.55,0.30,2.05),mats["darkmetal"])
	box(room,"Mattress",pos+Vector3(0,0.58,0),Vector3(1.43,0.16,1.91),mats["canvas"])
	box(room,"Blanket",pos+Vector3(0,0.69,0.35),Vector3(1.38,0.08,1.10),mats["olive"])
	box(room,"Pillow",pos+Vector3(0,0.72,-0.70),Vector3(1.02,0.15,0.39),mats["clinic"])
	for side in [-1.0,1.0]:
		box(room,"BedLeg",pos+Vector3(side*0.65,0.21,-0.78),Vector3(0.09,0.4,0.10),mats["steel"])

static func _workbench(room: Node3D, pos: Vector3, mats: Dictionary) -> void:
	box(room,"WorkBench",pos+Vector3(0,0.99,0),Vector3(2.55,0.18,1.15),mats["steel"])
	for side in [-1.0,1.0]:
		box(room,"BenchSupport",pos+Vector3(side*1.0,0.51,0),Vector3(0.13,0.95,0.90),mats["darkmetal"])
	box(room,"ToolTray",pos+Vector3(0.45,1.13,0.05),Vector3(0.83,0.11,0.61),mats["rust"])
	box(room,"Workpiece",pos+Vector3(-0.53,1.17,0),Vector3(0.43,0.20,0.33),mats["rooflight"])

static func _cabinet(room: Node3D, pos: Vector3, mats: Dictionary) -> void:
	box(room,"StorageCabinet",pos+Vector3(0,1.05,0),Vector3(1.05,1.95,0.66),mats["steel"])
	box(room,"CabinetFace",pos+Vector3(0,1.10,-0.36),Vector3(0.82,1.72,0.04),mats["darkmetal"])
	box(room,"CabinetHandle",pos+Vector3(0.30,1.1,-0.39),Vector3(0.07,0.30,0.07),mats["rooflight"])

# A second pass adds facility-specific staging. Props occupy peripheral zones
# and are visual only until furniture-aware navigation ships in issue #8.
static func _crate_shelf(room: Node3D, at: Vector3, mats: Dictionary) -> void:
	for side in [-1.0,1.0]:
		box(room,"ShelfPost",at+Vector3(side*0.76,1.09,0),Vector3(0.10,2.16,0.65),mats["steel"])
	for tier in range(3):
		var y := 0.37+float(tier)*0.65
		box(room,"ShelfDeck",at+Vector3(0,y,0),Vector3(1.72,0.10,0.76),mats["darkmetal"])
		box(room,"StoredSupplies",at+Vector3(0,y+0.23,0),Vector3(1.34,0.39,0.52),mats["canvas"])

static func _stage_rooms(room: Node3D, kind: String, size: Vector2, mats: Dictionary) -> void:
	var x := size.x*0.5
	var z := size.y*0.5
	var color: Material=mats["clinic"] if kind=="medical" else (mats["rust"] if kind in ["industry","storage"] else (mats["blue"] if kind in ["water","purifier","water_pump","water_tank","sewage"] else mats["olive"]))
	for side in [-1.0,1.0]:
		box(room,"FloorZone",Vector3(side*x*0.48,0.298,0),Vector3(maxf(0.60,x*0.44),0.015,size.y*0.70),mats["foundation"])
		box(room,"RoomZoneStripe",Vector3(side*x*0.24,0.311,0),Vector3(0.10,0.020,size.y*0.66),color)
	for depth in [-0.29,0.31]:
		box(room,"CeilingLightRail",Vector3(0,2.75,depth*size.y),Vector3(minf(4.2,x),0.12,0.21),mats["rooflight"])
		box(room,"LightDiffuser",Vector3(0,2.68,depth*size.y),Vector3(minf(3.9,x),0.04,0.14),mats["glow"])
	match kind:
		"housing":
			for side in [-1.0,1.0]:
				_crate_shelf(room,Vector3(side*x*0.68,0,z*0.72),mats)
				box(room,"FootLocker",Vector3(side*x*0.66,0.43,-z*0.40),Vector3(1.10,0.73,0.70),mats["olive"])
			box(room,"DiningBench",Vector3(0,0.61,z*0.36),Vector3(2.2,0.16,0.75),mats["rust"])
		"medical":
			for side in [-1.0,1.0]:
				var cx := side*x*0.34
				cylinder(room,"IVStand",Vector3(cx,1.15,z*0.23),0.042,2.16,mats["steel"])
				box(room,"IVSupport",Vector3(cx,2.15,z*0.23),Vector3(0.50,0.08,0.09),mats["steel"])
				box(room,"FluidBag",Vector3(cx+0.18,1.83,z*0.23),Vector3(0.22,0.42,0.18),mats["clinic"])
				_crate_shelf(room,Vector3(side*x*0.68,0,z*0.73),mats)
		"industry","storage":
			for side in [-1.0,1.0]:
				_crate_shelf(room,Vector3(side*x*0.66,0,z*0.72),mats)
				box(room,"SupplyPallet",Vector3(side*x*0.61,0.28,-z*0.43),Vector3(1.88,0.17,1.25),mats["canvas"])
				box(room,"PalletLoad",Vector3(side*x*0.61,0.71,-z*0.43),Vector3(1.43,0.68,0.98),mats["steel"])
		"command":
			for side in [-1.0,1.0]:
				box(room,"MissionBoard",Vector3(side*x*0.69,1.60,z*0.69),Vector3(1.90,1.22,0.14),mats["darkmetal"])
				box(room,"MissionMap",Vector3(side*x*0.69,1.60,z*0.58),Vector3(1.65,0.95,0.045),mats["glass"])
			_crate_shelf(room,Vector3(x*0.22,0,z*0.75),mats)
		_:
			for side in [-1.0,1.0]:
				_crate_shelf(room,Vector3(side*x*0.68,0,z*0.73),mats)
				box(room,"MachineServicePanel",Vector3(side*x*0.59,1.05,-z*0.34),Vector3(1.24,1.33,0.40),mats["steel"])
				box(room,"StatusDisplay",Vector3(side*x*0.59,1.41,-z*0.56),Vector3(0.86,0.40,0.05),mats["glass"])

static func populate(group: Node3D, kind: String, size: Vector2, mats: Dictionary) -> Node3D:
	var room := Node3D.new()
	room.name="InteriorFurnishings"
	group.add_child(room)
	var hx := size.x*0.5
	var hz := size.y*0.5
	box(room,"InteriorFloor",Vector3(0,0.24,0),Vector3(size.x-0.53,0.09,size.y-0.53),mats["concrete"])
	box(room,"CentralAccessAisle",Vector3(0,0.298,-0.18),Vector3(1.52,0.014,size.y*0.77),mats["foundation"])
	for side in [-1.0,1.0]:
		box(room,"WallUtilityStrip",Vector3(side*(hx-0.26),0.42,0),Vector3(0.08,0.24,size.y*0.84),mats["rust"])
	match kind:
		"housing":
			for side in [-1.0,1.0]:
				for depth in [-0.24,0.25]:
					_bed(room,Vector3(side*hx*0.60,0,depth*size.y),mats)
				_cabinet(room,Vector3(side*hx*0.66,0,size.y*0.40),mats)
			box(room,"SharedDiningTable",Vector3(0,0.96,size.y*0.28),Vector3(2.2,0.14,1.13),mats["rust"])
		"medical":
			for side in [-1.0,1.0]:
				_bed(room,Vector3(side*hx*0.56,0,0),mats)
				_cabinet(room,Vector3(side*hx*0.68,0,size.y*0.38),mats)
				box(room,"BedsideMonitor",Vector3(side*hx*0.55,1.44,-size.y*0.30),Vector3(0.62,0.74,0.25),mats["darkmetal"])
				box(room,"MedicalMonitorGlass",Vector3(side*hx*0.55,1.44,-size.y*0.44),Vector3(0.47,0.51,0.04),mats["glass"])
			_workbench(room,Vector3(0,0,size.y*0.24),mats)
		"command":
			_workbench(room,Vector3(0,0,size.y*0.18),mats)
			box(room,"CommandTableMap",Vector3(0,1.15,size.y*0.18),Vector3(1.65,0.025,0.74),mats["glass"])
			for side in [-1.0,1.0]:
				_cabinet(room,Vector3(side*hx*0.63,0,size.y*0.31),mats)
				box(room,"RadioConsole",Vector3(side*hx*0.64,1.08,-size.y*0.17),Vector3(1.6,0.70,0.82),mats["darkmetal"])
				box(room,"RadioDisplay",Vector3(side*hx*0.64,1.47,-size.y*0.34),Vector3(1.20,0.42,0.06),mats["glass"])
		"industry","storage":
			for side in [-1.0,1.0]:
				for depth in [-0.18,0.28]:
					_workbench(room,Vector3(side*hx*0.63,0,depth*size.y),mats)
			box(room,"FabricationMachine",Vector3(0,0.95,size.y*0.38),Vector3(2.0,1.30,1.45),mats["darkmetal"])
			box(room,"SafetyStripe",Vector3(0,0.30,size.y*0.33),Vector3(2.6,0.014,0.12),mats["warning"])
		"generator","power","battery":
			for side in [-1.0,1.0]:
				box(room,"GeneratorEngine",Vector3(side*hx*0.53,1.05,size.y*0.12),Vector3(2.2,1.64,2.3),mats["darkmetal"])
				cylinder(room,"DriveHub",Vector3(side*hx*0.53,1.2,-size.y*0.14),0.65,0.56,mats["steel"])
			_workbench(room,Vector3(0,0,size.y*0.30),mats)
		"water","water_pump","purifier","water_tank","sewage":
			for side in [-1.0,1.0]:
				cylinder(room,"FilterVessel",Vector3(side*hx*0.58,1.30,size.y*0.13),0.85,2.08,mats["blue"])
				box(room,"ValveAssembly",Vector3(side*hx*0.55,1.22,-size.y*0.22),Vector3(1.05,0.36,1.06),mats["steel"])
			_workbench(room,Vector3(0,0,size.y*0.30),mats)
		_:
			for side in [-1.0,1.0]:
				_cabinet(room,Vector3(side*hx*0.65,0,size.y*0.19),mats)
			_workbench(room,Vector3(0,0,size.y*0.30),mats)
	_stage_rooms(room,kind,size,mats)
	# Restrict internal light to revealed interiors; no glowing exterior boxes.
	var light := OmniLight3D.new()
	light.name="InteriorWorkLight"
	light.position=Vector3(0,2.72,0)
	light.light_color=Color("#f6cda3")
	light.light_energy=0.82
	light.omni_range=13.0
	light.shadow_enabled=false
	room.add_child(light)
	room.visible=false
	return room
