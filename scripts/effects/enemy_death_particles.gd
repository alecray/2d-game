extends CPUParticles2D

var base_color: Color = Color(0.9, 0.4, 0.1)  # set before add_child
var base_amount: int = 28                      # set before add_child to scale particle count

func _ready() -> void:
	one_shot = true
	explosiveness = 0.95
	amount = base_amount
	lifetime = 0.7
	emitting = true

	direction = Vector2(0.0, -1.0)
	spread = 180.0
	gravity = Vector2(0.0, 140.0)
	initial_velocity_min = 70.0
	initial_velocity_max = 210.0

	scale_amount_min = 3.0
	scale_amount_max = 7.0

	# lighter and darker shades of the enemy's own color
	var init_grad = Gradient.new()
	init_grad.colors = PackedColorArray([
		base_color.lightened(0.4),
		base_color,
		base_color.darkened(0.35),
	])
	color_initial_ramp = init_grad

	var life_grad = Gradient.new()
	life_grad.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.7),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	life_grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	color_ramp = life_grad

	z_index = 5
	finished.connect(queue_free)
