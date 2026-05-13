extends Node

# total enemies killed this run — read this on the end screen
var kills: int = 0
var map_bg_color: Color = Color(0.53, 0.81, 0.92)
var map_bg_texture: String = "res://assets/sprites/backgrounds/background-1.png"
var map_world_color: Color = Color(0.85, 0.85, 0.65)
var map_grass_scene: String = "res://prefabs/environment/grass1.tscn"
var map_leaf_palette: Array = [
	Color(0.04, 0.18, 0.05),
	Color(0.08, 0.28, 0.09),
	Color(0.13, 0.40, 0.12),
	Color(0.20, 0.52, 0.16),
]
var map_canopy_shadow: Color = Color(0.22, 0.55, 0.17, 0.28)
var map_spawn_table: Array = [
	{"scene": "res://prefabs/enemies/spider.tscn", "weight": 55},
	{"scene": "res://prefabs/enemies/blob.tscn", "weight": 25},
	{"scene": "res://prefabs/enemies/triangle.tscn", "weight": 20},
]
var boss_tokens: int = 0               # tokens collected this run; reaching 5 spawns the boss
var dev_boss_token_force: bool = false  # set by dev menu; makes boss tokens drop 100% of the time
var dev_god_mode: bool = false          # set by dev menu; player takes no damage
var map_boss_scene: String = "res://prefabs/enemies/boss_goblin.tscn"
var map_boss_health_mult: float = 1.0
var map_boss_damage_mult: float = 1.0
var map_boss_unlocks: String = ""       # map name to unlock when this map's boss is defeated
var boss_alive: bool = false
var boss_triggered: bool = false        # true once boss has been spawned this run; never resets

func reset() -> void:
	kills = 0
	boss_tokens = 0
	boss_alive = false
	boss_triggered = false
