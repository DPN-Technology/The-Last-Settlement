class_name SettlementIndustry3D
extends RefCounted

# Physical, low-cost transitional factory art. It lives beside (not across)
# the workshop's central exterior doorway and can be replaced by licensed
# production models later. No shader-dependent or fictional resource effects.

static func _box(parent: Node3D, name: String, center: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	part.mesh = mesh
	part.position = center
	part.material_override = material
	parent.add_child(part)
	return part

static func _cylinder(parent: Node3D, name: String, center: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	part.mesh = mesh
	part.position = center
	part.material_override = material
	parent.add_child(part)
	return part

static func build(parent: Node3D, footprint: Vector2, mats: Dictionary) -> Dictionary:
	var yard := Node3D.new()
	yard.name = "WorkingIndustrialYard"
	# The 1.8m-wide central entry and exterior nav target must remain clear.
	# Position the press to the RIGHT side and ahead of the workshop facade.
	yard.position = Vector3(maxf(3.4,footprint.x*0.33),0.0,-footprint.y*0.5-3.4)
	parent.add_child(yard)
	_box(yard,"WeatheredAssemblyPad",Vector3(0,0.08,0),Vector3(6.5,0.16,5.2),mats["foundation"])
	for side in [-1.0,1.0]:
		_box(yard,"StampedSafetyStripe",Vector3(side*2.82,0.174,0),Vector3(0.12,0.012,4.65),mats["warning"])
		_box(yard,"PressUpright",Vector3(side*1.14,1.79,-0.35),Vector3(0.34,3.55,0.58),mats["steel"])
		_box(yard,"PressFoot",Vector3(side*1.14,0.38,-0.35),Vector3(0.83,0.54,0.98),mats["rust"])
	_box(yard,"StampedPressHeadstock",Vector3(0,3.6,-0.35),Vector3(2.72,0.8,1.8),mats["darkmetal"])
	_cylinder(yard,"HydraulicSleeve",Vector3(0,2.93,-0.35),0.31,0.84,mats["rust"])
	_box(yard,"LowerPressDie",Vector3(0,0.79,-0.35),Vector3(1.7,0.25,1.2),mats["steel"])
	var ram := Node3D.new()
	ram.name = "StampingRam"
	ram.position = Vector3(0,2.04,-0.35)
	yard.add_child(ram)
	_cylinder(ram,"MovingHydraulicShaft",Vector3(0,0.45,0),0.16,1.1,mats["steel"])
	_box(ram,"MovingUpperDie",Vector3(0,-0.12,0),Vector3(1.5,0.32,1.12),mats["rust"])
	# Functional-looking intake conveyor: rollers, bed, side guard and
	# moving workpiece. Only the workpiece/ram animate during real production.
	_box(yard,"FeedConveyorBed",Vector3(-1.3,0.73,1.35),Vector3(3.3,0.24,1.0),mats["darkmetal"])
	for i in range(6):
		var offset := -2.65+float(i)*0.52
		var roller := _cylinder(yard,"ConveyorRoller",Vector3(offset,0.88,1.35),0.12,0.84,mats["steel"])
		roller.rotation.x = PI*0.5
	for side in [-1.0,1.0]:
		_box(yard,"ConveyorSafetyRail",Vector3(-1.35,1.03,1.35+side*0.56),Vector3(3.4,0.10,0.10),mats["rust"])
	var carrier := Node3D.new()
	carrier.name = "MovingBlankCarrier"
	carrier.position = Vector3(-2.1,1.02,1.35)
	yard.add_child(carrier)
	_box(carrier,"PressedMetalBlank",Vector3.ZERO,Vector3(0.48,0.13,0.45),mats["steel"])
	# Outdoor electric cabinet, grounded service piping, salvage storage.
	_box(yard,"SafetyElectricalCabinet",Vector3(2.13,1.10,1.18),Vector3(0.65,1.97,0.80),mats["rooflight"])
	_box(yard,"CabinetServiceDoor",Vector3(2.12,1.20,0.74),Vector3(0.53,1.56,0.05),mats["darkmetal"])
	_box(yard,"PowerConduit",Vector3(2.72,0.67,-0.28),Vector3(0.19,0.18,2.90),mats["pipe"])
	for i in range(3):
		_box(yard,"SalvageStockPallet",Vector3(-1.65+float(i)*0.66,0.25,-1.93),Vector3(0.57,0.35,0.60),mats["rust"])
	# The beacon is tied to running, staffed production, not permanently lit.
	var running_light := _box(yard,"LiveWorkshopStatusLamp",Vector3(2.13,2.30,1.18),Vector3(0.24,0.19,0.24),mats["warning"])
	running_light.visible = false
	var idle_light := _box(yard,"WorkshopIdleMarker",Vector3(2.13,2.30,1.18),Vector3(0.24,0.19,0.24),mats["rooflight"])
	return {"root":yard,"ram":ram,"carrier":carrier,"running_light":running_light,"idle_light":idle_light}
