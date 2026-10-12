class_name SettlementWorld3D
extends Node3D

# Real 3D scene: perspective camera, physically lit geometry, terrain and
# interactive ground projection. Existing settlement save format is unchanged.
# The runtime models are transitional assets; production glTF/PBR art can
# replace them without modifying simulation or player controls.

const SCALE := 0.085
const ORIGIN := Vector2(700.0, 450.0)
const GROUND_SHADER := """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
varying vec3 coord;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i), hash(i+vec2(1.,0.)), f.x),
	           mix(hash(i+vec2(0.,1.)), hash(i+vec2(1.,1.)), f.x), f.y);
}
void vertex(){coord = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;}
void fragment(){
	float a = n2(coord.xz*0.48);
	float b = n2(coord.xz*2.4);
	float c = n2(coord.xz*11.0);
	ALBEDO = mix(vec3(0.105,0.101,0.087),vec3(0.24,0.223,0.179),a*0.72+b*0.2)
	       + vec3(c*0.034);
	ROUGHNESS = 0.95;
	METALLIC = 0.0;
}
"""

const WEATHERED_MATERIAL_SHADER := """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 tint : source_color = vec4(0.43, 0.41, 0.36, 1.0);
uniform float surface_roughness = 0.82;
uniform float surface_metallic = 0.0;
uniform float grime = 0.5;
varying vec3 world_coords;
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise21(vec2 p) {
	vec2 i=floor(p); vec2 f=fract(p);
	f=f*f*(3.0-2.0*f);
	return mix(mix(hash21(i),hash21(i+vec2(1.,0.)),f.x),mix(hash21(i+vec2(0.,1.)),hash21(i+vec2(1.,1.)),f.x),f.y);
}
void vertex() { world_coords = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 uv = world_coords.xz * 0.37 + world_coords.xy * 0.19 + world_coords.yz * 0.18;
	float broad = noise21(uv * 0.68);
	float mottled = noise21(uv * 5.2);
	float fine = noise21(uv * 24.0);
	float patches = smoothstep(0.53, 0.83, noise21(uv * 1.5));
	float paint_wear = mix(0.66, 1.12, broad) - grime * patches * 0.28;
	float corrosion = grime * smoothstep(0.69, 0.9, mottled);
	vec3 rusty = vec3(0.22, 0.115, 0.067);
	ALBEDO = mix(tint.rgb * paint_wear, rusty, corrosion * (0.28 + 0.4 * patches));
	ALBEDO *= 0.94 + fine * 0.11;
	ROUGHNESS = clamp(surface_roughness + mottled * 0.13 + grime * patches * 0.11, 0.25, 1.0);
	METALLIC = surface_metallic * (1.0 - corrosion * 0.5);
}
"""

var camera: Camera3D
var light: DirectionalLight3D
var world_environment: Environment
var sky_material: ProceduralSkyMaterial
var weather_effects: SettlementWeather3D
var command_lamp: OmniLight3D
var prior_lighting_hour := -10.0
var structure_layer: Node3D
var survivors_layer: Node3D
var terrain_layer: Node3D
var focus := Vector3(4.0, 0.0, 2.0)
var camera_distance := 43.0
var yaw := 0.0
var pitch := deg_to_rad(44.0)
var cached_layout := ""
var last_daylight := -1
var people: Dictionary = {}
var animated_vent_fans: Array[Node3D] = []
var industrial_yards: Array[Dictionary] = []
var industry_cycle := 0.0
var materials: Dictionary = {}
var selected_key := ""
var cutaway_views := 0
var visual_time := 0.0
var terrain_height_noise := FastNoiseLite.new()

func _ready() -> void:
	_create_materials()
	_create_environment()
	weather_effects=SettlementWeather3D.new()
	add_child(weather_effects)
	terrain_layer = Node3D.new()
	terrain_layer.name = "Terrain"
	add_child(terrain_layer)
	_build_terrain()
	structure_layer = Node3D.new()
	structure_layer.name = "Infrastructure"
	add_child(structure_layer)
	survivors_layer = Node3D.new()
	survivors_layer.name = "Survivors"
	add_child(survivors_layer)
	camera = Camera3D.new()
	camera.name = "PlayablePerspectiveCamera"
	camera.fov = 50.0
	camera.near = 0.08
	camera.far = 500.0
	add_child(camera)
	camera.current = true
	_position_camera()

