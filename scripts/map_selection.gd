extends Control

const MAP_CARD_SCENE = preload("res://prefabs/map_card.tscn")

const MAPS = [
	{
		"name": "Cracked Plains",
		"texture": "res://assets/sprites/backgrounds/background-1.png",
		"scene": "res://scenes/main.tscn",
		"bg_color": Color(0.53, 0.81, 0.92),
		"world_color": Color(0.85, 0.85, 0.65),
		"grass_scene": "res://prefabs/environment/grass1.tscn",
		"spawn_table": [
			{"scene": "res://prefabs/enemies/spider.tscn", "weight": 55},
			{"scene": "res://prefabs/enemies/blob.tscn", "weight": 25},
			{"scene": "res://prefabs/enemies/triangle.tscn", "weight": 20},
		],
	},
	{
		"name": "Frigid Tundra",
		"texture": "res://assets/sprites/backgrounds/background-2.png",
		"scene": "res://scenes/main.tscn",
		"bg_color": Color(0.72, 0.82, 0.90),
		"world_color": Color(0.78, 0.90, 1.00),
		"grass_scene": "res://prefabs/environment/grass2.tscn",
		"leaf_palette": [
			Color(0.75, 0.82, 0.88),
			Color(0.82, 0.87, 0.92),
			Color(0.65, 0.75, 0.82),
			Color(0.88, 0.90, 0.92),
		],
		"canopy_shadow": Color(0.55, 0.70, 0.85, 0.20),
		"spawn_table": [
			{"scene": "res://prefabs/enemies/spider.tscn", "weight": 55},
			{"scene": "res://prefabs/enemies/blob.tscn", "weight": 25},
			{"scene": "res://prefabs/enemies/triangle.tscn", "weight": 20},
		],
	},
	{
		"name": "Depths",
		"texture": "res://assets/sprites/backgrounds/background-3.png",
		"scene": "res://scenes/main.tscn",
		"bg_color": Color(0.08, 0.10, 0.22),
		"world_color": Color(0.30, 0.30, 0.50),
		"spawn_table": [
			{"scene": "res://prefabs/enemies/spider.tscn", "weight": 55},
			{"scene": "res://prefabs/enemies/blob.tscn", "weight": 25},
			{"scene": "res://prefabs/enemies/triangle.tscn", "weight": 20},
		],
	},
]

@onready var _grid: GridContainer = $VBoxContainer/CenterContainer/GridContainer

func _ready() -> void:
	var stats = get_node("/root/PlayerStats")
	for data in MAPS:
		var card = MAP_CARD_SCENE.instantiate()
		_grid.add_child(card)
		var card_data = data.duplicate()
		var map_name: String = data.get("name", "")
		if map_name != "Cracked Plains" and not stats.unlocked_maps.has(map_name):
			card_data["locked"] = true
		card.setup(card_data)
		card.map_selected.connect(_on_map_selected)
	$VBoxContainer/Button_Back.pressed.connect(_on_back)

func _on_map_selected(data: Dictionary) -> void:
	var state = get_node("/root/GameState")
	state.reset()
	state.map_bg_color = data.get("bg_color", Color(0.53, 0.81, 0.92))
	state.map_bg_texture = data.get("texture", "res://assets/sprites/backgrounds/background-1.png")
	state.map_world_color = data.get("world_color", Color(0.85, 0.85, 0.65))
	state.map_grass_scene = data.get("grass_scene", "res://prefabs/environment/grass1.tscn")
	state.map_leaf_palette = data.get("leaf_palette", [
		Color(0.04, 0.18, 0.05), Color(0.08, 0.28, 0.09),
		Color(0.13, 0.40, 0.12), Color(0.20, 0.52, 0.16),
	])
	state.map_canopy_shadow = data.get("canopy_shadow", Color(0.22, 0.55, 0.17, 0.28))
	state.map_spawn_table = data.get("spawn_table", state.map_spawn_table)
	get_tree().change_scene_to_file(data.get("scene", "res://scenes/main.tscn"))

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/game_over.tscn")
