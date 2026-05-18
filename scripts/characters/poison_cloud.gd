## Lingering toxic mist — damages enemies inside its radius over time for DURATION seconds.
## Spawn at the player's position; handles everything itself.
extends Node2D

const DURATION   := 5.5
const RADIUS     := 85.0
const TICK_RATE  := 0.35   # seconds between damage ticks
const TICK_DMG   := 4      # damage per tick per enemy

var _tick_timer := 0.0
var _dead       := false

func _ready() -> void:
	# Ground layer — dense slow mist hugging the floor
	add_child(_make_ground_mist())
	# Rising wisp layer — thin tendrils that curl upward
	add_child(_make_wisps())
	# Toxic spore layer — tiny bright specks scattered through the cloud
	add_child(_make_spores())
	# Bubbling core — concentrated burst at centre on spawn
	var burst := _make_burst()
	add_child(burst)

	# Fade the whole cloud out over its last 1.5 s
	var tween := create_tween()
	tween.tween_interval(DURATION - 1.5)
	tween.tween_property(self, "modulate:a", 0.0, 1.5)

	get_tree().create_timer(DURATION + 0.5).timeout.connect(queue_free, CONNECT_ONE_SHOT)

func _make_ground_mist() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting               = true
	p.one_shot               = false
	p.amount                 = 55
	p.lifetime               = 2.2
	p.emission_shape         = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = RADIUS * 0.65
	p.direction              = Vector2(0.0, -1.0)
	p.spread                 = 60.0
	p.initial_velocity_min   = 8.0
	p.initial_velocity_max   = 22.0
	p.gravity                = Vector2(0.0, 12.0)  # sinks back down — stays low
	p.scale_amount_min       = 6.0
	p.scale_amount_max       = 14.0

	var init_ramp := Gradient.new()
	init_ramp.colors  = PackedColorArray([
		Color(0.05, 0.45, 0.02),  # dark swamp green
		Color(0.18, 0.70, 0.05),  # mid poison green
		Color(0.40, 0.85, 0.00),  # yellow-green
		Color(0.08, 0.55, 0.12),  # deep toxic green
	])
	init_ramp.offsets = PackedFloat32Array([0.0, 0.30, 0.62, 1.0])
	p.color_initial_ramp = init_ramp

	var life_ramp := Gradient.new()
	life_ramp.colors  = PackedColorArray([
		Color(1, 1, 1, 0.0),
		Color(1, 1, 1, 0.5),
		Color(1, 1, 1, 0.3),
		Color(1, 1, 1, 0.0),
	])
	life_ramp.offsets = PackedFloat32Array([0.0, 0.12, 0.72, 1.0])
	p.color_ramp = life_ramp

	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	return p

func _make_wisps() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting               = true
	p.one_shot               = false
	p.amount                 = 30
	p.lifetime               = 1.5
	p.emission_shape         = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = RADIUS * 0.5
	p.direction              = Vector2(0.0, -1.0)
	p.spread                 = 35.0
	p.initial_velocity_min   = 18.0
	p.initial_velocity_max   = 40.0
	p.gravity                = Vector2(0.0, -15.0)  # rise upward
	p.scale_amount_min       = 2.5
	p.scale_amount_max       = 6.0

	var init_ramp := Gradient.new()
	init_ramp.colors  = PackedColorArray([
		Color(0.45, 1.00, 0.10),  # neon acid green
		Color(0.70, 1.00, 0.00),  # toxic lime
		Color(0.25, 0.95, 0.20),  # vivid green
	])
	init_ramp.offsets = PackedFloat32Array([0.0, 0.48, 1.0])
	p.color_initial_ramp = init_ramp

	var life_ramp := Gradient.new()
	life_ramp.colors  = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)])
	life_ramp.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	p.color_ramp = life_ramp

	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	return p

func _make_spores() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting               = true
	p.one_shot               = false
	p.amount                 = 22
	p.lifetime               = 1.0
	p.emission_shape         = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = RADIUS * 0.45
	p.direction              = Vector2(1.0, 0.0)
	p.spread                 = 180.0
	p.initial_velocity_min   = 35.0
	p.initial_velocity_max   = 70.0
	p.gravity                = Vector2(0.0, 50.0)
	p.scale_amount_min       = 1.0
	p.scale_amount_max       = 2.8

	var init_ramp := Gradient.new()
	init_ramp.colors  = PackedColorArray([
		Color(0.60, 1.00, 0.00),  # acid lime
		Color(0.90, 1.00, 0.15),  # bright yellow-green
	])
	init_ramp.offsets = PackedFloat32Array([0.0, 1.0])
	p.color_initial_ramp = init_ramp

	var life_ramp := Gradient.new()
	life_ramp.colors  = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.0)])
	life_ramp.offsets = PackedFloat32Array([0.0, 1.0])
	p.color_ramp = life_ramp

	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	return p

func _make_burst() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting               = true
	p.one_shot               = true
	p.explosiveness          = 0.85
	p.amount                 = 40
	p.lifetime               = 0.9
	p.emission_shape         = CPUParticles2D.EMISSION_SHAPE_POINT
	p.direction              = Vector2(1.0, 0.0)
	p.spread                 = 180.0
	p.initial_velocity_min   = 50.0
	p.initial_velocity_max   = 110.0
	p.gravity                = Vector2(0.0, -20.0)
	p.scale_amount_min       = 3.0
	p.scale_amount_max       = 8.0

	var init_ramp := Gradient.new()
	init_ramp.colors  = PackedColorArray([
		Color(0.20, 0.80, 0.05),
		Color(0.55, 1.00, 0.00),
		Color(0.10, 0.65, 0.10),
		Color(0.75, 1.00, 0.20),
	])
	init_ramp.offsets = PackedFloat32Array([0.0, 0.30, 0.65, 1.0])
	p.color_initial_ramp = init_ramp

	var life_ramp := Gradient.new()
	life_ramp.colors  = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0.0)])
	life_ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	p.color_ramp = life_ramp

	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	return p

func _process(delta: float) -> void:
	_tick_timer += delta
	if _tick_timer >= TICK_RATE:
		_tick_timer -= TICK_RATE
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(enemy):
				continue
			if global_position.distance_to(enemy.global_position) <= RADIUS:
				enemy.take_damage(TICK_DMG)
