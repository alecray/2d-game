## Controls the player character — handles movement, shooting, and taking damage
extends CharacterBody2D

var SPEED = 200.0            # how fast the player moves
var MAX_HEALTH = 100
const DAMAGE_COOLDOWN = 0.5    # seconds of invincibility after getting hit
const BULLET_SCENE = preload("res://prefabs/bullet.tscn")
const KNOCKBACK_FORCE = 1200.0  # how hard enemies push the player back on contact
const GUN_TIP_LOCAL = Vector2(40.0, 0.0)  # tip of the 64px barrel in gun local space (offset 8 + half-width 32)
var FIRE_RATE = 0.1          # seconds between shots while holding the mouse button
var MAX_AMMO = 300
var bullet_damage = 5        # base bullet damage, boosted by PlayerStats
var bullet_speed_multiplier = 1.0
var bullet_extra_bounces = 0
var bullet_piercing = false
var bullet_explosive = false
var bullet_homing = false
var bullet_count = 1
var bullet_split = false
var bullet_color = Color.WHITE     # gun types will override this
var bullet_size_mult: float = 1.0
var _shoot_mode: String = "bullet"
var _laser: Node2D = null
const BULLET_SPREAD_ANGLE = 0.22  # ~12.5 degrees, used for Payload spread
const BULLET_SPLIT_ANGLE = 0.10   # ~5.7 degrees between the two Split bullets
const MAX_MANA = 100
const MAGIC_COST = 50
const MANA_REGEN = 5.0  # mana restored per second
const BOB_FREQUENCY = 14.0   # cycles per second
const BOB_AMPLITUDE = 4.0    # pixels up and down
const IDLE_FREQUENCY = 1.5   # gentle breathing pace while standing still
const IDLE_AMPLITUDE = 2.0   # subtle float distance in pixels
const AIM_TURN_SPEED = 10.0  # radians per second the aim direction can rotate
const TILT_AMOUNT = 0.13     # max lean angle in radians (~7.5 degrees)
const WORLD_BOUNDS = Vector2(1576, 1440)  # half-extents of the background sprite

const MagicWave = preload("res://scripts/characters/magic_wave.gd")
const PlayerShadow = preload("res://scripts/characters/player_shadow.gd")
const BloodParticles = preload("res://scripts/effects/blood_particles.gd")
const LaserBeam = preload("res://scripts/effects/laser_beam.gd")

const SHADOW_OFFSET_Y = 20.0   # pixels below the player centre where the shadow sits
const SHADOW_BASE_ALPHA = 0.4  # opacity at rest
const SHADOW_BOB_ALPHA = 0.55  # opacity at the lowest point of the bob
const SHAKE_INTENSITY = 7.0
const SHAKE_STEPS = 6
const SHAKE_DURATION = 0.35
const DEATH_SHAKE_INTENSITY = 16.0
const DEATH_SHAKE_STEPS = 14
const DEATH_SHAKE_DURATION = 0.7
const DEATH_ZOOM = Vector2(2.5, 2.5)
const DEATH_ZOOM_DURATION = 1.4
const MAP_BOUNDS_BUFFER = 100 # account for edges of the map when clamping player position

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
var _laser_shake_accum: float = 0.0
var ammo = MAX_AMMO:
	set(value):
		ammo = value
		ammo_changed.emit(value)
var mana = MAX_MANA:
	set(value):
		mana = value
		mana_changed.emit(int(value))
var _dying := false
var knockback_velocity = Vector2.ZERO  # decays each frame, applied on top of movement
var aim_direction = Vector2.RIGHT      # current aim angle, rate-limited toward the mouse
const GUN_ROTATION_OFFSET = 0.0
var bob_time = 0.0
var idle_time = 0.0
var _shadow: Node2D
@onready var _gun: Sprite2D = $Gun

func _ready() -> void:
	add_to_group("player")
	$HurtBox.add_to_group("player_hitbox")
	# attach the white flash shader so we can trigger it when the player takes damage
	var shader_mat = ShaderMaterial.new()
	shader_mat.shader = preload("res://assets/shaders/white_flash.gdshader")
	$AnimatedSprite2D_Player.material = shader_mat

	_shadow = Node2D.new()
	_shadow.set_script(PlayerShadow)
	_shadow.position = Vector2(0, SHADOW_OFFSET_Y)
	_shadow.z_index = -1
	add_child(_shadow)

	var player_light = PointLight2D.new()
	player_light.color = Color(1.0, 0.92, 0.82)
	player_light.energy = 0.35
	player_light.texture = _make_light_texture()
	player_light.texture_scale = 200.0 / (0.1 * 256.0)
	add_child(player_light)

	# apply persistent upgrades from PlayerStats
	var stats = get_node("/root/PlayerStats")
	MAX_HEALTH += stats.health_bonus()
	health = MAX_HEALTH
	SPEED += stats.speed_bonus()
	FIRE_RATE = maxf(0.05, FIRE_RATE - stats.fire_rate_reduction())
	MAX_AMMO += stats.ammo_bonus()
	ammo = MAX_AMMO
	bullet_damage += stats.damage_bonus()

	# apply equipped gun stats on top of persistent upgrades
	var gun = PlayerStats.GUN_DEFS.get(stats.equipped_gun, PlayerStats.GUN_DEFS["gun1"])
	FIRE_RATE = maxf(0.05, FIRE_RATE * gun["fire_rate_mult"])
	bullet_damage = maxi(1, int(bullet_damage * gun["damage_mult"]))
	bullet_count = gun["bullet_count"]
	bullet_speed_multiplier = gun["speed_mult"]
	bullet_extra_bounces = gun["bounces"]
	bullet_color = gun["color"]
	bullet_size_mult = gun.get("bullet_size", 1.0)
	_shoot_mode = gun.get("shoot_mode", "bullet")
	if gun["sprite"] != "":
		_gun.texture = load(gun["sprite"])


