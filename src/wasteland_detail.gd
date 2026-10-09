class_name WastelandDetail
extends RefCounted

# Transitional authored-by-code 3D detail. Replace with optimized glTF models
# as assets arrive; all pieces live under the visual scene, not the save model.
static func box(parent: Node3D, center: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var obj := MeshInstance3D.new()
	obj.mesh = mesh
	obj.material_override = mat
	obj.position = center
	parent.add_child(obj)
	return obj

static func cylinder(parent: Node3D, center: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	var obj := MeshInstance3D.new()
	obj.mesh = mesh
	obj.material_override = mat
	obj.position = center
	parent.add_child(obj)
	return obj

static func terrain_height(x: float, z: float, noise: FastNoiseLite) -> float:
	# Flat playable core keeps saved building positions and ground click picking
	# accurate; rolling eroded terrain begins only outside the construction zone.
	var radius := maxf(absf(x), absf(z))
	var falloff := smoothstep(51.0, 111.0, radius)
	var waves := noise.get_noise_2d(x * 1.4, z * 1.4) * 7.2
	var rocky := noise.get_noise_2d(x * 5.5 + 311.0, z * 5.5) * 1.1
	return (waves + rocky + 0.4) * falloff

static func terrain_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var noise := FastNoiseLite.new()
	noise.seed = 114722
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.015
	noise.fractal_octaves = 4
	var side := 320.0
	var cells := 100
	var step := side / float(cells)
	for zi in range(cells):
		for xi in range(cells):
			var x0 := -side * 0.5 + float(xi) * step
			var x1 := x0 + step
			var z0 := -side * 0.5 + float(zi) * step
			var z1 := z0 + step
			var a := Vector3(x0, terrain_height(x0,z0,noise), z0)
			var b := Vector3(x1, terrain_height(x1,z0,noise), z0)
			var c := Vector3(x0, terrain_height(x0,z1,noise), z1)
			var d := Vector3(x1, terrain_height(x1,z1,noise), z1)
			# Winding is upward facing: b/c winding yields positive Y.
			for v in [a,c,b,b,c,d]:
				tool.set_uv(Vector2((v.x + 160.0)/8.0,(v.z + 160.0)/8.0))
				tool.add_vertex(v)
	tool.generate_normals()
	return tool.commit()

static func detail_building(group: Node3D, kind: String, size: Vector2, height: float, condition: float, mats: Dictionary) -> void:
	var x := size.x * 0.5
	var z := size.y * 0.5
	var y := height + 0.5
	var beam: Material = mats["steel"]
	var rust: Material = mats["rust"]
	var trim: Material = mats["rooflight"]
	# Roof parapet / rain gutters / painted metal edge: four separate members.
	box(group,Vector3(0,y+0.27,-z),Vector3(size.x+0.55,0.6,0.32),beam)
	box(group,Vector3(0,y+0.27,z),Vector3(size.x+0.55,0.6,0.32),beam)
	box(group,Vector3(-x,y+0.27,0),Vector3(0.32,0.6,size.y+0.55),beam)
	box(group,Vector3(x,y+0.27,0),Vector3(0.32,0.6,size.y+0.55),beam)
	# Reinforcement and service ladders establish a building height/scale.
	for dir in [-1.0,1.0]:
		for edge in [-1.0,1.0]:
			box(group,Vector3(dir*(x-0.3),height*0.5,edge*(z-0.25)),Vector3(0.26,height,0.28),trim)
	for index in range(3):
		var zx := -z*0.60 + float(index)*z*0.60
		box(group,Vector3(x+0.11,1.5,zx),Vector3(0.20,1.1,1.15),mats["glass"])
		box(group,Vector3(-x-0.11,1.5,zx),Vector3(0.20,1.1,1.15),mats["glass"])
	box(group,Vector3(-x+0.7,y+0.14,z*0.64),Vector3(0.95,0.20,0.95),rust)
	# Roof ducts and cooling-unit shrouds have physical openings.
	var equipment_z := -z*0.34
	box(group,Vector3(x*0.36,y+0.55,equipment_z),Vector3(2.4,1.0,1.55),mats["darkmetal"])
	box(group,Vector3(x*0.36,y+1.12,equipment_z),Vector3(2.1,0.14,1.38),trim)
	for index in range(3):
		box(group,Vector3(-x*0.45+float(index)*0.65,y+0.18,z*0.5),Vector3(0.28,0.18,1.65),rust)
	# Railings on the service side.
	for index in range(5):
		var px := -x+0.8+float(index)*(size.x-1.6)/4.0
		box(group,Vector3(px,y+0.7,z+0.38),Vector3(0.12,1.4,0.12),beam)
	box(group,Vector3(0,y+1.25,z+0.38),Vector3(size.x,0.12,0.12),beam)
	# Dry streaks and patched panels visibly respond to existing condition.
	if condition < 95.0:
		box(group,Vector3(-x*0.32,y+0.24,-z*0.4),Vector3(2.0,0.09,1.0),rust)
	if condition < 75.0:
		box(group,Vector3(x*0.28,y+0.25,z*0.12),Vector3(1.7,0.1,2.1),rust)
	# Facility-specific fixtures make functions recognizable from silhouettes.
	match kind:
		"housing":
			_housing(group,size,height,mats)
		"industry", "storage":
			_workshop(group,size,height,mats)
		"medical":
			_clinic(group,size,height,mats)
		"command":
			_command(group,size,height,mats)
		"power", "generator", "battery":
			_power(group,size,height,mats)
		"water", "water_pump", "purifier", "water_tank", "sewage":
			_fluid(group,size,height,mats)

static func _housing(group: Node3D, size: Vector2, height: float, mats: Dictionary) -> void:
	var x := size.x*0.5
	var z := size.y*0.5
	for sign in [-1.0,1.0]:
		var p: float = float(sign)*x*0.45
		var panel := box(group,Vector3(p,height+1.25,0),Vector3(2.8,0.13,3.0),mats["blue"])
		panel.rotation.z = sign*0.11
		box(group,Vector3(p,height+1.4,0),Vector3(0.09,0.19,3.0),mats["steel"])
	box(group,Vector3(0,0.16,-z-1.2),Vector3(2.8,0.26,2.5),mats["concrete"])
	for index in range(2):
		box(group,Vector3(-x*0.45+float(index)*1.5,height+1.15,z*0.4),Vector3(1.0,0.9,1.1),mats["darkmetal"])

static func _workshop(group: Node3D, size: Vector2, height: float, mats: Dictionary) -> void:
	var x := size.x*0.5
	var z := size.y*0.5
	cylinder(group,Vector3(x*0.62,height+2.25,-z*0.42),0.62,3.5,mats["rust"])
	cylinder(group,Vector3(x*0.62,height+4.2,-z*0.42),0.85,0.4,mats["steel"])
	for index in range(4):
		var px := -x*0.7+float(index)*2.0
		box(group,Vector3(px,1.7,-z-0.15),Vector3(0.25,2.0,0.25),mats["rust"])
		box(group,Vector3(px,2.5,-z-0.16),Vector3(1.35,0.12,0.2),mats["steel"])
	box(group,Vector3(0,0.55,-z-2.0),Vector3(5.1,1.0,2.8),mats["darkmetal"])

static func _clinic(group: Node3D, size: Vector2, height: float, mats: Dictionary) -> void:
	var z := size.y*0.5
	box(group,Vector3(0,3.1,-z-1.4),Vector3(5.6,0.32,3.7),mats["clinic"])
	for dir in [-1.0,1.0]:
		box(group,Vector3(dir*2.65,1.55,-z-2.1),Vector3(0.17,3.1,0.17),mats["steel"])
	box(group,Vector3(0,2.4,-z-0.31),Vector3(2.1,0.15,0.15),mats["cross"])
	box(group,Vector3(0,2.4,-z-0.33),Vector3(0.17,1.95,0.16),mats["cross"])

static func _command(group: Node3D, size: Vector2, height: float, mats: Dictionary) -> void:
	var x := size.x*0.5
	var z := size.y*0.5
	# Protected operations hut, elevated control deck, radio-support braces.
	box(group,Vector3(-x*0.42,height+1.0,0),Vector3(3.1,1.8,2.8),mats["concrete"])
	for sx in [-1.0,1.0]:
		for sz in [-1.0,1.0]:
			box(group,Vector3(sx*x*0.19,height+1.3,sz*z*0.36),Vector3(0.22,2.6,0.22),mats["steel"])
	box(group,Vector3(0,height+2.5,0),Vector3(x*0.6,0.2,z*0.7),mats["darkmetal"])

static func _power(group: Node3D, size: Vector2, height: float, mats: Dictionary) -> void:
	var x := size.x*0.5
	var z := size.y*0.5
	for index in range(4):
		var px := -x*0.73 + float(index)*(x*0.48)
		cylinder(group,Vector3(px,height+1.0,z*0.25),0.47,1.25,mats["steel"])
		box(group,Vector3(px,height+1.7,z*0.25),Vector3(0.6,0.2,0.6),mats["warning"])
	for sign in [-1.0,1.0]:
		box(group,Vector3(sign*x*0.58,1.5,-z-1.1),Vector3(0.55,1.2,2.0),mats["pipe"])

static func _fluid(group: Node3D, size: Vector2, height: float, mats: Dictionary) -> void:
	var x := size.x*0.5
	var z := size.y*0.5
	for sign in [-1.0,1.0]:
		cylinder(group,Vector3(sign*x*0.77,0.85,z*0.12),0.56,1.7,mats["pipe"])
		box(group,Vector3(sign*x*0.77,1.8,z*0.12),Vector3(0.95,0.16,0.95),mats["steel"])
	for i in range(3):
		var px := -x*0.64+float(i)*x*0.6
		box(group,Vector3(px,height+0.68,z*0.6),Vector3(0.25,0.33,1.5),mats["steel"])

static func detail_farm(group: Node3D, size: Vector2, mats: Dictionary) -> void:
	# Greenhouse cold frames, supported water pipe and actual rows of crop covers.
	var x := size.x * 0.5
	var z := size.y * 0.5
	for end in [-1.0,1.0]:
		box(group,Vector3(end*x*0.87,0.75,0),Vector3(0.18,1.5,size.y),mats["rust"])
	for i in range(7):
		var px := -x+float(i)*(size.x/6.0)
		box(group,Vector3(px,0.7,-z),Vector3(0.12,1.4,0.12),mats["steel"])
		box(group,Vector3(px,0.7,z),Vector3(0.12,1.4,0.12),mats["steel"])
	box(group,Vector3(0,1.4,-z),Vector3(size.x,0.12,0.12),mats["pipe"])
	box(group,Vector3(0,1.4,z),Vector3(size.x,0.12,0.12),mats["pipe"])
	for i in range(9):
		var pz := -z*0.8+float(i)*z*0.2
		cylinder(group,Vector3(-x*0.7,0.4,pz),0.14,0.65,mats["leaf"])

static func detail_ruins(terrain: Node3D, mats: Dictionary) -> void:
	# Foreground salvage site: palette breaks the empty uniform dirt plane.
	for base in [Vector3(-31,0,12),Vector3(33,0,-27),Vector3(-33,0,-30),Vector3(40,0,20)]:
		for i in range(6):
			var p: Vector3 = Vector3(base) + Vector3(float(i%3)*1.05,0,float(i/3)*1.1)
			box(terrain,p+Vector3(0,0.4,0),Vector3(0.8,0.8,0.85),mats["rust"] if i%2==0 else mats["concrete"])
	# Broken fence segments with pilings and warning lights.
	for edge in range(2):
		var z := -34.0 if edge==0 else 38.0
		for i in range(12):
			var x := -45.0 + float(i)*3.8
			if i >= 5 and i <= 8:
				continue # breach for expansion & the access road
			box(terrain,Vector3(x,1.05,z),Vector3(0.15,2.1,0.15),mats["rust"])
			box(terrain,Vector3(x+1.9,0.8,z),Vector3(3.65,0.07,0.1),mats["steel"])
			box(terrain,Vector3(x+1.9,1.45,z),Vector3(3.65,0.07,0.1),mats["steel"])


static func build_terrain_dressing(parent: Node3D, mats: Dictionary) -> void:
	# MultiMesh minimizes individual draw calls. Ground patches / scrap are
	# decorative only; the center of the base is left free for gameplay.
	var rng := RandomNumberGenerator.new()
	rng.seed = 991427
	var gravel_mesh := BoxMesh.new()
	gravel_mesh.size = Vector3(1.0, 0.045, 1.0)
	var gravel := MultiMesh.new()
	gravel.transform_format = MultiMesh.TRANSFORM_3D
	gravel.mesh = gravel_mesh
	gravel.instance_count = 260
	var gravel_layer := MultiMeshInstance3D.new()
	gravel_layer.name = "DarkSoilGravelAndRubble"
	gravel_layer.multimesh = gravel
	gravel_layer.material_override = mats["stone"]
	parent.add_child(gravel_layer)
	for i in range(gravel.instance_count):
		var x := rng.randf_range(-84.0, 88.0)
		var z := rng.randf_range(-73.0, 69.0)
		# Stay off hard-surfaced service roads and future build plots.
		if absf(x) < 28.0 and absf(z) < 26.0:
			x += 33.0 if x > 0.0 else -33.0
		var obj_transform := Transform3D(Basis.IDENTITY, Vector3(x, 0.075, z))
		obj_transform.basis = Basis(Vector3.UP, rng.randf_range(-PI, PI))
		obj_transform.basis = obj_transform.basis.scaled(Vector3(rng.randf_range(0.35, 2.4), 1.0, rng.randf_range(0.45, 1.8)))
		gravel.set_instance_transform(i, obj_transform)

	var metal_mesh := BoxMesh.new()
	metal_mesh.size = Vector3(0.86, 0.10, 0.40)
	var metal := MultiMesh.new()
	metal.transform_format = MultiMesh.TRANSFORM_3D
	metal.mesh = metal_mesh
	metal.instance_count = 110
	var scrap := MultiMeshInstance3D.new()
	scrap.name = "ScatteredCollapsedMetal"
	scrap.multimesh = metal
	scrap.material_override = mats["rust"]
	parent.add_child(scrap)
	for i in range(metal.instance_count):
		var x := rng.randf_range(-75.0, 79.0)
		var z := rng.randf_range(-55.0, 62.0)
		if absf(x) < 28.0 and absf(z) < 26.0:
			z += 30.0 if z > 0.0 else -30.0
		var t := Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)), Vector3(x, 0.12, z))
		t.basis = t.basis.scaled(Vector3(rng.randf_range(0.6, 1.8), 1.0, rng.randf_range(0.6, 1.3)))
		metal.set_instance_transform(i, t)

	# Remains of former settlement infrastructure, not a repeating flat field.
	for ix in range(5):
		for iz in range(3):
			var base := Vector3(-64.0 + float(ix)*6.5, 0, -38.0 + float(iz)*6.0)
			box(parent, base + Vector3(0, 0.06, 0), Vector3(4.5, 0.12, 4.0), mats["concrete"])
			if (ix+iz) % 2 == 0:
				box(parent, base + Vector3(-1.65, 0.72, 0), Vector3(0.22, 1.44, 3.8), mats["rust"])
				box(parent, base + Vector3(0, 0.72, 1.7), Vector3(3.4, 1.44, 0.22), mats["concrete"])
	for pos in [Vector3(-32,0,-24), Vector3(52,0,-26)]:
		_build_watchpost(parent, pos, mats)
	for pos in [Vector3(-24,0,31), Vector3(33,0,32), Vector3(-18,0,-28)]:
		_drum_stack(parent, pos, mats)

