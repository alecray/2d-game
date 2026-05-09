## Player character controller with health system
extends CharacterBody2D

const SPEED = 200.0
const MAX_HEALTH = 100
const DAMAGE_COOLDOWN = 0.5

var health = MAX_HEALTH
var damage_cooldown = 0.0

func _ready() -> void:
	var shader_mat = ShaderMaterial.new()
	shader_mat.shader = preload("res://assets/shaders/white_flash.gdshader")
	$Sprite2D_Player.material = shader_mat

	update_health_display()

func _physics_process(delta: float) -> void:
	## Collect input from WASD keys
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

	## Check for collisions with enemies
	damage_cooldown -= delta
	for body in $HurtBox.get_overlapping_bodies():
		if body.is_in_group("enemy") and damage_cooldown <= 0:
			take_damage(1)
			damage_cooldown = DAMAGE_COOLDOWN

## Takes damage and updates display
func take_damage(amount: int) -> void:
	health -= amount
	update_health_display()
	print("Player took damage! Health: ", health)
	flash_white()

## Flash the sprite white for visual damage feedback
func flash_white() -> void:
	var sprite = $Sprite2D_Player
	var mat = sprite.material as ShaderMaterial
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(
		func(v): mat.set_shader_parameter("flash_amount", v),
		0.0, 1.0, 0.1
	)
	tween.tween_method(
		func(v): mat.set_shader_parameter("flash_amount", v),
		1.0, 0.0, 0.1
	)
	tween.tween_method(
		func(v): mat.set_shader_parameter("flash_amount", v),
		0.0, 1.0, 0.1
	)
	tween.tween_method(
		func(v): mat.set_shader_parameter("flash_amount", v),
		1.0, 0.0, 0.1
	)

## Updates health label with current health value
func update_health_display() -> void:
	$Label_Health.text = str(health)
