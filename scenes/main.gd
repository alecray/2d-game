## Main game scene - manages enemy spawning and level environment
extends Node2D

const SPIDER_SCENE = preload("res://prefabs/enemies/spider.tscn")  # fallback
const GRASS_SCENE_DEFAULT = preload("res://prefabs/environment/grass1.tscn")
const WALL_SCRIPT = preload("res://scripts/environment/wall.gd")
const DUST_SCRIPT = preload("res://scripts/environment/dust_particles.gd")
const TreeGenerator = preload("res://scripts/environment/tree_generator.gd")
const WALL_TEXTURE_SOLID    := preload("res://assets/sprites/environment/wall1.png")
const BREAKABLE_WALL_SCRIPT := preload("res://scripts/environment/breakable_wall.gd")
const BREAKABLE_WALL_CHANCE   := 0.30   # fraction of wall segments that are breakable
const EXTRA_OPEN_CHANCE       := 0.30   # fraction of closed passages reopened for ruin feel
const PILLAR_REMOVE_CHANCE    := 0.45   # fraction of corner pillars omitted
const TorchLight = preload("res://scripts/environment/torch_light.gd")
const CloudLayer = preload("res://scripts/environment/cloud_layer.gd")
const FogOfWar        = preload("res://scripts/environment/fog_of_war.gd")
const SpellbookHUD    = preload("res://scripts/ui/spellbook_hud.gd")
const PedestalScript  = preload("res://scripts/environment/pedestal.gd")
const MerchantScene   = preload("res://prefabs/npcs/merchant.tscn")
const CRATE_SCENE     = preload("res://prefabs/items/crate.tscn")
const CRATE_COUNT     = 8   # crates scattered through the maze (plus 1 guaranteed near start)
const TORCH_ON_WALL_CHANCE = 0.25
const CLUSTER_SPREAD = 40.0
const MAX_ENEMIES_CAP = 80
const ELITE_CHANCE = 0.15   # 15% chance a cluster spawns as elite
const ELITE_PACK_SIZE = 3   # elite clusters always spawn this many
const RARE_CHANCE = 0.02    # 2% chance any individual enemy spawns as rare (golden)
const INITIAL_ENEMY_COUNT := 60   # total enemies placed at game start
const INITIAL_MIN_DIST    := 280.0 # world-space radius around origin kept clear of enemies
const WORLD_SIZE = 2700
const MAP_BOUNDS = Vector2(1576, 1440)  # half-extents of the background sprite — matches player.gd WORLD_BOUNDS
const GRASS_COUNT = 100
const WALL_UNIT = 32  # one tile — matches TILE_SIZE in wall.gd so each block is exactly one texture tile

# Maze generation — sized to cover the full background (3152 × 2880 px)
const MAZE_COLS := 17   # cells wide  → (17×6+1)×32 = 3296 px  (±1648, covers ±1576)
const MAZE_ROWS := 15   # cells tall  → (15×6+1)×32 = 2912 px  (±1456, covers ±1440)
const MAZE_CELL := 5    # corridor width in tiles (5 × 32 = 160 px)
# wall thickness is always 1 tile (WALL_UNIT = 32 px)

@onready var player = $CharacterBody2D_Player
@onready var grass_parent = $GrassParent
@onready var _bg_sprite = $Sprite2D_Background
const FONT_BOSS = preload("res://assets/fonts/PressStart2P-Regular.ttf")
const BossDeathParticles = preload("res://scripts/effects/enemy_death_particles.gd")
const BossHealthBarScript = preload("res://scripts/ui/boss_health_bar.gd")
const BossArrowScene = preload("res://prefabs/ui/boss_arrow.tscn")

var _grass_scene: PackedScene
var _spawn_table: Array = []
var _next_pack_id := 0
var _boss_alive := false
var _boss_triggered := false

