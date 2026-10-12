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

static func _cylinder_between(parent: Node3D, name: String, from_point: Vector3, to_point: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var axis := to_point-from_point
	var length := axis.length()
	var mesh := CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.height=length
	mesh.radial_segments=6
	var node := MeshInstance3D.new()
	node.name=name+"_"+str(parent.get_child_count())
	node.mesh=mesh
	node.material_override=material
	var direction := axis/length
	var x_axis := Vector3.UP.cross(direction)
	if x_axis.length_squared()<0.0001:
		x_axis=Vector3.RIGHT.cross(direction)
	x_axis=x_axis.normalized()
	var z_axis := x_axis.cross(direction).normalized()
	node.transform=Transform3D(Basis(x_axis,direction,z_axis),(from_point+to_point)*0.5)
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
	# Reuse one seeded noise object for all instanced foliage and rock heights.
	# Creating 1,745 noise instances would unnecessarily stall the startup.
	var height_noise := FastNoiseLite.new()
	height_noise.seed=114722
	height_noise.noise_type=FastNoiseLite.TYPE_SIMPLEX
	height_noise.frequency=0.015
	height_noise.fractal_octaves=4
	var cluster_count: int=maxi(12,int(sqrt(float(count))))
	var cluster_centers: Array[Vector2]=[]
	for cluster_index in range(cluster_count):
		var center := Vector2(rng.randf_range(-91.0,91.0),rng.randf_range(-77.0,77.0))
		if absf(center.x)<39.0 and absf(center.y)<34.0:
			if band==0:
				center.x=(1.0 if center.x>=0.0 else -1.0)*rng.randf_range(43.0,88.0)
			else:
				center.y=(1.0 if center.y>=0.0 else -1.0)*rng.randf_range(38.0,76.0)
		cluster_centers.append(center)
	var spread: float=4.8 if band==0 else 7.0
	for i in range(count):
		var center: Vector2=cluster_centers[rng.randi_range(0,cluster_centers.size()-1)]
		var x: float=clampf(rng.randfn(center.x,spread),-104.0,104.0)
		var z: float=clampf(rng.randfn(center.y,spread),-92.0,92.0)
		if absf(x)<39.0 and absf(z)<34.0:
			if band==0:
				x=(1.0 if x>=0.0 else -1.0)*rng.randf_range(41.0,91.0)
			else:
				z=(1.0 if z>=0.0 else -1.0)*rng.randf_range(36.0,80.0)
		var sx: float=rng.randf_range(0.35,1.70)
		var sz: float=rng.randf_range(0.36,1.55)
		var sy: float=rng.randf_range(0.48,1.22)
		var y: float=WastelandDetail.terrain_height(x,z,height_noise)
		var scale := Vector3(sx,sy,sz)
		var basis := WastelandDetail.terrain_basis(x,z,height_noise,rng.randf_range(0.0,TAU),scale)
		var ground_offset: float=mesh.get_aabb().size.y*sy*0.35
		instances.set_instance_transform(i,Transform3D(basis,Vector3(x,y+ground_offset,z)))

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
	_box(post,"PoleBasePlate",Vector3(0,0.06,0),Vector3(0.46,0.12,0.46),mat["darkmetal"])
	_box(post,"PowerMastExtension",Vector3(0,5.64,0),Vector3(0.085,3.08,0.085),mat["steel"])
	_box(post,"MastSleeveCollar",Vector3(0,4.24,0),Vector3(0.21,0.16,0.21),mat["darkmetal"])
	_box(post,"ServiceCableCrossarm",Vector3(0,7.20,0),Vector3(0.86,0.12,0.15),mat["rust"])
	for conductor_side in [-1.0,1.0]:
		_cylinder(post,"PorcelainLineInsulator",Vector3(conductor_side*0.16,7.33,0),0.075,0.18,mat["glass"])
	for side in [-1.0,1.0]:
		var gusset := _box(post,"PoleMountingGusset",Vector3(side*0.20,3.82,0),Vector3(0.09,0.74,0.09),mat["steel"])
		gusset.rotation.z=-side*0.48
	_box(post,"PoleFeedConduit",Vector3(-0.10,2.10,0.09),Vector3(0.055,3.24,0.055),mat["darkmetal"])
	_box(post,"PoleJunctionBox",Vector3(-0.10,1.00,0.10),Vector3(0.34,0.42,0.22),mat["rust"])
	for side in [-1.0,1.0]:
		_box(post,"JunctionCoverRib",Vector3(-0.10+side*0.08,1.00,0.22),Vector3(0.035,0.30,0.025),mat["steel"])
	_box(post,"Stanchion",Vector3(0,2.05,0),Vector3(0.14,4.10,0.13),mat["rust"])
	_box(post,"BentLightArm",Vector3(0.46,4.03,0),Vector3(0.93,0.11,0.12),mat["steel"])
	var arm_brace := _box(post,"LampArmBrace",Vector3(0.25,3.80,0),Vector3(0.09,0.73,0.09),mat["steel"])
	arm_brace.rotation.z=-0.72
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

static func _power_run_mesh(parent: Node3D, pole_positions: Array[Vector3], material: Material) -> MultiMeshInstance3D:
	var spans: int=pole_positions.size()-1
	var conductors_per_span := 2
	var segments_per_conductor := 8
	var wire := CylinderMesh.new()
	wire.top_radius=0.022
	wire.bottom_radius=0.022
	wire.height=1.0
	wire.radial_segments=6
	var multimesh := MultiMesh.new()
	multimesh.transform_format=MultiMesh.TRANSFORM_3D
	multimesh.mesh=wire
	multimesh.instance_count=spans*conductors_per_span*segments_per_conductor
	var run := MultiMeshInstance3D.new()
	run.name="OverheadInsulatedPowerRuns"
	run.multimesh=multimesh
	run.material_override=material
	run.set_meta("span_count",spans)
	run.set_meta("conductors_per_span",conductors_per_span)
	run.set_meta("segments_per_conductor",segments_per_conductor)
	parent.add_child(run)
	var instance_index := 0
	for span_index in range(spans):
		var from_pole: Vector3=pole_positions[span_index]
		var to_pole: Vector3=pole_positions[span_index+1]
		for conductor_side in [-1.0,1.0]:
			var offset := Vector3(conductor_side*0.16,7.42,0)
			var from_point := from_pole+offset
			var to_point := to_pole+offset
			for segment_index in range(segments_per_conductor):
				var t0 := float(segment_index)/float(segments_per_conductor)
				var t1 := float(segment_index+1)/float(segments_per_conductor)
				var start := _sagging_wire_point(from_point,to_point,t0)
				var finish := _sagging_wire_point(from_point,to_point,t1)
				var direction := (finish-start).normalized()
				var x_axis := Vector3.UP.cross(direction)
				if x_axis.length_squared()<0.0001:
					x_axis=Vector3.RIGHT.cross(direction)
				x_axis=x_axis.normalized()
				var z_axis := x_axis.cross(direction).normalized()
				var basis := Basis(x_axis,direction,z_axis)
				basis=basis.scaled(Vector3(1.0,finish.distance_to(start),1.0))
				multimesh.set_instance_transform(instance_index,Transform3D(basis,(start+finish)*0.5))
				instance_index+=1
	return run

static func _sagging_wire_point(from_point: Vector3, to_point: Vector3, t: float) -> Vector3:
	var point := from_point.lerp(to_point,t)
	point.y-=sin(t*PI)*0.72
	return point

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
		_cylinder(site,"DrumOfSupplies",Vector3(side*2.03,0.62,0.72),0.36,1.22,mats["blue"])
	for side in [-1.0,1.0]:
		_cylinder_between(site,"CanvasEaveRail",Vector3(side*2.55,3.08,-1.75),Vector3(side*2.55,2.68,1.72),0.055,mats["wood"])
	_cylinder_between(site,"RearCanopyHeader",Vector3(-2.55,3.08,-1.75),Vector3(2.55,3.08,-1.75),0.055,mats["wood"])
	_cylinder_between(site,"FrontCanopyHeader",Vector3(-2.55,2.68,1.72),Vector3(2.55,2.68,1.72),0.055,mats["wood"])
	var tarp_tool := SurfaceTool.new()
	tarp_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tarp_columns := 12
	var tarp_rows := 16
	var wear_variant: float=1.0 if pos.x>0.0 else 0.0
	for row in range(tarp_rows):
		var tz0 := float(row)/float(tarp_rows)
		var tz1 := float(row+1)/float(tarp_rows)
		for column in range(tarp_columns):
			var tx0 := float(column)/float(tarp_columns)
			var tx1 := float(column+1)/float(tarp_columns)
			var p00 := _canopy_point(tx0,tz0,wear_variant)
			var p01 := _canopy_point(tx0,tz1,wear_variant)
			var p10 := _canopy_point(tx1,tz0,wear_variant)
			var p11 := _canopy_point(tx1,tz1,wear_variant)
			for point in [p00,p01,p10,p10,p01,p11]:
				tarp_tool.set_uv(Vector2(point.x/5.25+0.5,(point.z+2.25)/4.5))
				tarp_tool.set_color(_canopy_color(point,wear_variant))
				tarp_tool.add_vertex(point)
	tarp_tool.index()
	tarp_tool.generate_normals()
	var tarp := MeshInstance3D.new()
	tarp.name="SaggingPatchedCanvasCanopy"
	tarp.mesh=tarp_tool.commit()
	var tarp_material := (mats["cloth"] as StandardMaterial3D).duplicate() as StandardMaterial3D
	tarp_material.cull_mode=BaseMaterial3D.CULL_DISABLED
	tarp_material.vertex_color_use_as_albedo=true
	tarp_material.uv1_triplanar=false
	tarp_material.uv1_scale=Vector3(7.0,6.0,1.0)
	tarp.material_override=tarp_material
	site.add_child(tarp)
	_box(site,"RainwaterCollectionGutter",Vector3(0,2.64,1.77),Vector3(5.08,0.09,0.12),mats["darkmetal"])
	for bracket_index in range(5):
		var bracket_x := -2.2+float(bracket_index)*1.1
		_box(site,"GutterMountingStrap",Vector3(bracket_x,2.57,1.75),Vector3(0.055,0.14,0.16),mats["steel"])
	_cylinder_between(site,"RainwaterDownspout",Vector3(0,2.60,1.77),Vector3(0,1.03,1.77),0.045,mats["darkmetal"])
	var catchment_ground_y: float=WastelandDetail.terrain_height(site.position.x,site.position.z+2.42)-site.position.y
	_box(site,"RainBarrelReclaimedPallet",Vector3(0,catchment_ground_y+0.08,2.42),Vector3(0.98,0.16,0.92),mats["wood"])
	_cylinder(site,"RainCatchmentBarrel",Vector3(0,catchment_ground_y+0.68,2.42),0.39,1.20,mats["blue"])
	for band_y in [0.25,0.62,0.99]:
		_cylinder(site,"RainBarrelReinforcingBand",Vector3(0,catchment_ground_y+band_y,2.42),0.405,0.055,mats["darkmetal"])
	_cylinder_between(site,"BarrelFillElbow",Vector3(0,1.03,1.77),Vector3(0,catchment_ground_y+1.12,2.08),0.04,mats["steel"])
	_box(site,"RainBarrelInspectionPlate",Vector3(0,catchment_ground_y+0.72,2.82),Vector3(0.30,0.24,0.045),mats["rust"])
	for side in [-1.0,1.0]:
		for end in [-1.0,1.0]:
			var stake_x := side*3.14
			var stake_z := end*2.37
			var stake_y: float=WastelandDetail.terrain_height(site.position.x+stake_x,site.position.z+stake_z)-site.position.y
			var stake := _cylinder(site,"CanvasGuylineGroundStake",Vector3(stake_x,stake_y+0.15,stake_z),0.065,0.30,mats["darkmetal"])
			stake.rotation.z=side*0.12
			var top := Vector3(side*2.46,2.62 if end>0.0 else 2.96,end*1.61)
			var anchor := Vector3(stake_x,stake_y+0.25,stake_z)
			_cylinder_between(site,"TautCanvasGuyline",top,anchor,0.018,mats["darkmetal"])
	for index in range(4):
		_box(site,"StackedRecoveryCrate",Vector3(-1.35+float(index)*0.92,0.46,1.12),Vector3(0.78,0.78,0.77),mats["rust"] if index%2==0 else mats["steel"])
	_box(site,"ServiceBench",Vector3(0,0.93,-1.2),Vector3(2.30,0.15,0.84),mats["wood"])
	_camp_light(site,Vector3(1.95,0,-1.4),mats)

static func _canopy_point(tx: float, tz: float, wear_variant: float) -> Vector3:
	var x := (tx-0.5)*5.25
	var z := (tz-0.5)*4.5
	var y := lerpf(3.12,2.72,tz)
	y-=absf(tx-0.5)*0.24
	y-=sin(tz*PI)*lerpf(0.035,0.065,wear_variant)
	y+=sin(tx*3.0*PI+tz*2.0*PI)*lerpf(0.014,0.024,wear_variant)
	return Vector3(x,y,z)

static func _canopy_color(point: Vector3, wear_variant: float) -> Color:
	var tx := point.x/5.25+0.5
	var tz := (point.z+2.25)/4.5
	var patch_side: bool=(tx>0.61 and tx<0.80) if wear_variant<0.5 else (tx>0.20 and tx<0.39)
	if patch_side and tz>0.40 and tz<0.72:
		return Color("#746b52")
	var patch_end: bool=(tx>0.17 and tx<0.35) if wear_variant<0.5 else (tx>0.65 and tx<0.83)
	if patch_end and tz>0.70 and tz<0.88:
		return Color("#8f8162")
	return Color("#ad9c78")

static func build_world(parent: Node3D, mats: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name="ReferenceQualityWorldDressing"
	parent.add_child(root)
	_natural_scrub(root,mats)
	# Planked sections through the main camp, matching the reference's
	# broken timber paths and retaining all existing walkable corridors.
	_timber_walkway(root,Vector3(-24,0,8),Vector3(-12,0,8),mats["wood"],1231)
	_timber_walkway(root,Vector3(-8,0,14),Vector3(10,0,14),mats["wood"],1232)
	_timber_walkway(root,Vector3(8,0,-9),Vector3(22,0,-9),mats["wood"],1233)
	_timber_walkway(root,Vector3(-4,0,19),Vector3(-4,0,27),mats["wood"],1234)
	_timber_walkway(root,Vector3(28,0,13),Vector3(39,0,13),mats["wood"],1235)
	var lamp_positions: Array[Vector3]=[
		Vector3(-30.0,0,-14.0),Vector3(-20.0,0,12.0),
		Vector3(-2.0,0,22.0),Vector3(16.0,0,-17.0),
		Vector3(26.0,0,16.0),Vector3(48.0,0,-15.0),
		Vector3(56.0,0,18.0)
	]
	var grounded_lamp_positions: Array[Vector3]=[]
	for light_pos in lamp_positions:
		var grounded_light_pos: Vector3=light_pos
		grounded_light_pos.y=_terrain_height(grounded_light_pos.x,grounded_light_pos.z)
		_camp_light(root,grounded_light_pos,mats)
		grounded_lamp_positions.append(grounded_light_pos)
	_power_run_mesh(root,grounded_lamp_positions,mats["darkmetal"])
	_salvage_camp(root,Vector3(-50,0,-25),mats)
	_salvage_camp(root,Vector3(66,0,-34),mats)
	return root

static func _service_prop(parent: Node3D, mats: Dictionary, size: Vector2, kind: String) -> void:
	var hx: float=size.x*0.5
	var hz: float=size.y*0.5
	for side in [-1.0,1.0]:
		# Physical, imperfect salvage storage right beside the rear facade.
		var x: float=side*(hx+1.20)
		_box(parent,"DeliveryPallet",Vector3(x,0.18,hz*0.46),Vector3(1.53,0.22,1.00),mats["wood"])
		for i in range(2):
			_box(parent,"SideCargo",Vector3(x,0.58+float(i)*0.48,hz*0.46),Vector3(1.09,0.43,0.65),mats["rust"] if i%2==0 else mats["rooflight"])
		_cylinder(parent,"SalvageWaterBarrel",Vector3(x,0.56,-hz*0.22),0.34,1.09,mats["blue"])
	if kind in ["command","industry","generator","power","storage"]:
		var conduit := _box(parent,"OverheadConduitRack",Vector3(0,2.80,hz+0.20),Vector3(size.x*0.59,0.22,0.20),mats["steel"])
		conduit.rotation.z=0.01

static func _industrial_roof_detail(parent: Node3D, size: Vector2, mats: Dictionary, kind: String) -> void:
	# Compact silhouette detail. The core building owns the roof/cutaway; these
	# additions remain under its roofline and do not affect selection or routes.
	var hx: float = size.x * 0.5
	var hz: float = size.y * 0.5
	if kind in ["industry", "generator", "power", "workshop"]:
		for i in range(3):
			var x: float = (float(i) - 1.0) * minf(1.55, hx * 0.40)
			_box(parent, "RoofVentHousing", Vector3(x, 4.22, hz * 0.16), Vector3(0.77, 0.37, 0.86), mats["darkmetal"])
			_box(parent, "VentLouver", Vector3(x, 4.22, hz * 0.16 + 0.44), Vector3(0.65, 0.21, 0.04), mats["steel"])
		var stack := _cylinder(parent, "ExhaustStack", Vector3(hx * 0.63, 4.84, hz * 0.47), 0.24, 1.7, mats["rust"])
		_box(parent, "StackRainCap", stack.position + Vector3(0, 0.89, 0), Vector3(0.70, 0.10, 0.70), mats["darkmetal"])
	elif kind in ["medical", "clinic"]:
		_box(parent, "RoofAirHandling", Vector3(hx * 0.38, 4.13, hz * 0.17), Vector3(1.18, 0.49, 0.91), mats["clinic"])
		_box(parent, "IntakeSlats", Vector3(hx * 0.38, 4.15, hz * 0.17 + 0.48), Vector3(0.97, 0.28, 0.055), mats["darkmetal"])
	elif kind in ["command", "security", "watchtower"]:
		_box(parent, "AntennaMast", Vector3(hx * 0.62, 4.94, hz * 0.39), Vector3(0.09, 2.11, 0.09), mats["steel"])
		_box(parent, "RadioCrossarm", Vector3(hx * 0.62, 5.53, hz * 0.39), Vector3(0.94, 0.07, 0.07), mats["steel"])
		_box(parent, "AmberWarningBeacon", Vector3(hx * 0.62, 6.05, hz * 0.39), Vector3(0.20, 0.20, 0.20), mats["warning"])


static func _facade_readability(parent: Node3D, size: Vector2, mats: Dictionary, kind: String) -> void:
	# Set-dressing in shallow layers instead of oversized flat panels; narrow
	# window recesses, covered entrance and rain drains break up box silhouettes.
	var hx: float = size.x * 0.5
	var hz: float = size.y * 0.5
	var window_count: int = clampi(int(floor((size.x - 3.1) / 2.4)), 0, 4)
	for i in range(window_count):
		var x: float = (float(i) - (float(window_count) - 1.0) * 0.5) * 2.4
		if absf(x) < 1.45:
			continue # Never obscure the existing physical door.
		_box(parent, "RecessedWindow", Vector3(x, 2.03, -hz - 0.13), Vector3(0.99, 0.75, 0.035), mats["glass"])
		_box(parent, "WindowHead", Vector3(x, 2.47, -hz - 0.17), Vector3(1.20, 0.09, 0.11), mats["steel"])
		_box(parent, "WindowSill", Vector3(x, 1.59, -hz - 0.17), Vector3(1.23, 0.11, 0.18), mats["rust"])
		for bar in [-0.29, 0.29]:
			_box(parent, "SafetyGrille", Vector3(x + bar, 2.03, -hz - 0.20), Vector3(0.035, 0.73, 0.035), mats["darkmetal"])
	for side in [-1.0, 1.0]:
		var drain_x: float = side * (hx - 0.20)
		_box(parent, "RainDownpipe", Vector3(drain_x, 1.65, -hz - 0.18), Vector3(0.12, 3.17, 0.14), mats["rust"])
	if kind in ["storage", "industry", "workshop"]:
		# Cargo shutter detail stays on the back facade away from the entry.
		for stripe in range(5):
			_box(parent, "ShutterRib", Vector3(0, 1.35 + float(stripe) * 0.34, hz + 0.18), Vector3(minf(2.65, size.x * 0.50), 0.065, 0.09), mats["steel"])


static func _lived_in_facility_detail(parent: Node3D, size: Vector2, mats: Dictionary, kind: String) -> void:
	# Dedicated exterior dressing: never blocks the central front entrance.
	# Deterministic variation keeps screenshots stable and saved games identical.
	var hx: float = size.x * 0.5
	var hz: float = size.y * 0.5
	if kind in ["wall", "floor", "door", "pipe", "power_pole", "farm"]:
		return
	# Reclaimed braces create actual depth and self-shadow instead of drawn stripes.
	for side in [-1.0, 1.0]:
		var x: float = side * (hx + 0.12)
		var brace := _box(parent, "PatchworkSideBrace", Vector3(x, 1.61, 0), Vector3(0.18, 3.03, 0.15), mats["wood"])
		brace.rotation.x = side * 0.14
		_box(parent, "CornerReinforcement", Vector3(x, 2.95, -hz + 0.34), Vector3(0.27, 0.20, 0.71), mats["rust"])
	# Differentiated, human-scale signs give player-readable building identity.
	var identity_color: Material = mats["steel"]
	if kind in ["medical", "clinic"]:
		identity_color = mats["clinic"]
	elif kind in ["generator", "power", "industry"]:
		identity_color = mats["warning"]
	elif kind in ["command", "security", "watchtower"]:
		identity_color = mats["blue"]
	_box(parent, "FacilityMarkerPlate", Vector3(0, 3.18, -hz - 0.25), Vector3(1.42, 0.32, 0.13), identity_color)
	_box(parent, "FacilityMarkerBacking", Vector3(0, 3.18, -hz - 0.18), Vector3(1.65, 0.45, 0.12), mats["darkmetal"])
	# Compact everyday objects near the rear service yard, not on pedestrian paths.
	if kind in ["storage", "command", "industry", "workshop", "generator", "power"]:
		for index in range(3):
			var offset: float = float(index) * 0.47
			_box(parent, "ScrapLumberStack", Vector3(-hx * 0.48, 0.18 + offset * 0.22, hz + 0.68), Vector3(1.35, 0.12, 0.24), mats["wood"])
		_cylinder(parent, "ServiceCanister", Vector3(hx * 0.53, 0.43, hz + 0.66), 0.21, 0.76, mats["rust"])
	elif kind in ["medical", "clinic"]:
		_box(parent, "MedicalSupplyCase", Vector3(hx * 0.50, 0.38, hz + 0.63), Vector3(0.91, 0.61, 0.51), mats["clinic"])
		_box(parent, "MedicalCaseLatch", Vector3(hx * 0.50, 0.44, hz + 0.90), Vector3(0.18, 0.12, 0.055), mats["steel"])


static func _reclaimed_roof_patchwork(parent: Node3D, size: Vector2, mats: Dictionary, kind: String, body_height: float) -> void:
	# Low profile overlapping sheet-metal repairs follow the roof instead of
	# covering doors, interaction targets or the camera-facing building facade.
	if kind in ["wall", "floor", "door", "pipe", "power_pole", "farm", "housing"]:
		return # Pitched housing roofs require slope-matched panels, not flat patches.
	var roof_y: float = body_height + 0.47
	var width: float = minf(size.x * 0.23, 2.0)
	var depth: float = minf(size.y * 0.26, 1.8)
	if width < 0.48 or depth < 0.48:
		return
	for index in range(4):
		var col: int = index % 2
		var row: int = int(index / 2)
		var x: float = (float(col) - 0.5) * size.x * 0.42
		var z: float = (float(row) - 0.5) * size.y * 0.40
		var patch := _box(parent, "OverlappedReclaimedRoofSheet", Vector3(x, roof_y + float(index) * 0.007, z), Vector3(width, 0.035, depth), mats["rooflight"] if index % 3 == 0 else mats["rust"])
		patch.rotation.y = (float(index) - 1.5) * 0.035
		for rib in range(3):
			_box(parent, "SheetMetalRaisedSeam", Vector3(x + (float(rib) - 1.0) * width * 0.28, roof_y + 0.035 + float(index) * 0.007, z), Vector3(0.035, 0.027, depth * 0.90), mats["steel"])
	# Bracing on high walls creates visible layered silhouette from the
	# playable elevated camera without replacing gameplay geometry.
	for side in [-1.0, 1.0]:
		_box(parent, "RoofEdgeFlashing", Vector3(side * (size.x * 0.5 - 0.12), body_height + 0.40, 0), Vector3(0.18, 0.13, size.y * 0.82), mats["darkmetal"])


static func _exterior_weathering(parent: Node3D, size: Vector2, mats: Dictionary, kind: String) -> void:
	# Mesh-based surface wear remains deterministic and purely decorative.
	# Broken plaster and patched cladding are kept shallow on rear/side walls.
	if kind in ["wall", "floor", "door", "pipe", "power_pole", "farm"]:
		return
	var hx: float = size.x * 0.5
	var hz: float = size.y * 0.5
	for side in [-1.0, 1.0]:
		for index in range(3):
			var z: float = (float(index) - 1.0) * size.y * 0.21
			var y: float = 1.12 + float((index + 1) % 3) * 0.76
			var width: float = minf(size.y * 0.14, 0.85)
			_box(parent, "BoltedSideRepairPlate", Vector3(side * (hx + 0.14), y, z), Vector3(0.055, 0.49, width), mats["rust"] if index != 1 else mats["rooflight"])
			for z_sign in [-1.0, 1.0]:
				_box(parent, "PlateRivet", Vector3(side * (hx + 0.185), y, z + z_sign * width * 0.38), Vector3(0.025, 0.07, 0.07), mats["steel"])
	# Rear cladding avoids the front entrance and view facing the player.
	for i in range(4):
		var x: float = (float(i) - 1.5) * size.x * 0.18
		_box(parent, "ReclaimedRearSiding", Vector3(x, 2.30, hz + 0.17), Vector3(minf(0.66, size.x * 0.16), 1.14 + float(i % 2) * 0.20, 0.055), mats["wood"] if i % 3 == 0 else mats["rooflight"])


static func detail_facility(group: Node3D, kind: String, size: Vector2, mats: Dictionary, body_height: float) -> void:
	# New visual props remain distinct from the core gameplay shell so roofs,
	# doors, selection and simulation remain unchanged.
	if kind in ["wall","floor","door","pipe","power_pole","farm"]:
		return
	var scene := Node3D.new()
	scene.name="ReferenceExteriorDetail"
	group.add_child(scene)
	_service_prop(scene,mats,size,kind)
	_facade_readability(scene,size,mats,kind)
	_industrial_roof_detail(scene,size,mats,kind)
	_lived_in_facility_detail(scene,size,mats,kind)
	_reclaimed_roof_patchwork(scene,size,mats,kind,body_height)
	_exterior_weathering(scene,size,mats,kind)
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
