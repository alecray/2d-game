## Shared logic for all enemy types. Subclasses override stat vars in their own _ready()
## before calling super._ready() — everything else (AI, drops, health bar, elite, etc.) is inherited.
class_name BaseEnemy
extends CharacterBody2D

## Base stats — subclasses reassign these before calling super._ready() to customise behaviour
var SPEED = 100.0           # normal wandering speed
var CHASE_SPEED = 220.0     # speed when actively chasing the player
var ACCELERATION = 250.0    # how quickly the enemy ramps between speeds
var DAMAGE = 10             # contact damage dealt to the player per hit
var max_health = 10

const CHANGE_DIRECTION_TIME = 2.0   # max seconds between random direction changes while wandering
const DETECTION_RANGE = 200.0       # distance at which the enemy notices and starts chasing the player
const SEPARATION_RADIUS = 28.0      # enemies within this distance push each other apart
const SEPARATION_FORCE = 80.0       # strength of that push
const INVISIBLE_CHANCE = 0.05       # probability this enemy spawns nearly transparent
const INVISIBLE_ALPHA = 0.1         # opacity while invisible — just visible enough to hint at presence
const RAGE_DURATION = 1.5           # seconds the enemy charges at boosted speed after taking a hit
const RAGE_SPEED_MULTIPLIER = 2.0   # speed multiplier applied during rage
const BOSS_TOKEN_DROP_CHANCE = 0.005  # checked first; rarest drop
const CRATE_DROP_CHANCE = 0.025       # 2.5% base, scaled by difficulty
const HEALTH_DROP_CHANCE = 0.1        # 10%
const AMMO_DROP_CHANCE = 0.1          # 10%
const COIN_DROP_CHANCE = 0.15         # 15% base, scaled by difficulty
const CRATE_SCENE = preload("res://prefabs/items/crate.tscn")
const COIN_SCENE = preload("res://prefabs/items/coin.tscn")
const BOSS_TOKEN_SCENE = preload("res://prefabs/items/boss_token.tscn")
const HEALTH_PICKUP_SCENE = preload("res://prefabs/items/health_pickup.tscn")
const AMMO_PICKUP_SCENE = preload("res://prefabs/items/ammo_pickup.tscn")
const XP_REWARD = 5                 # XP granted to the player on death
const ELITE_XP_REWARD = 15         # XP for elite (pack) enemies
const RARE_XP_REWARD = 50          # XP for rare (golden) enemies
const HEALTH_BAR_WIDTH = 32.0
const HEALTH_BAR_HEIGHT = 4.0
const HEALTH_BAR_OFFSET_Y = 26.0    # how far above the sprite centre the health bar sits
const FloatingText = preload("res://scripts/utils/floating_text.gd")
const EnemyDeathParticles = preload("res://scripts/effects/enemy_death_particles.gd")

var health = 10
var rage_timer = 0.0   # while > 0, enemy charges at boosted speed
var pack_id = -1       # shared ID for elite pack-mates; -1 means no pack
var is_invisible = false
var is_rare = false
var aura_color: Color = Color.TRANSPARENT
var _aura_time: float = 0.0
var direction = Vector2.ZERO    # current movement direction (unit vector)
var time_until_change = 0.0     # countdown until the next random direction pick
var current_speed = 0.0         # smoothly interpolated actual speed; set in _ready
var knockback_velocity = Vector2.ZERO
var _attack_timer := 0.0
var _attack_cooldown := 0.0
var _flip_facing := false  # set true in subclass _ready() if sprite art faces left by default
var _player: Node2D         # cached at spawn — avoids tree search every frame
var _sep_offset: int = 0    # stagger so enemies don't all recalculate separation on the same frame
var _cached_separation: Vector2 = Vector2.ZERO