func _physics_process(delta: float) -> void:
	if _dying:
		return
	_handle_movement(delta)
	_handle_contact_damage(delta)
	_update_aim(delta)
	_handle_shooting(delta)
	if mana < MAX_MANA:
		mana = min(MAX_MANA, mana + MANA_REGEN * delta)

func _update_aim(delta: float) -> void:
	var target = (_world_mouse_position() - global_position).normalized()
	var diff = angle_difference(aim_direction.angle(), target.angle())
	var max_turn = AIM_TURN_SPEED * delta
	aim_direction = Vector2.from_angle(aim_direction.angle() + clampf(diff, -max_turn, max_turn))
	_gun.rotation = aim_direction.angle() + GUN_ROTATION_OFFSET
	_gun.flip_v = aim_direction.x < 0

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
	global_position.x = clampf(global_position.x, -WORLD_BOUNDS.x + MAP_BOUNDS_BUFFER, WORLD_BOUNDS.x - MAP_BOUNDS_BUFFER)
	global_position.y = clampf(global_position.y, -WORLD_BOUNDS.y, WORLD_BOUNDS.y)

	# flip the sprite to match the horizontal direction the player is moving
	if input_direction.x != 0:
		$AnimatedSprite2D_Player.flip_h = input_direction.x < 0

	if input_direction != Vector2.ZERO:
		if $AnimatedSprite2D_Player.animation != "Walk":
			$AnimatedSprite2D_Player.play("Walk")
		idle_time = 0.0
		bob_time += delta * BOB_FREQUENCY
		$AnimatedSprite2D_Player.position.y = abs(sin(bob_time)) * BOB_AMPLITUDE
	else:
		if $AnimatedSprite2D_Player.animation != "Idle":
			$AnimatedSprite2D_Player.play("Idle")
		bob_time = 0.0
		idle_time += delta * IDLE_FREQUENCY
		var idle_y = sin(idle_time) * IDLE_AMPLITUDE
		$AnimatedSprite2D_Player.position.y = lerpf($AnimatedSprite2D_Player.position.y, idle_y, delta * 5.0)

	_gun.position.y = $AnimatedSprite2D_Player.position.y

	var target_tilt: float = input_direction.x * TILT_AMOUNT
	$AnimatedSprite2D_Player.rotation = lerpf($AnimatedSprite2D_Player.rotation, target_tilt, delta * 12.0)

	# shadow fades slightly lighter when the sprite is higher, heavier when it bobs down
	var bob_t = ($AnimatedSprite2D_Player.position.y + IDLE_AMPLITUDE) / (BOB_AMPLITUDE + IDLE_AMPLITUDE)
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
	var firing := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

	if _shoot_mode == "laser":
		if firing and ammo > 0:
			if _laser == null:
				_laser = LaserBeam.new()
				add_sibling(_laser)
				_laser.exclude_rids = [get_rid()]
			_laser.global_position = _gun.global_transform * GUN_TIP_LOCAL
			_laser.direction = aim_direction
			_laser.damage = bullet_damage
			if fire_cooldown <= 0:
				ammo -= 1
				fire_cooldown = FIRE_RATE
			_laser_shake_accum += delta
			if _laser_shake_accum >= 0.12:
				_laser_shake_accum = 0.0
				_shake_camera_laser()
		else:
			_stop_laser()
			_laser_shake_accum = 0.0
	else:
		_stop_laser()
		_laser_shake_accum = 0.0
		if firing and fire_cooldown <= 0:
			shoot_bullet()
			fire_cooldown = FIRE_RATE

func _stop_laser() -> void:
	if _laser:
		_laser.queue_free()
		_laser = null


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if mana >= MAGIC_COST:
			var wave = MagicWave.new()
			add_sibling(wave)
			wave.global_position = global_position
			mana -= MAGIC_COST
			magic_used.emit(MAGIC_COST)

func take_damage(amount: int) -> void:
	if get_node("/root/GameState").dev_god_mode:
		return
	if _dying:
		return
	health = max(0, health - amount)  # setter emits health_changed automatically
	damage_taken.emit(amount)
	if health > 0:
		FlashUtils.flash_white($AnimatedSprite2D_Player)
	var blood = CPUParticles2D.new()
	blood.set_script(BloodParticles)
	add_sibling(blood)
	blood.global_position = global_position
	_shake_camera()
	if health <= 0:
		_start_death()

