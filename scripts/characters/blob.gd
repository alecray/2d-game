extends "res://scripts/characters/base_enemy.gd"
# Blob — slow and heavy: 1/3 speed, 3x damage

func _ready() -> void:
	SPEED = 33.0
	CHASE_SPEED = 73.0
	DAMAGE = 30
	super._ready()

func get_death_color() -> Color:
	return Color(0.75, 0.35, 0.1)
