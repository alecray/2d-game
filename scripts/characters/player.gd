extends CharacterBody2D

const SPEED = 200.0

func _physics_process(_delta: float) -> void:
	var input_direction = Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		input_direction.y -= 1
	if Input.is_key_pressed(KEY_S):
		input_direction.y += 1
	if Input.is_key_pressed(KEY_A):
		input_direction.x -= 1
	if Input.is_key_pressed(KEY_D):
		input_direction.x += 1

	if input_direction != Vector2.ZERO:
		input_direction = input_direction.normalized()
		velocity = input_direction * SPEED
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	if input_direction.x != 0:
		$Sprite2D_Player.flip_h = input_direction.x < 0
