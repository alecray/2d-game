## Player character controller with health system
extends CharacterBody2D

const SPEED = 200.0
const MAX_HEALTH = 100
const DAMAGE_COOLDOWN = 0.5
const BULLET_SCENE = preload("res://prefabs/bullet.tscn")
const KNOCKBACK_FORCE = 300.0

var health = MAX_HEALTH
var damage_cooldown = 0.0
var ammo = 100

func _ready() -> void:
	add_to_group("player")
	var shader_mat = ShaderMaterial.new()
	shader_mat.shader = preload("res://assets/shaders/white_flash.gdshader")
	$Sprite2D_Player.material = shader_mat

	update_health_display()
	update_ammo_display()

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
			take_damage(body.DAMAGE)
			damage_cooldown = DAMAGE_COOLDOWN

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		shoot_bullet()


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

## Updates ammo label with current ammo value
func update_ammo_display() -> void:
	$Camera2D/UI/Label_Ammo.text = str(ammo)

## Shoot a bullet toward the cursor
func shoot_bullet() -> void:
	if ammo <= 0:
		return

	var bullet = BULLET_SCENE.instantiate()
	var direction_to_cursor = (get_global_mouse_position() - global_position).normalized()
	bullet.direction = direction_to_cursor
	bullet.global_position = global_position + direction_to_cursor * 20
	get_parent().add_child(bullet)

	ammo -= 1
	update_ammo_display()
