extends "res://scripts/characters/base_enemy.gd"
# Enemy2 — slow and heavy: 1/3 speed, 3x damage

func _ready() -> void:
	SPEED = 33.0
	CHASE_SPEED = 73.0
	DAMAGE = 30
	super._ready()
