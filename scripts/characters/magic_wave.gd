## Expanding particle ring that kills any enemy it passes through.
## Spawn it at the player's position and it handles everything itself.
extends Node2D

const EXPAND_SPEED = 250.0
const MAX_RADIUS   = 350.0

var radius = 0.0
var _hit   = {}

func _ready() -> void:
	# Outer ring — tight speed so particles stay in a thin band.
	var outer := _make_particles(80, EXPAND_SPEED, 0.06, 3.5, 7.0)
	add_child(outer)
	outer.finished.connect(queue_free)  # node lives until all particles expire

	# Inner sparkle layer — slower, tinier, gives the ring some depth.
	var inner := _make_particles(40, EXPAND_SPEED * 0.55, 0.18, 1.5, 4.0)
	add_child(inner)

func _make_particles(amount: int, speed: float, speed_var: float,
		scale_min: float, scale_max: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting            = true
	p.one_shot            = true
	p.explosiveness       = 1.0
	p.amount              = amount
	p.lifetime            = MAX_RADIUS / EXPAND_SPEED
	p.emission_shape      = CPUParticles2D.EMISSION_SHAPE_POINT
	p.direction           = Vector2(1.0, 0.0)
	p.spread              = 180.0
	p.initial_velocity_min = speed * (1.0 - speed_var)
	p.initial_velocity_max = speed * (1.0 + speed_var)
	p.gravity             = Vector2.ZERO
	p.scale_amount_min    = scale_min
	p.scale_amount_max    = scale_max

	# Each particle gets a random shade from the purple-to-blue spectrum.
	var init_ramp := Gradient.new()
	init_ramp.colors  = PackedColorArray([
		Color(0.55, 0.00, 1.00),  # deep purple
		Color(0.75, 0.10, 1.00),  # violet
		Color(0.20, 0.30, 1.00),  # blue-purple
		Color(0.05, 0.55, 1.00),  # bright blue
	])
	init_ramp.offsets = PackedFloat32Array([0.0, 0.33, 0.66, 1.0])
	p.color_initial_ramp = init_ramp

	# Fade out toward the end of each particle's life.
	var life_ramp := Gradient.new()
	life_ramp.colors  = PackedColorArray([Color(1,1,1,1), Color(1,1,1,0.6), Color(1,1,1,0)])
	life_ramp.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	p.color_ramp = life_ramp

	# Additive blending makes the particles glow where they overlap.
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat

	return p

func _process(delta: float) -> void:
	radius += EXPAND_SPEED * delta

	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy in _hit:
			continue
		if global_position.distance_to(enemy.global_position) <= radius:
			_hit[enemy] = true
			enemy.die()

	if radius >= MAX_RADIUS:
		set_process(false)  # stop hit detection; particles finish on their own
