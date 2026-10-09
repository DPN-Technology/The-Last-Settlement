class_name SettlementDetailArt3D
extends RefCounted

# Asset-independent visual detail for Godot 4.3. These are improved placeholder
# meshes, not finished photorealistic character/plant assets. Kept separate from
# simulation so future licensed glTF/rigged art drops in without save changes.

static func _box(parent: Node3D, name: String, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var obj := MeshInstance3D.new()
	obj.name = name
	obj.mesh = mesh
	obj.material_override = material
	obj.position = at
	parent.add_child(obj)
	return obj

static func _sphere(parent: Node3D, name: String, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh.rings = 7
	var obj := MeshInstance3D.new()
	obj.name = name
	obj.mesh = mesh
	obj.material_override = material
	obj.position = at
	obj.scale = size
	parent.add_child(obj)
	return obj

static func _capsule(parent: Node3D, name: String, at: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 5
	var obj := MeshInstance3D.new()
	obj.name = name
	obj.mesh = mesh
	obj.material_override = material
	obj.position = at
	parent.add_child(obj)
	return obj

static func _crop_leaf_mesh() -> ArrayMesh:
	# Double-curved, narrow-lanceolate leaf rather than the old green sphere.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := [
		Vector3(0.0, 0.02, 0.0),
		Vector3(0.15, 0.17, -0.08),
		Vector3(0.26, 0.34, -0.16),
		Vector3(0.45, 0.47, -0.20),
		Vector3(0.63, 0.32, -0.12)
	]
	var widths := [0.02, 0.13, 0.19, 0.15, 0.0]
	for i in range(points.size()-1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i+1]
		var av := Vector3(0.0, 0.0, widths[i])
		var bv := Vector3(0.0, 0.0, widths[i+1])
		for v in [a-av, b-bv, a+av, a+av, b-bv, b+bv]:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()

static func create_crops(group: Node3D, size: Vector2, mats: Dictionary) -> void:
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color("#627b42")
	leaf_mat.roughness = 0.98
	leaf_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	leaf_mat.subsurf_scatter_strength = 0.1
	var leaf_mesh := _crop_leaf_mesh()
	var count := 6 * 9
	var blades_per_crop := 6
	var leaves := MultiMesh.new()
	leaves.transform_format = MultiMesh.TRANSFORM_3D
	leaves.mesh = leaf_mesh
	leaves.instance_count = count * blades_per_crop
	var leaf_inst := MultiMeshInstance3D.new()
	leaf_inst.name = "LeafyCropCanopy"
	leaf_inst.multimesh = leaves
	leaf_inst.material_override = leaf_mat
	group.add_child(leaf_inst)

	var stems := MultiMesh.new()
	stems.transform_format = MultiMesh.TRANSFORM_3D
	var stem_mesh := CylinderMesh.new()
	stem_mesh.bottom_radius = 0.045
	stem_mesh.top_radius = 0.027
	stem_mesh.height = 0.37
	stem_mesh.radial_segments = 6
	stems.mesh = stem_mesh
	stems.instance_count = count
	var stem_inst := MultiMeshInstance3D.new()
	stem_inst.name = "CropStems"
	stem_inst.multimesh = stems
	stem_inst.material_override = mats["olive"]
	group.add_child(stem_inst)

	var leaf_index := 0
	var stem_index := 0
	for row in range(6):
		var x := -size.x * 0.38 + float(row) * size.x * 0.15
		for plot in range(9):
			var z := -size.y * 0.4 + float(plot) * size.y * 0.1
			var center := Vector3(x, 0.48, z)
			var variety := 0.8 + float((row * 7 + plot * 3) % 5) * 0.055
			stems.set_instance_transform(stem_index, Transform3D(Basis.IDENTITY, center + Vector3(0, 0.11, 0)))
			stem_index += 1
			for part in range(blades_per_crop):
				var angle := (float(part) / float(blades_per_crop)) * TAU + float((row + plot) % 3) * 0.22
				var basis := Basis(Vector3.UP, angle)
				basis = basis.scaled(Vector3(variety, variety, variety))
				leaves.set_instance_transform(leaf_index, Transform3D(basis, center))
				leaf_index += 1

static func create_survivor(person: Node3D, citizen: Dictionary, mats: Dictionary) -> void:
	var job := str(citizen.get("job",""))
	var uid := int(citizen.get("id", 0))
	var skin: Material = mats["skin"]
	if uid % 3 == 0:
		skin = mats["skin_deep"]
	elif uid % 3 == 1:
		skin = mats["skin_light"]
	var coat: Material = mats["uniform"]
	match job:
		"Guard": coat = mats["guard_uniform"]
		"Medic": coat = mats["medic_uniform"]
		"Engineer", "Builder": coat = mats["workwear"]
		"Scavenger": coat = mats["denim"]
		"Farmer": coat = mats["olive"]
	var legmat: Material = mats["trousers"]
	var boots: Material = mats["boots"]

	# Anatomical proportions; actual hip/shoulder joints are Node3D pivots.
	# Pivot names remain compatible with the current walking animation.
	_capsule(person, "Torso", Vector3(0, 1.42, 0), 0.34, 0.88, coat)
	_sphere(person, "Shoulders", Vector3(0, 1.71, 0), Vector3(0.85, 0.34, 0.43), coat)
	_box(person, "Harness", Vector3(0, 1.48, 0.29), Vector3(0.52, 0.58, 0.13), mats["webbing"])
	_sphere(person, "Neck", Vector3(0, 1.87, 0), Vector3(0.19, 0.23, 0.19), skin)
	_sphere(person, "Head", Vector3(0, 2.07, -0.02), Vector3(0.51, 0.61, 0.48), skin)
	_sphere(person, "Nose", Vector3(0, 2.06, -0.26), Vector3(0.13, 0.15, 0.14), skin)
	_box(person, "CapTop", Vector3(0, 2.38, 0.0), Vector3(0.53, 0.13, 0.48), mats["boots"])
	_box(person, "CapBill", Vector3(0, 2.31, -0.31), Vector3(0.51, 0.07, 0.31), mats["boots"])

	for sign in [-1.0,1.0]:
		var left: bool = float(sign) < 0.0
		var leg := Node3D.new()
		leg.name = "LegLeft" if left else "LegRight"
		leg.position = Vector3(sign * 0.21, 0.94, 0.0)
		person.add_child(leg)
		_capsule(leg, "TrouserLeg", Vector3(0, -0.42, 0), 0.17, 0.81, legmat)
		_box(leg, "Boot", Vector3(0, -0.82, -0.1), Vector3(0.32, 0.22, 0.52), boots)
		var arm := Node3D.new()
		arm.name = "ArmLeft" if left else "ArmRight"
		arm.position = Vector3(sign * 0.48, 1.72, 0)
		person.add_child(arm)
		_capsule(arm, "Sleeve", Vector3(0, -0.4, 0), 0.14, 0.75, coat)
		_sphere(arm, "Hand", Vector3(0, -0.79, 0), Vector3(0.21, 0.22, 0.20), skin)

	_box(person, "Backpack", Vector3(0, 1.42, 0.42), Vector3(0.67, 0.77, 0.42), mats["canvas"])
	_box(person, "LeftStrap", Vector3(-0.2, 1.5, -0.34), Vector3(0.12, 0.76, 0.08), mats["webbing"])
	_box(person, "RightStrap", Vector3(0.2, 1.5, -0.34), Vector3(0.12, 0.76, 0.08), mats["webbing"])
	_box(person, "Belt", Vector3(0, 1.03, -0.04), Vector3(0.69, 0.16, 0.40), mats["webbing"])
	match job:
		"Medic":
			_box(person, "MedicPatchVertical", Vector3(0, 1.58, -0.41), Vector3(0.08, 0.32, 0.025), mats["cross"])
			_box(person, "MedicPatchHorizontal", Vector3(0, 1.58, -0.415), Vector3(0.3, 0.08, 0.025), mats["cross"])
		"Guard":
			_box(person, "ArmoredPlate", Vector3(0, 1.47, -0.42), Vector3(0.52, 0.56, 0.12), mats["steel"])
		"Engineer", "Builder":
			_box(person, "ToolRoll", Vector3(0.42, 0.95, 0.06), Vector3(0.24, 0.43, 0.24), mats["rust"])
		"Farmer":
			_box(person, "SeedPouch", Vector3(0.4, 1.06, 0), Vector3(0.24, 0.31, 0.27), mats["canvas"])
		"Scavenger":
			_box(person, "ScrapPack", Vector3(0, 1.40, 0.71), Vector3(0.48, 0.38, 0.30), mats["steel"])
