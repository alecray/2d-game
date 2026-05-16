## Ranged enemy — keeps its distance, strafes, and fires purple bullets at the player.
## When hit it briefly flees before retreating back into orbit.
## Stops and plays "Range" animation each time it fires.
extends "res://scripts/characters/base_enemy.gd"

const PREFERRED_RANGE = 230.0    # tries to stay roughly this far from the player
const TOO_CLOSE_RANGE = 130.0    # retreats if the player gets closer than this
const FIRE_RATE = 2.0            # seconds between shots
const SHOOT_RANGE = 350.0        # won't shoot if the player is further away than this
const RANGED_ATTACK_DURATION = 0.4  # seconds frozen in Range animation per shot (2× the 0.2s cycle)
const ENEMY_BULLET = preload("res://prefabs/projectiles/enemy_bullet.tscn")

var fire_timer = 0.0
var _strafe_sign = 1  # which side to circle — randomised at spawn so groups orbit differently
var _ranged_attack_timer := 0.0

func _ready() -> void:
	SPEED = 75.0
	CHASE_SPEED = 130.0
	DAMAGE = 5        # low contact damage — this enemy is not meant to touch the player
	max_health = 15
	_strafe_sign = 1 if randf() < 0.5 else -1
	fire_timer = randf_range(0.0, FIRE_RATE)  # stagger so a pack doesn't all fire at once
	super._ready()

func _physics_process(delta: float) -> void:
	var player := _player if is_instance_valid(_player) else null

	# === RANGED ATTACK STATE: frozen for the animation duration ===
	if _ranged_attack_timer > 0.0:
		_ranged_attack_timer -= delta
		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, delta * KNOCKBACK_FRICTION)
		velocity = knockback_velocity
		rage_timer -= delta
		if aura_color.a > 0.0:
			_aura_time += delta
			queue_redraw()
		move_and_slide()
		return

	if player:
		var dist = global_position.distance_to(player.global_position)
		var to_player = (player.global_position - global_position).normalized()
		var perp = Vector2(-to_player.y, to_player.x) * _strafe_sign

		if rage_timer > 0:
			# took a hit — flee away from the player then settle back into orbit
			direction = -to_player
			current_speed = move_toward(current_speed, CHASE_SPEED, ACCELERATION * delta)
		elif dist < TOO_CLOSE_RANGE:
			# player is too close — back away while strafing
			direction = (-to_player + perp).normalized()
			current_speed = move_toward(current_speed, SPEED, ACCELERATION * delta)
		elif dist > PREFERRED_RANGE:
			# too far away — close the gap
			direction = to_player
			current_speed = move_toward(current_speed, SPEED, ACCELERATION * delta)
		else:
			# at preferred range — strafe perpendicular to keep circling
			direction = perp
			current_speed = move_toward(current_speed, SPEED * 0.7, ACCELERATION * delta)

		# === RANGED ATTACK TRIGGER ===
		fire_timer -= delta
		if fire_timer <= 0 and dist <= SHOOT_RANGE:
			direction = to_player
			if direction.x != 0:
				$AnimatedSprite2D.flip_h = _flip_facing != (direction.x < 0)
			_shoot(to_player)
			fire_timer = FIRE_RATE
			_ranged_attack_timer = RANGED_ATTACK_DURATION
			velocity = Vector2.ZERO
			move_and_slide()
			_play_anim("Range")
			return

	rage_timer -= delta
	if aura_color.a > 0.0:
		_aura_time += delta
		queue_redraw()
	velocity = direction * current_speed + _get_separation()
	knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, delta * KNOCKBACK_FRICTION)
	move_and_slide()

	if direction.x != 0:
		$AnimatedSprite2D.flip_h = _flip_facing != (direction.x < 0)

	_play_anim("Walk" if velocity.length() > 5.0 else "Idle")

func get_death_color() -> Color:
	return Color(0.55, 0.1, 0.85)

func _shoot(aim_direction: Vector2) -> void:
	var bullet = ENEMY_BULLET.instantiate()
	bullet.direction = aim_direction
	bullet.global_position = global_position
	get_parent().add_child(bullet)
