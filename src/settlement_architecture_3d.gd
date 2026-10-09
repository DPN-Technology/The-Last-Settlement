class_name SettlementArchitecture3D
extends RefCounted

# The first actual modular facade pass. Uses wall spans, structural corners,
# door openings and role-dependent roof volumes rather than monolithic boxes.
# No navmesh/collision claim: Issue #8 owns walking through doors/walls.

static func box(parent: Node3D, name: String, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var obj := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	obj.name = name
	obj.mesh = mesh
	obj.position = at
	obj.material_override = mat
	parent.add_child(obj)
	return obj

static func facade(group: Node3D, kind: String, size: Vector2, height: float, wall_mat: Material, mats: Dictionary) -> void:
	var x := size.x*0.5
	var z := size.y*0.5
	var base := 0.20
	var door_width := 1.8
	var door_height := minf(2.48, height - 0.68)
	var remainder := maxf(0.5, (size.x - door_width)*0.5)
	var post: Material = mats["steel"]
	var trim: Material = mats["rooflight"]
	# Distinct wall spans leave a physical ground-level access opening.
	box(group,"RearWall",Vector3(0,height*0.5+base,z),Vector3(size.x,height,0.27),wall_mat)
	box(group,"LeftWall",Vector3(-x,height*0.5+base,0),Vector3(0.27,height,size.y),wall_mat)
	box(group,"RightWall",Vector3(x,height*0.5+base,0),Vector3(0.27,height,size.y),wall_mat)
	for side in [-1.0,1.0]:
		box(group,"FrontWallSegment",Vector3(side*(door_width*0.5+remainder*0.5),height*0.5+base,-z),Vector3(remainder,height,0.27),wall_mat)
		box(group,"EntryColumn",Vector3(side*(door_width*0.5+0.13),door_height*0.5+base,-z-0.14),Vector3(0.22,door_height,0.22),post)
		for back in [-1.0,1.0]:
			box(group,"StructuralPilaster",Vector3(side*(x-0.10),height*0.5+base,back*(z-0.12)),Vector3(0.30,height,0.30),post)
	box(group,"DoorLintel",Vector3(0,base+door_height+(height-door_height)*0.5,-z),Vector3(door_width,height-door_height,0.29),wall_mat)
	# Distinct door leaf recessed behind the wall plane, with inset handle.
	var leaf := box(group,"RecessedEntryDoor",Vector3(0,door_height*0.5+base,-z+0.12),Vector3(door_width-0.12,door_height-0.07,0.11),mats["darkmetal"])
	leaf.name = "EntryDoor"
	box(group,"DoorHandle",Vector3(0.63,1.16,-z-0.03),Vector3(0.08,0.19,0.06),trim)
	box(group,"EntryStep",Vector3(0,0.16,-z-0.86),Vector3(door_width+1.1,0.19,1.75),mats["concrete"])
	box(group,"EntryCanopy",Vector3(0,door_height+0.45,-z-0.73),Vector3(door_width+1.4,0.17,1.78),post)
	# Real thickness and panel trim break up all four silhouettes.
	for side in [-1.0,1.0]:
		box(group,"FrontPlate",Vector3(side*(door_width*0.5+1.4),height*0.62,-z-0.19),Vector3(0.14,1.25,0.07),mats["rust"])
		box(group,"GutterDownpipe",Vector3(side*(x-0.55),height*0.5,-z-0.25),Vector3(0.13,height,0.14),trim)
		for pane in range(2):
			var window_z := -z*0.38+float(pane)*z*0.70
			box(group,"SideWindowFrame",Vector3(side*(x+0.16),height*0.55,window_z),Vector3(0.12,1.10,1.37),post)
			box(group,"RecessedWindowGlass",Vector3(side*(x+0.225),height*0.55,window_z),Vector3(0.06,0.85,1.13),mats["glass"])
	# Two-tone grounded lower cladding hides tile-like photo texture repetition.
	for side in [-1.0,1.0]:
		box(group,"LowerServiceWall",Vector3(side*(x+0.016),0.65,0),Vector3(0.05,0.70,size.y*0.88),mats["foundation"])
	box(group,"RearBand",Vector3(0,0.61,z+0.17),Vector3(size.x*0.94,0.74,0.08),mats["foundation"])
	# Narrow plinth vents and minor fabricated structures, not large monoliths.
	for i in range(4):
		var px := -x*0.67 + float(i)*(size.x*0.45)
		box(group,"VentShutter",Vector3(px,0.69,z+0.26),Vector3(0.85,0.26,0.11),mats["darkmetal"])

	# Different rooflines read as fundamentally different buildings at zoom-out.
	if kind == "housing":
		_pitched_shelter_roof(group,size,height,mats)
	elif kind == "medical":
		_clinic_roof(group,size,height,mats)
	else:
		_flat_service_roof(group,size,height,kind,mats)

static func _pitched_shelter_roof(group: Node3D, size: Vector2, height: float, mats: Dictionary) -> void:
	var half := size.x*0.5
	var ridge := 1.55
	var pitch := atan2(ridge,half)
	var sloped_span := sqrt(half*half+ridge*ridge)+0.55
	for sign in [-1.0,1.0]:
		var panel := box(group,"PitchedHousingRoof",Vector3(sign*half*0.5,height+0.24+ridge*0.5,0),Vector3(sloped_span,0.22,size.y+0.95),mats["roof"])
		panel.rotation.z = -sign*pitch
	for side in [-1.0,1.0]:
		box(group,"RidgeRoofEndTrim",Vector3(0,height+ridge+0.23,side*(size.y*0.5+0.43)),Vector3(0.24,0.18,0.12),mats["steel"])
	box(group,"CappedRidge",Vector3(0,height+ridge+0.25,0),Vector3(0.3,0.18,size.y+1.1),mats["rooflight"])
	for sign in [-1.0,1.0]:
		box(group,"WeatheredShutter",Vector3(sign*(half*0.5),height+0.43, -size.y*0.20),Vector3(1.15,0.12,1.55),mats["rust"])

static func _clinic_roof(group: Node3D, size: Vector2, height: float, mats: Dictionary) -> void:
	box(group,"ClinicRoof",Vector3(0,height+0.25,0),Vector3(size.x+0.5,0.33,size.y+0.5),mats["rooflight"])
	box(group,"MedicalVentPavilion",Vector3(-size.x*0.25,height+1.05,size.y*0.17),Vector3(2.1,1.42,2.4),mats["clinic"])
	box(group,"MedicalVentCap",Vector3(-size.x*0.25,height+1.85,size.y*0.17),Vector3(2.5,0.17,2.7),mats["roof"])

static func _flat_service_roof(group: Node3D, size: Vector2, height: float, kind: String, mats: Dictionary) -> void:
	box(group,"ServiceRoof",Vector3(0,height+0.26,0),Vector3(size.x+0.68,0.37,size.y+0.68),mats["roof"])
	if kind in ["industry","storage"]:
		# Two asymmetrical machine-room volumes create an industrial sawtooth skyline.
		var shack := box(group,"RaisedMachineRoom",Vector3(-size.x*0.21,height+0.96,-size.y*0.17),Vector3(size.x*0.29,1.26,size.y*0.42),mats["steel"])
		shack.rotation.y = 0.035
		box(group,"RaisedMachineCap",Vector3(-size.x*0.21,height+1.66,-size.y*0.17),Vector3(size.x*0.34,0.16,size.y*0.49),mats["rooflight"])
	elif kind in ["command","power","generator"]:
		box(group,"ServiceRaisedPlatform",Vector3(size.x*0.32,height+0.61,size.y*0.20),Vector3(2.0,0.39,2.8),mats["steel"])
	else:
		box(group,"UtilityWeatherCover",Vector3(-size.x*0.25,height+0.53,size.y*0.13),Vector3(1.85,0.34,1.7),mats["rooflight"])
