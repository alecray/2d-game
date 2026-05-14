## Main game scene - manages enemy spawning and level environment
extends Node2D

const SPIDER_SCENE = preload("res://prefabs/enemies/spider.tscn")  # fallback
const GRASS_SCENE_DEFAULT = preload("res://prefabs/environment/grass1.tscn")
const WALL_SCRIPT = preload("res://scripts/environment/wall.gd")
const DUST_SCRIPT = preload("res://scripts/environment/dust_particles.gd")
const TreeGenerator = preload("res://scripts/environment/tree_generator.gd")
# Drop your tileable stone texture at this path to apply it to all walls
const WALL_TEXTURE = "res://assets/sprites/environment/wall1.png"
const TorchLight = preload("res://scripts/environment/torch_light.gd")
const CloudLayer = preload("res://scripts/environment/cloud_layer.gd")
const TORCH_ON_WALL_CHANCE = 0.25
const BASE_SPAWN_INTERVAL = 2.0  # starting time between enemy spawns
const MIN_SPAWN_INTERVAL = 0.25  # fastest the spawner can ever get
const SPAWN_DISTANCE = 80.0  # extra buffer beyond the screen edge to spawn enemies
const KILLS_PER_EXTRA_ENEMY = 30  # one extra enemy spawned per tick for every N kills
const CLUSTER_SPREAD = 40.0       # how far apart enemies in the same cluster can spawn
const MAX_ENEMIES_CAP = 80
const SCALE_RAMP_TIME = 20.0   # seconds at cap before each difficulty increment
const SCALE_INCREMENT = 0.10   # stat multiplier added per increment (+10%)
const SCALE_MAX = 4.0          # ceiling so stats don't grow forever
const ELITE_CHANCE = 0.15   # 15% chance a cluster spawns as elite
const ELITE_PACK_SIZE = 3   # elite clusters always spawn this many
const RARE_CHANCE = 0.02    # 2% chance any individual enemy spawns as rare (golden)
const WORLD_SIZE = 2700
const MAP_BOUNDS = Vector2(1576, 1440)  # half-extents of the background sprite — matches player.gd WORLD_BOUNDS
const GRASS_COUNT = 100
const RUIN_CLUSTER_COUNT = 24
const RUIN_MIN_PIECES = 2
const RUIN_MAX_PIECES = 8
const RUIN_SCATTER = 60.0
const WALL_ROTATION_RANGE = 0.2

@onready var player = $CharacterBody2D_Player
@onready var grass_parent = $GrassParent
@onready var _bg_sprite = $Sprite2D_Background
const FONT_BOSS = preload("res://assets/fonts/PressStart2P-Regular.ttf")
const BossDeathParticles = preload("res://scripts/effects/enemy_death_particles.gd")
const BossHealthBarScript = preload("res://scripts/ui/boss_health_bar.gd")
const BossArrowScene = preload("res://prefabs/ui/boss_arrow.tscn")

var spawn_timer = 0.0
var _grass_scene: PackedScene
var _spawn_table: Array = []  # resolved [{scene: PackedScene, weight: float}] built in _ready()
var _next_pack_id = 0
var difficulty_scale := 1.0
var _cap_time := 0.0
var _boss_alive := false
var _boss_triggered := false

func _get_spawn_interval() -> float:
	var kills = get_node("/root/GameState").kills
	# logarithmic curve: drops quickly in early kills, then levels off into a steady rate
	return max(MIN_SPAWN_INTERVAL, BASE_SPAWN_INTERVAL / (1.0 + log(kills + 1)))

func _get_spawn_count() -> int:
	var kills = get_node("/root/GameState").kills
	return 1 + kills / KILLS_PER_EXTRA_ENEMY

func _ready() -> void:
	add_to_group("main_scene")
	spawn_timer = BASE_SPAWN_INTERVAL
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
	spawn_ruins()
	var trees := Node2D.new()
	trees.set_script(TreeGenerator)
	add_child(trees)
	_setup_lighting()
	var clouds := Node2D.new()
	clouds.set_script(CloudLayer)
	add_child(clouds)