const KNOCKBACK_FRICTION = 14.0
const ATTACK_DURATION = 0.7     # default seconds locked in melee animation (override via _get_attack_duration)
const ATTACK_COOLDOWN = 0.4     # extra seconds after the animation before it can attack again
const ATTACK_HIT_WINDOW_FRAC = 0.35  # fraction of attack duration where contact damage is active (tail end)
const PLAYER_AVOIDANCE_RADIUS = 24.0  # enemies won't try to occupy this space around the player
const PLAYER_AVOIDANCE_FORCE = 150.0

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_sep_offset = randi() % 5
	current_speed = SPEED
	health = max_health
	collision_layer = 4  # enemy body on layer 3
	collision_mask = 5   # collide with walls (layer 1) and other enemies (layer 3)

	# stagger wander timers so enemies don't all turn at the same moment
	time_until_change = randf_range(0.5, CHANGE_DIRECTION_TIME)
	pick_random_direction()
	_play_anim("Idle")

	# 5% chance to spawn nearly invisible — becomes fully visible on first hit
	if randf() < INVISIBLE_CHANCE:
		is_invisible = true
		modulate.a = INVISIBLE_ALPHA

	add_to_group("enemy")
	if has_node("Area2D"):
		$Area2D.add_to_group("enemy_hitbox")

func _get_melee_range() -> float:
	return 0.0

func _get_attack_duration() -> float:
	return ATTACK_DURATION

## Returns false for melee enemies outside their hit window.
## Melee enemies only deal damage in the last ATTACK_HIT_WINDOW_FRAC of the animation.
func is_contact_damage_active() -> bool:
	if _get_melee_range() == 0.0:
		return true
	return _attack_timer > 0.0 and _attack_timer <= _get_attack_duration() * ATTACK_HIT_WINDOW_FRAC

func _physics_process(delta: float) -> void:
	var player := _player if is_instance_valid(_player) else null
	_attack_cooldown -= delta

	# === ATTACK STATE: frozen for the duration of the melee animation ===
	if _attack_timer > 0.0:
		_attack_timer -= delta
		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, delta * KNOCKBACK_FRICTION)
		velocity = knockback_velocity
		if aura_color.a > 0.0:
			_aura_time += delta
			queue_redraw()
		if direction.x != 0:
			$AnimatedSprite2D.flip_h = _flip_facing != (direction.x < 0)
		move_and_slide()
		return

	# === MELEE TRIGGER: commit to attack before moving this frame ===
	var melee_range := _get_melee_range()
	if melee_range > 0.0 and _attack_cooldown <= 0.0 \
			and player and global_position.distance_to(player.global_position) <= melee_range:
		direction = (player.global_position - global_position).normalized()
		if direction.x != 0:
			$AnimatedSprite2D.flip_h = _flip_facing != (direction.x < 0)
		var dur := _get_attack_duration()
		_attack_timer = dur
		_attack_cooldown = dur + ATTACK_COOLDOWN
		velocity = Vector2.ZERO
		move_and_slide()
		_play_anim("Melee")
		return

	# === NORMAL AI MOVEMENT ===
	var in_range = player and global_position.distance_to(player.global_position) <= DETECTION_RANGE
	if player and (in_range or rage_timer > 0):
		# chase the player; double speed while enraged from a recent hit
		direction = (player.global_position - global_position).normalized()
		var target_speed = CHASE_SPEED * (RAGE_SPEED_MULTIPLIER if rage_timer > 0 else 1.0)
		current_speed = move_toward(current_speed, target_speed, ACCELERATION * delta)
	else:
		# wander randomly, picking a new direction every few seconds
		time_until_change -= delta
		if time_until_change <= 0:
			pick_random_direction()
			time_until_change = randf_range(0.5, CHANGE_DIRECTION_TIME)
		current_speed = move_toward(current_speed, SPEED, ACCELERATION * delta)

	rage_timer -= delta
	if aura_color.a > 0.0:
		_aura_time += delta
		queue_redraw()
	velocity = direction * current_speed + _get_separation() + _get_player_avoidance() + knockback_velocity
	knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, delta * KNOCKBACK_FRICTION)
	move_and_slide()

	if direction.x != 0:
		$AnimatedSprite2D.flip_h = _flip_facing != (direction.x < 0)

	var anim := "Walk" if velocity.length() > 5.0 else "Idle"
	_play_anim(_pick_anim(anim))