func _ready() -> void:
	add_to_group("main_scene")
	var state = get_node("/root/GameState")
	RenderingServer.set_default_clear_color(state.map_bg_color)
	var tex = load(state.map_bg_texture)
	if tex:
		_bg_sprite.texture = tex
	_grass_scene = load(state.map_grass_scene) if state.map_grass_scene else GRASS_SCENE_DEFAULT
	for entry in state.map_spawn_table:
		var w := float(entry["weight"])
		if w > 0.0:
			_spawn_table.append({"scene": load(entry["scene"]) as PackedScene, "weight": w})
	var dust = CPUParticles2D.new()
	dust.set_script(DUST_SCRIPT)
	player.add_child(dust)
	var spawn_area_size = Vector2(WORLD_SIZE, WORLD_SIZE)
	var spawn_area_offset = -spawn_area_size / 2
	spawn_grass_in_area(GRASS_COUNT, spawn_area_size, spawn_area_offset)
	spawn_maze()
	_spawn_pedestal()
	_spawn_merchant()
	_spawn_crates()
	var trees := Node2D.new()
	trees.set_script(TreeGenerator)
	add_child(trees)
	_setup_lighting()
	var clouds := Node2D.new()
	clouds.set_script(CloudLayer)
	add_child(clouds)
	_spawn_fog()
	_spawn_spellbook_hud()
	_spawn_initial_enemies()
	get_tree().create_timer(1.5).timeout.connect(_spawn_hint_banner, CONNECT_ONE_SHOT)

