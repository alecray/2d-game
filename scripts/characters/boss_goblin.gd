## Boss enemy — one assigned per map. Chases aggressively and fires bullet spreads.
## Spawned by main.gd when 5 boss tokens are collected.
extends "res://scripts/characters/base_enemy.gd"

signal boss_died

const FIRE_RATE = 3.5          # seconds between bursts at full health
const FIRE_RATE_ENRAGED = 1.8  # seconds between bursts below 50% HP
const SHOOT_RANGE = 400.0      # won't shoot if player is further than this
const SPREAD_COUNT = 3         # bullets per burst
const SPREAD_ANGLE = 0.35      # radians between spread bullets
const MELEE_RANGE = 180.0      # distance at which the Melee animation plays
const BOSS_XP_REWARD = 200
const ENEMY_BULLET = preload("res://prefabs/enemy_bullet.tscn")
const CRATE_SCENE_BOSS = preload("res://prefabs/crate.tscn")
const FloatingTextBoss = preload("res://scripts/utils/floating_text.gd")
const EnemyDeathParticlesBoss = preload("res://scripts/effects/enemy_death_particles.gd")

var fire_timer := 0.0
var _ranged_anim_timer := 0.0

func _ready() -> void:
	SPEED = 80.0
	CHASE_SPEED = 150.0
	DAMAGE = 30
	max_health = 300
	fire_timer = randf_range(0.0, FIRE_RATE)
	super._ready()
	add_to_group("boss")

## Called by main.gd at spawn to apply per-map stat tuning and visual setup.
func make_boss(health_mult: float, damage_mult: float) -> void:
	max_health = int(max_health * health_mult)
	health = max_health
	DAMAGE = int(DAMAGE * damage_mult)
	scale = Vector2(2.0, 2.0)
	aura_color = Color(0.9, 0.1, 0.1)
	queue_redraw()

func _physics_process(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")

	var dist := INF
	if player:
		dist = global_position.distance_to(player.global_position)
		var to_player = (player.global_position - global_position).normalized()
		direction = to_player
		# cap rage speed to 1.2× so the boss never outruns the player
		var target_speed = CHASE_SPEED * (1.2 if rage_timer > 0 else 1.0)
		current_speed = move_toward(current_speed, target_speed, ACCELERATION * delta)

		fire_timer -= delta
		if fire_timer <= 0 and dist <= SHOOT_RANGE:
			_shoot_spread(to_player)
			fire_timer = FIRE_RATE_ENRAGED if health < max_health * 0.5 else FIRE_RATE
	else:
		current_speed = move_toward(current_speed, SPEED, ACCELERATION * delta)

	rage_timer -= delta
	if aura_color.a > 0.0:
		_aura_time += delta
		queue_redraw()

	velocity = direction * current_speed + _get_separation() + knockback_velocity
	knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, delta * KNOCKBACK_FRICTION)
	move_and_slide()

	for i in get_slide_collision_count():
		var collider = get_slide_collision(i).get_collider()
		if is_instance_valid(collider) and (collider.is_in_group("destructible_wall") or collider.is_in_group("destructible_tree")):
			_destroy_obstacle(collider)

	if direction.x != 0:
		$AnimatedSprite2D.flip_h = direction.x < 0

	_ranged_anim_timer = maxf(_ranged_anim_timer - delta, 0.0)

	if dist < MELEE_RANGE:
		_play_anim("Melee")
	elif _ranged_anim_timer > 0.0:
		_play_anim("Ranged")
	else:
		_play_anim("Walk" if velocity.length() > 5.0 else "Idle")

func _shoot_spread(aim: Vector2) -> void:
	_ranged_anim_timer = 0.7
	var half = (SPREAD_COUNT - 1) / 2.0
	for i in SPREAD_COUNT:
		var angle = (i - half) * SPREAD_ANGLE
		var bullet = ENEMY_BULLET.instantiate()
		bullet.direction = aim.rotated(angle)
		bullet.global_position = global_position
		get_parent().add_child(bullet)

func _destroy_obstacle(collider: Node) -> void:
	var is_tree := collider.is_in_group("destructible_tree")
	collider.remove_from_group("destructible_wall")
	collider.remove_from_group("destructible_tree")
	for child in collider.get_children():
		if child is CollisionShape2D:
			child.disabled = true
	var target: Node = collider.get_parent() if is_tree else collider
	var color := Color(0.35, 0.20, 0.08) if is_tree else Color(0.55, 0.45, 0.35)
	var particles := CPUParticles2D.new()
	particles.set_script(EnemyDeathParticlesBoss)
	particles.base_color = color
	particles.base_amount = 25
	get_parent().add_child(particles)
	particles.global_position = collider.global_position
	target.queue_free()

func _draw() -> void:
	# square ground shadow in local space (320×320 at 2× world scale)
	draw_rect(Rect2(-80, 50, 160, 80), Color(0, 0, 0, 0.38))
	# boss-scale aura rings — 5× larger radii than the base enemy
	if aura_color.a > 0.0:
		var pulse := sin(_aura_time * 3.0) * 0.35 + 0.65
		for i in 4:
			var ring_alpha := (1.0 - float(i) / 4.0) * pulse * 0.7
			draw_circle(Vector2.ZERO, 90.0 + float(i) * 18.0,
					Color(aura_color.r, aura_color.g, aura_color.b, ring_alpha))

func get_death_color() -> Color:
	return Color(0.8, 0.1, 0.1)

func die() -> void:
	get_node("/root/GameState").kills += 1

	var xp_label = FloatingTextBoss.new()
	xp_label.text = "+" + str(BOSS_XP_REWARD) + " XP"
	xp_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.1, 1.0))
	xp_label.add_theme_font_size_override("font_size", 12)
	xp_label.hold_duration = 0.5
	xp_label.fade_duration = 0.4
	get_parent().add_child(xp_label)
	xp_label.global_position = global_position
	get_node("/root/PlayerStats").add_xp(BOSS_XP_REWARD)

	var particles = CPUParticles2D.new()
	particles.set_script(EnemyDeathParticlesBoss)
	particles.base_color = get_death_color()
	particles.base_amount = 200
	get_parent().add_child(particles)
	particles.global_position = global_position

	var crate = CRATE_SCENE_BOSS.instantiate()
	crate.position = get_parent().to_local(global_position)
	get_parent().call_deferred("add_child", crate)

	boss_died.emit()
	queue_free.call_deferred()
