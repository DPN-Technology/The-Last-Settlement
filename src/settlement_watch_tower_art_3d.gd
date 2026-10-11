class_name SettlementWatchTowerArt3D
extends RefCounted

# Rebuild the prototype watchtower silhouettes into weathered lookout stations.
# Existing watchtower object and surveillance regions remain unchanged.

static func box(parent: Node3D, name: String, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name=name+"_"+str(parent.get_child_count())
	node.position=pos
	var mesh := BoxMesh.new()
	mesh.size=size
	node.mesh=mesh
	node.material_override=mat
	parent.add_child(node)
	return node

static func _beam(parent: Node3D, name: String, begin: Vector3, end: Vector3, radius: float, mat: Material) -> void:
	var direction := end-begin
	var beam := box(parent,name,(begin+end)*0.5,Vector3(radius,direction.length(),radius),mat)
	beam.quaternion=Quaternion(Vector3.UP,direction.normalized())

static func _deck(parent: Node3D, mats: Dictionary) -> void:
	for plank in range(9):
		var depth: float=-2.12+float(plank)*0.53
		box(parent,"ReclaimedDeckPlank",Vector3(0,6.94,depth),Vector3(4.67,0.09,0.45),mats["wood"])
		for side in [-1.0,1.0]:
			box(parent,"DeckEdgePlate",Vector3(side*2.43,7.02,depth),Vector3(0.09,0.18,0.41),mats["rust"])
	for side in [-1.0,1.0]:
		box(parent,"DeckOuterBeam",Vector3(side*2.35,6.76,0),Vector3(0.13,0.26,4.94),mats["darkmetal"])

static func _roof(parent: Node3D, mats: Dictionary) -> void:
	# Corrugated metal panels are individual rust-striped ribs, not a flat cap.
	for n in range(13):
		var x: float=-2.60+float(n)*0.43
		var rib := box(parent,"WeatheredCorrugation",Vector3(x,8.58+absf(x)*0.025,0),Vector3(0.39,0.076,5.41),mats["rust"] if n%4==0 else mats["roof"])
		rib.rotation.z=0.025 if n%2==0 else -0.025
		box(parent,"RaisedRainSeam",Vector3(x+0.15,8.66+absf(x)*0.025,0),Vector3(0.04,0.055,5.45),mats["steel"])
	for edge in [-1.0,1.0]:
		box(parent,"EaveRustedGutter",Vector3(0,8.39,edge*2.72),Vector3(5.72,0.19,0.18),mats["rust"])
		for x in [-2.60,2.60]:
			_beam(parent,"RoofSupportDiagonal",Vector3(x*0.89,7.41,edge*2.36),Vector3(x,8.44,edge*2.59),0.12,mats["wood"])

static func _rail_and_ladder(parent: Node3D, mats: Dictionary) -> void:
	for side in [-1.0,1.0]:
		for z in [-1.62,0,1.62]:
			box(parent,"PlatformWoodUpright",Vector3(side*2.40,7.58,z),Vector3(0.16,1.32,0.16),mats["wood"])
		for y in [7.47,8.12]:
			box(parent,"HandRail",Vector3(side*2.40,y,0),Vector3(0.10,0.12,5.02),mats["rust"])
	for z in [-2.38,2.38]:
		for x in [-1.75,0,1.75]:
			box(parent,"ParapetUpright",Vector3(x,7.58,z),Vector3(0.15,1.31,0.16),mats["wood"])
		# Leave ladder climb gap in front lower handrail.
		if z>0:
			box(parent,"FarRail",Vector3(0,7.95,z),Vector3(4.74,0.12,0.13),mats["wood"])
	for x in [-0.67,0.67]:
		_beam(parent,"ExternalLadderRail",Vector3(x,0.28,-2.23),Vector3(x,7.30,-2.23),0.11,mats["darkmetal"])
	for r in range(13):
		box(parent,"LadderStep",Vector3(0,0.53+float(r)*0.50,-2.25),Vector3(1.28,0.105,0.14),mats["steel"])

static func _brace(parent: Node3D, mats: Dictionary) -> void:
	for side in [-1.0,1.0]:
		for front in [-1.0,1.0]:
			# External diagonal wooden bracing, cross-linked between
			# structural legs and deck, casts real isometric silhouettes.
			_beam(parent,"CrossBracedWatchTower",Vector3(side*1.83,0.75,front*1.83),Vector3(-side*1.83,5.75,front*1.83),0.14,mats["wood"])
			_beam(parent,"CrossBracedWatchTower",Vector3(side*1.83,0.75,front*1.83),Vector3(side*1.83,5.75,-front*1.83),0.12,mats["steel"])

static func _watchlight(parent: Node3D, mats: Dictionary) -> void:
	var lampholder := Node3D.new()
	lampholder.name="WatchtowerNavigationLight"
	lampholder.position=Vector3(1.80,7.74,-2.43)
	parent.add_child(lampholder)
	box(lampholder,"RustedFixture",Vector3.ZERO,Vector3(0.34,0.30,0.40),mats["darkmetal"])
	box(lampholder,"WarmWorkLens",Vector3(0,-0.14,-0.20),Vector3(0.22,0.12,0.15),mats["glow"])
	var light := OmniLight3D.new()
	light.name="TowerWarmWorkLight"
	light.position=Vector3(0,-0.22,-0.30)
	light.light_color=Color("#ffca8a")
	light.omni_range=13.0
	light.light_energy=0.48
	light.shadow_enabled=false
	lampholder.add_child(light)

static func enrich_existing(parent: Node3D, mats: Dictionary) -> int:
	var count := 0
	for object in parent.get_children():
		if not str(object.name).begins_with("PerimeterWatchtower"):
			continue
		var style := Node3D.new()
		style.name="RealisticTimberWatchTower"
		object.add_child(style)
		_deck(style,mats)
		_roof(style,mats)
		_rail_and_ladder(style,mats)
		_brace(style,mats)
		_watchlight(style,mats)
		count+=1
	return count
