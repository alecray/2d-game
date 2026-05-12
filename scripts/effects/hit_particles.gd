extends CPUParticles2D

var hit_direction: Vector2 = Vector2.RIGHT  # set to bullet direction before add_child

func _ready() -> void:
	one_shot = true
	explosiveness = 1.0
	amount = 10
	lifetime = 0.2
	emitting = true

	direction = hit_direction
	spread = 55.0
	gravity = Vector2.ZERO
	initial_velocity_min = 180.0
	initial_velocity_max = 380.0

	scale_amount_min = 1.0
	scale_amount_max = 2.5

	var init_grad = Gradient.new()
	init_grad.colors = PackedColorArray([
		Color(1.0, 1.0, 0.8, 1.0),
		Color(1.0, 0.85, 0.3, 1.0),
	])
	color_initial_ramp = init_grad

	var life_grad = Gradient.new()
	life_grad.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	life_grad.offsets = PackedFloat32Array([0.0, 1.0])
	color_ramp = life_grad

	z_index = 5
	finished.connect(queue_free)
