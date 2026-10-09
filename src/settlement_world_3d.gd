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
var command_lamp: OmniLight3D
var prior_lighting_hour := -10.0
var structure_layer: Node3D
var survivors_layer: Node3D
var terrain_layer: Node3D
var focus := Vector3(4.0, 0.0, 2.0)
var camera_distance := 48.0
var yaw := 0.0
var pitch := deg_to_rad(44.0)
var cached_layout := ""
var last_daylight := -1
var people: Dictionary = {}
var animated_vent_fans: Array[Node3D] = []
var materials: Dictionary = {}
var selected_key := ""
var visual_time := 0.0

func _ready() -> void:
	_create_materials()
	_create_environment()
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
	_mat("skin", Color("#a88e71"))
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
	world_environment.background_mode = Environment.BG_SKY
	world_environment.sky = sky
	world_environment.background_energy_multiplier = 0.25
	world_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_environment.ambient_light_color = Color("#7c8a91")
	world_environment.ambient_light_energy = 0.24
	world_environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	world_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.tonemap_exposure = 0.76
	world_environment.fog_enabled = true
	world_environment.fog_light_color = Color("#5c615b")
	world_environment.fog_density = 0.0018
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
	var twilight := clampf(1.0 - absf(hour - 18.0) / 3.5, 0.0, 1.0)
	light.light_energy = lerpf(0.03, 0.94, daylight)
	light.light_color = Color("#f5c293").lerp(Color("#e0e6ea"), daylight * 0.64)
	light.rotation_degrees = Vector3(-18.0 - daylight * 53.0, 35.0 + hour * 4.0, -3.0)
	world_environment.ambient_light_energy = lerpf(0.105, 0.32, daylight)
	world_environment.background_energy_multiplier = lerpf(0.09, 0.25, daylight)
	world_environment.ambient_light_color = Color("#35465c").lerp(Color("#82939a"), daylight)
	world_environment.fog_light_color = Color("#202d36").lerp(Color("#6c6d63"), daylight)
	sky_material.sky_top_color = Color("#0d1b2a").lerp(Color("#3b5566"), daylight)
	sky_material.sky_horizon_color = Color("#222c3a").lerp(Color("#9d9788"), daylight)
	command_lamp.light_energy = lerpf(1.7, 0.0, daylight) + twilight * 0.14

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
	# Render opaque ground before decorative roads. These underlays are a safety
	# net if a GPU drops the procedural heightfield; never expose the sky below.
	var fallback_outer := MeshInstance3D.new()
	fallback_outer.name = "GroundFailsafeOuter"
	var outer_mesh := PlaneMesh.new()
	outer_mesh.size = Vector2(360.0, 360.0)
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

	# Graveled settlement access. Physical 3D roads and lane marking strips.
	_road(Vector3(-87, 0, 5), Vector3(-9, 0, 5), 8.4)
	_road(Vector3(-9, 0, 5), Vector3(42, 0, 5), 5.0)
	_road(Vector3(0, 0, -19), Vector3(0, 0, 30), 4.4)
	for index in range(13):
		var x := -82.0 + float(index) * 5.6
		_box(terrain_layer, Vector3(x, 0.065, 5), Vector3(2.0, 0.012, 0.08), materials["stripe"])
	
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

func _road(a: Vector3, b: Vector3, width: float) -> void:
	var delta := b - a
	var segment := _box(terrain_layer, (a+b)*0.5 + Vector3(0, 0.045, 0), Vector3(delta.length(), 0.07, width), materials["asphalt"])
	segment.rotation.y = -atan2(delta.z, delta.x)

func _tree(point: Vector3, scale: float) -> void:
	var branch := Node3D.new()
	branch.position = point
	branch.scale = Vector3.ONE * scale
	terrain_layer.add_child(branch)
	_cylinder(branch, Vector3(0, 1.9, 0), 0.23, 3.8, materials["roof"], 0.11)
	for p in [Vector3(-1.1, 4.1, 0), Vector3(0.7, 4.5, 0.3), Vector3(0, 5.1, -0.7)]:
		_sphere(branch, p, 1.55, materials["olive"])

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

func sync(sim: SettlementSimulation, selected_building: Dictionary, selected_citizen: Dictionary, build_mode: bool, mouse_world: Vector2, build_definition: Dictionary, rotated: bool, delta: float) -> void:
	visual_time += delta
	if cached_layout != _layout_signature(sim):
		cached_layout = _layout_signature(sim)
		_rebuild_structures(sim)
	_update_people(sim, selected_citizen)
	_update_daylight(sim.hour)
	_animate_machinery(delta, bool(sim.utility_state.get("power_online", true)) and not sim.paused)
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
	var authored_scene := "res://assets/3d/structures/%s.glb" % type
	if _try_authored_model(group, authored_scene, size):
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
	_box(group, Vector3(0,body_height*0.5+0.2,0), Vector3(size.x,body_height,size.y),body_mat)
	# Flat weathered roofs become distinctive mechanical surfaces, not labels.
	_box(group, Vector3(0,body_height+0.38,0), Vector3(size.x+0.8,0.35,size.y+0.8), materials["roof"])
	for xdir in [-1.0,1.0]:
		_box(group, Vector3(xdir*(size.x/2.0-0.7),body_height*0.6+0.2,-size.y/2.0-0.05), Vector3(1.2,0.85,0.15), materials["glass"])
	_box(group, Vector3(0,1.4,-size.y/2.0-0.15), Vector3(1.7,2.6,0.18), materials["darkmetal"])
	_box(group, Vector3(0,3.3,-size.y/2.0-0.22), Vector3(1.8,0.16,0.2), materials["glow"])
	if type == "command":
		_cylinder(group, Vector3(0,body_height+1.28,0),2.0,1.3,materials["darkmetal"])
		_cylinder(group, Vector3(0,body_height+2.0,0),1.6,0.18,materials["glass"])
		_cylinder(group, Vector3(0,body_height+3.6,0),0.07,3.0,materials["steel"])
		_sphere(group, Vector3(0,body_height+5.0,0),0.25,materials["warning"])
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
	elif type == "housing":
		for i in [-1.0,1.0]:
			_box(group,Vector3(i*size.x*0.23,body_height+0.86,0),Vector3(2.5,1.1,2.4),materials["rooflight"])
	WastelandDetail.detail_building(group,type,size,body_height,float(b.get("condition",100.0)),materials)
	if float(b.get("condition",100.0)) < 60.0:
		_box(group,Vector3(size.x*0.35,body_height+0.63,0),Vector3(2.0,0.17,1.1),materials["rust"])

