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
varying float level;
varying vec3 surface_normal;
void vertex() {
	level = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
	surface_normal = NORMAL;
}
void fragment() {
	float boots = smoothstep(boot_cutoff - 0.025, boot_cutoff + 0.025, level);
	float jacket = smoothstep(0.87, 0.99, level);
	float neck = smoothstep(1.46, 1.55, level);
	vec3 cloth = mix(vec3(0.085, 0.093, 0.086), pants_color.rgb, boots);
	cloth = mix(cloth, coat_color.rgb, jacket);
	cloth = mix(cloth, skin_color.rgb, neck);
	float stitches = sin(level * 67.0) * 0.009;
	float grain = fract(sin(dot(FRAGCOORD.xy + vec2(level), vec2(14.17, 55.63))) * 43758.5);
	float dirt = mix(0.76, 1.01, grain);
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
	return material

static func _shade_meshes(node: Node, garment: ShaderMaterial) -> int:
	var count := 0
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = garment
		count += 1
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
	_box(gear, "Backpack", Vector3(0, 1.19, 0.29), Vector3(0.38, 0.54, 0.25), pack)
	_box(gear, "PackRoll", Vector3(0, 1.52, 0.33), Vector3(0.43, 0.17, 0.26), band)
	_box(gear, "PackFastener", Vector3(0, 1.19, 0.44), Vector3(0.09, 0.20, 0.05), metal)
	_box(gear, "WaistBelt", Vector3(0, 0.92, -0.05), Vector3(0.43, 0.10, 0.26), band)
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
