## Main game scene - manages enemy spawning and level environment
extends Node2D

const ENEMY_SCENE = preload("res://prefabs/enemies/enemy1.tscn")
const GRASS_SCENE = preload("res://prefabs/environment/grass1.tscn")
const WALL_SCRIPT = preload("res://scripts/environment/wall.gd")
const BASE_SPAWN_INTERVAL = 2.0  # starting time between enemy spawns
const MIN_SPAWN_INTERVAL = 0.25  # fastest the spawner can ever get
const SPAWN_DISTANCE = 300.0
const KILLS_PER_EXTRA_ENEMY = 30  # one extra enemy spawned per tick for every N kills
const CLUSTER_SPREAD = 40.0       # how far apart enemies in the same cluster can spawn
const MAX_ENEMIES = 100
const ELITE_CHANCE = 0.15   # 15% chance a cluster spawns as elite
const ELITE_PACK_SIZE = 3   # elite clusters always spawn this many

@onready var player = $CharacterBody2D_Player
@onready var grass_parent = $GrassParent
var spawn_timer = 0.0
var _next_pack_id = 0

func _get_spawn_interval() -> float:
	var kills = get_node("/root/GameState").kills
	# logarithmic curve: drops quickly in early kills, then levels off into a steady rate
	return max(MIN_SPAWN_INTERVAL, BASE_SPAWN_INTERVAL / (1.0 + log(kills + 1)))

func _get_spawn_count() -> int:
	var kills = get_node("/root/GameState").kills
	return 1 + kills / KILLS_PER_EXTRA_ENEMY

func _ready() -> void:
	spawn_timer = BASE_SPAWN_INTERVAL
	var spawn_area_size = Vector2(2000, 2000)
	var spawn_area_offset = -spawn_area_size / 2
	spawn_grass_in_area(200, spawn_area_size, spawn_area_offset)
	spawn_ruins()

func spawn_ruins() -> void:
	var wall_sizes = [
		Vector2(80, 20), Vector2(20, 80),
		Vector2(48, 20), Vector2(20, 48),
		Vector2(64, 20), Vector2(20, 64),
	]
	for i in 18:
		var angle = randf() * TAU
		var dist = randf_range(200, 900)
		var cluster_pos = Vector2.from_angle(angle) * dist
		for j in randi_range(2, 5):
			var offset = Vector2(randf_range(-60, 60), randf_range(-60, 60))
			var wall = StaticBody2D.new()
			wall.set_script(WALL_SCRIPT)
			wall.size = wall_sizes[randi() % wall_sizes.size()]
			wall.rotation = randf_range(-0.2, 0.2)
			add_child(wall)
			wall.global_position = cluster_pos + offset

func _process(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer <= 0:
		var current = get_tree().get_nodes_in_group("enemy").size()
		var count = _get_spawn_count()
		if current < MAX_ENEMIES:
			# roll elite once per cluster — elites always come in a fixed pack size
			var is_elite = randf() < ELITE_CHANCE
			var cluster_origin = _get_cluster_origin()
			var spawn_count = ELITE_PACK_SIZE if is_elite else count
			var pack_id = -1
			if is_elite:
				pack_id = _next_pack_id
				_next_pack_id += 1
			for i in spawn_count:
				if current + i < MAX_ENEMIES:
					spawn_enemy(cluster_origin, is_elite, pack_id)
		spawn_timer = _get_spawn_interval()

## Returns a random point just outside the player's view to use as a cluster center
func _get_cluster_origin() -> Vector2:
	var angle = randf() * TAU
	var distance = randf_range(SPAWN_DISTANCE * 0.8, SPAWN_DISTANCE)
	return player.global_position + Vector2.from_angle(angle) * distance

## Spawns one enemy near the given cluster origin
func spawn_enemy(cluster_origin: Vector2, is_elite: bool = false, pack_id: int = -1) -> void:
	var enemy = ENEMY_SCENE.instantiate()
	var scatter = Vector2.from_angle(randf() * TAU) * randf() * CLUSTER_SPREAD
	enemy.global_position = cluster_origin + scatter
	enemy.add_to_group("enemy")
	add_child(enemy)
	if is_elite:
		enemy.make_elite()
		enemy.pack_id = pack_id

## Generates grass using blue noise algorithm for natural distribution
func spawn_grass_in_area(count: int, area_size: Vector2, area_offset: Vector2) -> void:
	print("Spawning ", count, " grass in area ", area_size, " at offset ", area_offset)
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

	print("Generated ", points.size(), " grass points")
	for point in points:
		var grass = GRASS_SCENE.instantiate()
		grass_parent.add_child(grass)
		grass.global_position = point
	print("Finished spawning grass")

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
