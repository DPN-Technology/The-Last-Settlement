class_name SettlementRoomIdentity3D
extends RefCounted

# Compact playable-scene art. Each interior has unmistakable function,
# readable work zones and lived-in detail at normal isometric zoom.
# Decorative geometry only: never changes assignments, collision or saves.
static func box(parent: Node3D, name: String, p: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var obj := MeshInstance3D.new()
	obj.name=name
	var mesh := BoxMesh.new()
	mesh.size=size
	obj.mesh=mesh
	obj.position=p
	obj.material_override=mat
	parent.add_child(obj)
	return obj

static func cylinder(parent: Node3D, name: String, p: Vector3, radius: float, h: float, mat: Material) -> MeshInstance3D:
	var obj := MeshInstance3D.new()
	obj.name=name
	var mesh := CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.height=h
	mesh.radial_segments=12
	obj.mesh=mesh
	obj.position=p
	obj.material_override=mat
	parent.add_child(obj)
	return obj

static func _privacy_curtain_mesh(width: float, height: float, depth: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var width_segments := 24
	var height_segments := 8
	for row in range(height_segments):
		var v0 := float(row)/float(height_segments)
		var v1 := float(row+1)/float(height_segments)
		for column in range(width_segments):
			var u0 := float(column)/float(width_segments)
			var u1 := float(column+1)/float(width_segments)
			var points := [
				Vector2(u0,v0),Vector2(u0,v1),Vector2(u1,v0),
				Vector2(u1,v0),Vector2(u0,v1),Vector2(u1,v1)
			]
			for uv in points:
				var fold := sin(uv.x*TAU*8.0)*depth
				var droop := sin(uv.x*PI)*0.055*(1.0-uv.y)
				var point := Vector3(fold,height*uv.y+droop,(uv.x-0.5)*width)
				var lower_wear := lerpf(0.88,1.0,uv.y)
				var fold_shade := 0.91+0.09*cos(uv.x*TAU*8.0)
				surface.set_uv(Vector2(uv.x*3.2,uv.y*1.7))
				surface.set_color(Color(lower_wear*fold_shade,lower_wear*fold_shade,lower_wear*fold_shade,1.0))
				surface.add_vertex(point)
	surface.generate_normals()
	return surface.commit()

static func _privacy_curtain(parent: Node3D, name: String, pos: Vector3, width: float, height: float, mat: Material) -> void:
	var curtain := MeshInstance3D.new()
	curtain.name=name
	curtain.mesh=_privacy_curtain_mesh(width,height,0.055)
	curtain.position=pos
	curtain.material_override=mat
	curtain.set_meta("clinic_privacy_curtain",true)
	parent.add_child(curtain)

static func _chair(parent: Node3D, p: Vector3, mats: Dictionary) -> void:
	box(parent,"ChairedSeat",p+Vector3(0,0.55,0),Vector3(0.63,0.13,0.64),mats["canvas"])
	box(parent,"BackRest",p+Vector3(0,1.05,0.28),Vector3(0.63,0.85,0.12),mats["steel"])
	for side in [-1.0,1.0]:
		box(parent,"SeatFeet",p+Vector3(side*0.24,0.27,-0.21),Vector3(0.075,0.52,0.075),mats["darkmetal"])

static func _work_light(parent: Node3D, p: Vector3) -> void:
	var lamp := OmniLight3D.new()
	lamp.name="FacilityTaskAccent"
	lamp.position=p
	lamp.omni_range=4.2
	lamp.light_color=Color("#f1d5b3")
	lamp.light_energy=0.20
	lamp.shadow_enabled=false
	parent.add_child(lamp)

static func _wall_label(parent: Node3D, label: String, x: float, z: float) -> void:
	var plaque := Label3D.new()
	plaque.name="InteriorFunctionMarker"
	plaque.text=label
	plaque.font_size=28
	plaque.pixel_size=0.008
	plaque.outline_size=3
	plaque.modulate=Color("#eee8da")
	plaque.position=Vector3(x,2.05,z)
	plaque.visible=false # 3D GL Compatibility glyph atlas renders white bars; see HUD labels.
	plaque.rotation.y=PI
	parent.add_child(plaque)

static func _housing(parent: Node3D, size: Vector2, mats: Dictionary) -> void:
	var hx := size.x*0.5
	var hz := size.y*0.5
	# Real surfaces identify sleeping, storage and shared eating areas.
	box(parent,"ShelterSleepingRug",Vector3(0,0.327,0.17),Vector3(1.12,0.017,size.y*0.52),mats["cloth"])
	for side in [-1.0,1.0]:
		var x: float=side*hx*0.60
		box(parent,"BunkHeadboard",Vector3(x,0.89,-hz*0.40),Vector3(1.42,0.36,0.12),mats["rust"])
		box(parent,"FoldedBlankets",Vector3(x,0.76,-hz*0.06),Vector3(1.24,0.065,0.43),mats["cloth"])
		box(parent,"BedsideLocker",Vector3(side*hx*0.85,0.64,hz*0.04),Vector3(0.74,0.86,0.68),mats["darkmetal"])
		box(parent,"LockerLatch",Vector3(side*hx*0.85,0.76,-0.04+hz*0.04),Vector3(0.29,0.10,0.06),mats["rooflight"])
		_chair(parent,Vector3(side*hx*0.29,0,hz*0.40),mats)
		box(parent,"FamilyShelf",Vector3(side*hx*0.66,1.42,hz*0.73),Vector3(1.34,0.12,0.45),mats["rust"])
	box(parent,"SharedShelterTable",Vector3(0,0.93,hz*0.56),Vector3(1.42,0.10,0.65),mats["steel"])
	for i in range(3):
		var x: float=float(i-1)*0.56
		cylinder(parent,"MealTin",Vector3(x,1.055,hz*0.56),0.12,0.047,mats["rooflight"])
	_wall_label(parent,"SLEEP  /  COMMON AREA",0,hz-0.26)
	_work_light(parent,Vector3(0,2.45,hz*0.47))

static func _medical(parent: Node3D, size: Vector2, mats: Dictionary) -> void:
	var hx := size.x*0.5
	var hz := size.y*0.5
	# Distinct brighter treatment lane, occupied examination bays to its sides.
	box(parent,"ClinicTreatmentFloor",Vector3(0,0.322,0),Vector3(1.04,0.012,size.y*0.69),mats["foundation"])
	for side in [-1.0,1.0]:
		var x: float=side*hx*0.59
		box(parent,"BedsideTreatmentCart",Vector3(x,0.86,hz*0.47),Vector3(0.90,0.11,0.58),mats["steel"])
		for leg_side in [-1.0,1.0]:
			box(parent,"TriageCartLeg",Vector3(x+leg_side*0.34,0.45,hz*0.47),Vector3(0.07,0.76,0.38),mats["darkmetal"])
		box(parent,"SterileTray",Vector3(x,1.38,hz*0.47),Vector3(0.95,0.075,0.52),mats["steel"])
		box(parent,"PatientObservationDisplay",Vector3(side*hx*0.81,1.95,-hz*0.50),Vector3(0.91,0.62,0.18),mats["darkmetal"])
		box(parent,"VitalsScreen",Vector3(side*hx*0.81,1.97,-hz*0.61),Vector3(0.73,0.43,0.035),mats["glass"])
		var screen_x: float=side*hx*0.33
		var screen_z: float=hz*0.37
		box(parent,"MedicalPrivacyPost",Vector3(screen_x,1.25,screen_z),Vector3(0.09,2.1,0.09),mats["steel"])
		box(parent,"PrivacyCurtainTrack",Vector3(screen_x,2.21,screen_z),Vector3(0.10,0.10,1.9),mats["darkmetal"])
		_privacy_curtain(parent,"PleatedClinicPrivacyCurtain",Vector3(screen_x,1.22,screen_z),1.82,0.91,mats["cloth"])
		for hook_index in range(5):
			var hook_z: float=screen_z-0.72+float(hook_index)*0.36
			cylinder(parent,"CurtainTrackRoller",Vector3(screen_x,2.13,hook_z),0.055,0.12,mats["steel"])
	box(parent,"ClinicOxygenManifold",Vector3(0,1.78,-hz*0.66),Vector3(1.62,0.12,0.12),mats["pipe"])
	for side in [-1.0,1.0]:
		var oxygen_drop := cylinder(parent,"PatientOxygenDrop",Vector3(side*hx*0.36,1.34,-hz*0.62),0.035,0.78,mats["steel"])
		oxygen_drop.set_meta("clinic_oxygen_delivery",true)
		cylinder(parent,"OxygenFlowMeter",Vector3(side*hx*0.36,1.82,-hz*0.62),0.105,0.24,mats["glass"])
	box(parent,"ClinicTriageStation",Vector3(0,0.98,hz*0.72),Vector3(2.25,0.14,0.83),mats["steel"])
	box(parent,"SanitationSink",Vector3(0,0.92,hz*0.86),Vector3(0.76,0.11,0.37),mats["clinic"])
	for side in [-1.0,1.0]:
		box(parent,"ClinicCrossBar",Vector3(side*hx*0.53,2.20,hz-0.29),Vector3(0.57,0.13,0.09),mats["cross"])
		box(parent,"ClinicCrossStem",Vector3(side*hx*0.53,2.20,hz-0.28),Vector3(0.13,0.58,0.09),mats["cross"])
	_wall_label(parent,"TRIAGE  /  TREATMENT",0,hz-0.26)
	_work_light(parent,Vector3(0,2.51,0))

static func _command(parent: Node3D, size: Vector2, mats: Dictionary) -> void:
	var hx := size.x*0.5
	var hz := size.y*0.5
	# High contrast physical planning surfaces, visible even in isometric mode.
	box(parent,"CommandOperationsFloor",Vector3(0,0.325,hz*0.18),Vector3(1.16,0.012,size.y*0.48),mats["foundation"])
	box(parent,"CommandPlanningDesk",Vector3(0,1.02,hz*0.52),Vector3(2.16,0.14,0.86),mats["steel"])
	box(parent,"CommandMapSurface",Vector3(0,1.10,hz*0.52),Vector3(1.96,0.024,0.66),mats["olive"])
	for side in [-1.0,1.0]:
		var x: float=side*hx*0.63
		box(parent,"RadioOperationsRack",Vector3(x,1.13,hz*0.74),Vector3(0.88,1.54,0.47),mats["darkmetal"])
		for row in range(2):
			box(parent,"CommandDataScreen",Vector3(x,1.15+float(row)*0.66,hz*0.62),Vector3(0.70,0.38,0.055),mats["glass"])
			box(parent,"CommandStatusLamp",Vector3(x+0.22,1.03+float(row)*0.66,hz*0.60),Vector3(0.08,0.055,0.035),mats["glow"])
		_chair(parent,Vector3(side*hx*0.27,0,-hz*0.15),mats)
	box(parent,"SituationDisplayFrame",Vector3(0,1.90,hz-0.35),Vector3(3.20,1.11,0.15),mats["steel"])
	box(parent,"SituationDisplay",Vector3(0,1.90,hz-0.46),Vector3(2.97,0.88,0.036),mats["glass"])
	for i in range(7):
		var x: float=-1.50+float(i)*0.50
		box(parent,"MissionTicker",Vector3(x,1.66,hz-0.49),Vector3(0.20,0.055,0.016),mats["warning"] if i%3==0 else mats["olive"])
	_wall_label(parent,"OPERATIONS  /  LIVE NETWORK",0,hz-0.51)
	_work_light(parent,Vector3(0,2.51,hz*0.35))

static func _industrial(parent: Node3D, size: Vector2, mats: Dictionary) -> void:
	var hx := size.x*0.5
	var hz := size.y*0.5
	box(parent,"IndustrialWorkZone",Vector3(0,0.323,hz*0.18),Vector3(1.18,0.012,size.y*0.52),mats["foundation"])
	for side in [-1.0,1.0]:
		var x: float=side*hx*0.60
		box(parent,"FabricationFrame",Vector3(x,1.45,hz*0.43),Vector3(1.45,1.90,1.06),mats["darkmetal"])
		box(parent,"ToolBoard",Vector3(x,1.75,hz-0.26),Vector3(1.40,0.98,0.09),mats["rust"])
		for tool in range(4):
			box(parent,"HangingWorkshopTool",Vector3(x-0.49+float(tool)*0.32,1.68,hz-0.34),Vector3(0.08,0.46,0.045),mats["steel"])
		cylinder(parent,"MachineFlywheel",Vector3(x,1.16,hz*0.18),0.35,0.33,mats["rooflight"])
	box(parent,"SharedConveyor",Vector3(0,0.89,hz*0.64),Vector3(2.26,0.27,0.80),mats["darkmetal"])
	for i in range(4):
		cylinder(parent,"Roller",Vector3(-0.77+float(i)*0.51,1.02,hz*0.64),0.13,0.36,mats["steel"])
	_wall_label(parent,"FABRICATION  /  SERVICE",0,hz-0.26)

static func _utilities(parent: Node3D, kind: String, size: Vector2, mats: Dictionary) -> void:
	var hx := size.x*0.5
	var hz := size.y*0.5
	var wet := kind in ["water","water_pump","purifier","water_tank","sewage"]
	box(parent,"UtilityMaintenanceFloor",Vector3(0,0.325,hz*0.21),Vector3(1.20,0.013,size.y*0.48),mats["blue"] if wet else mats["rust"])
	for side in [-1.0,1.0]:
		var x: float=side*hx*0.59
		cylinder(parent,"ServicePressurePipe",Vector3(x,0.99,hz*0.50),0.20,1.73,mats["pipe"])
		cylinder(parent,"ValveHandwheel",Vector3(x,1.87,hz*0.50),0.34,0.095,mats["steel"])
		box(parent,"TelemetryPanel",Vector3(x,1.62,hz-0.26),Vector3(1.26,1.11,0.23),mats["darkmetal"])
		box(parent,"UtilityReadout",Vector3(x,1.77,hz-0.40),Vector3(0.84,0.44,0.04),mats["glass"])
	_wall_label(parent,"WATER CONTROL" if wet else "GRID DISTRIBUTION",0,hz-0.26)

static func populate(room: Node3D, kind: String, size: Vector2, mats: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name="FacilityInteriorIdentity"
	room.add_child(root)
	match kind:
		"housing":
			_housing(root,size,mats)
		"medical":
			_medical(root,size,mats)
		"command":
			_command(root,size,mats)
		"industry","storage":
			_industrial(root,size,mats)
		_:
			_utilities(root,kind,size,mats)
	return root
