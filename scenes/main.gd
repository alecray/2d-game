## Main game scene - manages enemy spawning and level environment
extends Node2D

const ENEMY_SCENE = preload("res://prefabs/enemies/enemy1.tscn")
const ENEMY2_SCENE = preload("res://prefabs/enemies/enemy2.tscn")
const ENEMY3_SCENE = preload("res://prefabs/enemies/enemy3.tscn")
const ENEMY2_CHANCE = 0.25  # probability any given enemy spawns as enemy2
const ENEMY3_CHANCE = 0.20  # probability any given enemy spawns as enemy3
const GRASS_SCENE = preload("res://prefabs/environment/grass1.tscn")
const WALL_SCRIPT = preload("res://scripts/environment/wall.gd")
const DUST_SCRIPT = preload("res://scripts/environment/dust_particles.gd")
# Drop your tileable stone texture at this path to apply it to all walls
const WALL_TEXTURE = "res://assets/sprites/environment/wall1.png"
const TorchLight = preload("res://scripts/environment/torch_light.gd")
const TORCH_ON_WALL_CHANCE = 0.25
const SCENE_DARKNESS = Color(0.85, 0.85, 0.65)  # tune this to adjust overall darkness
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
const GRASS_COUNT = 100
const RUIN_CLUSTER_COUNT = 24
const RUIN_MIN_PIECES = 2
const RUIN_MAX_PIECES = 8
const RUIN_SCATTER = 60.0
const WALL_ROTATION_RANGE = 0.2

@onready var player = $CharacterBody2D_Player
@onready var grass_parent = $GrassParent
var spawn_timer = 0.0
var _next_pack_id = 0
var difficulty_scale := 1.0
var _cap_time := 0.0

func _get_spawn_interval() -> float:
	var kills = get_node("/root/GameState").kills
	# logarithmic curve: drops quickly in early kills, then levels off into a steady rate
	return max(MIN_SPAWN_INTERVAL, BASE_SPAWN_INTERVAL / (1.0 + log(kills + 1)))

func _get_spawn_count() -> int:
	var kills = get_node("/root/GameState").kills
	return 1 + kills / KILLS_PER_EXTRA_ENEMY

func _ready() -> void:
	spawn_timer = BASE_SPAWN_INTERVAL
	var dust = CPUParticles2D.new()
	dust.set_script(DUST_SCRIPT)
	player.add_child(dust)
	var spawn_area_size = Vector2(WORLD_SIZE, WORLD_SIZE)
	var spawn_area_offset = -spawn_area_size / 2
	spawn_grass_in_area(GRASS_COUNT, spawn_area_size, spawn_area_offset)
	spawn_ruins()
	_setup_lighting()

func _setup_lighting() -> void:
	var canvas_mod = CanvasModulate.new()
	canvas_mod.color = SCENE_DARKNESS
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
	var camera = get_viewport().get_camera_2d()
	var zoom = camera.zoom.x if camera else 1.0
	var half_screen = get_viewport().get_visible_rect().size / (2.0 * zoom)
	var min_dist = half_screen.length() + SPAWN_DISTANCE
	var distance = randf_range(min_dist, min_dist + 150.0)
	return player.global_position + Vector2.from_angle(angle) * distance

## Spawns one enemy near the given cluster origin
func spawn_enemy(cluster_origin: Vector2, is_elite: bool = false, pack_id: int = -1, scale: float = 1.0) -> void:
	var roll = randf()
	var scene = ENEMY2_SCENE if roll < ENEMY2_CHANCE else ENEMY3_SCENE if roll < ENEMY2_CHANCE + ENEMY3_CHANCE else ENEMY_SCENE
	var enemy = scene.instantiate()
	var scatter = Vector2.from_angle(randf() * TAU) * randf() * CLUSTER_SPREAD
	enemy.global_position = cluster_origin + scatter
	enemy.add_to_group("enemy")
	add_child(enemy)
	if is_elite:
		enemy.make_elite()
		enemy.pack_id = pack_id
	elif randf() < RARE_CHANCE:
		enemy.make_rare()
	var diff_mult: float = get_node("/root/PlayerStats").enemy_stat_mult()
	enemy.apply_difficulty(scale * diff_mult)

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
		var grass = GRASS_SCENE.instantiate()
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
