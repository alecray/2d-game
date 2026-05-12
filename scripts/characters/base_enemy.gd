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
const AMMO_DROP_CHANCE = 0.1        # roll below this → drop ammo on death
const HEALTH_DROP_CHANCE = 0.2      # roll below this (but above ammo) → drop health on death
const CRATE_DROP_CHANCE = 0.025     # independent 2.5% chance to also drop an upgrade crate
const COIN_DROP_CHANCE = 0.15       # independent 15% chance to drop a coin
const CRATE_SCENE = preload("res://prefabs/crate.tscn")
const COIN_SCENE = preload("res://prefabs/coin.tscn")
const XP_REWARD = 5                 # XP granted to the player on death
const ELITE_XP_REWARD = 15         # XP for elite (pack) enemies
const RARE_XP_REWARD = 50          # XP for rare (golden) enemies
const HEALTH_BAR_WIDTH = 32.0
const HEALTH_BAR_HEIGHT = 4.0
const HEALTH_BAR_OFFSET_Y = 26.0    # how far above the sprite centre the health bar sits
const FloatingText = preload("res://scripts/utils/floating_text.gd")
const EnemyDeathParticles = preload("res://scripts/effects/enemy_death_particles.gd")

# what this enemy will drop when it dies — assigned randomly at spawn
enum DropType { NONE, AMMO, HEALTH }
var drop_type = DropType.NONE

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

const KNOCKBACK_FRICTION = 14.0

func _ready() -> void:
	current_speed = SPEED
	health = max_health

	# randomly assign this enemy's loot drop at spawn
	var roll = randf()
	if roll < AMMO_DROP_CHANCE:
		drop_type = DropType.AMMO
	elif roll < HEALTH_DROP_CHANCE:
		drop_type = DropType.HEALTH

	# stagger wander timers so enemies don't all turn at the same moment
	time_until_change = randf_range(0.5, CHANGE_DIRECTION_TIME)
	pick_random_direction()
	$AnimatedSprite2D.play("default")

	# 5% chance to spawn nearly invisible — becomes fully visible on first hit
	if randf() < INVISIBLE_CHANCE:
		is_invisible = true
		modulate.a = INVISIBLE_ALPHA

	add_to_group("enemy")
	if has_node("Area2D"):
		$Area2D.add_to_group("enemy_hitbox")

func _physics_process(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")

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
	velocity = direction * current_speed + _get_separation() + knockback_velocity
	knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, delta * KNOCKBACK_FRICTION)
	move_and_slide()

	# flip sprite to face the direction of travel
	if direction.x != 0:
		$AnimatedSprite2D.flip_h = direction.x < 0

## Returns a push vector that nudges this enemy away from any overlapping enemies.
## The force scales with how deeply they overlap — zero at the edge of the radius, max at full overlap.
func _get_separation() -> Vector2:
	var push = Vector2.ZERO
	for body in get_tree().get_nodes_in_group("enemy"):
		if body == self:
			continue
		var offset = global_position - body.global_position
		var dist = offset.length()
		if dist < SEPARATION_RADIUS and dist > 0:
			push += offset.normalized() * (1.0 - dist / SEPARATION_RADIUS) * SEPARATION_FORCE
	return push

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

func apply_difficulty(scale: float) -> void:
	max_health = int(max_health * scale)
	health = max_health
	DAMAGE = maxi(1, int(DAMAGE * scale))

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

	var player = get_tree().get_first_node_in_group("player")
	if player:
		if drop_type == DropType.AMMO:
			player.ammo = player.MAX_AMMO
			_spawn_popup("+ammo", Color(1, 1, 0, 1))
		elif drop_type == DropType.HEALTH:
			player.health = player.MAX_HEALTH
			_spawn_popup("+health", Color(0, 1, 0, 1))

	# color and particle count scale with enemy tier
	var p_color = Color(1.0, 0.75, 0.05) if is_rare else (Color(0.1, 0.45, 1.0) if pack_id != -1 else get_death_color())
	var p_amount = 80 if is_rare else (50 if pack_id != -1 else 28)
	var particles = CPUParticles2D.new()
	particles.set_script(EnemyDeathParticles)
	particles.base_color = p_color
	particles.base_amount = p_amount
	get_parent().add_child(particles)
	particles.global_position = global_position

	if randf() < CRATE_DROP_CHANCE:
		var crate = CRATE_SCENE.instantiate()
		crate.position = get_parent().to_local(global_position)
		get_parent().call_deferred("add_child", crate)

	if randf() < COIN_DROP_CHANCE:
		var coin = COIN_SCENE.instantiate()
		coin.position = get_parent().to_local(global_position)
		get_parent().call_deferred("add_child", coin)

	queue_free.call_deferred()

func _spawn_popup(text: String, color: Color) -> void:
	var label = FloatingText.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	get_parent().add_child(label)
	label.global_position = global_position
