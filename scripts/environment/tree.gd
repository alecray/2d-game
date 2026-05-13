extends Node2D

# base values — actual per-tree values are randomised in _ready()
const BASE_LEAF_COUNT = 35
const BASE_CANOPY_RADIUS = 30.0
const BASE_LEAF_SIZE_MIN = 8.0
const BASE_LEAF_SIZE_MAX = 14.0
const BASE_TRUNK_WIDTH = 11.0
const BASE_TRUNK_HEIGHT = 28.0
const TRUNK_MAX_LEAN = 0.10
const WIND_SPEED = 1.3
const BASE_WIND_AMPLITUDE = 3.0

# per-instance values
var LEAF_COUNT: int
var CANOPY_RADIUS: float
var LEAF_SIZE_MIN: float
var LEAF_SIZE_MAX: float
var TRUNK_WIDTH: float
var TRUNK_HEIGHT: float
var WIND_AMPLITUDE: float
var CANOPY_Y: float

var _leaf_pos: PackedVector2Array = PackedVector2Array()
var _leaf_size: PackedFloat32Array = PackedFloat32Array()
var _leaf_rot: PackedFloat32Array = PackedFloat32Array()
var _leaf_phase: PackedFloat32Array = PackedFloat32Array()
var _leaf_color: Array = []
var _trunk_angle: float = 0.0
var _time: float = 0.0
var _canopy: Node2D
var _player: Node2D = null

const TreeCanopy = preload("res://scripts/environment/tree_canopy.gd")

func _ready() -> void:
	z_index = 5
	z_as_relative = false
	_time = randf() * TAU
	_trunk_angle = randf_range(-TRUNK_MAX_LEAN, TRUNK_MAX_LEAN)

	# overall size scale so trees feel varied at a glance
	var size_scale := randf_range(0.6, 1.5)
	TRUNK_WIDTH    = BASE_TRUNK_WIDTH  * size_scale * randf_range(0.8, 1.2)
	TRUNK_HEIGHT   = BASE_TRUNK_HEIGHT * size_scale * randf_range(0.8, 1.3)
	CANOPY_RADIUS  = BASE_CANOPY_RADIUS * size_scale * randf_range(0.75, 1.25)
	LEAF_SIZE_MIN  = BASE_LEAF_SIZE_MIN * size_scale * randf_range(0.7, 1.1)
	LEAF_SIZE_MAX  = BASE_LEAF_SIZE_MAX * size_scale * randf_range(0.9, 1.3)
	LEAF_COUNT     = int(BASE_LEAF_COUNT * size_scale * randf_range(0.7, 1.3))
	WIND_AMPLITUDE = BASE_WIND_AMPLITUDE * randf_range(0.6, 1.4)
	CANOPY_Y       = -(TRUNK_HEIGHT + randf_range(5.0, 18.0))

	for i in LEAF_COUNT:
		var angle := randf() * TAU
		var dist := sqrt(randf()) * CANOPY_RADIUS
		_leaf_pos.append(Vector2.from_angle(angle) * dist)
		_leaf_size.append(randf_range(LEAF_SIZE_MIN, LEAF_SIZE_MAX))
		_leaf_rot.append(randf() * TAU)
		_leaf_phase.append(randf() * TAU)
		var palette: Array = get_node("/root/GameState").map_leaf_palette
		var v := randf()
		var c: Color = palette[
			0 if v < 0.30 else 1 if v < 0.65 else 2 if v < 0.90 else 3
		]
		_leaf_color.append(Color(c.r, c.g, c.b, 1.0))

	var body := StaticBody2D.new()
	var cshape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TRUNK_WIDTH + 4.0, TRUNK_HEIGHT)  # uses randomised values
	cshape.shape = rect
	cshape.position = Vector2(0.0, -TRUNK_HEIGHT * 0.5)
	cshape.rotation = _trunk_angle
	body.add_child(cshape)
	add_child(body)

	_canopy = Node2D.new()
	_canopy.set_script(TreeCanopy)
	add_child(_canopy)

func _process(delta: float) -> void:
	_time += delta * WIND_SPEED
	queue_redraw()
	_canopy.queue_redraw()
	# flip canopy z so player appears in front when south of trunk, behind when north
	if _player:
		_canopy.z_index = 5 if _player.global_position.y > global_position.y else 15

func _draw() -> void:
	# ground shadow
	draw_set_transform(Vector2(5, 3), 0.0, Vector2(1.2, 0.4))
	draw_circle(Vector2.ZERO, TRUNK_WIDTH, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# trunk
	draw_set_transform(Vector2.ZERO, _trunk_angle, Vector2.ONE)
	draw_rect(Rect2(-TRUNK_WIDTH * 0.5, -TRUNK_HEIGHT, TRUNK_WIDTH, TRUNK_HEIGHT),
			Color(0.26, 0.15, 0.07, 1.0))
	draw_rect(Rect2(-TRUNK_WIDTH * 0.5, -TRUNK_HEIGHT + 2.0, TRUNK_WIDTH * 0.28, TRUNK_HEIGHT - 4.0),
			Color(0.36, 0.22, 0.10, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
