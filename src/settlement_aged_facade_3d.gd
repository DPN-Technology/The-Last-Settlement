class_name SettlementAgedFacade3D
extends RefCounted

# DPN Last Haven actual 3D building-detail assembly.
# Layered damaged facades are attached to real walls, not screen overlays.
# This module does not move gameplay doors, colliders, or interior furniture.

static func box(parent: Node3D, label: String, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name=label+"_"+str(parent.get_child_count())
	var mesh := BoxMesh.new()
	mesh.size=size
	node.mesh=mesh
	node.position=at
	node.material_override=mat
	parent.add_child(node)
	return node

static func _tri(parent: Node3D, label: String, verts: PackedVector3Array, mat: Material) -> void:
	var mesh := ArrayMesh.new()
	var arr: Array=[]
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX]=verts
	var normals := PackedVector3Array()
	for i in range(0,verts.size(),3):
		var normal: Vector3=(verts[i+1]-verts[i]).cross(verts[i+2]-verts[i]).normalized()
		for j in range(3):
			normals.append(normal)
	arr[Mesh.ARRAY_NORMAL]=normals
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
	var obj := MeshInstance3D.new()
	obj.name=label+"_"+str(parent.get_child_count())
	obj.mesh=mesh
	obj.material_override=mat
	parent.add_child(obj)

static func _chipped_panel(parent: Node3D, center: Vector3, right: Vector3, up: Vector3, width: float, tall: float, mat: Material, rng: RandomNumberGenerator) -> void:
	# Irregular broken-mortar triangle fans, mounted 3mm proud of the wall.
	# Both face directions are physically double-sided where supported.
	var normal := right.cross(up).normalized()
	var c := center+normal*0.008
	var points := PackedVector3Array()
	for n in range(5):
		var alpha: float=float(n)/4.0*TAU
		points.append(c+right*cos(alpha)*width*rng.randf_range(0.55,1.03)+up*sin(alpha)*tall*rng.randf_range(0.65,1.12))
	var verts := PackedVector3Array()
	for i in range(4):
		verts.append(c)
		verts.append(points[i])
		verts.append(points[i+1])
	_tri(parent,"ChippedAggregatePlaster",verts,mat)

