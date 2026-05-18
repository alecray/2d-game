## Shatter spell — emits an ice ring that freezes nearby enemies, then detonates for damage.
## Spawn at the player's position; self-contained.
extends Node2D

const FREEZE_RADIUS   := 200.0
const FREEZE_DURATION := 1.8
const SHATTER_DAMAGE  := 50

var _frozen:     Array = []
var _orig_mods:  Array = []
var _ice_fx:     Array = []  # per-enemy persistent ice emitters to clean up on shatter

func _ready() -> void:
	_spawn_freeze_ring()

	for node in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(node):
			continue
		var enemy := node as Node2D
		if enemy == null:
			continue
		if global_position.distance_to(enemy.global_position) > FREEZE_RADIUS:
			continue
		_frozen.append(enemy)
		_orig_mods.append(enemy.modulate)
		enemy.modulate = Color(0.55, 0.82, 1.0)
		enemy.set("frozen", true)
		_spawn_freeze_burst(enemy.global_position)
		var shimmer := _make_shimmer(enemy)
		_ice_fx.append(shimmer)

	get_tree().create_timer(FREEZE_DURATION).timeout.connect(_shatter, CONNECT_ONE_SHOT)
	get_tree().create_timer(FREEZE_DURATION + 1.2).timeout.connect(queue_free, CONNECT_ONE_SHOT)

func _shatter() -> void:
	# Stop persistent ice shimmers and clean up
	for fx in _ice_fx:
		if is_instance_valid(fx):
			fx.emitting = false
			get_tree().create_timer(0.5).timeout.connect(fx.queue_free, CONNECT_ONE_SHOT)
	_ice_fx.clear()

	_spawn_shatter_burst()

	for i in _frozen.size():
		var enemy := _frozen[i] as Node2D
		if not is_instance_valid(enemy):
			continue
		enemy.set("frozen", false)
		enemy.modulate = _orig_mods[i]
		_spawn_shard_burst(enemy.global_position)
		enemy.call("take_damage", SHATTER_DAMAGE)
	_frozen.clear()
	_orig_mods.clear()

# ── Freeze ring (expands outward from the cast point) ─────────────────────────

func _spawn_freeze_ring() -> void:
	var ring_speed := 230.0
	var lifetime   := FREEZE_RADIUS / ring_speed

	var outer := CPUParticles2D.new()
	outer.emitting              = true
	outer.one_shot              = true
	outer.explosiveness         = 1.0
	outer.amount                = 80
	outer.lifetime              = lifetime
	outer.emission_shape        = CPUParticles2D.EMISSION_SHAPE_POINT
	outer.direction             = Vector2(1.0, 0.0)
	outer.spread                = 180.0
	outer.initial_velocity_min  = ring_speed * 0.95
	outer.initial_velocity_max  = ring_speed * 1.05
	outer.gravity               = Vector2.ZERO
	outer.scale_amount_min      = 2.5
	outer.scale_amount_max      = 6.0
	outer.color_initial_ramp    = _ice_init_ramp()
	outer.color_ramp            = _fade_ramp(0.0, 0.6)
	outer.material              = _add_mat()
	add_child(outer)

	var inner := CPUParticles2D.new()
	inner.emitting              = true
	inner.one_shot              = true
	inner.explosiveness         = 1.0
	inner.amount                = 40
	inner.lifetime              = lifetime
	inner.emission_shape        = CPUParticles2D.EMISSION_SHAPE_POINT
	inner.direction             = Vector2(1.0, 0.0)
	inner.spread                = 180.0
	inner.initial_velocity_min  = ring_speed * 0.35
	inner.initial_velocity_max  = ring_speed * 0.60
	inner.gravity               = Vector2.ZERO
	inner.scale_amount_min      = 1.0
	inner.scale_amount_max      = 3.0
	inner.color_initial_ramp    = _ice_init_ramp()
	inner.color_ramp            = _fade_ramp(0.0, 0.7)
	inner.material              = _add_mat()
	add_child(inner)

# ── Per-enemy freeze burst (one-shot on freeze) ────────────────────────────────

