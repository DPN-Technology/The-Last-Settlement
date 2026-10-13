class_name SettlementArchitecture3D
extends RefCounted

# The first actual modular facade pass. Uses wall spans, structural corners,
# door openings and role-dependent roof volumes rather than monolithic boxes.
# Exterior solid shells, hinged doors, cutaway roofs and playable furnishing anchors.
# Exterior navigation is preserved until a survivor reaches this actual doorway.

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

static func _side_wall_openings(group: Node3D, side: float, size: Vector2, height: float, base: float, wall_mat: Material, mats: Dictionary) -> void:
	# Cut genuine apertures into the side wall. Formerly the wall was one giant
	# solid cube with blue boxes glued to its outside, so it read as toy geometry.
	var half_x: float = size.x * 0.5
	var half_z: float = size.y * 0.5
	var side_x: float = side * half_x
	var opening_half: float = minf(0.59, size.y * 0.105)
	if size.y < 4.8 or height < 2.7:
		box(group,"SideWallSolid",Vector3(side_x,base+height*0.5,0),Vector3(0.27,height,size.y),wall_mat)
		return
	var window_y: float = base + height * 0.55
	var opening_h: float = minf(1.10, height * 0.31)
	var sill_y: float = window_y - opening_h * 0.5
	var lintel_y: float = window_y + opening_h * 0.5
	var centers: Array[float] = [-half_z * 0.38, half_z * 0.32]
	var previous: float = -half_z
	for i in range(centers.size()):
		var middle: float = centers[i]
		var start: float = middle - opening_half
		var finish: float = middle + opening_half
		# Continuous vertical piers carry the lintel between real windows.
		var pier_span: float = start - previous
		if pier_span > 0.04:
			box(group,"SideStructuralPier",Vector3(side_x,base+height*0.5,(previous+start)*0.5),Vector3(0.27,height,pier_span),wall_mat)
		var lower_h: float = sill_y - base
		var upper_h: float = base + height - lintel_y
		box(group,"SideWindowSpandrel",Vector3(side_x,base+lower_h*0.5,middle),Vector3(0.27,lower_h,opening_half*2.0),wall_mat)
		box(group,"SideWindowLintel",Vector3(side_x,lintel_y+upper_h*0.5,middle),Vector3(0.27,upper_h,opening_half*2.0),wall_mat)
		# Window glazing is actually INSIDE the wall rather than in front of it.
		box(group,"RecessedWindowGlass",Vector3(side*(half_x-0.075),window_y,middle),Vector3(0.045,opening_h*0.89,opening_half*1.80),mats["glass"])
		for edge in [-1.0,1.0]:
			box(group,"WindowStoneJamb",Vector3(side*(half_x+0.16),window_y,middle+edge*opening_half),Vector3(0.12,opening_h+0.14,0.11),mats["concrete"])
			box(group,"WindowSteelHeadSill",Vector3(side*(half_x+0.16),window_y+edge*opening_h*0.5,middle),Vector3(0.13,0.11,opening_half*2.0+0.20),mats["steel"])
		box(group,"WindowDeepReveal",Vector3(side*(half_x+0.23),sill_y-0.13,middle),Vector3(0.37,0.12,opening_half*2.0+0.32),mats["foundation"])
		box(group,"WindowDivider",Vector3(side*(half_x+0.20),window_y,middle),Vector3(0.09,opening_h*0.90,0.05),mats["darkmetal"])
		previous = finish
	var remaining: float = half_z - previous
	if remaining > 0.04:
		box(group,"SideStructuralPier",Vector3(side_x,base+height*0.5,(previous+half_z)*0.5),Vector3(0.27,height,remaining),wall_mat)


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
	_side_wall_openings(group,-1.0,size,height,base,wall_mat,mats)
	_side_wall_openings(group,1.0,size,height,base,wall_mat,mats)
	for side in [-1.0,1.0]:
		box(group,"FrontWallSegment",Vector3(side*(door_width*0.5+remainder*0.5),height*0.5+base,-z),Vector3(remainder,height,0.27),wall_mat)
		box(group,"EntryColumn",Vector3(side*(door_width*0.5+0.13),door_height*0.5+base,-z-0.14),Vector3(0.22,door_height,0.22),post)
		for back in [-1.0,1.0]:
			box(group,"StructuralPilaster",Vector3(side*(x-0.10),height*0.5+base,back*(z-0.12)),Vector3(0.30,height,0.30),post)
	box(group,"DoorLintel",Vector3(0,base+door_height+(height-door_height)*0.5,-z),Vector3(door_width,height-door_height,0.29),wall_mat)
	# Hinge on left jamb: the door is a real rotating leaf, not a flat decal.
	var hinge := Node3D.new()
	hinge.name="EntryDoorPivot"
	hinge.position=Vector3(-door_width*0.5+0.08,base,-z+0.13)
	group.add_child(hinge)
	box(hinge,"EntryDoor",Vector3((door_width-0.12)*0.5,(door_height-0.07)*0.5,0),Vector3(door_width-0.12,door_height-0.07,0.11),mats["darkmetal"])
	box(hinge,"DoorHandle",Vector3(door_width-0.35,1.04,-0.10),Vector3(0.08,0.19,0.06),trim)
	box(group,"EntryStep",Vector3(0,0.16,-z-0.86),Vector3(door_width+1.1,0.19,1.75),mats["concrete"])
	box(group,"EntryCanopy",Vector3(0,door_height+0.45,-z-0.73),Vector3(door_width+1.4,0.17,1.78),post)
	# Real thickness and panel trim break up all four silhouettes.
	for side in [-1.0,1.0]:
		box(group,"FrontPlate",Vector3(side*(door_width*0.5+1.4),height*0.62,-z-0.19),Vector3(0.14,1.25,0.07),mats["rust"])
		box(group,"GutterDownpipe",Vector3(side*(x-0.55),height*0.5,-z-0.25),Vector3(0.13,height,0.14),trim)
	# Two-tone grounded lower cladding hides tile-like photo texture repetition.
	for side in [-1.0,1.0]:
		box(group,"LowerServiceWall",Vector3(side*(x+0.016),0.65,0),Vector3(0.05,0.70,size.y*0.88),mats["foundation"])
	box(group,"RearBand",Vector3(0,0.61,z+0.17),Vector3(size.x*0.94,0.74,0.08),mats["foundation"])
	# Narrow plinth vents and minor fabricated structures, not large monoliths.
	for i in range(4):
		var px := -x*0.67 + float(i)*(size.x*0.45)
		box(group,"VentShutter",Vector3(px,0.69,z+0.26),Vector3(0.85,0.26,0.11),mats["darkmetal"])

	if kind == "medical":
		_clinic_service_drops(group,size,height,mats)
	elif kind == "industry":
		_workshop_wall_ribs(group,size,height,mats)

	# Roof pieces are tagged individually and retain their original scene paths,
	# so smoke tests and distinctive exterior silhouettes both continue working.
	var roof_first := group.get_child_count()
	if kind == "housing":
		_pitched_shelter_roof(group,size,height,mats)
		_housing_dormer(group,size,height,mats)
	elif kind == "medical":
		_clinic_roof(group,size,height,mats)
	else:
		_flat_service_roof(group,size,height,kind,mats)
	for index in range(roof_first,group.get_child_count()):
		group.get_child(index).set_meta("cutaway_roof",true)