## Returns a push vector that keeps this enemy from occupying the same space as the player.
func _get_player_avoidance() -> Vector2:
	var player := _player if is_instance_valid(_player) else null
	if not player:
		return Vector2.ZERO
	var offset = global_position - player.global_position
	var dist = offset.length()
	if dist < PLAYER_AVOIDANCE_RADIUS and dist > 0:
		return offset.normalized() * (1.0 - dist / PLAYER_AVOIDANCE_RADIUS) * PLAYER_AVOIDANCE_FORCE
	return Vector2.ZERO

## Returns a push vector that nudges this enemy away from any overlapping enemies.
## The force scales with how deeply they overlap — zero at the edge of the radius, max at full overlap.
func _get_separation() -> Vector2:
	if Engine.get_physics_frames() % 5 != _sep_offset:
		return _cached_separation
	var push = Vector2.ZERO
	for body in get_tree().get_nodes_in_group("enemy"):
		if body == self:
			continue
		var offset = global_position - body.global_position
		var dist = offset.length()
		if dist < SEPARATION_RADIUS and dist > 0:
			push += offset.normalized() * (1.0 - dist / SEPARATION_RADIUS) * SEPARATION_FORCE
	_cached_separation = push
	return push

func _pick_anim(default_anim: String) -> String:
	return default_anim

func _play_anim(anim: String) -> void:
	var frames: SpriteFrames = $AnimatedSprite2D.sprite_frames
	if not frames.has_animation(anim):
		anim = "Idle" if frames.has_animation("Idle") else "default"
	if $AnimatedSprite2D.animation != anim:
		$AnimatedSprite2D.play(anim)

func pick_random_direction() -> void:
	direction = Vector2.from_angle(randf() * TAU)

func take_damage(amount: int) -> void:
	health -= amount
	rage_timer = RAGE_DURATION  # triggers a charge at the player regardless of distance

	# first hit reveals an invisible enemy
	if is_invisible:
		is_invisible = false
		modulate.a = 1.0

	queue_redraw()  # refresh the health bar

	# alert pack-mates so the whole group charges together
	if pack_id != -1:
		for body in get_tree().get_nodes_in_group("enemy"):
			if body != self and body.pack_id == pack_id:
				body.rage_timer = RAGE_DURATION

	if health <= 0:
		die()

## Draws a health bar above the sprite — only visible after the enemy has taken damage.
func _draw() -> void:
	if aura_color.a > 0.0:
		var pulse = sin(_aura_time * 3.0) * 0.35 + 0.65
		for i in 4:
			var ring_alpha = (1.0 - float(i) / 4.0) * pulse * 0.7
			var ring_radius = 18.0 + float(i) * 8.0
			draw_circle(Vector2.ZERO, ring_radius, Color(aura_color.r, aura_color.g, aura_color.b, ring_alpha))

	if health >= max_health:
		return
	var bar_width = HEALTH_BAR_WIDTH
	var bar_height = HEALTH_BAR_HEIGHT
	var bar_pos = Vector2(-bar_width / 2, -HEALTH_BAR_OFFSET_Y)
	draw_rect(Rect2(bar_pos, Vector2(bar_width, bar_height)), Color(0.15, 0.15, 0.15, 0.9))
	var fill = bar_width * (float(health) / max_health)
	# green above half health, red below
	var col = Color(0.2, 0.85, 0.2) if health > max_health * 0.5 else Color(0.9, 0.2, 0.2)
	draw_rect(Rect2(bar_pos, Vector2(fill, bar_height)), col)

func apply_knockback(push: Vector2) -> void:
	knockback_velocity += push

func apply_difficulty(difficulty: float) -> void:
	max_health = int(max_health * difficulty)
	health = max_health
	DAMAGE = maxi(1, int(DAMAGE * difficulty))

