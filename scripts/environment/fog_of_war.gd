extends CanvasLayer

const FOG_SHADER := preload("res://assets/shaders/fog_of_war.gdshader")

# One fog pixel per 8 world-px.  The texture is _cols × _rows pixels,
# computed from the maze world size in setup().
const CELL_SIZE    := 8.0
const LOS_RAYS     := 180    # angular rays for LOS — more = smoother fog boundary
const VIEW_RANGE   := 400.0  # world-px radius revealed around the player
const SAMPLE_DIST  := 16.0   # world-px movement before re-running LOS
const FADE_SPEED        := 1.0   # reveal alpha units per second (1/FADE_SPEED = fade duration)
const ENEMY_FADE_SPEED  := 6.0   # how fast enemies fade in/out at fog boundary

# Minimap
const MM_W   := 180
const MM_H   := 159
const MM_PAD := 12

var _fog_img   : Image
var _fog_tex   : ImageTexture
var _mat       : ShaderMaterial
var _mm_dot    : ColorRect
var _mm_layer  : CanvasLayer
var _elapsed_time : float = 0.0

var _player : Node2D
var _origin : Vector2
var _size   : Vector2
var _cols   : int
var _rows   : int

var _last_pos              := Vector2(1e9, 1e9)
var _first_tick            := true
var _visibility_initialized := false
var _pending               : Dictionary = {}   # Vector2i cell → float alpha (0..1)
var _fog_vis_accum         : float = 0.0       # accumulated delta for throttled visibility updates

## Must be called before add_child() so _ready() has valid origin/size.
func setup(player: Node2D, maze_origin: Vector2, maze_world_size: Vector2) -> void:
	_player = player
	_origin = maze_origin
	_size   = maze_world_size
	_cols   = int(ceil(maze_world_size.x / CELL_SIZE))
	_rows   = int(ceil(maze_world_size.y / CELL_SIZE))

func _ready() -> void:
	layer = 8
	# World-space: the fog layer pans and zooms with the camera so the overlay
	# always correctly covers the maze regardless of camera zoom level.
	follow_viewport_enabled = true

	_fog_img = Image.create(_cols, _rows, false, Image.FORMAT_L8)
	_fog_img.fill(Color.BLACK)
	_fog_tex = ImageTexture.create_from_image(_fog_img)

	# Cover the maze in world coordinates — UV maps directly to fog_uv in the shader.
	var rect := ColorRect.new()
	rect.position = _origin
	rect.size = _size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_mat = ShaderMaterial.new()
	_mat.shader = FOG_SHADER
	_mat.set_shader_parameter("fog_mask", _fog_tex)
	_mat.set_shader_parameter("maze_origin", _origin)
	_mat.set_shader_parameter("maze_size",   _size)

	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.003
	var noise_tex := NoiseTexture2D.new()
	noise_tex.noise = noise
	noise_tex.width = 256
	noise_tex.height = 256
	noise_tex.seamless = true
	_mat.set_shader_parameter("fog_noise_tex", noise_tex)

	rect.material = _mat
	add_child(rect)

	# Minimap lives on its own screen-fixed CanvasLayer so it isn't affected by
	# follow_viewport_enabled scaling on this layer.
	_mm_layer = CanvasLayer.new()
	_mm_layer.layer = 9
	add_child(_mm_layer)
	_build_minimap()

