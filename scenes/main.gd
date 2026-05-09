extends Node2D

const ENEMY_SCENE = preload("res://prefabs/enemies/enemy1.tscn")
const GRASS_SCENE = preload("res://prefabs/environment/grass1.tscn")
const SPAWN_INTERVAL = 2.0
const SPAWN_DISTANCE = 300.0

@onready var player = $CharacterBody2D_Player
var spawn_timer = 0.0

func _ready() -> void:
	spawn_timer = SPAWN_INTERVAL
	spawn_grass(50, Vector2(720, 720))

func _process(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer <= 0:
		spawn_enemy()
		spawn_timer = SPAWN_INTERVAL

func spawn_enemy() -> void:
	var enemy = ENEMY_SCENE.instantiate()
	var random_angle = randf() * TAU
	var random_distance = randf_range(SPAWN_DISTANCE * 0.8, SPAWN_DISTANCE)
	var spawn_pos = player.global_position + Vector2.from_angle(random_angle) * random_distance

	enemy.global_position = spawn_pos
	add_child(enemy)

func spawn_grass(count: int, area_size: Vector2) -> void:
	for i in range(count):
		var grass = GRASS_SCENE.instantiate()
		grass.global_position = Vector2(randf_range(0, area_size.x), randf_range(0, area_size.y))
		add_child(grass)