func _setup_lighting() -> void:
	var canvas_mod = CanvasModulate.new()
	canvas_mod.color = get_node("/root/GameState").map_world_color
	add_child(canvas_mod)

func spawn_ruins() -> void:
	var wall_sizes = [
		Vector2(80, 20), Vector2(20, 80),
		Vector2(48, 20), Vector2(20, 48),
		Vector2(64, 20), Vector2(20, 64),
	]
	for i in RUIN_CLUSTER_COUNT:
		var angle = randf() * TAU
		var dist = randf_range(200, 900)
		var cluster_pos = Vector2.from_angle(angle) * dist
		for j in randi_range(RUIN_MIN_PIECES, RUIN_MAX_PIECES):
			var offset = Vector2(randf_range(-RUIN_SCATTER, RUIN_SCATTER), randf_range(-RUIN_SCATTER, RUIN_SCATTER))
			var wall = StaticBody2D.new()
			wall.set_script(WALL_SCRIPT)
			wall.size = wall_sizes[randi() % wall_sizes.size()]
			wall.rotation = randf_range(-WALL_ROTATION_RANGE, WALL_ROTATION_RANGE)
			add_child(wall)
			wall.global_position = cluster_pos + offset
			var tex = load(WALL_TEXTURE)
			if tex:
				wall.texture = tex
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

func _get_max_enemies() -> int:
	return MAX_ENEMIES_CAP

func _process(delta: float) -> void:
	var current = get_tree().get_nodes_in_group("enemy").size()
	if current >= MAX_ENEMIES_CAP:
		_cap_time += delta
		if _cap_time >= SCALE_RAMP_TIME:
			difficulty_scale = minf(SCALE_MAX, difficulty_scale + SCALE_INCREMENT)
			_cap_time = 0.0
	else:
		_cap_time = 0.0

	if not _boss_alive:
		spawn_timer -= delta
		if spawn_timer <= 0:
			var max_enemies = _get_max_enemies()
			var count = _get_spawn_count()
			if current < max_enemies:
				# roll elite once per cluster — elites always come in a fixed pack size
				var is_elite = randf() < ELITE_CHANCE
				var cluster_origin = _get_cluster_origin()
				var spawn_count = ELITE_PACK_SIZE if is_elite else count
				var pack_id = -1
				if is_elite:
					pack_id = _next_pack_id
					_next_pack_id += 1
				for i in spawn_count:
					if current + i < max_enemies:
						spawn_enemy(cluster_origin, is_elite, pack_id, difficulty_scale)
			spawn_timer = _get_spawn_interval()

## Returns a random point just outside the camera's visible area to use as a cluster center.
## Calculates the screen half-diagonal at runtime so it works at any resolution or zoom level.
func _get_cluster_origin() -> Vector2:
	var angle = randf() * TAU
	var zoom := 1.0
	var vp := get_viewport()
	if vp:
		var camera := vp.get_camera_2d()
		if camera:
			zoom = camera.zoom.x
	var half_screen := (vp.get_visible_rect().size if vp else Vector2(680, 440)) / (2.0 * zoom)
	var min_dist = half_screen.length() + SPAWN_DISTANCE
	var distance = randf_range(min_dist, min_dist + 150.0)
	return player.global_position + Vector2.from_angle(angle) * distance

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
	var diff_mult: float = get_node("/root/PlayerStats").enemy_stat_mult()
	enemy.apply_difficulty(diff_scale * diff_mult)

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
	var spawn_pos = _get_cluster_origin()
	boss.global_position = spawn_pos
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
	get_node("/root/GameState").boss_alive = false
	var unlocks: String = get_node("/root/GameState").map_boss_unlocks
	if not unlocks.is_empty():
		get_node("/root/PlayerStats").unlock_map(unlocks)
	_spawn_boss_defeated_banner()

func _spawn_boss_defeated_banner() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 15
	get_tree().root.add_child(layer)
	var lbl := Label.new()
	lbl.text = "BOSS DEFEATED!"
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
