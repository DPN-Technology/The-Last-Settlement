class_name SettlementWeather3D
extends Node3D

# A bounded GPU-instanced volume of visible airborne grit. Each streak uses
# one draw call through a MultiMesh rather than individual particle nodes.
# The effect is cosmetic, follows camera focus and has no physics collision.
const GRAIN_COUNT := 126
const FIELD_RADIUS := 35.0

var dust: MultiMeshInstance3D
var dust_time := 0.0
var gust_strength := 0.0

func _ready() -> void:
	name="AtmosphereAndDust"
	var grains := MultiMesh.new()
	grains.transform_format=MultiMesh.TRANSFORM_3D
	var grain_mesh := BoxMesh.new()
	grain_mesh.size=Vector3(1.1,0.027,0.045)
	var plume := StandardMaterial3D.new()
	plume.albedo_color=Color(0.74,0.64,0.49,0.22)
	plume.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	plume.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	plume.cull_mode=BaseMaterial3D.CULL_DISABLED
	grain_mesh.material=plume
	grains.mesh=grain_mesh
	grains.instance_count=GRAIN_COUNT
	dust=MultiMeshInstance3D.new()
	dust.name="MovingDustVolume"
	dust.multimesh=grains
	add_child(dust)
	dust.visible=false
	_place_grains(Vector3.ZERO,0.0)

func _fraction(value: float) -> float:
	return value-floorf(value)

func _place_grains(center: Vector3, clock: float) -> void:
	if dust==null:
		return
	for i in range(GRAIN_COUNT):
		var seed := float(i)+1.0
		# Irrational step sequences avoid randomness per frame and repeat
		# seamlessly around the focus after leaving the visible field.
		var x := (_fraction(seed*0.618034+clock*0.036)*2.0-1.0)*FIELD_RADIUS
		var z := (_fraction(seed*0.754877+clock*0.012)*2.0-1.0)*FIELD_RADIUS
		var y := 0.5+_fraction(seed*0.43858)*7.5
		var transform := Transform3D(Basis.IDENTITY,center+Vector3(x,y,z))
		transform.basis=Basis(Vector3.UP,-0.10+0.20*_fraction(seed*0.34))
		dust.multimesh.set_instance_transform(i,transform)

func update_weather(condition: String, intensity: float, focus_point: Vector3, delta: float, paused: bool) -> void:
	var storming := condition=="DUST STORM" and intensity>0.0
	gust_strength=intensity if storming else 0.0
	if dust==null:
		return
	dust.visible=storming
	if not storming:
		return
	if not paused:
		dust_time+=delta*(0.8+1.3*intensity)
	_place_grains(focus_point,dust_time)
