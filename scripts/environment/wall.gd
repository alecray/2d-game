extends StaticBody2D

var size = Vector2(80, 20)
var _poly: PackedVector2Array
var _uvs: PackedVector2Array

const EDGE_ROUGHNESS = 4.0
const EDGE_SEGMENTS = 1
const TILE_SIZE = 32.0  # world units one full texture tile covers — match your texture's pixel size

var texture: Texture2D  # set by main.gd after instantiation; falls back to solid gray if null

func _ready() -> void:
	add_to_group("destructible_wall")
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	var shape = RectangleShape2D.new()
	shape.size = size
	var col = CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	_poly = _build_rough_poly(size)
	_uvs = _build_uvs(_poly)

## Builds a rectangle polygon with gently bowed, irregular edges for a worn-stone look.
## Each edge gets 3 intermediate points offset by a sine-weighted random amount so the
## bulge is smooth (peaks at the midpoint, tapers to nothing at the corners).
func _build_rough_poly(s: Vector2) -> PackedVector2Array:
	var pts = PackedVector2Array()
	var h = s / 2
	var roughness = EDGE_ROUGHNESS
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
		for i in range(1, EDGE_SEGMENTS):
			var t = float(i) / float(EDGE_SEGMENTS)
			var mid = a.lerp(b, t)
			var bow = sin(t * PI) * randf_range(-roughness, roughness)
			pts.append(mid + n * bow)
	return pts

## Maps each polygon vertex to a UV coordinate so the texture tiles across the surface.
func _build_uvs(poly: PackedVector2Array) -> PackedVector2Array:
	var uvs = PackedVector2Array()
	for point in poly:
		uvs.append(point / TILE_SIZE)
	return uvs

func _draw() -> void:
	if texture:
		draw_colored_polygon(_poly, Color.WHITE, _uvs, texture)
	else:
		draw_colored_polygon(_poly, Color(0.20, 0.20, 0.20))
