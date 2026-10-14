class_name SettlementMaterialLibrary3D
extends RefCounted

# Offline 2.5D material swatches for re-used furniture, reclaimed wood and
# shelter fabrics. GL Compatibility-safe PBR, no shader hacks or new downloads.
const MAP_SIZE := 192

static func _albedo(kind: String) -> Image:
	var image := Image.create(MAP_SIZE,MAP_SIZE,false,Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed=498117 if kind=="timber" else 127301
	noise.frequency=0.075
	noise.fractal_octaves=3
	var subtle := FastNoiseLite.new()
	subtle.seed=177417 if kind=="timber" else 509721
	subtle.frequency=0.21
	subtle.fractal_octaves=3
	var walnut := Color("#493328")
	var oak := Color("#b08b5f")
	var dirty_canvas := Color("#7b7159")
	var faded_canvas := Color("#ad9c78")
	for y in range(MAP_SIZE):
		for x in range(MAP_SIZE):
			var a: float=noise.get_noise_2d(float(x),float(y))
			var b: float=subtle.get_noise_2d(float(x),float(y))
			var shade: float=clampf(0.49+(a+b*0.32)*0.26,0.04,0.96)
			if kind=="timber":
				# Knots & grain are directional, not the previous flat tan box.
				var grain: float=sin(float(y)*0.43+a*10.2+sin(float(x)*0.11)*1.4)
				var wood_var: float=clampf(shade+grain*0.13,0.16,0.95)
				image.set_pixel(x,y,walnut.lerp(oak,wood_var))
			else:
				var threads: float=0.08 if x%6<=1 or y%6<=1 else -0.02
				var canvas_var: float=clampf(shade+threads+b*0.11,0.16,0.91)
				image.set_pixel(x,y,dirty_canvas.lerp(faded_canvas,canvas_var))
	image.generate_mipmaps()
	return image

static func _normal(albedo: Image) -> Image:
	var image := Image.create(MAP_SIZE,MAP_SIZE,false,Image.FORMAT_RGB8)
	for y in range(MAP_SIZE):
		for x in range(MAP_SIZE):
			var left: float=albedo.get_pixel(maxi(0,x-1),y).get_luminance()
			var right: float=albedo.get_pixel(mini(MAP_SIZE-1,x+1),y).get_luminance()
			var up: float=albedo.get_pixel(x,maxi(0,y-1)).get_luminance()
			var down: float=albedo.get_pixel(x,mini(MAP_SIZE-1,y+1)).get_luminance()
			var n := Vector3((left-right)*2.6,(up-down)*2.6,1.0).normalized()
			image.set_pixel(x,y,Color(n.x*0.5+0.5,n.y*0.5+0.5,n.z*0.5+0.5))
	image.generate_mipmaps()
	return image

static func create(kind: String) -> StandardMaterial3D:
	var albedo := _albedo(kind)
	var result := StandardMaterial3D.new()
	result.albedo_texture=ImageTexture.create_from_image(albedo)
	result.albedo_color=Color("#f4ebdb")
	result.normal_enabled=true
	result.normal_texture=ImageTexture.create_from_image(_normal(albedo))
	result.normal_scale=0.55
	result.roughness=0.88 if kind=="timber" else 0.99
	result.uv1_triplanar=true
	result.uv1_scale=Vector3.ONE*0.68
	result.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return result