func _build_farm(group: Node3D, size: Vector2) -> void:
	_box(group, Vector3(0,0.08,0),Vector3(size.x,0.17,size.y),materials["soil"])
	for row in range(6):
		var x := -size.x*0.38 + float(row)*size.x*0.15
		_box(group,Vector3(x,0.2,0),Vector3(0.95,0.27,size.y*0.82),materials["farm"])
		for j in range(9):
			var z := -size.y*0.4 + float(j)*size.y*0.1
			_sphere(group,Vector3(x,0.5,z),0.25,materials["leaf"])
	WastelandDetail.detail_farm(group,size,materials)

func _update_people(sim: SettlementSimulation, selected_citizen: Dictionary) -> void:
	var alive_ids: Dictionary = {}
	for citizen in sim.citizens:
		if not bool(citizen["alive"]) or str(citizen.get("home_settlement","LAST_HAVEN")) != "LAST_HAVEN":
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
		_animate_survivor(person, traveling, int(citizen["id"]))
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
		# Selection node remains part of the gameplay layer, not the art asset.
		var art_selection := Node3D.new()
		art_selection.name = "Selection"
		person.add_child(art_selection)
		_cylinder(art_selection, Vector3(0, 0.05, 0), 0.95, 0.08, materials["warning"])
		art_selection.visible = false
		return person
	var uniform: Material = materials["uniform"]
	match str(c["job"]):
		"Guard": uniform=materials["rust"]
		"Medic": uniform=materials["clinic"]
		"Engineer","Builder": uniform=materials["warning"]
		"Scavenger": uniform=materials["denim"]
		"Farmer": uniform=materials["olive"]
	_cylinder(person,Vector3(0,1.20,0),0.37,1.1,uniform,0.25)
	_sphere(person,Vector3(0,1.95,0),0.31,materials["skin"])
	var left_leg := _box(person,Vector3(-0.25,0.4,0),Vector3(0.28,0.80,0.39),materials["darkmetal"])
	left_leg.name = "LegLeft"
	var right_leg := _box(person,Vector3(0.25,0.4,0),Vector3(0.28,0.80,0.39),materials["darkmetal"])
	right_leg.name = "LegRight"
	for dir in [-1.0,1.0]:
		var limb := _cylinder(person,Vector3(dir*0.48,1.27,0),0.14,0.9,uniform)
		limb.name = "ArmLeft" if dir < 0.0 else "ArmRight"
	_box(person,Vector3(0,1.5,0.39),Vector3(0.55,0.55,0.28),materials["roof"])
	# Pockets, vest webbing, headlamp and tool roll make jobs legible at zoom.
	_box(person,Vector3(-0.25,1.31,-0.35),Vector3(0.2,0.25,0.08),materials["rust"])
	_box(person,Vector3(0.25,1.31,-0.35),Vector3(0.2,0.25,0.08),materials["rust"])
	_box(person,Vector3(0,2.18,-0.15),Vector3(0.46,0.11,0.45),materials["darkmetal"])
	_box(person,Vector3(0,2.17,-0.4),Vector3(0.13,0.12,0.09),materials["glow"])
	var select := Node3D.new()
	select.name = "Selection"
	person.add_child(select)
	_cylinder(select,Vector3(0,0.05,0),0.95,0.08,materials["warning"])
	select.visible = false
	return person

func _animate_survivor(person: Node3D, traveling: bool, id: int) -> void:
	if not person.has_node("ArmLeft"):
		return # An imported rig is driven by its own AnimationTree.
	var stride := 0.0
	if traveling:
		stride = sin(visual_time * 7.5 + float(id) * 0.68) * 0.44
	var left_arm := person.get_node("ArmLeft") as Node3D
	var right_arm := person.get_node("ArmRight") as Node3D
	var left_leg := person.get_node("LegLeft") as Node3D
	var right_leg := person.get_node("LegRight") as Node3D
	left_arm.rotation.x = stride
	right_arm.rotation.x = -stride
	left_leg.rotation.x = -stride * 0.60
	right_leg.rotation.x = stride * 0.60
	person.position.y = absf(stride) * 0.12 if traveling else 0.0

func _animate_machinery(delta: float, active: bool) -> void:
	if not active:
		return
	for rotor in animated_vent_fans:
		if is_instance_valid(rotor):
			rotor.rotation.y += delta * 2.8
