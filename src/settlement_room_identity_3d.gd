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

static func _surface_wear_material(color: Color, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color=color
	material.roughness=0.84
	material.metallic=metallic
	return material

static func _surface_wear_mark(parent: Node3D, name: String, pos: Vector3, size: Vector3, mat: Material, angle: float) -> MeshInstance3D:
	var mark := box(parent,name,pos,size,mat)
	mark.rotation.y=angle
	mark.set_meta("furniture_surface_wear",true)
	return mark

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
			var points: Array[Vector2] = [
				Vector2(u0,v0),Vector2(u0,v1),Vector2(u1,v0),
				Vector2(u1,v0),Vector2(u0,v1),Vector2(u1,v1)
			]
			for uv: Vector2 in points:
				var fold: float=sin(uv.x*TAU*8.0)*depth
				var droop: float=sin(uv.x*PI)*0.055*(1.0-uv.y)
				var point := Vector3(fold,height*uv.y+droop,(uv.x-0.5)*width)
				var lower_wear: float=lerpf(0.88,1.0,uv.y)
				var fold_shade: float=0.91+0.09*cos(uv.x*TAU*8.0)
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
	var cleaning_streak := _surface_wear_material(Color("#929b99"),0.34)
	var tray_edge_scuff := _surface_wear_material(Color("#b0b5ad"),0.42)
	# Distinct brighter treatment lane, occupied examination bays to its sides.
	box(parent,"ClinicTreatmentFloor",Vector3(0,0.322,0),Vector3(1.04,0.012,size.y*0.69),mats["foundation"])
	for side in [-1.0,1.0]:
		var x: float=side*hx*0.59
		var task_lamp := box(parent,"ClinicExaminationTaskLamp",Vector3(x,2.36,0.02),Vector3(0.56,0.11,0.44),mats["clinic"])
		task_lamp.set_meta("clinic_examination_task_lamp",true)
		var lamp_arm := cylinder(parent,"ClinicTaskLampDrop",Vector3(x,2.08,0.02),0.035,0.47,mats["steel"])
		lamp_arm.set_meta("clinic_examination_task_lamp",true)
		var lamp_reach := box(parent,"ClinicTaskLampReach",Vector3(x,2.42,(hz-0.29+0.02)*0.5),Vector3(0.07,0.07,maxf(0.20,hz-0.31)),mats["steel"])
		lamp_reach.set_meta("clinic_examination_task_lamp",true)
		var lamp_mount := box(parent,"ClinicTaskLampWallMount",Vector3(x,2.43,hz-0.29),Vector3(0.38,0.10,0.18),mats["darkmetal"])
		lamp_mount.set_meta("clinic_examination_task_lamp",true)
		box(parent,"BedsideTreatmentCart",Vector3(x,0.86,hz*0.47),Vector3(0.90,0.11,0.58),mats["steel"])
		for leg_side in [-1.0,1.0]:
			box(parent,"TriageCartLeg",Vector3(x+leg_side*0.34,0.45,hz*0.47),Vector3(0.07,0.76,0.38),mats["darkmetal"])
		var sterile_tray := box(parent,"SterileTray",Vector3(x,1.38,hz*0.47),Vector3(0.95,0.075,0.52),mats["steel"])
		sterile_tray.set_meta("clinic_treatment_surface",true)
		var tray_contents := Node3D.new()
		tray_contents.name="SterileTrayContents"
		sterile_tray.add_child(tray_contents)
		box(tray_contents,"SterileTrayDivider",Vector3(0,0.055,0),Vector3(0.025,0.035,0.43),mats["darkmetal"])
		box(tray_contents,"InstrumentSterileWrap",Vector3(-0.23,0.075,0.12),Vector3(0.29,0.035,0.18),mats["clinic"])
		for instrument_index in range(2):
			var instrument_x: float=0.13+float(instrument_index)*0.20
			var instrument_jitter: float=side*(0.02 if instrument_index==0 else -0.015)
			var instrument := cylinder(tray_contents,"SterileInstrument_%d" % instrument_index,Vector3(instrument_x+instrument_jitter,0.088,-0.10+instrument_jitter*1.5),0.022,0.25,mats["steel"])
			instrument.rotation.z=PI*0.5
			instrument.rotation.y=instrument_jitter*2.5
		for edge in [-1.0,1.0]:
			box(tray_contents,"TrayRetentionLip",Vector3(0,0.055,edge*0.23),Vector3(0.91,0.045,0.035),mats["darkmetal"])
		var mirror: float=side
		_surface_wear_mark(tray_contents,"TrayDisinfectantWipe_1",Vector3(-0.29*mirror,0.040,-0.19),Vector3(0.18,0.002,0.012),cleaning_streak,0.11*mirror)
		_surface_wear_mark(tray_contents,"TrayDisinfectantWipe_2",Vector3(0.27*mirror,0.040,0.20),Vector3(0.13,0.002,0.010),cleaning_streak,-0.16*mirror)
		_surface_wear_mark(tray_contents,"TrayEdgeBurnish",Vector3(-0.405*mirror,0.040,0.16),Vector3(0.055,0.002,0.018),tray_edge_scuff,0.08*mirror)
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
	var bench_burnished_steel := _surface_wear_material(Color("#858981"),0.28)
	var bench_oil_shadow := _surface_wear_material(Color("#514c41"),0.04)
	box(parent,"IndustrialWorkZone",Vector3(0,0.323,hz*0.18),Vector3(1.18,0.012,size.y*0.52),mats["foundation"])
	var air_header := cylinder(parent,"WorkshopCompressedAirHeader",Vector3(0,2.40,hz*0.72),0.075,size.x*0.74,mats["pipe"])
	air_header.rotation.z=PI*0.5
	air_header.set_meta("workshop_compressed_air_header",true)
	for side in [-1.0,1.0]:
		var x: float=side*hx*0.60
		var air_drop := cylinder(parent,"WorkshopCompressedAirDrop",Vector3(x,1.95,hz*0.54),0.043,0.82,mats["steel"])
		air_drop.rotation.x=PI*0.5
		air_drop.set_meta("workshop_compressed_air_drop",true)
		var regulator := box(parent,"WorkshopAirRegulator",Vector3(x+side*0.86,1.52,hz*0.43),Vector3(0.26,0.31,0.17),mats["darkmetal"])
		regulator.set_meta("workshop_air_regulator",true)
		var gauge := cylinder(parent,"WorkshopAirGauge",Vector3(x+side*0.86,1.59,hz*0.405),0.095,0.045,mats["rooflight"])
		gauge.set_meta("workshop_air_gauge",true)
		var bench := Node3D.new()
		bench.name="FabricationFrame"
		bench.position=Vector3(x,0,hz*0.43)
		bench.set_meta("workshop_fabrication_workstation",true)
		parent.add_child(bench)
		var surface := box(bench,"FabricationWorkSurface",Vector3(0,1.08,0),Vector3(1.45,0.14,1.06),mats["steel"])
		surface.set_meta("workshop_fabrication_surface",true)
		for post_x in [-0.63,0.63]:
			for post_z in [-0.43,0.43]:
				box(bench,"FabricationBenchLeg",Vector3(post_x,0.69,post_z),Vector3(0.10,0.70,0.10),mats["darkmetal"])
		for side_z in [-0.43,0.43]:
			box(bench,"FabricationBenchLowerRail",Vector3(0,0.47,side_z),Vector3(1.20,0.09,0.09),mats["darkmetal"])
		var vise := Node3D.new()
		vise.name="BenchVise"
		vise.position=Vector3(-0.40,1.17,0.06)
		vise.set_meta("workshop_bench_vise",true)
		bench.add_child(vise)
		box(vise,"ViseBase",Vector3(0,0,0),Vector3(0.38,0.08,0.36),mats["darkmetal"])
		box(vise,"ViseFixedJaw",Vector3(0,0.09,-0.11),Vector3(0.38,0.11,0.08),mats["steel"])
		box(vise,"ViseMovingJaw",Vector3(0,0.09,0.12),Vector3(0.38,0.11,0.08),mats["steel"])
		box(vise,"ViseWorkpiece",Vector3(0,0.20,0.015),Vector3(0.24,0.10,0.16),mats["rust"])
		var vise_handle := cylinder(vise,"ViseHandle",Vector3(0,0.03,0.26),0.025,0.30,mats["rooflight"])
		vise_handle.rotation.z=PI*0.5
		var tool_tray := box(bench,"BenchToolTray",Vector3(0.39,1.18,-0.04),Vector3(0.40,0.045,0.50),mats["darkmetal"])
		tool_tray.set_meta("workshop_bench_tool_tray",true)
		for tool_index in range(3):
			var tool_x := 0.25+float(tool_index)*0.13
			var hand_tool := cylinder(bench,"BenchHandTool_%d" % tool_index,Vector3(tool_x,1.225,-0.10+(float(tool_index)-1.0)*0.03),0.018,0.33,mats["rooflight"] if tool_index==0 else mats["steel"])
			hand_tool.rotation.x=PI*0.5
			hand_tool.rotation.z=(float(tool_index)-1.0)*0.07
		var oil_shadow := MeshInstance3D.new()
		oil_shadow.name="BenchOilPatina"
		var oil_shadow_mesh := SphereMesh.new()
		oil_shadow_mesh.radius=0.5
		oil_shadow_mesh.height=0.08
		oil_shadow.mesh=oil_shadow_mesh
		oil_shadow.position=Vector3(0.10,1.156,0.36)
		oil_shadow.scale=Vector3(0.23,0.10,0.14)
		oil_shadow.material_override=bench_oil_shadow
		oil_shadow.set_meta("furniture_surface_wear",true)
		oil_shadow.set_meta("workshop_surface_wear",true)
		bench.add_child(oil_shadow)
		_surface_wear_mark(bench,"BenchGrindingScuff_1",Vector3(-0.18,1.1525,0.34),Vector3(0.26,0.003,0.012),bench_burnished_steel,0.19*side).set_meta("workshop_surface_wear",true)
		_surface_wear_mark(bench,"BenchGrindingScuff_2",Vector3(-0.42,1.1525,-0.32),Vector3(0.10,0.003,0.014),bench_burnished_steel,-0.24*side).set_meta("workshop_surface_wear",true)
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