## Override in subclasses to return the base sprite colour used for death particles.
func get_death_color() -> Color:
	return Color(0.25, 0.75, 0.25)

## Upgrades this enemy to rare tier: enormous, slow, very tough, and covered in gold.
func make_rare() -> void:
	is_rare = true
	aura_color = Color(1.0, 0.75, 0.05)
	var mat = ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/gold_glow.gdshader")
	$AnimatedSprite2D.material = mat
	scale = Vector2(3.0, 3.0)
	max_health *= 4
	health = max_health
	SPEED *= 0.5
	CHASE_SPEED *= 0.5
	DAMAGE *= 2
	current_speed = SPEED

## Upgrades this enemy to elite tier: bigger, faster, tougher, and visually distinct.
func make_elite() -> void:
	aura_color = Color(0.1, 0.45, 1.0)
	var mat = ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/blue_glow.gdshader")
	$AnimatedSprite2D.material = mat
	scale = Vector2(1.5, 1.5)
	CHASE_SPEED *= 1.5
	ACCELERATION *= 1.5
	DAMAGE *= 2
	max_health = 30
	health = max_health

## Removes the enemy, increments the kill counter, grants XP, and drops any loot.
func die() -> void:
	get_node("/root/GameState").kills += 1

	var xp = RARE_XP_REWARD if is_rare else (ELITE_XP_REWARD if pack_id != -1 else XP_REWARD)
	get_node("/root/PlayerStats").add_xp(xp)
	var xp_label = FloatingText.new()
	xp_label.text = "+" + str(xp) + " XP"
	xp_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.1, 1.0))
	xp_label.add_theme_font_size_override("font_size", 7)
	xp_label.hold_duration = 0.3
	xp_label.fade_duration = 0.25
	get_parent().add_child(xp_label)
	xp_label.global_position = global_position

	# color and particle count scale with enemy tier
	var p_color = Color(1.0, 0.75, 0.05) if is_rare else (Color(0.1, 0.45, 1.0) if pack_id != -1 else get_death_color())
	var p_amount = 80 if is_rare else (50 if pack_id != -1 else 28)
	var particles = CPUParticles2D.new()
	particles.set_script(EnemyDeathParticles)
	particles.base_color = p_color
	particles.base_amount = p_amount
	get_parent().add_child(particles)
	particles.global_position = global_position

	_drop_loot()

	queue_free.call_deferred()

func _drop_loot() -> void:
	var pos: Vector2 = get_parent().to_local(global_position)

	if get_node("/root/GameState").dev_boss_token_force:
		var token = BOSS_TOKEN_SCENE.instantiate()
		token.position = pos
		get_parent().call_deferred("add_child", token)
		return

	var r := randf()
	var accum := BOSS_TOKEN_DROP_CHANCE
	if r < accum:
		var token = BOSS_TOKEN_SCENE.instantiate()
		token.position = pos
		get_parent().call_deferred("add_child", token)
		return
	accum += CRATE_DROP_CHANCE
	if r < accum:
		var crate = CRATE_SCENE.instantiate()
		crate.position = pos
		get_parent().call_deferred("add_child", crate)
		return
	accum += HEALTH_DROP_CHANCE
	if r < accum:
		var pickup = HEALTH_PICKUP_SCENE.instantiate()
		pickup.position = pos
		get_parent().call_deferred("add_child", pickup)
		return
	accum += AMMO_DROP_CHANCE
	if r < accum:
		var pickup = AMMO_PICKUP_SCENE.instantiate()
		pickup.position = pos
		get_parent().call_deferred("add_child", pickup)
		return
	accum += COIN_DROP_CHANCE
	if r < accum:
		var coin = COIN_SCENE.instantiate()
		coin.position = pos
		get_parent().call_deferred("add_child", coin)

func _spawn_popup(text: String, color: Color) -> void:
	var label = FloatingText.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	get_parent().add_child(label)
	label.global_position = global_position
