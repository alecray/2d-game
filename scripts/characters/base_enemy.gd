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
const HEALTH_BAR_WIDTH = 32.0
const HEALTH_BAR_HEIGHT = 4.0
const HEALTH_BAR_OFFSET_Y = 26.0    # how far above the sprite centre the health bar sits
const FloatingText = preload("res://scripts/utils/floating_text.gd")

# what this enemy will drop when it dies — assigned randomly at spawn
enum DropType { NONE, AMMO, HEALTH }
var drop_type = DropType.NONE

var health = 10
var rage_timer = 0.0   # while > 0, enemy charges at boosted speed
var pack_id = -1       # shared ID for elite pack-mates; -1 means no pack
var is_invisible = false

var direction = Vector2.ZERO    # current movement direction (unit vector)
var time_until_change = 0.0     # countdown until the next random direction pick
var current_speed = 0.0         # smoothly interpolated actual speed; set in _ready

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
	velocity = direction * current_speed + _get_separation()
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

## Upgrades this enemy to elite tier: bigger, faster, tougher, and visually distinct.
func make_elite() -> void:
	var mat = ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/blue_glow.gdshader")
	$AnimatedSprite2D.material = mat
	scale = Vector2(1.5, 1.5)
	CHASE_SPEED *= 1.5
	ACCELERATION *= 1.5
	DAMAGE *= 2
	max_health = 30
	health = max_health

## Removes the enemy, increments the kill counter, and grants the player any loot drop.
func die() -> void:
	get_node("/root/GameState").kills += 1
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if drop_type == DropType.AMMO:
			player.ammo = player.MAX_AMMO
			_spawn_popup("AMMO!", Color(1, 1, 0, 1))
		elif drop_type == DropType.HEALTH:
			player.health = player.MAX_HEALTH
			_spawn_popup("HEALTH!", Color(0, 1, 0, 1))
	queue_free()

func _spawn_popup(text: String, color: Color) -> void:
	var label = FloatingText.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	get_parent().add_child(label)
	label.global_position = global_position
