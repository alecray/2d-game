extends CPUParticles2D

func _ready() -> void:
	one_shot = true
	explosiveness = 0.95
	amount = 8
	lifetime = 0.55
	emitting = true

	direction = Vector2(0.0, -1.0)
	spread = 110.0
	gravity = Vector2(0.0, 320.0)  # pulled down quickly
	initial_velocity_min = 90.0
	initial_velocity_max = 220.0

	scale_amount_min = 2.0
	scale_amount_max = 5.0

	var init_grad = Gradient.new()
	init_grad.colors = PackedColorArray([
		Color(1.0, 0.05, 0.05, 1.0),
		Color(0.7, 0.0,  0.0,  1.0),
	])
	color_initial_ramp = init_grad

	var life_grad = Gradient.new()
	life_grad.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.6),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	life_grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	color_ramp = life_grad

	z_index = 5
	finished.connect(queue_free)
