extends Node2D

func _draw() -> void:
	draw_colored_polygon(_circle_pts(6.0, 8), Color.WHITE)

func _circle_pts(r: float, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps:
		var a := float(i) / steps * TAU
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	return pts