func _spawn_freeze_burst(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.emitting             = true
	p.one_shot             = true
	p.explosiveness        = 0.9
	p.amount               = 18
	p.lifetime             = 0.7
	p.emission_shape       = CPUParticles2D.EMISSION_SHAPE_POINT
	p.direction            = Vector2(1.0, 0.0)
	p.spread               = 180.0
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 65.0
	p.gravity              = Vector2(0.0, 40.0)
	p.scale_amount_min     = 1.5
	p.scale_amount_max     = 4.0
	p.color_initial_ramp   = _ice_init_ramp()
	p.color_ramp           = _fade_ramp(0.0, 1.0)
	p.material             = _add_mat()
	get_parent().add_child(p)
	p.global_position = pos

# ── Per-enemy persistent shimmer while frozen ──────────────────────────────────

func _make_shimmer(enemy: Node2D) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting             = true
	p.one_shot             = false
	p.amount               = 8
	p.lifetime             = 0.6
	p.emission_shape       = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 10.0
	p.direction            = Vector2(0.0, -1.0)
	p.spread               = 50.0
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 25.0
	p.gravity              = Vector2(0.0, -5.0)
	p.scale_amount_min     = 0.8
	p.scale_amount_max     = 2.0
	p.color_initial_ramp   = _ice_init_ramp()
	p.color_ramp           = _fade_ramp(0.0, 1.0)
	p.material             = _add_mat()
	(enemy as Node2D).add_child(p)
	return p

# ── Shatter explosion (centred on cast point) ─────────────────────────────────

func _spawn_shatter_burst() -> void:
	# Wide shard spray
	var shards := CPUParticles2D.new()
	shards.emitting             = true
	shards.one_shot             = true
	shards.explosiveness        = 0.92
	shards.amount               = 130
	shards.lifetime             = 1.0
	shards.emission_shape       = CPUParticles2D.EMISSION_SHAPE_POINT
	shards.direction            = Vector2(1.0, 0.0)
	shards.spread               = 180.0
	shards.initial_velocity_min = 60.0
	shards.initial_velocity_max = 250.0
	shards.gravity              = Vector2(0.0, 120.0)
	shards.scale_amount_min     = 1.5
	shards.scale_amount_max     = 5.5
	shards.color_initial_ramp   = _shatter_init_ramp()
	shards.color_ramp           = _fade_ramp(0.4, 1.0)
	shards.material             = _add_mat()
	add_child(shards)

	# Dense white core flash
	var flash := CPUParticles2D.new()
	flash.emitting             = true
	flash.one_shot             = true
	flash.explosiveness        = 1.0
	flash.amount               = 60
	flash.lifetime             = 0.4
	flash.emission_shape       = CPUParticles2D.EMISSION_SHAPE_POINT
	flash.direction            = Vector2(1.0, 0.0)
	flash.spread               = 180.0
	flash.initial_velocity_min = 10.0
	flash.initial_velocity_max = 90.0
	flash.gravity              = Vector2.ZERO
	flash.scale_amount_min     = 3.0
	flash.scale_amount_max     = 10.0
	flash.color                = Color(0.85, 0.97, 1.0)
	flash.color_ramp           = _fade_ramp(0.0, 1.0)
	flash.material             = _add_mat()
	add_child(flash)

# ── Per-enemy shard burst at shatter moment ───────────────────────────────────

func _spawn_shard_burst(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.emitting             = true
	p.one_shot             = true
	p.explosiveness        = 0.95
	p.amount               = 30
	p.lifetime             = 0.7
	p.emission_shape       = CPUParticles2D.EMISSION_SHAPE_POINT
	p.direction            = Vector2(1.0, 0.0)
	p.spread               = 180.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 140.0
	p.gravity              = Vector2(0.0, 100.0)
	p.scale_amount_min     = 1.0
	p.scale_amount_max     = 4.0
	p.color_initial_ramp   = _shatter_init_ramp()
	p.color_ramp           = _fade_ramp(0.3, 1.0)
	p.material             = _add_mat()
	get_parent().add_child(p)
	p.global_position = pos

# ── Shared helpers ─────────────────────────────────────────────────────────────

func _ice_init_ramp() -> Gradient:
	var g := Gradient.new()
	g.colors  = PackedColorArray([
		Color(0.70, 0.93, 1.00),  # pale ice blue
		Color(1.00, 1.00, 1.00),  # white
		Color(0.35, 0.80, 1.00),  # vivid cyan
		Color(0.85, 0.97, 1.00),  # near-white
	])
	g.offsets = PackedFloat32Array([0.0, 0.28, 0.62, 1.0])
	return g

func _shatter_init_ramp() -> Gradient:
	var g := Gradient.new()
	g.colors  = PackedColorArray([
		Color(1.00, 1.00, 1.00),  # white
		Color(0.55, 0.90, 1.00),  # ice blue
		Color(0.20, 0.75, 1.00),  # cyan
		Color(0.80, 0.95, 1.00),  # pale blue
	])
	g.offsets = PackedFloat32Array([0.0, 0.30, 0.65, 1.0])
	return g

func _fade_ramp(fade_start: float, fade_end: float) -> Gradient:
	var g := Gradient.new()
	g.colors  = PackedColorArray([Color(1,1,1,1), Color(1,1,1,1), Color(1,1,1,0)])
	g.offsets = PackedFloat32Array([0.0, fade_start, fade_end])
	return g

func _add_mat() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m
