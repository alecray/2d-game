extends CPUParticles2D

func _ready() -> void:
	one_shot      = true
	explosiveness = 1.0
	amount        = 22
	lifetime      = 0.65
	emitting       = true

	direction = Vector2(0.0, -1.0)
	spread    = 180.0
	gravity   = Vector2(0.0, -60.0)  # drift upward like summoning smoke
	initial_velocity_min = 55.0
	initial_velocity_max = 160.0

	scale_amount_min = 3.5
	scale_amount_max = 8.0

	var init_grad := Gradient.new()
	init_grad.colors = PackedColorArray([
		Color(0.85, 0.1, 0.9),   # bright purple
		Color(0.55, 0.05, 0.65), # mid purple
		Color(0.2,  0.0,  0.3),  # deep violet
	])
	color_initial_ramp = init_grad

	var life_grad := Gradient.new()
	life_grad.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.5),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	life_grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	color_ramp = life_grad

	z_index = 5
	finished.connect(queue_free)
