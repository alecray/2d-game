extends Node2D

const CRACK_COUNT = 11
const SEG_LEN_MIN = 45.0
const SEG_LEN_MAX = 80.0
const SEGS_MIN = 5
const SEGS_MAX = 10
const ANGLE_JITTER = 0.38       # radians of random turn per segment
const BRANCH_CHANCE = 0.30      # probability of a side branch at each segment
const WORLD_HALF = 1300.0
const CLEAR_RADIUS = 220.0      # no cracks this close to the player spawn
const COLLISION_WIDTH = 12.0    # physics width — wider than the visual so it reliably blocks

var _taper: Curve = null  # shared across all Line2Ds

func _ready() -> void:
	z_index = -8
	z_as_relative = false
	_taper = _make_taper_curve()
	_generate()

func _generate() -> void:
	for i in CRACK_COUNT:
		var pos := _random_world_pos()
		_branch(pos, randf() * TAU, randi_range(SEGS_MIN, SEGS_MAX), 3.0, true)

func _random_world_pos() -> Vector2:
	for _attempt in 20:
		var p := Vector2(randf_range(-WORLD_HALF, WORLD_HALF), randf_range(-WORLD_HALF, WORLD_HALF))
		if p.length() > CLEAR_RADIUS:
			return p
	return Vector2(WORLD_HALF * 0.5, WORLD_HALF * 0.5)

func _branch(start: Vector2, angle: float, segments: int, width: float, can_branch: bool) -> void:
	var pts := PackedVector2Array()
	pts.append(start)
	var pos := start
	var ang := angle

	for i in segments:
		ang += randf_range(-ANGLE_JITTER, ANGLE_JITTER)
		var next := pos + Vector2.from_angle(ang) * randf_range(SEG_LEN_MIN, SEG_LEN_MAX)
		pts.append(next)
		_add_collision((pos + next) * 0.5, next - pos)

		if can_branch and randf() < BRANCH_CHANCE:
			var side := 1.0 if randf() < 0.5 else -1.0
			_branch(pos, ang + side * randf_range(0.55, 1.0), randi_range(2, 4), width * 0.55, false)

		pos = next

	var dirt_w := randf_range(0.28, 0.38)
	var dirt_h := randf_range(0.18, 0.26)
	_add_line(pts, width + 18.0, Color(dirt_w, dirt_h, 0.08, 0.75))  # dirt patch
	_add_line(pts, width + 3.5,  Color(0.0, 0.0, 0.0, 0.6))          # shadow
	var v := randf_range(0.06, 0.15)
	_add_line(pts, width, Color(v, v * 0.85, v * 0.7, 0.95))         # crack

func _add_line(pts: PackedVector2Array, width: float, color: Color) -> void:
	var line := Line2D.new()
	line.points = pts
	line.width = width
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_SHARP
	line.begin_cap_mode = Line2D.LINE_CAP_NONE
	line.end_cap_mode = Line2D.LINE_CAP_NONE
	line.width_curve = _taper
	add_child(line)

func _add_collision(center: Vector2, diff: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 0
	body.collision_mask = 0
	body.position = center
	var cshape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(diff.length(), COLLISION_WIDTH)
	cshape.shape = rect
	cshape.rotation = diff.angle()
	body.add_child(cshape)
	add_child(body)

func _make_taper_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.5))
	c.add_point(Vector2(0.12, 1.0))
	c.add_point(Vector2(0.78, 0.85))
	c.add_point(Vector2(1.0, 0.0))
	return c