static func _clinic_service_drops(group: Node3D, size: Vector2, height: float, mats: Dictionary) -> void:
	# Protected service risers make the clinic read as maintained utility
	# infrastructure without crossing its recessed side windows.
	var half_x := size.x * 0.5
	var half_z := size.y * 0.5
	var pipe_height := maxf(1.4,height-0.48)
	for side in [-1.0,1.0]:
		var pipe_x: float = side * (half_x + 0.13)
		var pipe_z: float = -half_z + 0.52
		var pipe_mesh := CylinderMesh.new()
		pipe_mesh.top_radius = 0.065
		pipe_mesh.bottom_radius = 0.075
		pipe_mesh.height = pipe_height
		pipe_mesh.radial_segments = 10
		var pipe := MeshInstance3D.new()
		pipe.name = "ClinicProtectedServiceRiser_%d" % int(side)
		pipe.mesh = pipe_mesh
		pipe.position = Vector3(pipe_x,0.39+pipe_height*0.5,pipe_z)
		pipe.material_override = mats["pipe"]
		pipe.set_meta("clinic_service_pipe",true)
		group.add_child(pipe)
		for clamp_index in range(3):
			var clamp_y := 0.72 + float(clamp_index) * (pipe_height - 0.48) / 2.0
			var clamp := box(group,"ClinicServiceRiserClamp_%d_%d" % [int(side),clamp_index],Vector3(side*(half_x+0.08),clamp_y,pipe_z),Vector3(0.17,0.075,0.15),mats["steel"])
			clamp.set_meta("clinic_service_pipe_clamp",true)

