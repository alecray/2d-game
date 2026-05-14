extends "res://scripts/characters/base_enemy.gd"
# Spider — uses all BaseEnemy defaults (SPEED 100, CHASE_SPEED 220, DAMAGE 10, max_health 10)

func _get_melee_range() -> float:
	return 40.0

func _get_attack_duration() -> float:
	return 1.1  # 11 frames × 0.1s at 10 FPS
