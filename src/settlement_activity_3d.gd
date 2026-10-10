class_name SettlementActivity3D
extends RefCounted

# Lightweight attached activity props. Visibility follows CURRENT simulation
# actions, not profession labels. These indicate duty without claiming full
# hand IK, task-specific motion capture, or walkable building interiors.

static func _box(parent: Node3D, name: String, position: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var visual := MeshInstance3D.new()
	visual.name = name
	visual.mesh = mesh
	visual.position = position
	visual.material_override = material
	parent.add_child(visual)
	return visual

static func _cylinder(parent: Node3D, name: String, position: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius=radius
	mesh.top_radius=radius
	mesh.height=height
	var visual := MeshInstance3D.new()
	visual.name=name
	visual.mesh=mesh
	visual.position=position
	visual.material_override=material
	parent.add_child(visual)
	return visual

static func attach(person: Node3D, mats: Dictionary) -> void:
	var duty := Node3D.new()
	duty.name = "LiveDutyEquipment"
	person.add_child(duty)
	# Single low-cost tool near the right hand, coherent at distant RTS zoom.
	var tool := Node3D.new()
	tool.name = "Construction"
	tool.position = Vector3(0.55,0.96,-0.16)
	duty.add_child(tool)
	_box(tool,"HandledWrench",Vector3(0,0.25,0),Vector3(0.09,0.65,0.10),mats["steel"])
	_box(tool,"OpenEndedWrenchJaw",Vector3(0,0.61,0),Vector3(0.28,0.11,0.13),mats["rust"])

	var field := Node3D.new()
	field.name = "Farming"
	field.position = Vector3(0.56,0.84,-0.13)
	duty.add_child(field)
	_cylinder(field,"HoeHandle",Vector3(0,0.55,0),0.045,1.4,mats["canvas"])
	_box(field,"SoilHoeBlade",Vector3(0,1.26,-0.22),Vector3(0.47,0.13,0.24),mats["steel"])

	var aid := Node3D.new()
	aid.name = "Medical"
	aid.position = Vector3(0.43,0.96,-0.16)
	duty.add_child(aid)
	_box(aid,"FirstAidSatchel",Vector3(0,0.02,0),Vector3(0.52,0.42,0.24),mats["clinic"])
	_box(aid,"MedicRedVertical",Vector3(0,0.03,-0.13),Vector3(0.07,0.27,0.025),mats["cross"])
	_box(aid,"MedicRedHorizontal",Vector3(0,0.03,-0.14),Vector3(0.26,0.07,0.025),mats["cross"])

	var radio := Node3D.new()
	radio.name = "Security"
	radio.position = Vector3(0.52,1.02,-0.18)
	duty.add_child(radio)
	_box(radio,"RadioBody",Vector3.ZERO,Vector3(0.23,0.38,0.15),mats["darkmetal"])
	_cylinder(radio,"RadioAntenna",Vector3(0.08,0.33,0),0.025,0.42,mats["steel"])

	var cargo := Node3D.new()
	cargo.name = "Hauling"
	cargo.position = Vector3(0.45,0.94,-0.16)
	duty.add_child(cargo)
	_box(cargo,"SalvagedSupplyBox",Vector3.ZERO,Vector3(0.48,0.43,0.46),mats["canvas"])
	_box(cargo,"StrappedCargo",Vector3(0,0.02,-0.238),Vector3(0.12,0.45,0.025),mats["webbing"])

	var skillet := Node3D.new()
	skillet.name = "Cooking"
	skillet.position = Vector3(0.46,1.04,-0.14)
	duty.add_child(skillet)
	_cylinder(skillet,"CookPan",Vector3(0,0,0),0.28,0.10,mats["steel"])
	_box(skillet,"PanHandle",Vector3(0.42,0,0),Vector3(0.55,0.09,0.08),mats["darkmetal"])

	for child in duty.get_children():
		(child as Node3D).visible=false

static func current_activity(citizen: Dictionary) -> String:
	var action := str(citizen.get("current_action",""))
	if action.begins_with("Build:") or action=="Work: Construction":
		return "Construction"
	if action=="Work: Farming":
		return "Farming"
	if action=="Work: Medical" or action=="Seek Treatment":
		return "Medical"
	if action=="Patrol":
		return "Security"
	if action=="Haul Supplies" or action=="Scavenge":
		return "Hauling"
	if action=="Prepare Meals":
		return "Cooking"
	if action=="Work: Engineering":
		return "Construction"
	if action.begins_with("Order: "):
		match str(citizen.get("job","")):
			"Farmer": return "Farming"
			"Medic": return "Medical"
			"Guard": return "Security"
			"Cook": return "Cooking"
			"Hauler", "Scavenger": return "Hauling"
			"Engineer", "Builder": return "Construction"
	return ""

static func update(person: Node3D, citizen: Dictionary, traveling: bool, paused: bool, clock: float) -> void:
	var duty := person.get_node_or_null("LiveDutyEquipment")
	if duty==null:
		return
	var current := "" if traveling or bool(citizen.get("on_expedition",false)) or bool(citizen.get("incarcerated",false)) else current_activity(citizen)
	for child in duty.get_children():
		var prop := child as Node3D
		prop.visible=prop.name==current and current!=""
		if prop.visible:
			# Freeze small work motions on pause; never move when off duty.
			prop.rotation.z = 0.0 if paused else 0.085*sin(clock*3.0+float(citizen.get("id",0))*0.45)