static func _workshop_wall_ribs(group: Node3D, size: Vector2, height: float, mats: Dictionary) -> void:
	# Slender external stiffeners follow the solid piers between side windows;
	# their foot plates reinforce the walls without narrowing any opening.
	var half_x := size.x * 0.5
	var half_z := size.y * 0.5
	var pier_positions: Array[float] = [-half_z*0.78,-half_z*0.03,half_z*0.82]
	for side in [-1.0,1.0]:
		for rib_index in range(pier_positions.size()):
			var z_position := pier_positions[rib_index]
			var rib := box(group,"WorkshopWallRib_%d_%d" % [int(side),rib_index],Vector3(side*(half_x+0.12),height*0.5+0.20,z_position),Vector3(0.13,maxf(1.8,height-0.24),0.18),mats["steel"])
			rib.set_meta("workshop_wall_rib",true)
			var foot := box(group,"WorkshopWallRibFoot_%d_%d" % [int(side),rib_index],Vector3(side*(half_x+0.14),0.49,z_position),Vector3(0.18,0.25,0.34),mats["rust"])
			foot.set_meta("workshop_wall_rib_foot",true)

static func _pitched_shelter_roof(group: Node3D, size: Vector2, height: float, mats: Dictionary) -> void:
	# Real gabled shelter silhouette: significantly steeper than the initial
	# prototype and without box-shaped machinery obscuring the roof pitch.
	var half := size.x * 0.5
	var ridge := 2.65
	var pitch := atan2(ridge, half)
	var sloped_span := sqrt(half * half + ridge * ridge) + 0.45
	for side in [-1.0, 1.0]:
		var panel := box(group, "PitchedHousingRoof", Vector3(side*half*0.5,height+0.32+ridge*0.5,0),Vector3(sloped_span,0.17,size.y+0.95),mats["roof"])
		panel.rotation.z = -side*pitch
		# Raised sheet-metal seams give each roof plane a readable scale.
		for seam_index in range(4):
			var seam_fraction := (float(seam_index) + 0.5) / 4.0
			var seam_x: float = side * half * seam_fraction
			var seam_y: float = height + 0.32 + ridge * (1.0 - seam_fraction) + 0.12
			var seam := box(group, "RoofStandingSeam_%d_%d" % [int(side), seam_index], Vector3(seam_x,seam_y,0),Vector3(0.075,0.10,size.y+0.98),mats["steel"])
			seam.rotation.z = -side*pitch
		var gutter := box(group, "EaveRainGutter", Vector3(side*(half+0.23),height+0.19,0),Vector3(0.27,0.22,size.y+1.12),mats["rust"])
		gutter.rotation.z = 0.0
		# Reinforced rake fascia caps the exposed gable edges at both roof ends.
		for end in [-1.0, 1.0]:
			var fascia := box(group, "GableRakeFascia_%d_%d" % [int(side), int(end)], Vector3(side*half*0.5,height+0.32+ridge*0.5,end*(size.y*0.5+0.49)),Vector3(sloped_span,0.20,0.16),mats["rust"])
			fascia.rotation.z = -side*pitch
			fascia.set_meta("housing_roof_fascia",true)
	# Fill the triangular exposed gables with physically lit, weathered walls.
	# A roof only made from two floating planes did not look like an actual hut.
	var gable := SurfaceTool.new()
	gable.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		var z: float = float(side) * size.y * 0.5
		var left := Vector3(-half,height+0.23,z)
		var right := Vector3(half,height+0.23,z)
		var apex := Vector3(0,height+ridge+0.23,z)
		var triangle: Array = [left,apex,right] if side < 0.0 else [left,right,apex]
		for vertex in triangle:
			gable.set_uv(Vector2((vertex.x+half)/maxf(1.0,size.x),(vertex.y-height)/maxf(1.0,ridge)))
			gable.add_vertex(vertex)
	gable.generate_normals()
	var gable_visual := MeshInstance3D.new()
	gable_visual.name = "ShelterGableEndWalls"
	gable_visual.mesh = gable.commit()
	gable_visual.material_override = mats["wall"]
	group.add_child(gable_visual)
	box(group,"CappedRidge",Vector3(0,height+ridge+0.29,0),Vector3(0.24,0.20,size.y+1.10),mats["rooflight"])
	# Damaged sheet-metal patch panels sit flush to slope, not floating cubes.
	for side in [-1.0,1.0]:
		var patch := box(group,"WeatheredRoofPatch",Vector3(side*half*0.53,height+0.42+ridge*0.47,-size.y*0.17),Vector3(1.8,0.045,1.45),mats["rust"])
		patch.rotation.z = -side*pitch

