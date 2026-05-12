## Enemy character with random movement and direction changes
extends CharacterBody2D

var SPEED = 100.0           # normal wandering speed
var CHASE_SPEED = 220.0     # speed when chasing the player
var ACCELERATION = 250.0    # how fast the enemy speeds up or slows down
const CHANGE_DIRECTION_TIME = 2.0  # max seconds before picking a new wander direction
const DETECTION_RANGE = 200.0 # how close the player has to be before the enemy notices them
var DAMAGE = 10              # damage dealt to player on contact
const SEPARATION_RADIUS = 28.0 # enemies start pushing apart within this distance
const SEPARATION_FORCE = 80.0  # strength of that push
const FloatingText = preload("res://scripts/utils/floating_text.gd")

# each enemy is assigned one drop type on spawn — 30% ammo, 30% health, 40% nothing
enum DropType { NONE, AMMO, HEALTH }
var drop_type = DropType.NONE

var max_health = 10
var health = max_health
var rage_timer = 0.0  # while > 0, enemy charges at boosted speed
var pack_id = -1      # shared ID for elite pack-mates; -1 means no pack

var direction = Vector2.ZERO  # which way the enemy is currently moving
var time_until_change = 0.0   # countdown until the next random direction change
var current_speed = SPEED     # tracks speed as it smoothly ramps up/down

func _ready() -> void:
	# randomly assign this enemy's drop at spawn
	var roll = randf()
	if roll < 0.1:
		drop_type = DropType.AMMO
	elif roll < 0.2:
		drop_type = DropType.HEALTH

	# start the direction change timer at a random value so not all enemies turn at the same time
	time_until_change = randf_range(0.5, CHANGE_DIRECTION_TIME)
	pick_random_direction()
	$AnimatedSprite2D_Enemy1.play()
	# register in groups so other scripts (player, bullets) can detect this enemy
	add_to_group("enemy")
	if has_node("Area2D"):
		$Area2D.add_to_group("enemy_hitbox")

func _physics_process(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")

	var in_range = player and global_position.distance_to(player.global_position) <= DETECTION_RANGE
	if player and (in_range or rage_timer > 0):
		# chase the player — at double speed if enraged from taking a hit
		direction = (player.global_position - global_position).normalized()
		var target_speed = CHASE_SPEED * (2.0 if rage_timer > 0 else 1.0)
		current_speed = move_toward(current_speed, target_speed, ACCELERATION * delta)
	else:
		# player is far away — wander randomly and slow back down
		time_until_change -= delta
		if time_until_change <= 0:
			pick_random_direction()
			time_until_change = randf_range(0.5, CHANGE_DIRECTION_TIME)
		current_speed = move_toward(current_speed, SPEED, ACCELERATION * delta)

	rage_timer -= delta
	velocity = direction * current_speed + _get_separation()
	move_and_slide()

	# flip the sprite to face whichever horizontal direction the enemy is moving
	if direction.x != 0:
		$AnimatedSprite2D_Enemy1.flip_h = direction.x < 0


## Pushes this enemy away from other nearby enemies so they don't fully stack
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

## Pick a completely random direction to wander toward
func pick_random_direction() -> void:
	var random_angle = randf() * TAU  # TAU is a full 360 degrees in radians
	direction = Vector2.from_angle(random_angle)

func take_damage(amount: int) -> void:
	health -= amount
	rage_timer = 1.5  # lunge at the player for 1.5s after being hit
	queue_redraw()
	if pack_id != -1:
		for body in get_tree().get_nodes_in_group("enemy"):
			if body != self and body.pack_id == pack_id:
				body.rage_timer = 1.5
	if health <= 0:
		die()

func _draw() -> void:
	if health >= max_health:
		return
	var bar_width = 32.0
	var bar_height = 4.0
	var bar_pos = Vector2(-bar_width / 2, -26)
	draw_rect(Rect2(bar_pos, Vector2(bar_width, bar_height)), Color(0.15, 0.15, 0.15, 0.9))
	var fill = bar_width * (float(health) / max_health)
	var col = Color(0.2, 0.85, 0.2) if health > max_health * 0.5 else Color(0.9, 0.2, 0.2)
	draw_rect(Rect2(bar_pos, Vector2(fill, bar_height)), col)

## Turns this enemy elite — applies a blue glow shader to mark it visually
func make_elite() -> void:
	var mat = ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/blue_glow.gdshader")
	$AnimatedSprite2D_Enemy1.material = mat
	scale = Vector2(1.5, 1.5)
	CHASE_SPEED *= 1.5
	ACCELERATION *= 1.5
	DAMAGE *= 2
	max_health = 30
	health = max_health

## Remove this enemy from the scene (called when hit by a bullet)
func die() -> void:
	get_node("/root/GameState").kills += 1
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if drop_type == DropType.AMMO:
			player.ammo = player.MAX_AMMO  # setter emits ammo_changed automatically
			_spawn_popup("AMMO!", Color(1, 1, 0, 1))
		elif drop_type == DropType.HEALTH:
			player.health = player.MAX_HEALTH  # setter emits health_changed automatically
			_spawn_popup("HEALTH!", Color(0, 1, 0, 1))
	queue_free()

func _spawn_popup(text: String, color: Color) -> void:
	var label = FloatingText.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	get_parent().add_child(label)
	label.global_position = global_position
