## Enemy character with random movement and direction changes
extends CharacterBody2D

const SPEED = 100.0           # normal wandering speed
const CHASE_SPEED = 220.0     # speed when chasing the player
const ACCELERATION = 250.0    # how fast the enemy speeds up or slows down
const CHANGE_DIRECTION_TIME = 2.0  # max seconds before picking a new wander direction
const DETECTION_RANGE = 200.0 # how close the player has to be before the enemy notices them
const DAMAGE = 10              # damage dealt to player on contact

var direction = Vector2.ZERO  # which way the enemy is currently moving
var time_until_change = 0.0   # countdown until the next random direction change
var current_speed = SPEED     # tracks speed as it smoothly ramps up/down

func _ready() -> void:
	# start the direction change timer at a random value so not all enemies turn at the same time
	time_until_change = randf_range(0.5, CHANGE_DIRECTION_TIME)
	pick_random_direction()
	$AnimatedSprite2D_Enemy1.play()
	# register in groups so other scripts (player, bullets) can detect this enemy
	add_to_group("enemy")
	if has_node("Area2D"):
		$Area2D.add_to_group("enemy_hitbox")

func _physics_process(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")

	if player and global_position.distance_to(player.global_position) <= DETECTION_RANGE:
		# player is nearby — point straight at them and accelerate
		direction = (player.global_position - global_position).normalized()
		current_speed = move_toward(current_speed, CHASE_SPEED, ACCELERATION * delta)
	else:
		# player is far away — wander randomly and slow back down
		time_until_change -= delta
		if time_until_change <= 0:
			pick_random_direction()
			time_until_change = randf_range(0.5, CHANGE_DIRECTION_TIME)
		current_speed = move_toward(current_speed, SPEED, ACCELERATION * delta)

	velocity = direction * current_speed
	move_and_slide()

	# flip the sprite to face whichever horizontal direction the enemy is moving
	if direction.x != 0:
		$AnimatedSprite2D_Enemy1.flip_h = direction.x < 0


## Pick a completely random direction to wander toward
func pick_random_direction() -> void:
	var random_angle = randf() * TAU  # TAU is a full 360 degrees in radians
	direction = Vector2.from_angle(random_angle)

## Remove this enemy from the scene (called when hit by a bullet)
func die() -> void:
	get_node("/root/GameState").kills += 1
	queue_free()