static func _build_watchpost(parent: Node3D, pos: Vector3, mats: Dictionary) -> void:
	var root := Node3D.new()
	root.position = pos
	root.name = "PerimeterWatchtower"
	parent.add_child(root)
	for dx in [-1.8, 1.8]:
		for dz in [-1.8, 1.8]:
			box(root, Vector3(dx, 3.4, dz), Vector3(0.35, 6.8, 0.35), mats["steel"])
	box(root, Vector3(0, 6.7, 0), Vector3(5.2, 0.35, 5.2), mats["concrete"])
	box(root, Vector3(0, 8.4, 0), Vector3(5.5, 0.35, 5.5), mats["rust"])
	for side in [-1.0,1.0]:
		box(root, Vector3(0, 7.6, side*2.5), Vector3(5.1, 1.5, 0.24), mats["steel"])
		box(root, Vector3(side*2.5, 7.6, 0), Vector3(0.24, 1.5, 5.1), mats["steel"])
	box(root, Vector3(0, 3.0, -2.0), Vector3(0.22, 6.0, 0.16), mats["rust"])
	for rung in range(12):
		box(root, Vector3(0, 0.45 + float(rung)*0.45, -2.1), Vector3(1.3, 0.10, 0.14), mats["steel"])

static func _drum_stack(parent: Node3D, center: Vector3, mats: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "AbandonedFuelDrums"
	root.position = center
	parent.add_child(root)
	for i in range(5):
		var x := float(i%3) * 0.8
		var z := float(i/3) * 0.95
		cylinder(root, Vector3(x, 0.55, z), 0.32, 1.1, mats["rust"])
		cylinder(root, Vector3(x, 1.1, z), 0.31, 0.04, mats["darkmetal"])