func _spawn_hint_banner() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 15
	get_tree().root.add_child(layer)
	var lbl := Label.new()
	lbl.text = "find the key pedestal"
	lbl.add_theme_font_override("font", FONT_BOSS)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.modulate.a = 0.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	lbl.offset_top = 48
	lbl.offset_bottom = 90
	layer.add_child(lbl)
	var tween := lbl.create_tween()
	tween.tween_property(lbl, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_QUAD)
	tween.tween_interval(2.5)
	tween.tween_property(lbl, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(layer.queue_free)

func _spawn_merchant() -> void:
	var G       := MAZE_CELL + 1
	var total_w := (MAZE_COLS * G + 1) * WALL_UNIT
	var total_h := (MAZE_ROWS * G + 1) * WALL_UNIT
	var org     := Vector2(-total_w * 0.5, -total_h * 0.5)

	var candidates: Array[Vector2] = []
	for r in MAZE_ROWS:
		for c in MAZE_COLS:
			var cell_center := org + Vector2((c * G + G * 0.5) * WALL_UNIT, (r * G + G * 0.5) * WALL_UNIT)
			if cell_center.length() >= 300.0:
				candidates.append(cell_center)

	if candidates.is_empty():
		return
	candidates.shuffle()
	var merchant := MerchantScene.instantiate()
	add_child(merchant)
	merchant.global_position = candidates[0]

## Picks a random maze cell at least 500 px from the origin and places the Pedestal there.
func _spawn_crates() -> void:
	var G       := MAZE_CELL + 1
	var total_w := float((MAZE_COLS * G + 1) * WALL_UNIT)
	var total_h := float((MAZE_ROWS * G + 1) * WALL_UNIT)
	var org     := Vector2(-total_w * 0.5, -total_h * 0.5)

	var near_cells: Array[Vector2] = []
	var far_cells:  Array[Vector2] = []
	for r in MAZE_ROWS:
		for c in MAZE_COLS:
			var center := org + Vector2((c * G + G * 0.5) * WALL_UNIT, (r * G + G * 0.5) * WALL_UNIT)
			if center.length() <= 200.0:
				near_cells.append(center)
			else:
				far_cells.append(center)

	# One crate guaranteed close to player start
	if not near_cells.is_empty():
		near_cells.shuffle()
		var crate := CRATE_SCENE.instantiate()
		add_child(crate)
		crate.global_position = near_cells[0]

	# Scatter the rest across the maze
	far_cells.shuffle()
	for i in mini(CRATE_COUNT, far_cells.size()):
		var crate := CRATE_SCENE.instantiate()
		add_child(crate)
		crate.global_position = far_cells[i]

func _spawn_pedestal() -> void:
	var G      := MAZE_CELL + 1
	var total_w := (MAZE_COLS * G + 1) * WALL_UNIT
	var total_h := (MAZE_ROWS * G + 1) * WALL_UNIT
	var org    := Vector2(-total_w * 0.5, -total_h * 0.5)

	var candidates: Array[Vector2] = []
	for r in MAZE_ROWS:
		for c in MAZE_COLS:
			var cell_center := org + Vector2((c * G + G * 0.5) * WALL_UNIT, (r * G + G * 0.5) * WALL_UNIT)
			if cell_center.length() >= 500.0:
				candidates.append(cell_center)

	if candidates.is_empty():
		return
	var pos := candidates[randi() % candidates.size()]
	var pedestal := Node2D.new()
	pedestal.set_script(PedestalScript)
	add_child(pedestal)
	pedestal.global_position = pos

func _spawn_spellbook_hud() -> void:
	var hud := CanvasLayer.new()
	hud.set_script(SpellbookHUD)
	hud.setup(player)
	add_child(hud)

func _spawn_fog() -> void:
	var G      := MAZE_CELL + 1
	var maze_w := float((MAZE_COLS * G + 1) * WALL_UNIT)
	var maze_h := float((MAZE_ROWS * G + 1) * WALL_UNIT)
	var origin := Vector2(-maze_w * 0.5, -maze_h * 0.5)
	var fog    := CanvasLayer.new()
	fog.set_script(FogOfWar)
	# setup() before add_child() so _origin/_size exist when _ready() builds the wall map
	fog.setup(player, origin, Vector2(maze_w, maze_h))
	add_child(fog)
	fog.set_fog_color(get_node("/root/GameState").map_fog_color)

func _setup_lighting() -> void:
	var canvas_mod = CanvasModulate.new()
	canvas_mod.color = get_node("/root/GameState").map_world_color
	add_child(canvas_mod)

## Recursive-backtracker DFS maze.  Returns two 2-D bool arrays:
##   "right"[r][c] — passage open between cell (r,c) and (r, c+1)
##   "down" [r][c] — passage open between cell (r,c) and (r+1, c)
func _generate_maze_passages(rows: int, cols: int) -> Dictionary:
	var right: Array = []   # rows × (cols-1)
	var down:  Array = []   # (rows-1) × cols
	for r in rows:
		right.append([])
		for c in cols - 1:
			right[r].append(false)
	for r in rows - 1:
		down.append([])
		for c in cols:
			down[r].append(false)

	var visited: Array = []
	for r in rows:
		visited.append([])
		for c in cols:
			visited[r].append(false)

	var stack: Array = [Vector2i(randi() % cols, randi() % rows)]
	visited[stack[0].y][stack[0].x] = true

	while stack.size() > 0:
		var cur: Vector2i = stack.back()
		var r: int = cur.y
		var c: int = cur.x
		var nb: Array = []
		if r > 0        and not visited[r-1][c]: nb.append(Vector2i( 0,-1))
		if r < rows - 1 and not visited[r+1][c]: nb.append(Vector2i( 0, 1))
		if c > 0        and not visited[r][c-1]: nb.append(Vector2i(-1, 0))
		if c < cols - 1 and not visited[r][c+1]: nb.append(Vector2i( 1, 0))
		if nb.size() > 0:
			var d: Vector2i = nb[randi() % nb.size()]
			if   d.y ==  1: down [r  ][c  ] = true
			elif d.y == -1: down [r-1][c  ] = true
			elif d.x ==  1: right[r  ][c  ] = true
			else:           right[r  ][c-1] = true
			var nr := r + d.y
			var nc := c + d.x
			visited[nr][nc] = true
			stack.append(Vector2i(nc, nr))
		else:
			stack.pop_back()

	# Ruin pass: randomly reopen a fraction of remaining walls to create loops
	for r in rows:
		for c in range(cols - 1):
			if not right[r][c] and randf() < EXTRA_OPEN_CHANCE:
				right[r][c] = true
	for r in range(rows - 1):
		for c in cols:
			if not down[r][c] and randf() < EXTRA_OPEN_CHANCE:
				down[r][c] = true

	return {"right": right, "down": down}

## Builds a perfect maze using the recursive-backtracker algorithm and places
## wall segments using the existing _place_wall / _try_place_torch pipeline.
## No outer border is placed — every edge corridor opens to the world so
## enemies can enter freely from any direction.
func spawn_maze() -> void:
	var rows    := MAZE_ROWS
	var cols    := MAZE_COLS
	var cell    := MAZE_CELL   # corridor width in tiles
	var wall    := 1           # wall thickness in tiles
	var G       := cell + wall # grid unit in tiles (= 4)
	var u       := WALL_UNIT   # px per tile (= 32)

	var passages := _generate_maze_passages(rows, cols)
	var pr: Array = passages["right"]
	var pd: Array = passages["down"]

	# Centre the maze at world origin
	var total_w: float = (cols * G + wall) * u
	var total_h: float = (rows * G + wall) * u
	var org := Vector2(-total_w * 0.5, -total_h * 0.5)

	# Returns the world-space centre of a tile-block at (tx,ty) with size (tw,th) tiles
	var wp = func(tx: int, ty: int, tw: int, th: int) -> Vector2:
		return org + Vector2((tx + tw * 0.5) * u, (ty + th * 0.5) * u)

	# ── Inner corner pillars — omit ~45 % to widen collapsed junctions ───────
	for ir in range(1, rows):
		for ic in range(1, cols):
			if randf() >= PILLAR_REMOVE_CHANCE:
				_place_wall(wp.call(ic*G, ir*G, wall, wall), Vector2(wall*u, wall*u), false)

	# ── Vertical wall strips — 30 % chance breakable ─────────────────────────
	for r in rows:
		for c in range(cols - 1):
			if not pr[r][c]:
				_place_wall(wp.call((c+1)*G, r*G+wall, wall, cell),
					Vector2(wall*u, cell*u), randf() < BREAKABLE_WALL_CHANCE)

	# ── Horizontal wall strips — 30 % chance breakable ───────────────────────
	for r in range(rows - 1):
		for c in cols:
			if not pd[r][c]:
				_place_wall(wp.call(c*G+wall, (r+1)*G, cell, wall),
					Vector2(cell*u, wall*u), randf() < BREAKABLE_WALL_CHANCE)

func _place_wall(pos: Vector2, size: Vector2, breakable: bool = false) -> void:
	if breakable:
		# Split the strip into individual WALL_UNIT×WALL_UNIT cells so each block
		# has its own health and can be destroyed independently.
		var count_x := int(round(size.x / WALL_UNIT))
		var count_y := int(round(size.y / WALL_UNIT))
		var half_x  := (count_x - 1) * 0.5 * WALL_UNIT
		var half_y  := (count_y - 1) * 0.5 * WALL_UNIT
		for cy in count_y:
			for cx in count_x:
				var cell_pos := pos + Vector2(cx * WALL_UNIT - half_x, cy * WALL_UNIT - half_y)
				var w := StaticBody2D.new()
				w.set_script(BREAKABLE_WALL_SCRIPT)
				w.size = Vector2(WALL_UNIT, WALL_UNIT)
				add_child(w)
				w.global_position = cell_pos
		return
	var wall := StaticBody2D.new()
	wall.set_script(WALL_SCRIPT)
	wall.size = size
	wall.rotation = 0.0
	add_child(wall)
	wall.global_position = pos
	wall.texture = WALL_TEXTURE_SOLID
	_try_place_torch(wall)


func _try_place_torch(wall: StaticBody2D) -> void:
	if randf() > TORCH_ON_WALL_CHANCE:
		return
	var w = wall.size.x
	var h = wall.size.y
	var local_offset: Vector2
	if w >= h:
		var side = 1.0 if randf() < 0.5 else -1.0
		local_offset = Vector2(randf_range(-w * 0.35, w * 0.35), side * (h * 0.5 + 10.0))
	else:
		var side = 1.0 if randf() < 0.5 else -1.0
		local_offset = Vector2(side * (w * 0.5 + 10.0), randf_range(-h * 0.35, h * 0.35))
	var torch = PointLight2D.new()
	torch.set_script(TorchLight)
	torch.position = wall.global_position + local_offset.rotated(wall.rotation)
	add_child(torch)

## Places all enemies at game start in clusters spread across maze cells.
func _spawn_initial_enemies() -> void:
	var G       := MAZE_CELL + 1
	var total_w := float((MAZE_COLS * G + 1) * WALL_UNIT)
	var total_h := float((MAZE_ROWS * G + 1) * WALL_UNIT)
	var org     := Vector2(-total_w * 0.5, -total_h * 0.5)

	var cells: Array[Vector2] = []
	for r in MAZE_ROWS:
		for c in MAZE_COLS:
			var center := org + Vector2((c * G + G * 0.5) * WALL_UNIT, (r * G + G * 0.5) * WALL_UNIT)
			if center.length() >= INITIAL_MIN_DIST:
				cells.append(center)
	cells.shuffle()

	var spawned := 0
	var cell_idx := 0
	while spawned < INITIAL_ENEMY_COUNT and cell_idx < cells.size():
		var is_elite := randf() < ELITE_CHANCE
		var cluster_size := ELITE_PACK_SIZE if is_elite else randi_range(2, 4)
		var pack_id := -1
		if is_elite:
			pack_id = _next_pack_id
			_next_pack_id += 1
		for i in mini(cluster_size, INITIAL_ENEMY_COUNT - spawned):
			var offset := Vector2.from_angle(randf() * TAU) * randf() * CLUSTER_SPREAD
			spawn_enemy(cells[cell_idx] + offset, is_elite, pack_id, 1.0)
			spawned += 1
		cell_idx += 1

func _pick_enemy_scene() -> PackedScene:
	if _spawn_table.is_empty():
		return SPIDER_SCENE
	var total := 0.0
	for entry in _spawn_table:
		total += entry["weight"]
	var roll := randf() * total
	var accum := 0.0
	for entry in _spawn_table:
		accum += entry["weight"]
		if roll < accum:
			return entry["scene"]
	return _spawn_table[-1]["scene"]

## Spawns one enemy near the given cluster origin
func spawn_enemy(cluster_origin: Vector2, is_elite: bool = false, pack_id: int = -1, diff_scale: float = 1.0) -> void:
	var scene := _pick_enemy_scene()
	var enemy = scene.instantiate()
	var scatter = Vector2.from_angle(randf() * TAU) * randf() * CLUSTER_SPREAD
	var spawn_pos = cluster_origin + scatter
	spawn_pos.x = clampf(spawn_pos.x, -MAP_BOUNDS.x, MAP_BOUNDS.x)
	spawn_pos.y = clampf(spawn_pos.y, -MAP_BOUNDS.y, MAP_BOUNDS.y)
	enemy.global_position = spawn_pos
	enemy.add_to_group("enemy")
	add_child(enemy)
	if is_elite:
		enemy.make_elite()
		enemy.pack_id = pack_id
	elif randf() < RARE_CHANCE:
		enemy.make_rare()
	enemy.apply_difficulty(diff_scale)

## Spawns the map's boss when called by boss_token.gd via the main_scene group.
func spawn_boss() -> void:
	if _boss_triggered:
		return
	var state = get_node("/root/GameState")
	_boss_triggered = true
	_boss_alive = true
	state.boss_alive = true
	state.boss_triggered = true
	_clear_battlefield()
	var scene: PackedScene = load(state.map_boss_scene)
	if not scene:
		return
	var boss = scene.instantiate()
	var vp := get_viewport()
	var zoom := vp.get_camera_2d().zoom.x if vp and vp.get_camera_2d() else 1.0
	var half_screen := (vp.get_visible_rect().size if vp else Vector2(680, 440)) / (2.0 * zoom)
	var boss_dist := half_screen.length() + 80.0
	boss.global_position = player.global_position + Vector2.from_angle(randf() * TAU) * boss_dist
	add_child(boss)
	boss.make_boss(state.map_boss_health_mult, state.map_boss_damage_mult)
	boss.boss_died.connect(_on_boss_defeated)
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 20
	get_tree().root.add_child(hud_layer)
	var bar := Control.new()
	bar.set_script(BossHealthBarScript)
	hud_layer.add_child(bar)
	bar.setup(boss)

	var arrow_layer := CanvasLayer.new()
	arrow_layer.layer = 20
	get_tree().root.add_child(arrow_layer)
	var arrow := BossArrowScene.instantiate()
	arrow_layer.add_child(arrow)
	arrow.setup(boss)

## Pops all enemies and pickups with explosion particles to clear the arena for the boss.
func _clear_battlefield() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue
		var particles = CPUParticles2D.new()
		particles.set_script(BossDeathParticles)
		var color = enemy.get_death_color() if enemy.has_method("get_death_color") else Color(0.5, 0.5, 0.5)
		particles.base_color = color
		particles.base_amount = 20
		add_child(particles)
		particles.global_position = enemy.global_position
		enemy.queue_free()
	for pickup in get_tree().get_nodes_in_group("pickup"):
		if not is_instance_valid(pickup):
			continue
		var particles = CPUParticles2D.new()
		particles.set_script(BossDeathParticles)
		particles.base_color = Color(1.0, 0.85, 0.2)
		particles.base_amount = 10
		add_child(particles)
		particles.global_position = pickup.global_position
		pickup.queue_free()

func _on_boss_defeated() -> void:
	_boss_alive = false
	var state := get_node("/root/GameState")
	state.boss_alive = false
	var unlocks: String = state.map_boss_unlocks
	var ps := get_node("/root/PlayerStats")
	var is_new_unlock: bool = not unlocks.is_empty() and not ps.unlocked_maps.has(unlocks)
	if is_new_unlock:
		ps.unlock_map(unlocks)
		state.just_unlocked_map = unlocks
	else:
		state.just_unlocked_map = ""
	var next := "res://scenes/map_selection.tscn" if is_new_unlock else "res://scenes/stats_screen.tscn"
	_spawn_boss_defeated_banner()
	get_tree().create_timer(2.8).timeout.connect(
		func(): get_tree().change_scene_to_file(next), CONNECT_ONE_SHOT
	)

func _spawn_boss_defeated_banner() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 15
	get_tree().root.add_child(layer)
	var lbl := Label.new()
	lbl.text = "BOSS FELLED!"
	lbl.add_theme_font_override("font", FONT_BOSS)
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(lbl)
	var tween := lbl.create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.8)
	tween.tween_callback(layer.queue_free)

