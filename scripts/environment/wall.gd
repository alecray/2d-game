extends StaticBody2D

var size = Vector2(80, 20)
var _poly: PackedVector2Array

func _ready() -> void:
	var shape = RectangleShape2D.new()
	shape.size = size
	var col = CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	_poly = _build_rough_poly(size)

## Builds a rectangle polygon with gently bowed, irregular edges for a worn-stone look.
## Each edge gets 3 intermediate points offset by a sine-weighted random amount so the
## bulge is smooth (peaks at the midpoint, tapers to nothing at the corners).
func _build_rough_poly(s: Vector2) -> PackedVector2Array:
	var pts = PackedVector2Array()
	var h = s / 2
	var roughness = 4.0
	var edges = [
		[Vector2(-h.x, -h.y), Vector2( h.x, -h.y), Vector2( 0, -1)],
		[Vector2( h.x, -h.y), Vector2( h.x,  h.y), Vector2( 1,  0)],
		[Vector2( h.x,  h.y), Vector2(-h.x,  h.y), Vector2( 0,  1)],
		[Vector2(-h.x,  h.y), Vector2(-h.x, -h.y), Vector2(-1,  0)],
	]
	for edge in edges:
		var a: Vector2 = edge[0]
		var b: Vector2 = edge[1]
		var n: Vector2 = edge[2]
		pts.append(a)
		for i in range(1, 4):
			var t = float(i) / 4.0
			var mid = a.lerp(b, t)
			var bow = sin(t * PI) * randf_range(-roughness, roughness)
			pts.append(mid + n * bow)
	return pts

func _draw() -> void:
	draw_colored_polygon(_poly, Color(0.20, 0.20, 0.20))
	var outline = PackedVector2Array(_poly)
	outline.append(_poly[0])
	draw_polyline(outline, Color(0.04, 0.04, 0.04), 2.0)