func _start_death() -> void:
	_dying = true
	$HurtBox.monitoring = false
	_stop_laser()
	var sprite := $AnimatedSprite2D_Player
	sprite.rotation = 0.0
	sprite.position.y = 0.0
	sprite.play("Death")
	sprite.animation_finished.connect(_on_death_animation_finished, CONNECT_ONE_SHOT)
	_death_camera_effect()

func _death_camera_effect() -> void:
	var vp := get_viewport()
	if not vp:
		return
	var camera := vp.get_camera_2d()
	if not camera:
		return
	var shake := create_tween()
	for i in DEATH_SHAKE_STEPS:
		var intensity = DEATH_SHAKE_INTENSITY * (1.0 - float(i) / DEATH_SHAKE_STEPS)
		var offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * intensity
		shake.tween_property(camera, "offset", offset, DEATH_SHAKE_DURATION / DEATH_SHAKE_STEPS)
	shake.tween_property(camera, "offset", Vector2.ZERO, DEATH_SHAKE_DURATION / DEATH_SHAKE_STEPS)
	create_tween().tween_property(camera, "zoom", DEATH_ZOOM, DEATH_ZOOM_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_death_animation_finished() -> void:
	await get_tree().create_timer(0.4).timeout
	var layer := CanvasLayer.new()
	layer.layer = 100
	get_tree().root.add_child(layer)
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 0)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	var fade_in := rect.create_tween()
	fade_in.tween_property(rect, "color:a", 1.0, 0.3)
	await fade_in.finished
	get_tree().change_scene_to_file("res://scenes/game_over.tscn")
	var fade_out := rect.create_tween()
	fade_out.tween_interval(0.1)
	fade_out.tween_property(rect, "color:a", 0.0, 0.4)
	fade_out.tween_callback(layer.queue_free)

func _make_light_texture() -> GradientTexture2D:
	var grad = Gradient.new()
	grad.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(0.0, 0.0, 0.0, 0.0)])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.6, 0.5)
	tex.width = 256
	tex.height = 256
	return tex

func _shake_camera() -> void:
	var vp := get_viewport()
	if not vp:
		return
	var camera = vp.get_camera_2d()
	if not camera:
		return
	var tween = create_tween()
	for i in SHAKE_STEPS:
		var t = float(i) / SHAKE_STEPS
		var intensity = SHAKE_INTENSITY * (1.0 - t)
		var offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * intensity
		tween.tween_property(camera, "offset", offset, SHAKE_DURATION / SHAKE_STEPS)
	tween.tween_property(camera, "offset", Vector2.ZERO, SHAKE_DURATION / SHAKE_STEPS)

func _shake_camera_laser() -> void:
	var vp := get_viewport()
	if not vp:
		return
	var camera = vp.get_camera_2d()
	if not camera:
		return
	var tween = create_tween()
	var offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * 3.0
	tween.tween_property(camera, "offset", offset, 0.06)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.06)

## Converts the mouse's screen position to a world position using the player's current
## global_position as the camera centre, bypassing the one-frame camera transform lag
## that makes get_global_mouse_position() drift when the player is moving.
func _world_mouse_position() -> Vector2:
	var viewport = get_viewport()
	if not viewport:
		return Vector2.ZERO
	var camera = viewport.get_camera_2d()
	if not camera:
		return get_global_mouse_position()
	var screen_mouse = get_viewport().get_mouse_position()
	var viewport_center = get_viewport().get_visible_rect().size * 0.5
	return global_position + (screen_mouse - viewport_center) / camera.zoom.x

func shoot_bullet() -> void:
	if ammo <= 0:
		return

	var spread_angles = [0.0]
	if bullet_count >= 3:
		spread_angles = [-BULLET_SPREAD_ANGLE, 0.0, BULLET_SPREAD_ANGLE]
	if bullet_split:
		var split := []
		for a in spread_angles:
			split.append(a - BULLET_SPLIT_ANGLE)
			split.append(a + BULLET_SPLIT_ANGLE)
		spread_angles = split

	for spread in spread_angles:
		var fire_dir = aim_direction.rotated(spread)
		var bullet = BULLET_SCENE.instantiate()
		bullet.direction = fire_dir
		bullet.global_position = _gun.global_transform * GUN_TIP_LOCAL
		bullet.damage = bullet_damage
		bullet.speed = bullet.SPEED * bullet_speed_multiplier
		var combined: Vector2 = fire_dir * bullet.speed + velocity
		bullet.speed = combined.length()
		bullet.direction = combined.normalized()
		bullet.max_bounces = bullet.MAX_BOUNCES + bullet_extra_bounces
		bullet.piercing = bullet_piercing
		bullet.explosive = bullet_explosive
		bullet.homing = bullet_homing
		bullet.bullet_color = bullet_color
		bullet.scale = Vector2.ONE * bullet_size_mult
		add_sibling(bullet)

	ammo -= 1  # setter emits ammo_changed automatically
