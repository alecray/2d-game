extends "res://scripts/characters/base_enemy.gd"
# Blob — slow and heavy: 1/3 speed, 3x damage

func _ready() -> void:
	SPEED = 33.0
	CHASE_SPEED = 73.0
	DAMAGE = 30
	_flip_facing = true
	super._ready()

func get_death_color() -> Color:
	return Color(0.75, 0.35, 0.1)

func _get_melee_range() -> float:
	return 40.0

func _get_attack_duration() -> float:
	return 1.4  # 7 frames × 0.2s/frame — full Melee cycle so unique frames are visible
