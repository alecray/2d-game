## Controls the player character — handles movement, shooting, and taking damage
extends CharacterBody2D

const SPEED = 200.0            # how fast the player moves
const MAX_HEALTH = 100
const DAMAGE_COOLDOWN = 0.5    # seconds of invincibility after getting hit
const BULLET_SCENE = preload("res://prefabs/bullet.tscn")
const KNOCKBACK_FORCE = 300.0  # how hard enemies push the player back on contact
const BULLET_SPAWN_OFFSET = 20.0  # how far in front of the player bullets spawn
const FIRE_RATE = 0.1          # seconds between shots while holding the mouse button
const MAX_AMMO = 300

var health = MAX_HEALTH
var damage_cooldown = 0.0  # counts down to zero between hits
var fire_cooldown = 0.0    # counts down to zero between shots
var ammo = MAX_AMMO
var knockback_velocity = Vector2.ZERO  # decays each frame, applied on top of movement

func _ready() -> void:
	add_to_group("player")
	# attach the white flash shader so we can trigger it when the player takes damage
	var shader_mat = ShaderMaterial.new()
	shader_mat.shader = preload("res://assets/shaders/white_flash.gdshader")
	$Sprite2D_Player.material = shader_mat

	update_health_display()
	update_ammo_display()

func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_contact_damage(delta)
	_handle_shooting(delta)

func _handle_movement(delta: float) -> void:
	# build a direction vector from whichever WASD keys are held
	var input_direction = Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		input_direction.y -= 1
	if Input.is_key_pressed(KEY_S):
		input_direction.y += 1
	if Input.is_key_pressed(KEY_A):
		input_direction.x -= 1
	if Input.is_key_pressed(KEY_D):
		input_direction.x += 1

	velocity = input_direction.normalized() * SPEED if input_direction != Vector2.ZERO else Vector2.ZERO
	# add knockback on top of normal movement, then let it fade out smoothly
	velocity += knockback_velocity
	knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, delta * 10)
	move_and_slide()

	# flip the sprite to match the horizontal direction the player is moving
	if input_direction.x != 0:
		$Sprite2D_Player.flip_h = input_direction.x < 0

func _handle_contact_damage(delta: float) -> void:
	damage_cooldown -= delta
	for body in $HurtBox.get_overlapping_bodies():
		# only take damage once per cooldown window to avoid instant death on overlap
		if body.is_in_group("enemy") and damage_cooldown <= 0:
			take_damage(body.DAMAGE)
			knockback_velocity = (global_position - body.global_position).normalized() * KNOCKBACK_FORCE
			damage_cooldown = DAMAGE_COOLDOWN

func _handle_shooting(delta: float) -> void:
	fire_cooldown -= delta
	# fire continuously while the mouse button is held, once per FIRE_RATE seconds
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and fire_cooldown <= 0:
		shoot_bullet()
		fire_cooldown = FIRE_RATE


func take_damage(amount: int) -> void:
	health = max(0, health - amount)
	update_health_display()
	FlashUtils.flash_white($Sprite2D_Player)
	if health <= 0:
		get_tree().change_scene_to_file("res://scenes/game_over.tscn")

func update_health_display() -> void:
	$Label_Health.text = str(health)

func update_ammo_display() -> void:
	$Camera2D/UI/Label_Ammo.text = str(ammo)

func shoot_bullet() -> void:
	if ammo <= 0:
		return

	var bullet = BULLET_SCENE.instantiate()
	var direction_to_cursor = (get_global_mouse_position() - global_position).normalized()
	bullet.direction = direction_to_cursor
	# spawn the bullet slightly ahead of the player so it doesn't immediately hit them
	bullet.global_position = global_position + direction_to_cursor * BULLET_SPAWN_OFFSET
	add_sibling(bullet)

	ammo -= 1
	update_ammo_display()