## Generates grass using blue noise algorithm for natural distribution
func spawn_grass_in_area(count: int, area_size: Vector2, area_offset: Vector2) -> void:

	var min_distance = 100.0
	var cell_size = min_distance / sqrt(2.0)
	var grid: Dictionary = {}
	var active_list: Array = []

	var first_point = Vector2(randf_range(0, area_size.x), randf_range(0, area_size.y)) + area_offset
	active_list.append(first_point)
	grid[_grid_key(first_point, cell_size)] = first_point
	var points: Array = [first_point]

	while active_list.size() > 0 and points.size() < count:
		var idx = randi() % active_list.size()
		var point = active_list[idx]
		var found = false

		for i in range(30):
			var angle = randf() * TAU
			var distance = randf_range(min_distance, 2.0 * min_distance)
			var new_point = point + Vector2.from_angle(angle) * distance

			if _is_valid_blue_noise_point(new_point, area_size, min_distance, cell_size, grid, area_offset):
				points.append(new_point)
				active_list.append(new_point)
				grid[_grid_key(new_point, cell_size)] = new_point
				found = true
				break

		if not found:
			active_list.remove_at(idx)


	for point in points:
		var grass = _grass_scene.instantiate()
		grass_parent.add_child(grass)
		grass.global_position = point

## Converts 2D position to grid cell key for spatial partitioning
func _grid_key(point: Vector2, cell_size: float) -> Vector2i:
	return Vector2i(int(point.x / cell_size), int(point.y / cell_size))

## Validates blue noise point - returns true if point maintains minimum distance from neighbors
func _is_valid_blue_noise_point(point: Vector2, area_size: Vector2, min_distance: float, cell_size: float, grid: Dictionary, area_offset: Vector2) -> bool:
	var local_point = point - area_offset
	if local_point.x < 0 or local_point.x >= area_size.x or local_point.y < 0 or local_point.y >= area_size.y:
		return false

	var grid_pos = _grid_key(point, cell_size)
	var search_range = 2

	for x in range(grid_pos.x - search_range, grid_pos.x + search_range + 1):
		for y in range(grid_pos.y - search_range, grid_pos.y + search_range + 1):
			var key = Vector2i(x, y)
			if grid.has(key):
				if point.distance_to(grid[key]) < min_distance:
					return false

	return true