func _mat(key: String, color: Color, rough: float = 0.86, metal: float = 0.0, emission: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = rough
	material.metallic = metal
	if emission:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.5
	materials[key] = material
	return material

func _weathered(key: String, color: Color, rough: float, metal: float, grime: float) -> void:
	var shader_material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = WEATHERED_MATERIAL_SHADER
	shader_material.shader = shader
	shader_material.set_shader_parameter("tint", color)
	shader_material.set_shader_parameter("surface_roughness", rough)
	shader_material.set_shader_parameter("surface_metallic", metal)
	shader_material.set_shader_parameter("grime", grime)
	materials[key] = shader_material

func _use_photo_pbr(key: String, asset: String, tint: Color, roughness: float, metallic: float, tiling: float) -> void:
	var texture_root := "res://assets/3d/pbr/"
	var diffuse_path := texture_root + asset + "_diff_1k.png"
	var normal_path := texture_root + asset + "_nor_gl_1k.png"
	if not ResourceLoader.exists(diffuse_path) or not ResourceLoader.exists(normal_path):
		return # Source checkout without build-provisioned CC0 assets stays playable.
	var diffuse := load(diffuse_path) as Texture2D
	var normal := load(normal_path) as Texture2D
	if diffuse == null or normal == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_texture = diffuse
	material.albedo_color = tint
	material.normal_enabled = true
	material.normal_texture = normal
	material.normal_scale = 0.46
	material.roughness = roughness
	material.metallic = metallic
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * maxf(0.09, tiling * 0.44)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	materials[key] = material

func _create_materials() -> void:
	_mat("concrete", Color("#777268"))
	_mat("foundation", Color("#484944"))
	_mat("wall", Color("#8a8173"))
	_mat("rust", Color("#774b35"), 0.88, 0.24)
	_mat("steel", Color("#58646a"), 0.51, 0.62)
	_mat("darkmetal", Color("#313a3d"), 0.62, 0.5)
	_mat("roof", Color("#514d48"), 0.76, 0.12)
	_mat("rooflight", Color("#77776c"), 0.68, 0.22)
	_mat("glass", Color("#46747c"), 0.25, 0.27)
	_mat("glow", Color("#e5bd78"), 0.35, 0.1, true)
	_mat("clinic", Color("#c2c8bd"))
	_mat("cross", Color("#9b3433"))
	_mat("farm", Color("#41382b"))
	_mat("leaf", Color("#4d6246"))
	_mat("olive", Color("#63714c"))
	_mat("skin", Color("#b18c69"))
	_mat("skin_deep", Color("#6e4636"))
	_mat("skin_light", Color("#d6ad8c"))
	_mat("trousers", Color("#383d39"))
	_mat("boots", Color("#242927"))
	_mat("webbing", Color("#625b48"))
	_mat("canvas", Color("#60563e"))
	materials["wood"]=SettlementMaterialLibrary3D.create("timber")
	materials["cloth"]=SettlementMaterialLibrary3D.create("cloth")
	_mat("medic_uniform", Color("#9faaa2"))
	_mat("guard_uniform", Color("#4a5951"))
	_mat("workwear", Color("#ad8650"))
	_mat("uniform", Color("#6c7060"))
	_mat("denim", Color("#4d5a62"))
	_mat("asphalt", Color("#30332f"))
	_mat("stripe", Color("#938973"))
	_mat("soil", Color("#453d31"))
	_mat("warning", Color("#dda04e"), 0.5, 0.1, true)
	_mat("blue", Color("#3e6575"))
	_mat("pipe", Color("#617b7d"), 0.52, 0.47)
	_mat("stone", Color("#635e54"))
	_weathered("concrete", Color("#65625a"), 0.96, 0.0, 0.45)
	_weathered("wall", Color("#666359"), 0.92, 0.03, 0.62)
	_weathered("roof", Color("#424b4c"), 0.82, 0.2, 0.67)
	_weathered("rooflight", Color("#626c6b"), 0.75, 0.2, 0.5)
	_weathered("rust", Color("#674633"), 0.90, 0.14, 0.81)
	_weathered("steel", Color("#4d5655"), 0.67, 0.46, 0.56)
	_weathered("foundation", Color("#383a36"), 0.95, 0.0, 0.45)
	_weathered("asphalt", Color("#2d3130"), 0.97, 0.0, 0.24)
	_weathered("pavement", Color("#393832"), 0.98, 0.0, 0.42)
	# Runtime photographic PBR replaces the older material shader when the
	# license-checked 1K maps are included in the exported Windows package.
	_use_photo_pbr("concrete", "rough_concrete", Color("#b3aca1"), 0.97, 0.03, 0.45)
	_use_photo_pbr("wall", "rough_concrete", Color("#b6b2aa"), 0.93, 0.02, 0.22)
	_use_photo_pbr("foundation", "rough_concrete", Color("#77746c"), 0.98, 0.01, 0.47)
	_use_photo_pbr("roof", "rusty_metal_sheet", Color("#a9a8a1"), 0.75, 0.23, 0.65)
	_use_photo_pbr("rust", "rusty_metal_sheet", Color("#bd9583"), 0.85, 0.24, 0.58)
	_use_photo_pbr("steel", "rusty_metal_sheet", Color("#888f90"), 0.72, 0.45, 0.68)
	_use_photo_pbr("soil", "gravel_ground_01", Color("#b3a38c"), 0.98, 0.0, 0.38)
	_use_photo_pbr("asphalt", "gravel_ground_01", Color("#69665c"), 0.98, 0.01, 0.32)
	var ghost := _mat("ghost", Color("#4fd3aa55"))
	ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func _create_environment() -> void:
	var sky := Sky.new()
	sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#243944")
	sky_material.sky_horizon_color = Color("#797066")
	sky_material.ground_bottom_color = Color("#181d1c")
	sky_material.ground_horizon_color = Color("#383b37")
	sky_material.use_debanding = true
	sky.sky_material = sky_material
	world_environment = Environment.new()
	# GL Compatibility SubViewport can output black for procedural sky at
	# certain camera angles. A lit earth-colored background is a reliable
	# fallback even beyond the 3D horizon mesh.
	world_environment.background_mode = Environment.BG_COLOR
	world_environment.background_color = Color("#615748")
	world_environment.sky = sky
	world_environment.background_energy_multiplier = 0.25
	world_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_environment.ambient_light_color = Color("#7c8a91")
	world_environment.ambient_light_energy = 0.24
	world_environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	world_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.tonemap_exposure = 1.00
	world_environment.fog_enabled = true
	world_environment.fog_light_color = Color("#5c615b")
	world_environment.fog_density = 0.00095
	var world_env := WorldEnvironment.new()
	world_env.environment = world_environment
	add_child(world_env)
	light = DirectionalLight3D.new()
	light.name = "DynamicDaylight"
	light.light_color = Color("#ddba89")
	light.light_energy = 0.72
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 100.0
	light.rotation_degrees = Vector3(-43, 30, -5)
	add_child(light)
	command_lamp = OmniLight3D.new()
	command_lamp.name = "CommandCampNightLighting"
	command_lamp.position = Vector3(0, 7.2, -3)
	command_lamp.light_color = Color("#e7b879")
	command_lamp.light_energy = 0.0
	command_lamp.omni_range = 26.0
	command_lamp.shadow_enabled = false
	add_child(command_lamp)

func _update_daylight(hour: float) -> void:
	if absf(hour - prior_lighting_hour) < 0.07:
		return
	prior_lighting_hour = hour
	var solar := sin((hour - 6.0) / 12.0 * PI)
	var daylight := clampf(solar, 0.0, 1.0)
	# Match the reference's warm, readable 07:00–09:00 period; do not
	# alter the actual simulation clock or nighttime darkness.
	var visual_day := pow(daylight,0.57)
	var twilight := clampf(1.0 - absf(hour - 18.0) / 3.5, 0.0, 1.0)
	light.light_energy = lerpf(0.04, 1.70, visual_day)
	light.light_color = Color("#efaf70").lerp(Color("#ebd9ba"), visual_day * 0.62)
	light.rotation_degrees = Vector3(-18.0 - daylight * 53.0, 35.0 + hour * 4.0, -3.0)
	world_environment.ambient_light_energy = lerpf(0.14, 0.71, visual_day)
	world_environment.background_energy_multiplier = lerpf(0.14, 0.42, daylight)
	world_environment.ambient_light_color = Color("#35465c").lerp(Color("#b39b82"), visual_day)
	world_environment.fog_light_color = Color("#202d36").lerp(Color("#a48a71"), visual_day)
	sky_material.sky_top_color = Color("#0d1b2a").lerp(Color("#3b5566"), daylight)
	sky_material.sky_horizon_color = Color("#222c3a").lerp(Color("#9d9788"), daylight)
	world_environment.background_color = Color("#343944").lerp(Color("#8a8070"),daylight)
	command_lamp.light_energy = lerpf(1.7, 0.0, daylight) + twilight * 0.14


func _update_weather_environment(sim: SettlementSimulation) -> void:
	# Recalculate from daylight source values every frame. Weather can begin
	# between the daylight threshold updates without accumulating color drift.
	var dust_strength := sim.weather_simulation.intensity if sim.weather_simulation.condition==WeatherSimulation.DUST_STORM else 0.0
	var solar := sin((sim.hour-6.0)/12.0*PI)
	var daylight := clampf(solar,0.0,1.0)
	var visual_day := pow(daylight,0.57)
	var base_fog := Color("#202d36").lerp(Color("#a48a71"),visual_day)
	var base_horizon := Color("#222c3a").lerp(Color("#9d9788"),daylight)
	world_environment.fog_density=lerpf(0.00095,0.0085,dust_strength)
	world_environment.fog_light_color=base_fog.lerp(Color("#8e7154"),dust_strength*0.75)
	sky_material.sky_horizon_color=base_horizon.lerp(Color("#8e6c52"),dust_strength*0.75)
	world_environment.background_color=Color("#343944").lerp(Color("#8a8070"),daylight).lerp(Color("#8e6c52"),dust_strength*0.75)
	world_environment.ambient_light_energy=lerpf(0.14,0.71,visual_day)*(1.0-0.20*dust_strength)
	light.light_energy=lerpf(0.04,1.70,visual_day)*(1.0-0.28*dust_strength)

func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var obj := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	obj.mesh = mesh
	obj.material_override = mat
	obj.position = pos
	parent.add_child(obj)
	return obj

func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material, top_radius: float = -1.0) -> MeshInstance3D:
	var obj := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = 16
	obj.mesh = mesh
	obj.material_override = mat
	obj.position = pos
	parent.add_child(obj)
	return obj

