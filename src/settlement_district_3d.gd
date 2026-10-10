class_name SettlementDistrict3D
extends RefCounted

# Outdoor camp scene dressing; these meshes do not add invisible collision
# barriers or change movement targets / old save-game coordinates.
static func box(parent: Node3D, name: String, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name=name
	var mesh := BoxMesh.new()
	mesh.size=size
	item.mesh=mesh
	item.position=at
	item.material_override=mat
	parent.add_child(item)
	return item

static func cylinder(parent: Node3D, name: String, at: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name=name
	var mesh := CylinderMesh.new()
	mesh.height=height
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.radial_segments=12
	item.mesh=mesh
	item.position=at
	item.material_override=mat
	parent.add_child(item)
	return item

static func _fence(parent: Node3D, at: Vector3, horizontal: bool, mats: Dictionary) -> void:
	var size := Vector3(9.3,0.13,0.15) if horizontal else Vector3(0.15,0.13,9.3)
	for y in [0.51,1.57]:
		box(parent,"PerimeterRail",at+Vector3(0,float(y),0),size,mats["steel"])
	for end in [-1.0,1.0]:
		var pos := at+(Vector3(end*4.60,0,0) if horizontal else Vector3(0,0,end*4.60))
		box(parent,"PerimeterPost",pos+Vector3(0,1.02,0),Vector3(0.16,2.04,0.16),mats["rust"])
	for i in range(6):
		var d := -3.86+float(i)*1.54
		var local := Vector3(d,0,0) if horizontal else Vector3(0,0,d)
		box(parent,"Picket",at+local+Vector3(0,1.03,0),Vector3(0.085,1.1,0.085),mats["rooflight"])

static func _lamp(parent: Node3D, at: Vector3, mats: Dictionary) -> void:
	var pole := Node3D.new()
	pole.name="CampLanternPost"
	pole.position=at
	parent.add_child(pole)
	box(pole,"Pole",Vector3(0,2.50,0),Vector3(0.14,5.0,0.14),mats["steel"])
	box(pole,"Arm",Vector3(0.54,4.90,0),Vector3(1.1,0.12,0.15),mats["rust"])
	box(pole,"LampHousing",Vector3(0.97,4.69,0),Vector3(0.63,0.31,0.48),mats["rooflight"])
	box(pole,"LampLens",Vector3(0.97,4.50,0),Vector3(0.47,0.07,0.35),mats["glow"])

static func _supply(parent: Node3D, at: Vector3, mats: Dictionary) -> void:
	var depot := Node3D.new()
	depot.name="SupplyDepot"
	depot.position=at
	parent.add_child(depot)
	box(depot,"Pallet",Vector3(0,0.18,0),Vector3(3.6,0.30,2.1),mats["canvas"])
	for i in range(3):
		box(depot,"SealedCargo",Vector3(-1.0+float(i)*1.0,0.70,0),Vector3(0.87,0.70,1.52),mats["rust"] if i%2==0 else mats["steel"])
	for side in [-1.0,1.0]:
		cylinder(depot,"Barrel",Vector3(side*2.18,0.60,0),0.45,1.13,mats["blue"])

static func build(parent: Node3D, mats: Dictionary) -> Node3D:
	var camp := Node3D.new()
	camp.name="LastHavenPerimeterDressing"
	parent.add_child(camp)
	# Perimeter outside all starting facilities; the northern road gate and
	# southern farm approaches deliberately remain unobstructed.
	for x in [-31.0,-21.5,-12.0,17.5,27.0,36.5,46.0,55.5]:
		_fence(camp,Vector3(float(x),0,-31.0),true,mats)
	for edge_x in [-39.0,64.5]:
		for z in [-24.0,-14.5,-5.0,4.5,14.0,23.5]:
			_fence(camp,Vector3(float(edge_x),0,float(z)),false,mats)
	# Landmarks are intentionally distant from built doors and workstations.
	for x in [-30.5,-13.0,10.0,29.0,55.0]:
		for z in [-22.5,27.0]:
			_lamp(camp,Vector3(float(x),0,float(z)),mats)
	for location in [
		Vector3(-33.0,0,-10.0),
		Vector3(-32.5,0,19.0),
		Vector3(34.0,0,-24.0),
		Vector3(57.5,0,3.0),
		Vector3(58.0,0,27.0)
	]:
		_supply(camp,location,mats)
	# Compact concrete strips make civilian zones readable at overview zoom.
	for x in [-28.0,29.0]:
		box(camp,"ServiceApron",Vector3(float(x),0.039,-2.8),Vector3(3.2,0.067,11.0),mats["asphalt"])
		for z in [-7.0,1.5]:
			box(camp,"TrafficMark",Vector3(float(x),0.078,float(z)),Vector3(2.3,0.017,0.16),mats["stripe"])
	return camp
