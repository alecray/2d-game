extends Node2D

var _corners := PackedVector2Array()

func _ready() -> void:
	_corners.resize(4)
	z_as_relative = false
	z_index = 15  # default: in front of player; parent overrides each frame

func _draw() -> void:
	var tree := get_parent()
	if not tree:
		return
	var gust: float = sin(tree._time) * tree.WIND_AMPLITUDE
	var gust_fast: float = sin(tree._time * 2.8) * tree.WIND_AMPLITUDE * 0.28
	for i in tree.LEAF_COUNT:
		var wx: float = gust + sin(tree._time + tree._leaf_phase[i] * 0.4) * 1.2 + gust_fast
		var wy: float = sin(tree._time * 0.6 + tree._leaf_phase[i] * 0.3) * tree.WIND_AMPLITUDE * 0.18
		var p: Vector2 = Vector2(wx, wy) + tree._leaf_pos[i] + Vector2(0.0, tree.CANOPY_Y)
		var half: float = tree._leaf_size[i] * 0.5
		var r: float = tree._leaf_rot[i] + sin(tree._time + tree._leaf_phase[i] * 0.4) * 0.18
		_corners[0] = p + Vector2(-half, -half).rotated(r)
		_corners[1] = p + Vector2( half, -half).rotated(r)
		_corners[2] = p + Vector2( half,  half).rotated(r)
		_corners[3] = p + Vector2(-half,  half).rotated(r)
		draw_colored_polygon(_corners, tree._leaf_color[i])
	draw_circle(Vector2(-7, tree.CANOPY_Y - 8), tree.CANOPY_RADIUS * 0.28,
			get_node("/root/GameState").map_canopy_shadow)