func _sphere(parent: Node3D, pos: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var obj := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 7
	obj.mesh = mesh
	obj.material_override = mat
	obj.position = pos
	parent.add_child(obj)
	return obj

func _build_terrain() -> void:
	terrain_height_noise.seed = 114722
	terrain_height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	terrain_height_noise.frequency = 0.015
	terrain_height_noise.fractal_octaves = 4
	# Render opaque ground before decorative roads. These underlays are a safety
	# net if a GPU drops the procedural heightfield; never expose the sky below.
	var fallback_outer := MeshInstance3D.new()
	fallback_outer.name = "GroundFailsafeOuter"
	var outer_mesh := PlaneMesh.new()
	# Emergency underlay covers the whole camera far range, not merely the
	# original 320m ground tile. The previous 360m plane exposed black beyond.
	outer_mesh.size = Vector2(2200.0, 2200.0)
	fallback_outer.mesh = outer_mesh
	fallback_outer.material_override = GroundAppearance.new_ground_failsafe_material()
	fallback_outer.position.y = -13.0
	terrain_layer.add_child(fallback_outer)

	var fallback_core := MeshInstance3D.new()
	fallback_core.name = "GroundFailsafeSettlementCore"
	var core_mesh := PlaneMesh.new()
	core_mesh.size = Vector2(102.0, 102.0)
	fallback_core.mesh = core_mesh
	fallback_core.material_override = GroundAppearance.new_ground_failsafe_material()
	fallback_core.position.y = -0.31
	terrain_layer.add_child(fallback_core)

	var ground := MeshInstance3D.new()
	ground.name = "PlayableHeightfieldTerrain"
	ground.mesh = WastelandDetail.terrain_mesh()
	# Baked soil/clay/gravel albedo works in Forward+ and GL Compatibility.
	# Render both sides: custom SurfaceTool winding must never disappear
	# from above due to backface culling.
	ground.material_override = GroundAppearance.new_ground_material()
	terrain_layer.add_child(ground)

	# A camera-safe continuation beyond the finite sculpted heightfield.
	# The edge heights smoothly approach 0 so this earth-textured plane sits
	# just under the landscape without an exposed vertical cliff / black void.
	var horizon := MeshInstance3D.new()
	horizon.name="GroundHorizonContinuation"
	# Use a true annular terrain extension with a hole in the middle:
	# a full PlaneMesh would cover negative-height valleys and leave hard
	# material polygons on the player-visible hills.
	horizon.mesh=WastelandDetail.horizon_ring_mesh()
	var horizon_material := (ground.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
	horizon_material.uv1_scale=Vector3.ONE
	horizon.material_override=horizon_material
	terrain_layer.add_child(horizon)

	# Broken asphalt access follows the sculpted ground instead of cutting
	# through the hills or hovering above them.
	_road(Vector3(-87, 0, 5), Vector3(-9, 0, 5), 8.4, true)
	_road(Vector3(-9, 0, 5), Vector3(42, 0, 5), 5.0)
	_road(Vector3(0, 0, -19), Vector3(0, 0, 30), 4.4)
	
	# Deterministic clutter: rock fields, scrub and broken roadside artifacts.
	var rng := RandomNumberGenerator.new()
	rng.seed = 74192
	for index in range(150):
		var point := Vector3(rng.randf_range(-135, 135), 0, rng.randf_range(-125, 125))
		if absf(point.x) < 47.0 and absf(point.z) < 40.0:
			continue
		if index % 4 == 0:
			_tree(point, 0.7 + rng.randf() * 0.6)
		elif index % 3 == 0:
			_sphere(terrain_layer, point + Vector3(0, 0.14, 0), rng.randf_range(0.14, 0.65), materials["stone"])
		else:
			_cylinder(terrain_layer, point + Vector3(0, 0.14, 0), rng.randf_range(0.14, 0.27), 0.25, materials["leaf"])
	for site in [Vector3(-40, 0, -32), Vector3(42, 0, 30), Vector3(-55, 0, 25)]:
		_abandoned_vehicle(site)
	for i in range(15):
		var p := Vector3(-48 + float(i % 5)*2.6, 0, 34 + float(i / 5)*3.0)
		_box(terrain_layer, p + Vector3(0, 0.6, 0), Vector3(1.9, 1.2, 1.9), materials["rust"])
	WastelandDetail.detail_ruins(terrain_layer, materials)
	WastelandDetail.build_terrain_dressing(terrain_layer, materials)
	SettlementWatchTowerArt3D.enrich_existing(terrain_layer,materials)
	SettlementDistrict3D.build(terrain_layer,materials)
	SettlementFidelity3D.terrain(terrain_layer,materials)
	SettlementReferenceEnvironment3D.build_world(terrain_layer,materials)
	SettlementAuthenticModel3D.build_world(terrain_layer)

func _road_point(a: Vector3, b: Vector3, progress: float, lateral: float, width: float, lift: float) -> Vector3:
	var center := a.lerp(b, progress)
	var direction := Vector2(b.x-a.x, b.z-a.z).normalized()
	var across := Vector3(-direction.y, 0.0, direction.x)
	var point := center + across * lateral * width
	point.y = WastelandDetail.terrain_height(point.x, point.z, terrain_height_noise) + lift
	return point

func _road_ribbon(a: Vector3, b: Vector3, width: float, lift: float, longitudinal_steps: int, cross_steps: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: Array = []
	for along in range(longitudinal_steps + 1):
		var row: Array[Vector3] = []
		var progress := float(along) / float(longitudinal_steps)
		for across in range(cross_steps + 1):
			var lateral := float(across) / float(cross_steps) - 0.5
			var point := _road_point(a, b, progress, lateral, width, lift)
			row.append(point)
		rows.append(row)
	for along in range(longitudinal_steps):
		for across in range(cross_steps):
			var uv_x0 := float(along) * 0.22
			var uv_x1 := float(along + 1) * 0.22
			var uv_y0 := float(across) / float(cross_steps)
			var uv_y1 := float(across + 1) / float(cross_steps)
			var p00: Vector3 = rows[along][across]
			var p10: Vector3 = rows[along+1][across]
			var p01: Vector3 = rows[along][across+1]
			var p11: Vector3 = rows[along+1][across+1]
			surface.set_uv(Vector2(uv_x0, uv_y0))
			surface.add_vertex(p00)
			surface.set_uv(Vector2(uv_x0, uv_y1))
			surface.add_vertex(p01)
			surface.set_uv(Vector2(uv_x1, uv_y0))
			surface.add_vertex(p10)
			surface.set_uv(Vector2(uv_x1, uv_y0))
			surface.add_vertex(p10)
			surface.set_uv(Vector2(uv_x0, uv_y1))
			surface.add_vertex(p01)
			surface.set_uv(Vector2(uv_x1, uv_y1))
			surface.add_vertex(p11)
	surface.index()
	surface.generate_normals()
	return surface.commit()

func _road_surface_strip(surface: SurfaceTool, first: Vector3, second: Vector3, half_width: float) -> void:
	var tangent := Vector2(second.x-first.x, second.z-first.z).normalized()
	var across := Vector3(-tangent.y, 0.0, tangent.x) * half_width
	var points: Array[Vector3] = [first-across, first+across, second-across, second+across]
	for index in [0, 1, 2, 2, 1, 3]:
		surface.add_vertex(points[index])

func _road_cracks(a: Vector3, b: Vector3, width: float, count: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var direction := Vector2(b.x-a.x, b.z-a.z).normalized()
	var forward := Vector3(direction.x, 0.0, direction.y)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(a.x * 431.0 + a.z * 673.0 + b.x * 127.0 + b.z * 211.0))
	for crack in range(count):
		var base_progress := (float(crack) + 0.5) / float(count)
		var previous := Vector3.ZERO
		for step in range(9):
			var lateral := -0.47 + float(step) * 0.1175
			var progress := clampf(base_progress + rng.randf_range(-0.009, 0.009), 0.02, 0.98)
			var point := _road_point(a, b, progress, lateral, width, 0.081)
			point += forward * rng.randf_range(-0.045, 0.045)
			point.y = WastelandDetail.terrain_height(point.x, point.z, terrain_height_noise) + 0.081
			if step > 0:
				_road_surface_strip(surface, previous, point, rng.randf_range(0.018, 0.032))
			previous = point
	surface.index()
	surface.generate_normals()
	return surface.commit()

func _road_markings(a: Vector3, b: Vector3, width: float, dash_length: float, gap: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length := Vector2(b.x-a.x, b.z-a.z).length()
	var stride := dash_length + gap
	var dash_count := int(floor(length / stride))
	for dash in range(dash_count):
		var start_distance := float(dash) * stride + (stride - dash_length) * 0.5
		var end_distance := start_distance + dash_length
		var start_progress := start_distance / length
		var end_progress := end_distance / length
		var p0 := _road_point(a, b, start_progress, -0.007, width, 0.101)
		var p1 := _road_point(a, b, start_progress, 0.007, width, 0.101)
		var p2 := _road_point(a, b, end_progress, -0.007, width, 0.101)
		var p3 := _road_point(a, b, end_progress, 0.007, width, 0.101)
		for point in [p0, p1, p2, p2, p1, p3]:
			surface.add_vertex(point)
	surface.index()
	surface.generate_normals()
	return surface.commit()

func _road(a: Vector3, b: Vector3, width: float, center_line: bool = false) -> void:
	var length := Vector2(b.x-a.x, b.z-a.z).length()
	var steps := maxi(2, int(ceil(length / 1.4)))
	var shoulder := MeshInstance3D.new()
	shoulder.name = "ErodedGravelRoadShoulder"
	shoulder.mesh = _road_ribbon(a, b, width + 1.1, 0.025, steps, 4)
	shoulder.material_override = materials["soil"]
	shoulder.set_meta("terrain_conforming", true)
	terrain_layer.add_child(shoulder)
	var road := MeshInstance3D.new()
	road.name = "TerrainConformingBrokenAsphalt"
	road.mesh = _road_ribbon(a, b, width, 0.075, steps, 6)
	road.material_override = materials["pavement"]
	road.set_meta("terrain_conforming", true)
	terrain_layer.add_child(road)
	var cracks := MeshInstance3D.new()
	cracks.name = "PhysicalRoadFissures"
	cracks.mesh = _road_cracks(a, b, width, maxi(2, int(floor(length / 12.0))))
	cracks.material_override = materials["foundation"]
	cracks.set_meta("terrain_conforming", true)
	terrain_layer.add_child(cracks)
	if center_line:
		var markings := MeshInstance3D.new()
		markings.name = "WornCenterlineDashes"
		markings.mesh = _road_markings(a, b, width, 1.8, 3.8)
		markings.material_override = materials["stripe"]
		markings.set_meta("terrain_conforming", true)
		terrain_layer.add_child(markings)

func _tree(point: Vector3, scale: float) -> void:
	# Real terrain height and seeded canopy variation avoid lollipop-like
	# trees floating at y=0 on the outer ridge. Asset-independent proxy art.
	var terrain_noise := FastNoiseLite.new()
	terrain_noise.seed=114722
	terrain_noise.noise_type=FastNoiseLite.TYPE_SIMPLEX
	terrain_noise.frequency=0.015
	terrain_noise.fractal_octaves=4
	var branch := Node3D.new()
	branch.name="DroughtHardwoodTree_"+str(terrain_layer.get_child_count())
	branch.position = Vector3(point.x,WastelandDetail.terrain_height(point.x,point.z,terrain_noise),point.z)
	branch.scale = Vector3.ONE * scale
	terrain_layer.add_child(branch)
	# Narrow tapered trunk, visible irregular boughs and multi-layer crown.
	var trunk := _cylinder(branch, Vector3(0, 2.0, 0), 0.27, 4.0, materials["roof"], 0.11)
	trunk.name="TaperedHardwoodTrunk"
	var rng := RandomNumberGenerator.new()
	rng.seed=int(absf(point.x*431.0+point.z*673.0))+12091
	var foliage_mesh := SphereMesh.new()
	foliage_mesh.radius=0.5
	foliage_mesh.height=1.0
	foliage_mesh.radial_segments=7
	foliage_mesh.rings=5
	for limb in range(5):
		var angle: float=float(limb)/5.0*TAU+rng.randf_range(-0.18,0.18)
		var reach: float=rng.randf_range(1.2,2.2)
		var y: float=rng.randf_range(3.0,4.6)
		var at := Vector3(cos(angle)*reach*0.47,y,sin(angle)*reach*0.47)
		var woody := _cylinder(branch,at,0.115,reach*1.05,materials["rust"],0.045)
		woody.name="AngledCrownBranch_"+str(limb)
		woody.rotation.z=sin(angle)*0.68
		woody.rotation.x=cos(angle)*0.68
	# Branch silhouettes are not replaced by a few identical round spheres.
	for tuft in range(13):
		var bearing: float=float(tuft)/13.0*TAU+rng.randf_range(-0.42,0.42)
		var spread: float=rng.randf_range(0.45,2.30)
		var y: float=rng.randf_range(3.35,5.55)
		var leaf := MeshInstance3D.new()
		leaf.name="IrregularFoliageCluster_"+str(tuft)
		leaf.mesh=foliage_mesh
		leaf.position=Vector3(cos(bearing)*spread,y,sin(bearing)*spread)
		leaf.rotation_degrees=Vector3(rng.randf_range(-18.0,18.0),rng.randf_range(0.0,180.0),rng.randf_range(-18.0,18.0))
		leaf.scale=Vector3(rng.randf_range(1.25,1.95),rng.randf_range(0.85,1.75),rng.randf_range(0.92,1.45))
		leaf.material_override=materials["leaf"] if tuft%3==0 else materials["olive"]
		branch.add_child(leaf)

func _abandoned_vehicle(pos: Vector3) -> void:
	var group := Node3D.new()
	group.position = pos
	group.rotation.y = 0.38
	terrain_layer.add_child(group)
	_box(group, Vector3(0, 0.9, 0), Vector3(5.6, 1.0, 2.8), materials["rust"])
	_box(group, Vector3(0.0, 1.7, 0), Vector3(2.4, 0.8, 2.6), materials["darkmetal"])
	for dx in [-1.8, 1.8]:
		for dz in [-1.5, 1.5]:
			var tyre := _cylinder(group, Vector3(dx, 0.55, dz), 0.69, 0.29, materials["darkmetal"])
			tyre.rotation.x = PI/2.0
	_box(group, Vector3(-0.9, 1.76, -1.33), Vector3(1.25, 0.58, 0.09), materials["glass"])

func world_position(position_2d: Vector2) -> Vector3:
	return Vector3((position_2d.x - ORIGIN.x) * SCALE, 0, (position_2d.y - ORIGIN.y) * SCALE)

func game_position(point: Vector3) -> Vector2:
	return Vector2(point.x / SCALE + ORIGIN.x, point.z / SCALE + ORIGIN.y)

func _position_camera() -> void:
	if camera == null:
		return
	# Keep panning / tracking inside the traversable terrain corridor, while
	# the horizon continuation hides far-field perspective beyond the tile.
	focus.x=clampf(focus.x,-135.0,135.0)
	focus.z=clampf(focus.z,-135.0,135.0)
	var horizontal := camera_distance * cos(pitch)
	camera.position = focus + Vector3(sin(yaw) * horizontal, camera_distance * sin(pitch), cos(yaw) * horizontal)
	camera.look_at(focus, Vector3.UP)

func pan_screen(delta: Vector2) -> void:
	var sensitivity := camera_distance * 0.00145
	var right := Vector3(camera.global_transform.basis.x.x, 0, camera.global_transform.basis.x.z).normalized()
	var depth := Vector3(camera.global_transform.basis.z.x, 0, camera.global_transform.basis.z.z).normalized()
	focus -= right * delta.x * sensitivity
	focus -= depth * delta.y * sensitivity
	_position_camera()

func orbit_camera(delta: Vector2) -> void:
	yaw -= delta.x * 0.009
	pitch = clampf(pitch + delta.y * 0.005, deg_to_rad(29.0), deg_to_rad(78.0))
	_position_camera()

func zoom_camera(direction: float) -> void:
	camera_distance = clampf(camera_distance + direction * 7.0, 22.0, 150.0)
	_position_camera()

func focus_game(position: Vector2) -> void:
	focus = world_position(position)
	_position_camera()

func ground_at(screen: Vector2) -> Vector2:
	if camera == null:
		return ORIGIN
	var from := camera.project_ray_origin(screen)
	var ray := camera.project_ray_normal(screen)
	if absf(ray.y) < 0.0001:
		return ORIGIN
	var hit := from + ray * (-from.y / ray.y)
	return game_position(hit)

func screen_at(game_point: Vector2) -> Vector2:
	if camera == null:
		return Vector2.ZERO
	return camera.unproject_position(world_position(game_point))

func _layout_signature(sim: SettlementSimulation) -> String:
	var bits := PackedStringArray(["b%d" % sim.buildings.size(), "p%d" % sim.blueprints.size()])
	for building in sim.buildings:
		bits.append("%s:%s:%s" % [str(building["type"]), str(building["position"]), str(int(float(building["condition"]) / 20.0))])
	for blueprint in sim.blueprints:
		bits.append("plan:%s:%s" % [str(blueprint["id"]), str(blueprint["position"])])
	return "|".join(bits)

func sync(sim: SettlementSimulation, selected_building: Dictionary, selected_citizen: Dictionary, build_mode: bool, mouse_world: Vector2, build_definition: Dictionary, rotated: bool, delta: float, roof_mode: int = 0) -> void:
	visual_time += delta
	if cached_layout != _layout_signature(sim):
		cached_layout = _layout_signature(sim)
		_rebuild_structures(sim)
	_update_people(sim, selected_citizen)
	_update_roof_views(sim,selected_building,selected_citizen,roof_mode)
	_animate_entry_doors(sim,delta)
	_update_daylight(sim.hour)
	_update_facility_lamps(sim)
	_update_weather_environment(sim)
	weather_effects.update_weather(sim.weather_simulation.condition,sim.weather_simulation.intensity,focus,delta,sim.paused)
	_animate_machinery(delta, bool(sim.utility_state.get("power_online", true)) and not sim.paused)
	_animate_industry(delta, _industry_operating(sim) and not sim.paused)
	# Construction hologram updates without re-instantiating building meshes.
	if building_preview != null:
		building_preview.visible = build_mode
		if build_mode:
			building_preview.position = world_position(Vector2(round(mouse_world.x / 20.0)*20.0, round(mouse_world.y / 20.0)*20.0))
			var footprint: Vector2 = build_definition["size"]
			if rotated:
				footprint = Vector2(footprint.y, footprint.x)
			building_preview.scale = Vector3(maxf(0.15, footprint.x*SCALE), 0.12, maxf(0.15, footprint.y*SCALE))
			var good := sim.can_place_blueprint(Vector2(round(mouse_world.x/20.0)*20.0,round(mouse_world.y/20.0)*20.0), footprint)
			building_preview.material_override = materials["ghost"] if good else materials["cross"]

var building_preview: MeshInstance3D

func _rebuild_structures(sim: SettlementSimulation) -> void:
	animated_vent_fans.clear()
	industrial_yards.clear()
	for node in structure_layer.get_children():
		node.queue_free()
	for building in sim.buildings:
		_build_structure(building)
	for blueprint in sim.blueprints:
		var p := world_position(Vector2(blueprint["position"]))
		var size := Vector2(blueprint["size"]) * SCALE
		_box(structure_layer, p + Vector3(0, 0.06, 0), Vector3(size.x, 0.09, size.y), materials["ghost"])
	if building_preview != null:
		building_preview.queue_free()
	building_preview = MeshInstance3D.new()
	var preview_mesh := BoxMesh.new()
	preview_mesh.size = Vector3.ONE
	building_preview.mesh = preview_mesh
	building_preview.material_override = materials["ghost"]
	structure_layer.add_child(building_preview)
	building_preview.visible = false

func _try_authored_model(parent: Node3D, model_path: String, footprint: Vector2 = Vector2.ONE) -> bool:
	# This is a production-art extension point. An authored .glb scene supersedes
	# primitive geometry on the next export, with no change to game saves.
	if not ResourceLoader.exists(model_path):
		return false
	var scene := load(model_path) as PackedScene
	if scene == null:
		push_warning("Invalid production model: " + model_path)
		return false
	var model := scene.instantiate() as Node3D
	if model == null:
		push_warning("Model root must be Node3D: " + model_path)
		return false
	# Imported scenes may contain placeholder mesh nodes with no resource.
	# Disable those while detached; adding them to the live viewport first
	# lets the renderer register them and emit null-mesh errors.
	SettlementAuthenticModel3D._disable_empty_renderers(model)
	parent.add_child(model)
	# Authored source models use meters, ground origin, forward -Z, and footprints
	# consistent with game building plans. Scale is authored in Blender/glTF.
	model.name = "ProductionArt"
	return true

func _build_structure(b: Dictionary) -> void:
	var type := str(b["type"])
	var p := world_position(Vector2(b["position"]))
	var size := Vector2(b["size"]) * SCALE
	var group := Node3D.new()
	group.position = p
	group.name = str(b["name"])
	structure_layer.add_child(group)
	group.set_meta("building_key",SettlementNavigation.building_key(b))
	group.set_meta("building_type",type)
	var authored_scene := "res://assets/3d/structures/%s.glb" % type
	if _try_authored_model(group, authored_scene, size):
		# Exterior gameplay props remain active even after installing a licensed
		# replacement for the structure's architectural model.
		if type=="industry":
			industrial_yards.append(SettlementIndustry3D.build(group,size,materials))
		return
	# Walls, flooring, pipes and utility poles remain independent modular pieces.
	if type in ["wall","floor","door","pipe","power_pole"]:
		var material: Material = materials["pipe"] if type in ["pipe","power_pole"] else materials["concrete"]
		_box(group, Vector3(0,0.35,0), Vector3(size.x, 0.7, size.y), material)
		return
	var body_height := 2.8
	if type in ["command","industry","power","generator"]:
		body_height = 4.4
	elif type in ["housing", "medical"]:
		body_height = 3.8
	elif type == "farm":
		_build_farm(group,size)
		return
	_box(group, Vector3(0, 0.11, 0), Vector3(size.x+0.6,0.2,size.y+0.6), materials["foundation"])
	var body_mat: Material = materials["wall"]
	if type in ["industry","power","generator","sewage"]:
		body_mat = materials["steel"]
	elif type in ["water","water_pump","purifier","water_tank"]:
		body_mat = materials["rooflight"]
	elif type == "command":
		body_mat = materials["concrete"]
	# No solid monolithic cube: a four-sided shell with a front doorway,
	# recessed access door, pitched/industrial roof and separate cladding.
	SettlementArchitecture3D.facade(group, type, size, body_height, body_mat, materials)
	# Physical furniture remains inside the shell; roofs can reveal it on demand.
	SettlementInteriors3D.populate(group,type,size,materials)
	SettlementWorldReadability3D.decorate(group,b,size,body_height,materials)
	SettlementFidelity3D.exterior(group,type,size,body_height,float(b.get("condition",100.0)),materials)
	SettlementReferenceEnvironment3D.detail_facility(group,type,size,materials,body_height)
	SettlementAgedFacade3D.decorate(group,type,size,body_height,materials)
	SettlementProductionProps3D.decorate_facility(group,type,size,materials)
	SettlementAuthenticModel3D.build_facility(group,type,size)
	if type == "command":
		_cylinder(group, Vector3(0,body_height+1.28,0),2.0,1.3,materials["darkmetal"])
		_cylinder(group, Vector3(0,body_height+2.0,0),1.6,0.18,materials["glass"])
		_cylinder(group, Vector3(0,body_height+3.6,0),0.07,3.0,materials["steel"])
		_sphere(group, Vector3(0,body_height+5.0,0),0.25,materials["warning"])
		# A readable settlement name, rather than a simulated corporate ID:
		# real 3D plaque mounted above the command entrance.
		_box(group,Vector3(0,3.23,-size.y*0.5-0.36),Vector3(5.15,0.65,0.18),materials["darkmetal"])
		_box(group,Vector3(0,2.88,-size.y*0.5-0.38),Vector3(5.15,0.09,0.19),materials["cross"])
		var identity := Label3D.new()
		identity.name="LastHavenPhysicalSign"
		identity.visible=false # HUD provides GL-safe label typography.
		identity.text="DPN  /  LAST HAVEN"
		identity.font_size=30
		identity.pixel_size=0.011
		identity.modulate=Color("#e7dfd5")
		identity.position=Vector3(0,3.22,-size.y*0.5-0.50)
		identity.rotation.y=PI
		group.add_child(identity)
	elif type == "medical":
		_box(group,Vector3(0,body_height+0.62,0),Vector3(0.82,0.09,3.0),materials["cross"])
		_box(group,Vector3(0,body_height+0.63,0),Vector3(3.0,0.09,0.82),materials["cross"])
	elif type in ["industry","storage"]:
		for i in range(3):
			_box(group,Vector3(-size.x*0.25 + float(i)*size.x*0.25,body_height+0.83,0),Vector3(1.65,0.9,1.4),materials["rust"])
	elif type in ["power","generator","battery"]:
		for i in [-1.0,1.0]:
			var fan := _cylinder(group,Vector3(i*size.x*0.21,body_height+0.72,0),1.3,0.52,materials["darkmetal"])
			var blades := Node3D.new()
			blades.name = "VentFanRotor"
			blades.position = Vector3(i*size.x*0.21,body_height+1.05,0)
			group.add_child(blades)
			_box(blades,Vector3.ZERO,Vector3(2.0,0.14,0.23),materials["steel"])
			_box(blades,Vector3.ZERO,Vector3(0.23,0.14,2.0),materials["steel"])
			_cylinder(blades,Vector3(0,0.14,0),0.28,0.20,materials["rooflight"])
			animated_vent_fans.append(blades)
	elif type in ["water","water_pump","purifier","water_tank","sewage"]:
		for i in [-1.0,1.0]:
			_cylinder(group,Vector3(i*size.x*0.20,body_height+1.15,0),1.8,1.65,materials["blue"])
			_cylinder(group,Vector3(i*size.x*0.20,body_height+2.02,0),1.76,0.12,materials["glass"])
		_box(group,Vector3(0,body_height+0.8,0),Vector3(1.2,0.4,size.y*0.65),materials["pipe"])
	WastelandDetail.detail_building(group,type,size,body_height,float(b.get("condition",100.0)),materials)
	if type=="industry":
		industrial_yards.append(SettlementIndustry3D.build(group,size,materials))
	if float(b.get("condition",100.0)) < 60.0:
		_box(group,Vector3(size.x*0.35,body_height+0.63,0),Vector3(2.0,0.17,1.1),materials["rust"])
	# Roof-top vents, ducts and signage can otherwise float after cutaway.
	for detail in group.get_children():
		if detail is MeshInstance3D and detail.position.y>body_height+0.46:
			detail.set_meta("cutaway_roof",true)

func _update_facility_lamps(sim: SettlementSimulation) -> void:
	var day := clampf(sin((sim.hour-6.0)/12.0*PI),0.0,1.0)
	var darkness := clampf(1.0-day*2.0,0.0,1.0)
	var powered := bool(sim.utility_state.get("power_online",true))
	var environmental: Node3D=terrain_layer.get_node_or_null("ReferenceQualityWorldDressing") as Node3D
	if environmental!=null:
		for post in environmental.get_children():
			var work_light: OmniLight3D=post.get_node_or_null("ReferenceWorkLight") as OmniLight3D
			if work_light==null:
				work_light=post.get_node_or_null("WarmCampLighting_0/ReferenceWorkLight") as OmniLight3D
			if work_light!=null:
				# A small emergency lamp glow remains under power shortfall, while
				# normal powered illumination follows time of day.
				work_light.light_energy=(0.50+0.25*darkness) if powered else 0.12
	for group in structure_layer.get_children():
		if group.is_queued_for_deletion():
			continue
		var lamp := group.get_node_or_null("ExteriorDoorLight") as OmniLight3D
		if lamp!=null:
			lamp.light_energy=(0.07+0.82*darkness) if powered else 0.0

func _update_roof_views(sim: SettlementSimulation, selected_building: Dictionary, selected_citizen: Dictionary, roof_mode: int) -> void:
	cutaway_views=0
	var focus_key := "" if selected_building.is_empty() else SettlementNavigation.building_key(selected_building)
	var selected_location := Vector2.ZERO if selected_citizen.is_empty() else Vector2(selected_citizen["position"])
	for group in structure_layer.get_children():
		if group.is_queued_for_deletion() or not group.has_meta("building_key"):
			continue
		var key := str(group.get_meta("building_key"))
		var reveal := roof_mode==1 or (roof_mode==0 and key==focus_key)
		if roof_mode==0 and not selected_citizen.is_empty():
			for b in sim.buildings:
				if SettlementNavigation.building_key(b)==key:
					var area := Rect2(Vector2(b["position"])-Vector2(b["size"])*0.5,Vector2(b["size"]))
					reveal=reveal or area.has_point(selected_location)
					break
		if reveal:
			cutaway_views+=1
		for piece in group.get_children():
			if piece.has_meta("cutaway_roof"):
				piece.visible=not reveal
		var furniture := group.get_node_or_null("InteriorFurnishings")
		if furniture!=null:
			furniture.visible=reveal

func _animate_entry_doors(sim: SettlementSimulation, delta: float) -> void:
	for b in sim.buildings:
		if not SettlementNavigation._is_solid(b):
			continue
		var group: Node3D=null
		var key := SettlementNavigation.building_key(b)
		for candidate in structure_layer.get_children():
			if not candidate.is_queued_for_deletion() and str(candidate.get_meta("building_key",""))==key:
				group=candidate
				break
		if group==null:
			continue
		var hinge := group.get_node_or_null("EntryDoorPivot") as Node3D
		if hinge==null:
			continue
		var doorstep := Vector2(SettlementNavigation.access_points(b,0)["threshold"])
		var opening := false
		for c in sim.citizens:
			if not bool(c.get("alive",false)) or bool(c.get("on_expedition",false)):
				continue
			if Vector2(c["position"]).distance_squared_to(doorstep)<18.0*18.0:
				opening=true
				break
		hinge.rotation.y=lerp_angle(hinge.rotation.y,-1.30 if opening else 0.0,clampf(delta*5.5,0.0,1.0))

func _build_farm(group: Node3D, size: Vector2) -> void:
	_box(group, Vector3(0,0.08,0),Vector3(size.x,0.17,size.y),materials["soil"])
	for row in range(6):
		var x := -size.x*0.38 + float(row)*size.x*0.15
		_box(group,Vector3(x,0.2,0),Vector3(0.95,0.27,size.y*0.82),materials["farm"])
	SettlementDetailArt3D.create_crops(group,size,materials)
	WastelandDetail.detail_farm(group,size,materials)

func _update_people(sim: SettlementSimulation, selected_citizen: Dictionary) -> void:
	var alive_ids: Dictionary = {}
	for citizen in sim.citizens:
		# A survivor on a regional expedition must no longer be drawn inside
		# Last Haven while simultaneously marked as being away in the roster.
		if not bool(citizen["alive"]) or bool(citizen.get("on_expedition",false)) or str(citizen.get("home_settlement","LAST_HAVEN")) != "LAST_HAVEN":
			continue
		var id := str(citizen["id"])
		alive_ids[id] = true
		if not people.has(id):
			people[id] = _make_survivor(citizen)
		var person: Node3D = people[id]
		var previous := person.position
		var target := world_position(Vector2(citizen["position"]))
		var traveling := previous.distance_to(target) > 0.02 and not sim.paused
		person.position = target
		if traveling:
			person.rotation.y = atan2(person.position.x-previous.x,person.position.z-previous.z)
		_animate_survivor(person, traveling, int(citizen["id"]), citizen, sim.paused)
		SettlementActivity3D.update(person,citizen,traveling,sim.paused,visual_time)
		var ring: Node3D = person.get_node("Selection")
		ring.visible = selected_citizen == citizen
	for id in people.keys():
		if not alive_ids.has(id):
			var person: Node3D = people[id]
			person.queue_free()
			people.erase(id)

func _make_survivor(c: Dictionary) -> Node3D:
	var person := Node3D.new()
	person.name = "Survivor_%s" % str(c["id"])
	survivors_layer.add_child(person)
	if _try_authored_model(person, "res://assets/3d/characters/survivor.glb"):
		# Correct the imported human's world scale and material. The original
		# CC0 rig otherwise appears as a glowing white mannequin next to huts.
		SurvivorVisuals3D.prepare(person.get_node("ProductionArt"), person, c, materials)
		# Selection node remains part of the gameplay layer, not the art asset.
		var art_selection := Node3D.new()
		art_selection.name = "Selection"
		person.add_child(art_selection)
		# A thin ground outline keeps the actual character visible; the old
		# bright solid disc obscured shoes and surrounding terrain.
		var outline_mesh := TorusMesh.new()
		outline_mesh.inner_radius = 0.64
		outline_mesh.outer_radius = 0.71
		outline_mesh.rings = 6
		outline_mesh.ring_segments = 24
		var outline := MeshInstance3D.new()
		outline.name = "SelectionOutline"
		outline.mesh = outline_mesh
		outline.material_override = materials["warning"]
		outline.position = Vector3(0, 0.055, 0)
		art_selection.add_child(outline)
		art_selection.visible = false
		SettlementActivity3D.attach(person,materials)
		return person
	SettlementDetailArt3D.create_survivor(person, c, materials)
	var select := Node3D.new()
	select.name = "Selection"
	person.add_child(select)
	var selected_mesh := TorusMesh.new()
	selected_mesh.inner_radius = 0.82
	selected_mesh.outer_radius = 0.90
	selected_mesh.rings = 8
	selected_mesh.ring_segments = 24
	var selected_ring := MeshInstance3D.new()
	selected_ring.mesh = selected_mesh
	selected_ring.material_override = materials["warning"]
	selected_ring.position = Vector3(0, 0.07, 0)
	select.add_child(selected_ring)
	select.visible = false
	SettlementActivity3D.attach(person,materials)
	return person

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

func _animate_imported_survivor(person: Node3D, traveling: bool) -> void:
	var imported := person.get_node_or_null("ProductionArt")
	if imported == null:
		return
	var player := _find_animation_player(imported)
	if player == null:
		return
	var preferred := "walk" if traveling else "idle"
	var fallback := ""
	var chosen := ""
	for clip in player.get_animation_list():
		var name := String(clip).to_lower()
		if fallback.is_empty():
			fallback = String(clip)
		if preferred in name:
			chosen = String(clip)
			break
	if chosen.is_empty():
		chosen = fallback
	if not chosen.is_empty() and player.current_animation != chosen:
		player.play(chosen, 0.2)

func _animate_survivor(person: Node3D, traveling: bool, id: int, citizen: Dictionary, paused: bool) -> void:
	if not person.has_node("ArmLeft"):
		_animate_imported_survivor(person, traveling)
		return
	var stride := 0.0
	if traveling:
		stride = sin(visual_time * 7.5 + float(id) * 0.68) * 0.44
	elif not paused and SettlementActivity3D.current_activity(citizen)!="":
		# Low amplitude hand-work cycle for the procedural rig; unlike walking,
		# legs remain planted while harvesting, carrying, treating or crafting.
		stride = sin(visual_time * 3.0 + float(id) * 0.68) * 0.19
	var left_arm := person.get_node("ArmLeft") as Node3D
	var right_arm := person.get_node("ArmRight") as Node3D
	var left_leg := person.get_node("LegLeft") as Node3D
	var right_leg := person.get_node("LegRight") as Node3D
	left_arm.rotation.x = stride
	right_arm.rotation.x = -stride
	left_leg.rotation.x = -stride * 0.60 if traveling else 0.0
	right_leg.rotation.x = stride * 0.60 if traveling else 0.0
	person.position.y = absf(stride) * 0.12 if traveling else 0.0

func _animate_machinery(delta: float, active: bool) -> void:
	if not active:
		return
	for rotor in animated_vent_fans:
		if is_instance_valid(rotor):
			rotor.rotation.y += delta * 2.8

func _industry_operating(sim: SettlementSimulation) -> bool:
	var eco := sim.economy_simulation
	if eco.production_paused:
		return false
	var active := false
	for batch in eco.production_queue:
		if str(batch.get("status",""))=="working":
			active=true
			break
	if not active:
		return false
	var workshops := 0
	for building in sim.buildings:
		if str(building.get("type",""))=="industry":
			workshops+=1
	if workshops==0:
		return false
	for person in sim.get_settlement_citizens():
		if str(person.get("job","")) not in ["Engineer","Builder"]:
			continue
		if int(person.get("age",0))<18 or bool(person.get("incarcerated",false)):
			continue
		if float(person.get("health",0.0))<30.0 or not sim.is_selected_work_enabled(person):
			continue
		if sim._is_shift_active(person):
			return true
	return false

func _animate_industry(delta: float, active: bool) -> void:
	if active:
		industry_cycle+=delta*3.2
	for yard in industrial_yards:
		var ram: Node3D=yard["ram"]
		var carrier: Node3D=yard["carrier"]
		var run_lamp: MeshInstance3D=yard["running_light"]
		var idle_lamp: MeshInstance3D=yard["idle_light"]
		if not is_instance_valid(ram) or not is_instance_valid(carrier):
			continue
		# Pausing preserves the exact mechanism position until work resumes.
		ram.position.y=2.04+0.30*sin(industry_cycle*1.8)
		carrier.position.x=-2.1+fposmod(industry_cycle*0.44,1.8)
		run_lamp.visible=active
		idle_lamp.visible=not active