static func _weather_strip(parent: Node3D, length: float, h: float, at: Vector3, horizontal: bool, inner: bool, mats: Dictionary, seed: int, side_name: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed=seed
	var right := Vector3.RIGHT if horizontal else Vector3.FORWARD
	var up := Vector3.UP
	var root := Node3D.new()
	root.name=side_name
	parent.add_child(root)
	var outer: Vector3=Vector3.FORWARD if horizontal else Vector3.RIGHT
	if inner:
		outer=-outer
	var margin: float=0.32
	var available: float=maxf(0.2,length-2.0*margin)
	# The outer concrete surface is offset ~0.14m from building bounds.
	var face_center := at+outer*0.164
	var trims := maxi(4,int(round(length*0.57)))
	for i in range(trims):
		var coord: float=-length*0.5+margin+float(i)/(float(trims))*available
		var height: float=rng.randf_range(0.66,h-0.44)
		# Bottom grime and structural scars; never plaster across doorway.
		if horizontal and side_name=="FrontWallAging" and absf(coord)<1.38:
			continue
		var position: Vector3=face_center+right*coord+up*height
		var material: Material=mats["foundation"] if i%3==0 else (mats["rust"] if i%3==1 else mats["steel"])
		_chipped_panel(root,position,right,up,rng.randf_range(0.28,0.72),rng.randf_range(0.08,0.24),material,rng)
		if i%2==0:
			var scar := box(root,"CrumblingJoint",position-up*rng.randf_range(0.13,0.27),
				Vector3(rng.randf_range(0.23,0.49),rng.randf_range(0.02,0.06),0.035) if horizontal
				else Vector3(0.035,rng.randf_range(0.02,0.06),rng.randf_range(0.23,0.49)),mats["foundation"])
			scar.rotation.y=rng.randf_range(-0.06,0.06)
	# Repair seams are fitted close to the exterior surface, with 3D bolts.
	for i in range(3):
		var coord: float=-length*0.35+float(i)*length*0.35
		var y: float=0.74+float(i%2)*0.64
		if horizontal and side_name=="FrontWallAging" and absf(coord)<1.35:
			continue
		var pos := face_center+right*coord+up*y
		var patch_width: float=rng.randf_range(0.61,1.04)
		var patch_height: float=rng.randf_range(0.35,0.55)
		var patch := box(root,"CorrodedStructuralPlate",pos,
			Vector3(patch_width,patch_height,0.08) if horizontal else Vector3(0.08,patch_height,patch_width),
			mats["rust"] if i%2==0 else mats["steel"])
		patch.rotation.y=0.025 if horizontal else 0.0
		for dx in [-0.32,0.32]:
			for dy in [-0.15,0.15]:
				var bolt: Vector3 = pos+right*(float(dx)*patch_width)+up*(float(dy)*patch_height)+outer*0.058
				box(root,"AgedRivet",bolt,Vector3(0.055,0.053,0.05),mats["rooflight"])

static func _window_details(parent: Node3D, size: Vector2, h: float, mats: Dictionary) -> void:
	var hx: float=size.x*0.5
	var hz: float=size.y*0.5
	# Deep steel surround and cross-mullions convert blue rectangles into
	# recognizable window openings and cast real, small-scale shadows.
	for side in [-1.0,1.0]:
		for depth in [-0.38,0.32]:
			var z: float=hz*depth
			var x: float=side*(hx+0.25)
			var y: float=h*0.55
			for zedge in [-0.59,0.59]:
				box(parent,"WindowRevealUpright",Vector3(x,y,z+zedge),Vector3(0.13,1.11,0.11),mats["darkmetal"])
			for yedge in [-0.49,0.49]:
				box(parent,"WindowRevealHeadSill",Vector3(x,y+yedge,z),Vector3(0.13,0.09,1.29),mats["steel"])
			box(parent,"WindowMullion",Vector3(x+side*0.055,y,z),Vector3(0.10,0.99,0.055),mats["rooflight"])
			box(parent,"WindowSecurityLattice",Vector3(x+side*0.086,y,z),Vector3(0.07,0.055,1.15),mats["darkmetal"])
			box(parent,"WindowStoneSill",Vector3(x,y-0.61,z),Vector3(0.37,0.10,1.50),mats["concrete"])

static func _structural_repairs(parent: Node3D, size: Vector2, height: float, kind: String, mats: Dictionary) -> void:
	var hx: float=size.x*0.5
	var hz: float=size.y*0.5
	# Real ground-contact details; prevent facade boxes from looking like
	# unbroken rectangular toy bricks.
	for side in [-1.0,1.0]:
		for depth in [-0.74,0.72]:
			var z: float=hz*depth
			box(parent,"ExteriorVerticalButtress",Vector3(side*(hx+0.21),height*0.36,z),Vector3(0.38,height*0.73,0.33),mats["concrete"])
			box(parent,"StructuralFootingStone",Vector3(side*(hx+0.28),0.18,z),Vector3(0.78,0.27,0.83),mats["foundation"])
			if kind in ["industry","command","generator","medical"]:
				var bracing := box(parent,"DiagonalReinforcement",Vector3(side*(hx+0.24),height*0.53,z),Vector3(0.09,height*0.63,0.16),mats["rust"])
				bracing.rotation.x=side*0.28
	for side in [-1.0,1.0]:
		var x: float=side*(hx-0.65)
		box(parent,"RooflineTornPlaster",Vector3(x,height-0.07,hz+0.18),Vector3(1.05,0.13,0.17),mats["foundation"])
		box(parent,"RustDripGuide",Vector3(x,1.12,hz+0.18),Vector3(0.052,0.84,0.10),mats["rust"])

static func _outdoor_scrap(parent: Node3D, size: Vector2, mats: Dictionary) -> void:
	var hx: float=size.x*0.5
	var hz: float=size.y*0.5
	# Broken tiles/gravel around wall footing; not across the door path.
	var rng := RandomNumberGenerator.new()
	rng.seed=817224
	for i in range(15):
		var side: float=-1.0 if i%2==0 else 1.0
		var x: float=side*(hx+rng.randf_range(0.35,1.75))
		var z: float=rng.randf_range(-hz,hz)
		var scale: float=rng.randf_range(0.17,0.49)
		var shard := box(parent,"ExcavatedMasonryChunk",Vector3(x,0.07,z),Vector3(scale,0.15,scale*rng.randf_range(0.65,1.32)),mats["concrete"] if i%3==0 else mats["stone"])
		shard.rotation.y=rng.randf_range(-PI,PI)

static func decorate(group: Node3D, kind: String, size: Vector2, height: float, mats: Dictionary) -> void:
	if kind in ["wall","floor","door","pipe","power_pole","farm"]:
		return
	var shell := Node3D.new()
	shell.name="DamagedReferenceBuildingFacade"
	group.add_child(shell)
	var hx: float=size.x*0.5
	var hz: float=size.y*0.5
	_weather_strip(shell,size.x,height,Vector3(0,0,hz),true,false,mats,178611,"RearWallAging")
	_weather_strip(shell,size.x,height,Vector3(0,0,-hz),true,true,mats,178612,"FrontWallAging")
	_weather_strip(shell,size.y,height,Vector3(hx,0,0),false,false,mats,178613,"RightWallAging")
	_weather_strip(shell,size.y,height,Vector3(-hx,0,0),false,true,mats,178614,"LeftWallAging")
	_window_details(shell,size,height,mats)
	_structural_repairs(shell,size,height,kind,mats)
	_outdoor_scrap(shell,size,mats)
