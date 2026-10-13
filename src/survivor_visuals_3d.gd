class_name SurvivorVisuals3D
extends RefCounted

# Preproduction presentation for the imported licensed rig. Skins the actual
# skeletal mesh with a worn multi-tone uniform rather than bright white source
# material, and normalizes body height to match buildings in world meters.
# An authored survivor costume GLB can replace this layer later.

const TARGET_HEIGHT := 1.82
const GARB_SHADER := """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;
uniform vec4 coat_color : source_color = vec4(0.25, 0.31, 0.24, 1.0);
uniform vec4 pants_color : source_color = vec4(0.13, 0.16, 0.14, 1.0);
uniform vec4 skin_color : source_color = vec4(0.54, 0.37, 0.27, 1.0);
uniform vec4 straps_color : source_color = vec4(0.30, 0.27, 0.21, 1.0);
uniform float boot_cutoff = 0.20;
uniform float wear_seed = 0.0;
varying float level;
varying vec3 garment_local_position;
void vertex() {
	level = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
	garment_local_position = VERTEX * length(MODEL_MATRIX[0].xyz);
}
void fragment() {
	float boots = smoothstep(boot_cutoff - 0.025, boot_cutoff + 0.025, level);
	float jacket = smoothstep(0.87, 0.99, level);
	float neck = smoothstep(1.46, 1.55, level);
	vec3 cloth = mix(vec3(0.085, 0.093, 0.086), pants_color.rgb, boots);
	cloth = mix(cloth, coat_color.rgb, jacket);
	cloth = mix(cloth, skin_color.rgb, neck);
	float stitches = sin(level * 67.0) * 0.009;
	vec3 seeded_position = garment_local_position + vec3(wear_seed * 13.7, wear_seed * 7.1, wear_seed * 19.3);
	float broad_wear = sin(dot(seeded_position, vec3(7.1, 13.7, 9.3)));
	float fine_wear = sin(dot(seeded_position, vec3(47.3, 31.1, 59.7)));
	float dirt = clamp(0.88 + broad_wear * 0.085 + fine_wear * 0.025, 0.74, 1.0);
	vec3 albedo = cloth * (dirt + stitches);
	ALBEDO = mix(albedo, straps_color.rgb, smoothstep(0.975, 0.988, level) * (1.0 - smoothstep(1.00, 1.04, level)) * 0.52);
	ROUGHNESS = 0.93;
	METALLIC = 0.0;
}
"""

static func _collect_mesh_bounds(node: Node, model: Node3D, bounds: Dictionary) -> void:
	if node is MeshInstance3D:
		var visual := node as MeshInstance3D
		if visual.mesh != null:
			var aabb := visual.get_aabb()
			var relative := model.global_transform.affine_inverse() * visual.global_transform
			for xi in range(2):
				for yi in range(2):
					for zi in range(2):
						var corner := aabb.position + aabb.size * Vector3(float(xi),float(yi),float(zi))
						var p := relative * corner
						bounds["low"] = Vector3(bounds["low"]).min(p)
						bounds["high"] = Vector3(bounds["high"]).max(p)
			bounds["count"] = int(bounds["count"]) + 1
	for child in node.get_children():
		_collect_mesh_bounds(child, model, bounds)

