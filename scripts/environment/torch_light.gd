extends PointLight2D

const LIGHT_COLOR = Color(1.0, 0.62, 0.15)

static var _cached_texture: ImageTexture

func _ready() -> void:
	if _cached_texture == null:
		_cached_texture = _make_radial_texture()
	color = LIGHT_COLOR
	_add_fire()
	_add_smoke()

func _add_fire() -> void:
	var fire = CPUParticles2D.new()
	fire.amount = 18
	fire.lifetime = 0.5
	fire.preprocess = 0.5
	fire.direction = Vector2(0.0, -1.0)
	fire.spread = 20.0
	fire.gravity = Vector2.ZERO
	fire.initial_velocity_min = 25.0
	fire.initial_velocity_max = 60.0
	fire.scale_amount_min = 1.5
	fire.scale_amount_max = 3.0
	var ramp = Gradient.new()
	ramp.colors = PackedColorArray([
		Color(1.0, 0.95, 0.4, 1.0),
		Color(1.0, 0.4,  0.05, 0.8),
		Color(0.5, 0.05, 0.0,  0.0),
	])
	ramp.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	fire.color_ramp = ramp
	fire.z_index = 2
	add_child(fire)

func _add_smoke() -> void:
	var smoke = CPUParticles2D.new()
	smoke.position = Vector2(0.0, -6.0)
	smoke.amount = 8
	smoke.lifetime = 2.0
	smoke.preprocess = 1.5
	smoke.direction = Vector2(0.0, -1.0)
	smoke.spread = 35.0
	smoke.gravity = Vector2(0.0, -12.0)
	smoke.initial_velocity_min = 8.0
	smoke.initial_velocity_max = 20.0
	smoke.scale_amount_min = 3.0
	smoke.scale_amount_max = 6.0
	var ramp = Gradient.new()
	ramp.colors = PackedColorArray([
		Color(0.5, 0.45, 0.4,  0.0),
		Color(0.4, 0.37, 0.33, 0.22),
		Color(0.3, 0.27, 0.25, 0.0),
	])
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	smoke.color_ramp = ramp
	smoke.z_index = 3
	add_child(smoke)

static func _make_radial_texture() -> ImageTexture:
	# bounding rect half = 128 * 30 = 3840px — exceeds world diagonal, so no culling ever occurs
	# outer pixels use near-zero alpha so Godot treats full texture dims as the light AABB
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := size * 0.5
	var grad_radius := 5.0
	for y in size:
		for x in size:
			var dist := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(center, center))
			var t := clampf(1.0 - dist / grad_radius, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, maxf(t, 0.004)))
	return ImageTexture.create_from_image(img)
