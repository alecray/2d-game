extends CPUParticles2D

func _ready() -> void:
	amount = 120
	lifetime = 5.0
	preprocess = 5.0
	randomness = 0.4

	emission_shape = EMISSION_SHAPE_RECTANGLE
	emission_rect_extents = Vector2(520, 360)

	# blow horizontally with a little vertical scatter
	direction = Vector2(1.0, 0.0)
	spread = 18.0
	gravity = Vector2(0.0, 0.0)
	initial_velocity_min = 18.0
	initial_velocity_max = 55.0

	# long thin streaks
	scale_amount_min = 1.5
	scale_amount_max = 4.0
	scale_amount_curve = _make_scale_curve()

	# pale blue-white wind tones
	var init_grad = Gradient.new()
	init_grad.colors = PackedColorArray([
		Color(0.88, 0.95, 1.00, 1.0),
		Color(0.78, 0.90, 1.00, 1.0),
		Color(1.00, 1.00, 1.00, 1.0),
		Color(0.82, 0.92, 0.98, 1.0),
	])
	color_initial_ramp = init_grad

	# fade in quickly, hold, then fade out at the end
	var life_grad = Gradient.new()
	life_grad.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.0),
		Color(1.0, 1.0, 1.0, 0.6),
		Color(1.0, 1.0, 1.0, 0.6),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	life_grad.offsets = PackedFloat32Array([0.0, 0.15, 0.75, 1.0])
	color_ramp = life_grad

	z_index = 2

func _make_scale_curve() -> Curve:
	var c = Curve.new()
	c.add_point(Vector2(0.0, 0.0))
	c.add_point(Vector2(0.1, 1.0))
	c.add_point(Vector2(0.85, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	return c
