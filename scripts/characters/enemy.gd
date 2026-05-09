## Enemy character with random movement and direction changes
extends CharacterBody2D

const SPEED = 100.0
const CHANGE_DIRECTION_TIME = 2.0

var direction = Vector2.ZERO
var time_until_change = 0.0

func _ready() -> void:
	time_until_change = randf_range(0.5, CHANGE_DIRECTION_TIME)
	pick_random_direction()
	$AnimatedSprite2D_Enemy1.play()

func _physics_process(delta: float) -> void:
	time_until_change -= delta
	if time_until_change <= 0:
		pick_random_direction()
		time_until_change = randf_range(0.5, CHANGE_DIRECTION_TIME)

	velocity = direction * SPEED
	move_and_slide()

	if direction.x != 0:
		$AnimatedSprite2D_Enemy1.flip_h = direction.x < 0


## Pick a random direction and reset timer for next direction change
func pick_random_direction() -> void:
	var random_angle = randf() * TAU
	direction = Vector2.from_angle(random_angle)
