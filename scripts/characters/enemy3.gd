## Ranged enemy — keeps its distance, strafes, and fires purple bullets at the player.
## When hit it briefly charges like a normal enemy before retreating again.
extends "res://scripts/characters/base_enemy.gd"

const PREFERRED_RANGE = 230.0    # tries to stay roughly this far from the player
const TOO_CLOSE_RANGE = 130.0    # retreats if the player gets closer than this
const FIRE_RATE = 2.0            # seconds between shots
const SHOOT_RANGE = 350.0        # won't shoot if the player is further away than this
const ENEMY_BULLET = preload("res://prefabs/enemy_bullet.tscn")

var fire_timer = 0.0
var _strafe_sign = 1  # which side to circle — randomised at spawn so groups orbit differently

func _ready() -> void:
	SPEED = 75.0
	CHASE_SPEED = 130.0
	DAMAGE = 5        # low contact damage — this enemy is not meant to touch the player
	max_health = 15
	_strafe_sign = 1 if randf() < 0.5 else -1
	fire_timer = randf_range(0.0, FIRE_RATE)  # stagger so a pack doesn't all fire at once
	super._ready()

func _physics_process(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")

	if player:
		var dist = global_position.distance_to(player.global_position)
		var to_player = (player.global_position - global_position).normalized()
		var perp = Vector2(-to_player.y, to_player.x) * _strafe_sign

		if rage_timer > 0:
			# took a hit — flee away from the player then settle back into orbit
			direction = -to_player
			current_speed = move_toward(current_speed, CHASE_SPEED, ACCELERATION * delta)
		elif dist < TOO_CLOSE_RANGE:
			# player is too close — back away while strafing
			direction = (-to_player + perp).normalized()
			current_speed = move_toward(current_speed, SPEED, ACCELERATION * delta)
		elif dist > PREFERRED_RANGE:
			# too far away — close the gap
			direction = to_player
			current_speed = move_toward(current_speed, SPEED, ACCELERATION * delta)
		else:
			# at preferred range — strafe perpendicular to keep circling
			direction = perp
			current_speed = move_toward(current_speed, SPEED * 0.7, ACCELERATION * delta)

		# shoot at the player periodically while within range
		fire_timer -= delta
		if fire_timer <= 0 and dist <= SHOOT_RANGE:
			_shoot(to_player)
			fire_timer = FIRE_RATE

	rage_timer -= delta
	velocity = direction * current_speed + _get_separation()
	move_and_slide()

	if direction.x != 0:
		$AnimatedSprite2D.flip_h = direction.x < 0

func _shoot(aim_direction: Vector2) -> void:
	var bullet = ENEMY_BULLET.instantiate()
	bullet.direction = aim_direction
	bullet.global_position = global_position
	get_parent().add_child(bullet)
