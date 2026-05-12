extends CPUParticles2D

func _ready() -> void:
	amount = 150
	lifetime = 8.0
	preprocess = 5.0
	randomness = 1.0

	emission_shape = EMISSION_SHAPE_RECTANGLE
	emission_rect_extents = Vector2(520, 360)

	direction = Vector2(0.0, -1.0)
	spread = 180.0
	gravity = Vector2(0.0, -4.0)
	initial_velocity_min = 3.0
	initial_velocity_max = 11.0

	scale_amount_min = 1.0
	scale_amount_max = 2.5

	# each particle randomly picks a color from this gradient — dust tones
	var init_grad = Gradient.new()
	init_grad.colors = PackedColorArray([
		Color(1.00, 1.00, 1.00, 1.0),  # bright white
		Color(1.00, 0.97, 0.88, 1.0),  # warm cream
		Color(0.88, 0.93, 1.00, 1.0),  # cool blue-white
		Color(0.84, 0.82, 0.79, 1.0),  # warm gray
		Color(1.00, 1.00, 1.00, 1.0),  # bright white again for more weight
	])
	color_initial_ramp = init_grad

	# fade in, hold, fade out over the particle's lifetime
	var life_grad = Gradient.new()
	life_grad.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.0),
		Color(1.0, 1.0, 1.0, 0.45),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	life_grad.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	color_ramp = life_grad

	z_index = 2
