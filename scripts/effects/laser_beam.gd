extends Node2D

const BEAM_WIDTH = 28.0
const CORE_WIDTH = 10.0
const MAX_RANGE = 2000.0
const ENEMY_HIT_RADIUS = 40.0
const BEAM_COLOR = Color(0.8, 0.3, 1.0, 0.85)
const CORE_COLOR = Color(1.0, 0.85, 1.0, 1.0)

var direction: Vector2 = Vector2.RIGHT
var damage: int = 10

var _damage_accum: float = 0.0
var _outer: Line2D
var _core: Line2D
var _beam_end: Vector2 = Vector2.ZERO

func _ready() -> void:
	z_index = 5
	_outer = _make_line(BEAM_WIDTH, BEAM_COLOR)
	_core  = _make_line(CORE_WIDTH,  CORE_COLOR)
	add_child(_outer)
	add_child(_core)

func _physics_process(delta: float) -> void:
	_update_beam()
	_damage_accum += damage * delta
	if _damage_accum >= 1.0:
		var dmg := int(_damage_accum)
		_damage_accum -= float(dmg)
		_apply_damage(dmg)

func _update_beam() -> void:
	var from := global_position
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, from + direction * MAX_RANGE)
	query.collide_with_areas = false
	var result := space.intersect_ray(query)
	_beam_end = result.position if result else from + direction * MAX_RANGE
	var end_local := to_local(_beam_end)
	_outer.set_point_position(1, end_local)
	_core.set_point_position(1, end_local)

func _apply_damage(dmg: int) -> void:
	var from := global_position
	var beam_length: float = from.distance_to(_beam_end)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var to_enemy: Vector2 = enemy.global_position - from
		var along: float = to_enemy.dot(direction)
		if along < 0.0 or along > beam_length:
			continue
		if absf(to_enemy.cross(direction)) <= ENEMY_HIT_RADIUS:
			if enemy.has_method("take_damage"):
				enemy.take_damage(dmg)

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
