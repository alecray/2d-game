extends Node2D

func _draw() -> void:
	draw_colored_polygon(
		_ellipse_pts(20.0, 7.0, 8),
		Color(0.0, 0.0, 0.0, 0.38)
	)

func _ellipse_pts(w: float, h: float, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps:
		var a := float(i) / steps * TAU
		pts.append(Vector2(cos(a) * w, sin(a) * h))
	return pts
