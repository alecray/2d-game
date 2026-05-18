extends Node2D

const BEAM_WIDTH = 28.0
const CORE_WIDTH = 10.0
const GLOW_WIDTH = 72.0
const MAX_RANGE = 2000.0
const ENEMY_HIT_RADIUS = 40.0

const BEAM_COLOR     = Color(0.8, 0.3, 1.0, 0.85)
const CORE_COLOR     = Color(1.0, 0.85, 1.0, 1.0)
const GLOW_COLOR     = Color(0.7, 0.2, 1.0, 0.10)
const HOT_BEAM_COLOR = Color(1.0, 0.25, 0.25, 0.85)
const HOT_CORE_COLOR = Color(1.0, 0.75, 0.75, 1.0)
const HOT_GLOW_COLOR = Color(1.0, 0.2, 0.2, 0.15)

const CHARGE_DURATION    = 0.15   # seconds to ramp from zero to full width
const JITTER_AMOUNT      = 3.5    # max perpendicular pixel wobble per frame
const FLICKER_WIDTH_VAR  = 0.12   # ±fraction of base width flickered per frame
const FLICKER_ALPHA_VAR  = 0.12   # ±fraction of base alpha flickered per frame
const OVERHEAT_TIME      = 3.5    # continuous fire seconds before cutout
const OVERHEAT_COOL_RATE = 2.0    # cools this many times faster than it heats
const HEAT_DAMAGE_MULT   = 2.2    # damage multiplier at maximum heat
const HEAT_WIDTH_MULT    = 1.7    # width multiplier at maximum heat
const KNOCKBACK_STRENGTH = 400.0  # pixels/sec push applied to enemies in the beam

var direction: Vector2 = Vector2.RIGHT
var damage: int = 10
var exclude_rids: Array = []

var _damage_accum: float = 0.0
var _charge_time: float = 0.0
var _heat: float = 0.0
var _overheated: bool = false
var _hitting_wall: bool = false
var _wall_collider: StaticBody2D = null

var _glow: Line2D
var _outer: Line2D
var _core: Line2D
var _sparks: CPUParticles2D
var _smoke: CPUParticles2D
var _beam_end: Vector2 = Vector2.ZERO

func _ready() -> void:
	z_index = 5
	_glow  = _make_line(GLOW_WIDTH,  GLOW_COLOR)
	_outer = _make_line(BEAM_WIDTH,  BEAM_COLOR)
	_core  = _make_line(CORE_WIDTH,  CORE_COLOR)
	add_child(_glow)
	add_child(_outer)
	add_child(_core)
	_sparks = _make_sparks()
	add_child(_sparks)
	_smoke = _make_smoke()
	add_child(_smoke)

func _physics_process(delta: float) -> void:
	if _overheated:
		_heat = maxf(0.0, _heat - delta * OVERHEAT_COOL_RATE)
		if _heat <= 0.0:
			_overheated = false
		_glow.visible = false
		_outer.visible = false
		_core.visible = false
		_sparks.emitting = false
		_smoke.emitting = true
		return

	_charge_time += delta
	_heat += delta
	if _heat >= OVERHEAT_TIME:
		_overheated = true

	_smoke.emitting = false
	_update_beam()
	var heat_t := clampf(_heat / OVERHEAT_TIME, 0.0, 1.0)
	_apply_visuals(heat_t)

	_damage_accum += damage * lerpf(1.0, HEAT_DAMAGE_MULT, heat_t) * delta
	var dmg := 0
	if _damage_accum >= 1.0:
		dmg = int(_damage_accum)
		_damage_accum -= float(dmg)
	_apply_effects(delta, dmg)

func _update_beam() -> void:
	var from := global_position
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, from + direction * MAX_RANGE)
	query.collide_with_areas = false
	query.exclude = exclude_rids
	var result := space.intersect_ray(query)
	_hitting_wall = not result.is_empty() and not result.collider.is_in_group("enemy")
	if _hitting_wall:
		_beam_end = result.position
		_wall_collider = result.collider as StaticBody2D
	else:
		_beam_end = from + direction * MAX_RANGE
		_wall_collider = null

func _apply_visuals(heat_t: float) -> void:
	var charge_t := clampf(_charge_time / CHARGE_DURATION, 0.0, 1.0)

	var beam_col := BEAM_COLOR.lerp(HOT_BEAM_COLOR, heat_t)
	var core_col := CORE_COLOR.lerp(HOT_CORE_COLOR, heat_t)
	var glow_col := GLOW_COLOR.lerp(HOT_GLOW_COLOR, heat_t)

	var fw := randf_range(1.0 - FLICKER_WIDTH_VAR, 1.0 + FLICKER_WIDTH_VAR)
	var fa := randf_range(1.0 - FLICKER_ALPHA_VAR, 1.0 + FLICKER_ALPHA_VAR)
	var width_scale := charge_t * lerpf(1.0, HEAT_WIDTH_MULT, heat_t) * fw

	_outer.width = BEAM_WIDTH * width_scale
	_core.width  = CORE_WIDTH * width_scale
	_glow.width  = GLOW_WIDTH * width_scale

	beam_col.a = clampf(BEAM_COLOR.a * fa, 0.0, 1.0)
	_outer.default_color = beam_col
	_core.default_color  = core_col
	_glow.default_color  = glow_col

	var perp := Vector2(-direction.y, direction.x)
	var jitter := perp * randf_range(-JITTER_AMOUNT, JITTER_AMOUNT) * charge_t
	var end_local := to_local(_beam_end) + jitter
	_glow.set_point_position(1, end_local)
	_outer.set_point_position(1, end_local)
	_core.set_point_position(1, end_local)

	_sparks.position = end_local
	_sparks.direction = -direction
	_sparks.emitting = _hitting_wall
	_sparks.color = core_col

	_glow.visible = true
	_outer.visible = true
	_core.visible = true

func _apply_effects(delta: float, dmg: int) -> void:
	if dmg > 0 and is_instance_valid(_wall_collider) and _wall_collider.has_method("take_damage"):
		_wall_collider.take_damage(dmg)
	var from := global_position
	var beam_length: float = from.distance_to(_beam_end)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var to_enemy: Vector2 = enemy.global_position - from
		var along: float = to_enemy.dot(direction)
		if along < 0.0 or along > beam_length:
			continue
		if absf(to_enemy.cross(direction)) <= ENEMY_HIT_RADIUS:
			if dmg > 0 and enemy.has_method("take_damage"):
				enemy.take_damage(dmg)
			if enemy.has_method("apply_knockback"):
				enemy.apply_knockback(direction * KNOCKBACK_STRENGTH * delta)

func _make_line(width: float, color: Color) -> Line2D:
	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	line.material = mat
	line.add_point(Vector2.ZERO)
	line.add_point(Vector2.RIGHT * MAX_RANGE)
	return line

func _make_smoke() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.amount = 10
	p.lifetime = 1.4
	p.explosiveness = 0.1
	p.randomness = 0.8
	p.spread = 50.0
	p.direction = Vector2(0.0, -1.0)
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 35.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 7.0
	p.gravity = Vector2(0.0, -20.0)
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(0.85, 0.85, 0.85, 0.7), Color(0.5, 0.5, 0.5, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 1.0])
	p.color_ramp = ramp
	return p

func _make_sparks() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.amount = 14
	p.lifetime = 0.18
	p.explosiveness = 0.6
	p.randomness = 0.5
	p.spread = 150.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 220.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.gravity = Vector2.ZERO
	p.color = CORE_COLOR
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	return p
