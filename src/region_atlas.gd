class_name RegionAtlas
extends RefCounted

# Procedural cartographic backdrop for the fictional region.
# This is a terrain-intelligence visualization, not a claim that roads are
# independently simulated travel paths. Live markers, discovery, and the
# radio range are supplied by WorldSimulation at draw time.
const MAP_W := 600
const MAP_H := 410
const REGION_W := 1200.0
const REGION_H := 820.0
var texture: ImageTexture
var last_range := -1.0

func get_texture(radio_range: float) -> Texture2D:
	if texture != null and absf(last_range-radio_range)<0.5:
		return texture
	last_range=radio_range
	var relief := FastNoiseLite.new()
	relief.seed=27019
	relief.noise_type=FastNoiseLite.TYPE_SIMPLEX
	relief.frequency=0.012
	relief.fractal_type=FastNoiseLite.FRACTAL_FBM
	relief.fractal_octaves=4
	var grain := FastNoiseLite.new()
	grain.seed=41816
	grain.noise_type=FastNoiseLite.TYPE_SIMPLEX
	grain.frequency=0.067
	var image := Image.create(MAP_W,MAP_H,false,Image.FORMAT_RGB8)
	for py in range(MAP_H):
		var world_y := float(py)*2.0
		for px in range(MAP_W):
			var world_x := float(px)*2.0
			var elevation := relief.get_noise_2d(world_x,world_y)*0.72+grain.get_noise_2d(world_x,world_y)*0.18
			var moisture := relief.get_noise_2d(world_x+1901.0,world_y-1300.0)
			# A fictional, winding water corridor creates an actual legible
			# landscape instead of a featureless radar circle.
			var river_x := 250.0+105.0*sin(world_y*0.006)+44.0*sin(world_y*0.018)
			var river_distance := absf(world_x-river_x)
			var water := river_distance<11.0 or (river_distance<28.0 and elevation < -0.25)
			var base := Color("#2d3230")
			if water:
				base=Color("#304952") if river_distance<8.0 else Color("#405960")
			elif elevation>0.34:
				base=Color("#616050")
			elif elevation>0.17:
				base=Color("#545448")
			elif moisture>0.21:
				base=Color("#344b3c")
			elif moisture< -0.21:
				base=Color("#584c3d")
			elif elevation< -0.22:
				base=Color("#42473c")
			var contour := absf(fposmod((elevation+1.2)*16.0,1.0)-0.5)
			if not water and contour < 0.045:
				base=base.lightened(0.09)
			var grittiness := clampf(grain.get_noise_2d(world_x*1.7,world_y*1.7)*0.055+0.97,0.82,1.04)
			base=Color(base.r*grittiness,base.g*grittiness,base.b*grittiness)
			var distance := Vector2(world_x-600.0,world_y-410.0).length()
			# Deep unexplored terrain is subdued but not erased, so the world
			# reads as a map while undiscovered coordinates stay secret.
			var unknown := smoothstep(radio_range-70.0,radio_range+85.0,distance)
			base=base.lerp(Color("#171d22"),unknown*0.62)
			image.set_pixel(px,py,base)
	texture=ImageTexture.create_from_image(image)
	return texture

static func _point(region: Rect2, world: Vector2) -> Vector2:
	return region.position+Vector2(world.x/REGION_W*region.size.x,world.y/REGION_H*region.size.y)

static func draw_cartography(canvas: CanvasItem, region: Rect2, atlas: RegionAtlas, radio_range: float) -> void:
	canvas.draw_texture_rect(atlas.get_texture(radio_range),region,false,Color.WHITE)
	# The linework is only a map convention: these are old-world road traces,
	# not expedition travel distance or a player-built supply network.
	var old_roads: Array[PackedVector2Array]=[
		PackedVector2Array([Vector2(100,395),Vector2(330,390),Vector2(580,400),Vector2(820,386),Vector2(1120,365)]),
		PackedVector2Array([Vector2(285,90),Vector2(380,265),Vector2(600,415),Vector2(730,560),Vector2(930,745)]),
		PackedVector2Array([Vector2(250,710),Vector2(490,615),Vector2(720,515),Vector2(900,280),Vector2(1090,130)]),
		PackedVector2Array([Vector2(135,230),Vector2(350,285),Vector2(600,405),Vector2(770,312),Vector2(1040,285)])
	]
	for road in old_roads:
		var projected := PackedVector2Array()
		for point in road:
			projected.append(_point(region,point))
		for point_index in range(projected.size()-1):
			DPNUISkin.stroke(canvas,projected[point_index],projected[point_index+1],Color("#171b1a",0.7),4.0)
			DPNUISkin.stroke(canvas,projected[point_index],projected[point_index+1],Color("#807360",0.55),1.6)
	# Low-contrast regional grid, north pointer, and physical map key.
	for i in range(1,6):
		var x := region.position.x+region.size.x*float(i)/6.0
		var y := region.position.y+region.size.y*float(i)/6.0
		DPNUISkin.stroke(canvas,Vector2(x,region.position.y),Vector2(x,region.end.y),Color("#9a8e7e",0.10),1.0)
		DPNUISkin.stroke(canvas,Vector2(region.position.x,y),Vector2(region.end.x,y),Color("#9a8e7e",0.10),1.0)
	canvas.draw_rect(Rect2(region.position,Vector2(region.size.x,30.0)),Color("#080b11",0.89))
	canvas.draw_string(ThemeDB.fallback_font,region.position+Vector2(12,20),"DPN  /  WASTELAND TERRAIN INTELLIGENCE",HORIZONTAL_ALIGNMENT_LEFT,region.size.x-105.0,13,Color("#efe8df"))
	canvas.draw_string(ThemeDB.fallback_font,Vector2(region.end.x-16,region.position.y+20),"N  ↑",HORIZONTAL_ALIGNMENT_RIGHT,66.0,13,Color("#ec5363"))
	canvas.draw_rect(Rect2(region.position.x,region.end.y-27.0,region.size.x,27.0),Color("#080b11",0.93))
	canvas.draw_string(ThemeDB.fallback_font,Vector2(region.position.x+12,region.end.y-9),"LAND   /   WATER   /   ROAD TRACES   •   SELECT MARKERS TO PLAN MISSIONS",HORIZONTAL_ALIGNMENT_LEFT,region.size.x-26.0,10,Color("#c4bab1"))
	DPNUISkin.outline(canvas,region,Color("#9b3949",0.65),1.0)
