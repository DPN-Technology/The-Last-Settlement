class_name GroundAppearance
extends RefCounted

# Deterministic locally baked texture. Unlike the former spatial fragment
# shader, this remains visible through Forward+ and GL Compatibility renderers.
# It does not depend on external services, GPU shader noise, or player files.
const TEXTURE_SIZE := 384
const SEED := 738119

static func bake_image() -> Image:
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGB8)
	var broad := FastNoiseLite.new()
	broad.seed = SEED
	broad.frequency = 0.012
	broad.fractal_octaves = 3
	var gravel := FastNoiseLite.new()
	gravel.seed = SEED + 17
	gravel.frequency = 0.085
	gravel.fractal_octaves = 3
	var speckles := FastNoiseLite.new()
	speckles.seed = SEED + 231
	speckles.frequency = 0.37
	for y in range(TEXTURE_SIZE):
		for x in range(TEXTURE_SIZE):
			var high := broad.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var medium := gravel.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var fine := speckles.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var wear := smoothstep(0.45, 0.79, high)
			var dark := Color("#2c2922")
			var clay := Color("#514738")
			var stony := Color("#6b6354")
			var base := dark.lerp(clay, 0.19 + high * 0.54)
			base = base.lerp(stony, medium * 0.20)
			base = base.darkened(wear * 0.11)
			var pebble := smoothstep(0.76, 0.92, fine) * 0.16
			base = base.lightened(pebble)
			image.set_pixel(x, y, base)
	image.generate_mipmaps()
	return image

static func bake() -> ImageTexture:
	return ImageTexture.create_from_image(bake_image())

static func new_ground_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = bake()
	mat.albedo_color = Color("#cac2b2")
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.uv1_scale = Vector3.ONE
	mat.roughness = 0.97
	mat.metallic = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	return mat

static func sample_luminance(img: Image) -> float:
	if img == null:
		return -1.0
	var sum := 0.0
	var count := 0
	for y in range(0, img.get_height(), 16):
		for x in range(0, img.get_width(), 16):
			var c := img.get_pixel(x, y)
			sum += c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
			count += 1
	return sum / maxf(1.0, float(count))
