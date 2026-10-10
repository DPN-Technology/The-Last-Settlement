class_name SettlementWorldReadability3D
extends RefCounted

# Facility signage comes from real saved building names. All geometry is
# presentation-only; occupancy, movement and the save schema are unchanged.
static func decorate(group: Node3D, b: Dictionary, size: Vector2, h: float, mats: Dictionary) -> void:
	var name := Label3D.new()
	name.name="FacilityNameMarker"
	name.text=str(b.get("name","Facility")).to_upper()
	name.font_size=34
	name.pixel_size=0.010
	name.outline_size=5
	name.modulate=Color("#efdfc9")
	name.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	name.position=Vector3(0,h+1.68,0)
	group.add_child(name)
	var kind := str(b.get("type",""))
	var accent: Material=mats["cross"] if kind=="medical" else (mats["blue"] if kind in ["water","water_pump","purifier","water_tank","sewage"] else (mats["rust"] if kind in ["industry","storage"] else mats["olive"]))
	var front := -size.y*0.5
	for side in [-1.0,1.0]:
		SettlementInteriors3D.box(group,"EntryWayfinding",Vector3(side*1.52,2.12,front-0.28),Vector3(0.30,0.95,0.12),accent)
	var lamp := OmniLight3D.new()
	lamp.name="ExteriorDoorLight"
	lamp.position=Vector3(0,2.86,front-1.05)
	lamp.light_color=Color("#f3c89d")
	lamp.omni_range=7.0
	lamp.shadow_enabled=false
	lamp.light_energy=0.0
	group.add_child(lamp)
	SettlementInteriors3D.box(group,"EntryLampHousing",Vector3(0,2.85,front-0.41),Vector3(0.43,0.22,0.25),mats["darkmetal"])
