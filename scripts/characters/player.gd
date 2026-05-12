## Controls the player character — handles movement, shooting, and taking damage
extends CharacterBody2D

var SPEED = 200.0            # how fast the player moves
var MAX_HEALTH = 100
const DAMAGE_COOLDOWN = 0.5    # seconds of invincibility after getting hit
const BULLET_SCENE = preload("res://prefabs/bullet.tscn")
const KNOCKBACK_FORCE = 300.0  # how hard enemies push the player back on contact
const BULLET_SPAWN_OFFSET = 20.0  # how far in front of the player bullets spawn
var FIRE_RATE = 0.1          # seconds between shots while holding the mouse button
var MAX_AMMO = 300
var bullet_damage = 5        # base bullet damage, boosted by PlayerStats
const MAX_MANA = 100
const MAGIC_COST = 50
const MANA_REGEN = 5.0  # mana restored per second
const BOB_FREQUENCY = 14.0   # cycles per second
const BOB_AMPLITUDE = 4.0    # pixels up and down
const IDLE_FREQUENCY = 1.5   # gentle breathing pace while standing still
const IDLE_AMPLITUDE = 2.0   # subtle float distance in pixels

const MagicWave = preload("res://scripts/characters/magic_wave.gd")
const PlayerShadow = preload("res://scripts/characters/player_shadow.gd")
const BloodParticles = preload("res://scripts/effects/blood_particles.gd")

const SHADOW_OFFSET_Y = 20.0   # pixels below the player centre where the shadow sits
const SHADOW_BASE_ALPHA = 0.4  # opacity at rest
const SHADOW_BOB_ALPHA = 0.55  # opacity at the lowest point of the bob

signal health_changed(value: int)
signal damage_taken(amount: int)
signal ammo_changed(value: int)
signal mana_changed(value: int)
signal magic_used(cost: int)
var health = MAX_HEALTH:
	set(value):
		health = value
		health_changed.emit(value)
var damage_cooldown = 0.0  # counts down to zero between hits
var fire_cooldown = 0.0    # counts down to zero between shots
var ammo = MAX_AMMO:
	set(value):
		ammo = value
		ammo_changed.emit(value)
var mana = MAX_MANA:
	set(value):
		mana = value
		mana_changed.emit(int(value))
var knockback_velocity = Vector2.ZERO  # decays each frame, applied on top of movement
var bob_time = 0.0
var idle_time = 0.0
var _shadow: Node2D

func _ready() -> void:
	add_to_group("player")
	$HurtBox.add_to_group("player_hitbox")
	# attach the white flash shader so we can trigger it when the player takes damage
	var shader_mat = ShaderMaterial.new()
	shader_mat.shader = preload("res://assets/shaders/white_flash.gdshader")
	$Sprite2D_Player.material = shader_mat

	_shadow = Node2D.new()
	_shadow.set_script(PlayerShadow)
	_shadow.position = Vector2(0, SHADOW_OFFSET_Y)
	_shadow.z_index = -1
	add_child(_shadow)

	# apply persistent upgrades from PlayerStats
	var stats = get_node("/root/PlayerStats")
	MAX_HEALTH += stats.health_bonus()
	health = MAX_HEALTH
	SPEED += stats.speed_bonus()
	FIRE_RATE = maxf(0.05, FIRE_RATE - stats.fire_rate_reduction())
	MAX_AMMO += stats.ammo_bonus()
	ammo = MAX_AMMO
	bullet_damage += stats.damage_bonus()



func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_contact_damage(delta)
	_handle_shooting(delta)
	if mana < MAX_MANA:
		mana = min(MAX_MANA, mana + MANA_REGEN * delta)

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

	if input_direction != Vector2.ZERO:
		idle_time = 0.0
		bob_time += delta * BOB_FREQUENCY
		$Sprite2D_Player.position.y = abs(sin(bob_time)) * BOB_AMPLITUDE
	else:
		bob_time = 0.0
		idle_time += delta * IDLE_FREQUENCY
		var idle_y = sin(idle_time) * IDLE_AMPLITUDE
		$Sprite2D_Player.position.y = lerpf($Sprite2D_Player.position.y, idle_y, delta * 5.0)

	# shadow fades slightly lighter when the sprite is higher, heavier when it bobs down
	var bob_t = ($Sprite2D_Player.position.y + IDLE_AMPLITUDE) / (BOB_AMPLITUDE + IDLE_AMPLITUDE)
	_shadow.modulate.a = lerpf(SHADOW_BASE_ALPHA, SHADOW_BOB_ALPHA, clampf(bob_t, 0.0, 1.0))

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


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if mana >= MAGIC_COST:
			var wave = MagicWave.new()
			add_sibling(wave)
			wave.global_position = global_position
			mana -= MAGIC_COST
			magic_used.emit(MAGIC_COST)

func take_damage(amount: int) -> void:
	health = max(0, health - amount)  # setter emits health_changed automatically
	damage_taken.emit(amount)
	FlashUtils.flash_white($Sprite2D_Player)
	var blood = CPUParticles2D.new()
	blood.set_script(BloodParticles)
	add_sibling(blood)
	blood.global_position = global_position
	if health <= 0:
		get_tree().change_scene_to_file("res://scenes/game_over.tscn")

## Converts the mouse's screen position to a world position using the player's current
## global_position as the camera centre, bypassing the one-frame camera transform lag
## that makes get_global_mouse_position() drift when the player is moving.
func _world_mouse_position() -> Vector2:
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return get_global_mouse_position()
	var screen_mouse = get_viewport().get_mouse_position()
	var viewport_center = get_viewport().get_visible_rect().size * 0.5
	return global_position + (screen_mouse - viewport_center) / camera.zoom.x

func shoot_bullet() -> void:
	if ammo <= 0:
		return

	var bullet = BULLET_SCENE.instantiate()
	var direction_to_cursor = (_world_mouse_position() - global_position).normalized()
	bullet.direction = direction_to_cursor
	# spawn the bullet slightly ahead of the player so it doesn't immediately hit them
	bullet.global_position = global_position + direction_to_cursor * BULLET_SPAWN_OFFSET
	bullet.damage = bullet_damage
	add_sibling(bullet)

	ammo -= 1  # setter emits ammo_changed automatically
