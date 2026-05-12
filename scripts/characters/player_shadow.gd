extends Node2D

const LAYERS = 5
const STEPS = 24

func _draw() -> void:
	for i in LAYERS:
		var t = float(i) / (LAYERS - 1)  # 0 = outermost, 1 = innermost
		draw_colored_polygon(
			_ellipse_pts(lerpf(20.0, 10.0, t), lerpf(7.0, 3.5, t)),
			Color(0.0, 0.0, 0.0, lerpf(0.0, 0.38, t))
		)

func _ellipse_pts(w: float, h: float) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in STEPS:
		var a = float(i) / STEPS * TAU
		pts.append(Vector2(cos(a) * w, sin(a) * h))
	return pts