static func _housing_dormer(group: Node3D, size: Vector2, height: float, mats: Dictionary) -> void:
	# A small front-facing dormer breaks up the otherwise uninterrupted pitched
	# roof. Positioned above the entrance; no collisions or door changes.
	var ridge: float = 2.65
	var half: float = size.x * 0.5
	if half < 2.2 or size.y < 4.0:
		return
	var front_z: float = -size.y * 0.25
	var dormer_width: float = minf(2.25, size.x * 0.25)
	var dormer_depth: float = minf(1.5, size.y * 0.20)
	var roof_base: float = height + ridge * 0.62
	box(group, "ShelterDormerFront", Vector3(0, roof_base, front_z), Vector3(dormer_width, 1.04, 0.14), mats["wall"])
	box(group, "ShelterDormerWindow", Vector3(0, roof_base + 0.03, front_z - 0.095), Vector3(dormer_width * 0.53, 0.59, 0.055), mats["glass"])
	for side in [-1.0, 1.0]:
		box(group, "DormerWindowTrim", Vector3(side * dormer_width * 0.30, roof_base + 0.02, front_z - 0.14), Vector3(0.09, 0.78, 0.11), mats["wood"])
		var slope := box(group, "DormerRoofSlope", Vector3(side * dormer_width * 0.26, roof_base + 0.74, front_z + dormer_depth * 0.33), Vector3(dormer_width * 0.63, 0.12, dormer_depth), mats["roof"])
		slope.rotation.z = -side * 0.36
	box(group, "DormerRidge", Vector3(0, roof_base + 0.94, front_z + dormer_depth * 0.33), Vector3(0.12, 0.10, dormer_depth), mats["steel"])


static func _clinic_roof(group: Node3D, size: Vector2, height: float, mats: Dictionary) -> void:
	box(group,"ClinicRoof",Vector3(0,height+0.25,0),Vector3(size.x+0.5,0.33,size.y+0.5),mats["rooflight"])
	var parapet_y := height + 0.50
	var parapet_x := size.x * 0.5 + 0.15
	var parapet_z := size.y * 0.5 + 0.15
	for side in [-1.0, 1.0]:
		var long_parapet := box(group,"ClinicRoofParapet_%d" % int(side),Vector3(0,parapet_y,side*parapet_z),Vector3(size.x+0.32,0.22,0.16),mats["foundation"])
		long_parapet.set_meta("clinic_roof_edge",true)
		var long_coping := box(group,"ClinicRoofCoping_%d" % int(side),Vector3(0,parapet_y+0.14,side*parapet_z),Vector3(size.x+0.32,0.07,0.19),mats["steel"])
		long_coping.set_meta("clinic_roof_edge",true)
		var end_parapet := box(group,"ClinicRoofParapetEnd_%d" % int(side),Vector3(side*parapet_x,parapet_y,0),Vector3(0.16,0.22,size.y+0.32),mats["foundation"])
		end_parapet.set_meta("clinic_roof_edge",true)
		var end_coping := box(group,"ClinicRoofCopingEnd_%d" % int(side),Vector3(side*parapet_x,parapet_y+0.14,0),Vector3(0.19,0.07,size.y+0.32),mats["steel"])
		end_coping.set_meta("clinic_roof_edge",true)
	box(group,"MedicalVentPavilion",Vector3(-size.x*0.25,height+1.05,size.y*0.17),Vector3(2.1,1.42,2.4),mats["clinic"])
	box(group,"MedicalVentCap",Vector3(-size.x*0.25,height+1.85,size.y*0.17),Vector3(2.5,0.17,2.7),mats["roof"])
	var pavilion_x := -size.x * 0.25
	var pavilion_z := size.y * 0.17
	for louver_index in range(5):
		var louver := box(group,"MedicalVentLouver_%d" % louver_index,Vector3(pavilion_x,height+0.62+float(louver_index)*0.19,pavilion_z-1.24),Vector3(1.14,0.08,0.07),mats["steel"])
		louver.set_meta("clinic_vent_louver",true)
	for stack_index in range(2):
		var stack_x := pavilion_x + (float(stack_index)-0.5)*1.0
		_roof_stack(group,"MedicalVentStack_%d" % stack_index,Vector3(stack_x,height+2.11,pavilion_z),0.18,0.40,mats["darkmetal"])
		var stack_cap := box(group,"MedicalVentStackCap_%d" % stack_index,Vector3(stack_x,height+2.34,pavilion_z),Vector3(0.48,0.08,0.48),mats["rust"])
		stack_cap.set_meta("clinic_vent_stack_cap",true)