static func _make_garment(job: String, id: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = GARB_SHADER
	material.shader = sh
	var coat := Color("#525f4a")
	match job:
		"Medic": coat = Color("#8a9990")
		"Guard": coat = Color("#4b5750")
		"Engineer", "Builder": coat = Color("#a47b4b")
		"Scavenger": coat = Color("#4d5a60")
		"Farmer": coat = Color("#606b46")
	var skin := Color("#af866a")
	match id % 4:
		0: skin = Color("#d0a888")
		1: skin = Color("#93654b")
		2: skin = Color("#634332")
		3: skin = Color("#b98062")
	material.set_shader_parameter("coat_color", coat)
	material.set_shader_parameter("pants_color", Color("#343b37") if job != "Medic" else Color("#555d58"))
	material.set_shader_parameter("skin_color", skin)
	material.set_shader_parameter("straps_color", Color("#544a38"))
	material.set_shader_parameter("wear_seed", fposmod(float(id) * 0.61803398875, 1.0))
	return material

static func _shade_meshes(node: Node, garment: ShaderMaterial) -> int:
	var count := 0
	if node is MeshInstance3D:
		var visual := node as MeshInstance3D
		if visual.mesh != null:
			visual.material_override = garment
			count += 1
		else:
			visual.visible = false
	elif node is MultiMeshInstance3D:
		var visual := node as MultiMeshInstance3D
		if visual.multimesh == null or visual.multimesh.mesh == null:
			visual.visible = false
	for child in node.get_children():
		count += _shade_meshes(child, garment)
	return count

static func _box(parent: Node3D, name: String, pos: Vector3, size: Vector3, mat: Material) -> void:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.name = name
	visual.position = pos
	visual.material_override = mat
	parent.add_child(visual)

static func _sphere(parent: Node3D, name: String, pos: Vector3, dimensions: Vector3, mat: Material) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name=name
	var mesh := SphereMesh.new()
	mesh.radius=0.5
	mesh.height=1.0
	mesh.radial_segments=16
	mesh.rings=8
	visual.mesh=mesh
	visual.position=pos
	visual.scale=dimensions
	visual.material_override=mat
	parent.add_child(visual)
	return visual

static func _cylinder(parent: Node3D, name: String, pos: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name=name
	var mesh := CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.height=height
	mesh.radial_segments=12
	visual.mesh=mesh
	visual.position=pos
	visual.material_override=mat
	parent.add_child(visual)
	return visual

static func _rounded_pack(parent: Node3D, material: Material) -> void:
	# Small curved hiking rucksack replaces the conspicuous floating cube.
	var pack_mesh := CapsuleMesh.new()
	pack_mesh.radius = 0.18
	pack_mesh.height = 0.50
	pack_mesh.radial_segments = 12
	pack_mesh.rings = 5
	var pack := MeshInstance3D.new()
	pack.name = "Backpack"
	pack.mesh = pack_mesh
	pack.material_override = material
	pack.position = Vector3(0, 1.25, 0.25)
	parent.add_child(pack)

static func _kit(root: Node3D, citizen: Dictionary, palette: Dictionary) -> void:
	# High-contrast, non-emissive gear establishes a readable silhouette from
	# the overhead gameplay camera without obscuring the imported rig/skeleton.
	var job := str(citizen.get("job", ""))
	var gear := Node3D.new()
	gear.name = "SurvivorEquipment"
	root.add_child(gear)
	var pack: Material = palette["canvas"]
	var metal: Material = palette["darkmetal"]
	var band: Material = palette["webbing"]
	_rounded_pack(gear, pack)
	var bedroll_mesh := CapsuleMesh.new()
	bedroll_mesh.radius=0.12
	bedroll_mesh.height=0.82
	bedroll_mesh.radial_segments=12
	bedroll_mesh.rings=5
	var bedroll := MeshInstance3D.new()
	bedroll.name="RolledBedroll"
	bedroll.mesh=bedroll_mesh
	bedroll.position=Vector3(0,1.53,0.30)
	bedroll.rotation.z=PI*0.5
	bedroll.material_override=pack
	gear.add_child(bedroll)
	for side in [-1.0,1.0]:
		_box(gear,"BedrollCompressionStrap",Vector3(side*0.17,1.53,0.30),Vector3(0.045,0.27,0.27),band)
	# Low-profile clips and webbing remain readable at settlement view,
	# without hiding the actual human upper body like the old square backpack.
	_box(gear, "PackFastener", Vector3(0, 1.21, 0.42), Vector3(0.07, 0.15, 0.035), metal)
	_box(gear, "ShoulderStrapLeft", Vector3(-0.16, 1.30, -0.11), Vector3(0.06, 0.44, 0.045), band)
	_box(gear, "ShoulderStrapRight", Vector3(0.16, 1.30, -0.11), Vector3(0.06, 0.44, 0.045), band)
	_box(gear, "WaistBelt", Vector3(0, 0.94, -0.05), Vector3(0.38, 0.08, 0.20), band)
	for side in [-1.0,1.0]:
		_box(gear,"UtilityBeltPouch",Vector3(side*0.17,1.00,-0.17),Vector3(0.13,0.17,0.08),pack)
		_box(gear,"PouchFastener",Vector3(side*0.17,1.04,-0.215),Vector3(0.055,0.035,0.018),metal)
	_cylinder(gear,"FieldCanteen",Vector3(0.24,1.19,0.22),0.075,0.27,metal)
	var headwear: Material=pack
	if job=="Medic":
		headwear=palette["clinic"]
	elif job in ["Guard","Engineer","Builder"]:
		headwear=metal
	var brim_radius: float=0.18 if job in ["Guard","Engineer","Builder"] else (0.24 if job=="Farmer" else 0.16)
	_cylinder(gear,"SurvivorFieldCapBrim",Vector3(0,1.63,-0.015),brim_radius,0.045,headwear)
	_sphere(gear,"SurvivorFieldCapCrown",Vector3(0,1.69,0.005),Vector3(0.28,0.17,0.27),headwear)
	if job=="Medic":
		_box(gear,"MedicCapMark",Vector3(0,1.69,-0.132),Vector3(0.045,0.075,0.018),palette["cross"])
		_box(gear,"MedicCapMarkCrossbar",Vector3(0,1.69,-0.134),Vector3(0.09,0.025,0.02),palette["cross"])
	match job:
		"Medic":
			_box(gear, "MedicCase", Vector3(0.26, 0.82, 0), Vector3(0.28, 0.33, 0.30), palette["clinic"])
			_box(gear, "MedicCaseMark", Vector3(0.415, 0.82, 0), Vector3(0.015, 0.20, 0.055), palette["cross"])
		"Guard":
			_box(gear, "ArmoredVest", Vector3(0, 1.28, -0.22), Vector3(0.42, 0.42, 0.13), metal)
		"Engineer", "Builder":
			_box(gear, "ToolRoll", Vector3(0.28, 0.91, 0), Vector3(0.16, 0.29, 0.21), palette["rust"])
		"Farmer":
			_box(gear, "SeedPouch", Vector3(-0.28, 0.88, 0), Vector3(0.20, 0.24, 0.22), pack)
		"Scavenger":
			_box(gear, "SalvageSidepack", Vector3(0.31, 1.10, 0.04), Vector3(0.22, 0.33, 0.26), palette["steel"])

static func prepare(model: Node3D, owner: Node3D, citizen: Dictionary, palette: Dictionary) -> void:
	var bounds: Dictionary = {
		"low": Vector3(999999,999999,999999),
		"high": Vector3(-999999,-999999,-999999),
		"count": 0
	}
	_collect_mesh_bounds(model, model, bounds)
	var height := 0.0
	if int(bounds["count"]) > 0:
		height = Vector3(bounds["high"]).y - Vector3(bounds["low"]).y
	if height > 0.2:
		var factor := clampf(TARGET_HEIGHT / height, 0.09, 8.0)
		model.scale = Vector3.ONE * factor
		model.position.y = -Vector3(bounds["low"]).y * factor
		model.set_meta("visual_height_m", height * factor)
	else:
		# Preserve source asset and mark invalid metrics for explicit CI detection.
		model.set_meta("visual_height_m", height)
	var clothes := _make_garment(str(citizen.get("job", "")), int(citizen.get("id", 0)))
	var shaded := _shade_meshes(model, clothes)
	model.set_meta("garment_mesh_count", shaded)
	_kit(owner, citizen, palette)