func _process(delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		return

	_elapsed_time += delta
	_mat.set_shader_parameter("time", _elapsed_time)

	if _first_tick or _player.global_position.distance_to(_last_pos) >= SAMPLE_DIST:
		_first_tick = false
		_last_pos = _player.global_position
		_update_los()

	_advance_pending(delta)
	_update_fog_visibility(delta)
	_process_minimap_dot()

func _update_los() -> void:
	var space : PhysicsDirectSpaceState2D = _player.get_world_2d().direct_space_state
	var from  := _player.global_position
	var excl  := [_player.get_rid()]

	# Always reveal the cell directly under the player
	var pc := _world_to_cell(from)
	if pc.x >= 0 and pc.x < _cols and pc.y >= 0 and pc.y < _rows:
		if _fog_img.get_pixel(pc.x, pc.y).r < 1.0 and not (pc in _pending):
			_pending[pc] = 0.0

	# Cast LOS_RAYS evenly-spaced angular rays. For each ray, march cell-by-cell
	# along the ray and reveal every cell until a wall blocks the path.
	# This is O(LOS_RAYS) physics queries regardless of CELL_SIZE.
	for i in LOS_RAYS:
		var dir := Vector2.from_angle(float(i) / LOS_RAYS * TAU)
		var to  := from + dir * VIEW_RANGE

		var query := PhysicsRayQueryParameters2D.create(from, to)
		query.collide_with_areas = false
		query.exclude = excl
		var hit : Dictionary = space.intersect_ray(query)

		# How far can we see along this ray?
		var end_dist := VIEW_RANGE
		if not hit.is_empty() and hit.collider is StaticBody2D:
			# Stop just past the wall face so the wall tile itself is revealed
			end_dist = from.distance_to(hit.position) + CELL_SIZE

		# Reveal every cell from the player outward to end_dist
		var steps := int(end_dist / CELL_SIZE) + 1
		for step in steps:
			var wp   := from + dir * (step * CELL_SIZE)
			var cell := _world_to_cell(wp)
			if cell.x < 0 or cell.x >= _cols or cell.y < 0 or cell.y >= _rows:
				break
			if _fog_img.get_pixel(cell.x, cell.y).r >= 1.0:
				continue  # already fully revealed — skip
			if not (cell in _pending):
				_pending[cell] = 0.0

func _advance_pending(delta: float) -> void:
	if _pending.is_empty():
		return
	var done : Array = []
	for cell : Vector2i in _pending:
		var val : float = minf(_pending[cell] + delta * FADE_SPEED, 1.0)
		_pending[cell] = val
		_fog_img.set_pixel(cell.x, cell.y, Color(val, val, val))
		if val >= 1.0:
			done.append(cell)
	for cell : Vector2i in done:
		_pending.erase(cell)
	_fog_tex.update(_fog_img)

func _update_fog_visibility(delta: float) -> void:
	var snap := not _visibility_initialized
	_visibility_initialized = true
	_fog_vis_accum += delta
	# Run every 3 frames; accumulate delta so the lerp speed stays correct.
	if not snap and Engine.get_process_frames() % 3 != 0:
		return
	var effective_delta := _fog_vis_accum
	_fog_vis_accum = 0.0
	for group in ["enemy", "merchant"]:
		for node in get_tree().get_nodes_in_group(group):
			if not is_instance_valid(node):
				continue
			var target := _fog_value_at(node.global_position)
			node.modulate.a = target if snap else lerpf(node.modulate.a, target, effective_delta * ENEMY_FADE_SPEED)

func _fog_value_at(world_pos: Vector2) -> float:
	var cell := _world_to_cell(world_pos)
	if cell.x < 0 or cell.x >= _cols or cell.y < 0 or cell.y >= _rows:
		return 0.0
	return _fog_img.get_pixel(cell.x, cell.y).r

func _world_to_cell(world_pos: Vector2) -> Vector2i:
	var rel := world_pos - _origin
	return Vector2i(int(rel.x / CELL_SIZE), int(rel.y / CELL_SIZE))

func _cell_to_world(cx: int, cy: int) -> Vector2:
	return _origin + Vector2((cx + 0.5) * CELL_SIZE, (cy + 0.5) * CELL_SIZE)

func _build_minimap() -> void:
	var vp      := get_viewport()
	var vp_size : Vector2 = vp.get_visible_rect().size if vp else Vector2(1280.0, 720.0)
	var mm := Control.new()
	mm.set_anchors_preset(Control.PRESET_TOP_LEFT)
	mm.position = Vector2(vp_size.x - MM_W - MM_PAD, MM_PAD)
	mm.size     = Vector2(MM_W, MM_H)
	mm.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_mm_layer.add_child(mm)

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.10, 0.90)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mm.add_child(bg)

	var map_tex := TextureRect.new()
	map_tex.texture        = _fog_tex
	map_tex.stretch_mode   = TextureRect.STRETCH_SCALE
	map_tex.expand_mode    = TextureRect.EXPAND_IGNORE_SIZE
	map_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_tex.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	mm.add_child(map_tex)

	_mm_dot = ColorRect.new()
	_mm_dot.color        = Color(0.20, 1.00, 0.45)
	_mm_dot.size         = Vector2(4.0, 4.0)
	_mm_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mm.add_child(_mm_dot)

func set_fog_color(color: Color) -> void:
	_mat.set_shader_parameter("fog_color", color)

func reveal_area(world_pos: Vector2, radius: float) -> void:
	var cell_radius := int(ceil(radius / CELL_SIZE))
	var center := _world_to_cell(world_pos)
	for dy in range(-cell_radius, cell_radius + 1):
		for dx in range(-cell_radius, cell_radius + 1):
			if dx * dx + dy * dy > cell_radius * cell_radius:
				continue
			var cx := center.x + dx
			var cy := center.y + dy
			if cx < 0 or cx >= _cols or cy < 0 or cy >= _rows:
				continue
			_fog_img.set_pixel(cx, cy, Color.WHITE)
	_fog_tex.update(_fog_img)

func _process_minimap_dot() -> void:
	if _mm_dot and _player and is_instance_valid(_player):
		var puv := (_player.global_position - _origin) / _size
		_mm_dot.position = Vector2(puv.x * MM_W - 2.0, puv.y * MM_H - 2.0)