static func _roof_stack(group: Node3D, name: String, at: Vector3, radius: float, height: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 0.88
	mesh.height = height
	mesh.radial_segments = 12
	var stack := MeshInstance3D.new()
	stack.name = name
	stack.mesh = mesh
	stack.position = at
	stack.material_override = material
	stack.set_meta("roof_exhaust_stack",true)
	group.add_child(stack)

static func _industrial_sawtooth_roof(group: Node3D, size: Vector2, height: float, mats: Dictionary) -> void:
	# Functional sawtooth architecture: angled roof planes and clerestory
	# glazing, instead of a second cube sitting on a flat roof.
	var bays: int = 3
	var bay_width: float = size.x / float(bays)
	var rise: float = 1.10
	for i in range(bays):
		var x: float = -size.x * 0.5 + (float(i) + 0.5) * bay_width
		var slope_length: float = sqrt(bay_width * bay_width + rise * rise)
		var panel := box(group, "IndustrialSlopingRoofBay", Vector3(x,height+0.40+rise*0.5,0), Vector3(slope_length+0.16,0.15,size.y+0.54), mats["roof"])
		panel.rotation.z = -atan2(rise,bay_width)
		var high_edge: float = x + bay_width * 0.5
		box(group, "ClerestoryFrame", Vector3(high_edge,height+0.42+rise*0.5,0), Vector3(0.14,rise,size.y+0.35),mats["steel"])
		box(group, "ClerestoryGlass", Vector3(high_edge+0.025,height+0.42+rise*0.5,0), Vector3(0.06,rise*0.74,size.y*0.85),mats["glass"])
		box(group, "IndustrialRaisedSeam", Vector3(x,height+0.47+rise*0.5,0), Vector3(0.065,0.07,size.y+0.60),mats["rooflight"])
	for side in [-1.0,1.0]:
		box(group,"SawtoothEndGutter",Vector3(0,height+0.29,side*(size.y*0.5+0.24)),Vector3(size.x+0.42,0.17,0.19),mats["rust"])


static func _flat_service_roof(group: Node3D, size: Vector2, height: float, kind: String, mats: Dictionary) -> void:
	box(group,"ServiceRoof",Vector3(0,height+0.26,0),Vector3(size.x+0.68,0.37,size.y+0.68),mats["roof"])
	if kind in ["industry","storage"]:
		_industrial_sawtooth_roof(group,size,height,mats)
		if kind == "industry":
			var machine_x := -size.x * 0.21
			var machine_z := -size.y * 0.17
			var machine_width := size.x * 0.29
			var machine_depth := size.y * 0.42
			var shack := box(group,"RaisedMachineRoom",Vector3(machine_x,height+0.96,machine_z),Vector3(machine_width,1.26,machine_depth),mats["steel"])
			shack.rotation.y = 0.035
			var cap := box(group,"RaisedMachineCap",Vector3(machine_x,height+1.66,machine_z),Vector3(machine_width*1.17,0.16,machine_depth*1.17),mats["rooflight"])
			cap.set_meta("industrial_roof_machine_cap",true)
			for louver_index in range(3):
				var louver := box(group,"IndustrialMachineLouver_%d" % louver_index,Vector3(machine_x,height+0.76+float(louver_index)*0.22,machine_z-machine_depth*0.5-0.035),Vector3(machine_width*0.62,0.09,0.08),mats["darkmetal"])
				louver.set_meta("industrial_roof_louver",true)
			for stack_index in range(2):
				var stack_x := machine_x + (float(stack_index)-0.5)*machine_width*0.48
				_roof_stack(group,"IndustrialExhaustStack_%d" % stack_index,Vector3(stack_x,height+1.99,machine_z),0.20,0.48,mats["darkmetal"])
				var stack_cap := box(group,"IndustrialExhaustCap_%d" % stack_index,Vector3(stack_x,height+2.26,machine_z),Vector3(0.52,0.08,0.52),mats["rust"])
				stack_cap.set_meta("industrial_roof_stack_cap",true)
		else:
			var shack := box(group,"RaisedMachineRoom",Vector3(-size.x*0.21,height+0.96,-size.y*0.17),Vector3(size.x*0.29,1.26,size.y*0.42),mats["steel"])
			shack.rotation.y = 0.035
			box(group,"RaisedMachineCap",Vector3(-size.x*0.21,height+1.66,-size.y*0.17),Vector3(size.x*0.34,0.16,size.y*0.49),mats["rooflight"])
	elif kind in ["command","power","generator"]:
		box(group,"ServiceRaisedPlatform",Vector3(size.x*0.32,height+0.61,size.y*0.20),Vector3(2.0,0.39,2.8),mats["steel"])
	else:
		box(group,"UtilityWeatherCover",Vector3(-size.x*0.25,height+0.53,size.y*0.13),Vector3(1.85,0.34,1.7),mats["rooflight"])
