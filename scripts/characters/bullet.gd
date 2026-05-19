extends Area2D

const SPEED = 400.0
const LIFETIME = 1.5
const MAX_RANGE_SQ = 750.0 * 750.0  # cull if bullet travels beyond this distance from spawn
const MAX_BOUNCES = 0
const DAMAGE = 5
const FADE_START = 0.8  # begin fading when this many seconds of lifetime remain
const ENEMY_KNOCKBACK = 200.0
const EXPLOSION_RADIUS = 80.0
const HOMING_STRENGTH = 2.5  # lerp factor toward target per second

const HitParticles = preload("res://scripts/effects/hit_particles.gd")
const GroundShadow = preload("res://scripts/effects/ground_shadow.gd")

var direction = Vector2.ZERO
var lifetime = LIFETIME
var _spawn: Vector2
var bounces = 0
var damage = DAMAGE         # can be overridden by the shooter
var speed = SPEED           # boosted by Velocity upgrade
var max_bounces = MAX_BOUNCES  # boosted by Ricochet upgrade
var piercing = false        # Penetrator: pass through enemies
var explosive = false       # Volatile: AOE damage on hit
var homing = false          # Seeker: curve toward nearest enemy
var bullet_color = Color.WHITE  # set by the player; gun types will override this
# Dictionary used as a set — keyed by enemy node reference so piercing bullets
# can't hit the same enemy twice and explosion splash can't double-count.
var _hit_enemies: Dictionary = {}
var _homing_target: Node = null
var _homing_refresh: float = 0.0

func _ready() -> void:
	_spawn = global_position
	area_entered.connect(_on_area_entered)
	$ColorRect.color = bullet_color
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	var shadow := Node2D.new()
	shadow.set_script(GroundShadow)
	shadow.position = Vector2(0.0, 16.0)
	shadow.scale = Vector2(0.44, 0.18)
	shadow.modulate = Color(0.0, 0.0, 0.0, 0.22)
	shadow.z_index = -1
	add_child(shadow)

func _physics_process(delta: float) -> void:
	if homing:
		_homing_refresh -= delta
		if _homing_refresh <= 0.0 or not is_instance_valid(_homing_target):
			_homing_target = _nearest_enemy()
			_homing_refresh = 0.2
		if _homing_target and is_instance_valid(_homing_target):
			var to_target = (_homing_target.global_position - global_position).normalized()
			direction = direction.lerp(to_target, HOMING_STRENGTH * delta).normalized()

	var motion = direction * speed * delta

	# Raycast the full frame's movement before moving to catch thin walls the Area2D
	# might tunnel through at high speed. area_entered still handles enemy hits.
	var space = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + motion)
	query.exclude = [get_rid()]
	query.collide_with_areas = false  # enemy hitboxes are Area2D; skip them here
	var result = space.intersect_ray(query)

	if result and result.collider is StaticBody2D:
		_spawn_wall_hit_sparks(result.normal)
		if result.collider.has_method("take_damage"):
			result.collider.take_damage(damage, result.normal)
		if bounces < max_bounces:
			direction = direction.bounce(result.normal)
			bounces += 1
		else:
			queue_free.call_deferred()
			return

	position += direction * speed * delta
	lifetime -= delta

	# fade out as lifetime runs low so disappearance feels gradual
	if lifetime < FADE_START:
		modulate.a = lifetime / FADE_START

	# distance_squared avoids a sqrt; MAX_RANGE_SQ is pre-squared at declaration.
	if lifetime <= 0 or global_position.distance_squared_to(_spawn) > MAX_RANGE_SQ:
		queue_free.call_deferred()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_hitbox"):
		var enemy = area.get_parent()
		if enemy in _hit_enemies:
			return
		_hit_enemies[enemy] = true
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage)
		if enemy.has_method("apply_knockback"):
			enemy.apply_knockback(direction * ENEMY_KNOCKBACK)
		if explosive:
			_explode()
		var sparks = CPUParticles2D.new()
		sparks.set_script(HitParticles)
		sparks.hit_direction = direction
		get_parent().add_child(sparks)
		sparks.global_position = global_position
		if not piercing:
			queue_free.call_deferred()

func _explode() -> void:
	# Splash deals half damage; minimum 1 so no hit is ever silent.
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy in _hit_enemies:
			continue
		if global_position.distance_to(enemy.global_position) <= EXPLOSION_RADIUS:
			if enemy.has_method("take_damage"):
				enemy.take_damage(maxi(1, int(damage * 0.5)))
			_hit_enemies[enemy] = true

func _spawn_wall_hit_sparks(normal: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot              = true
	p.explosiveness         = 1.0
	p.amount                = 5
	p.lifetime              = 0.22
	p.gravity               = Vector2.ZERO
	p.direction             = normal
	p.spread                = 50.0
	p.initial_velocity_min  = 80.0
	p.initial_velocity_max  = 220.0
	p.scale_amount_min      = 1.0
	p.scale_amount_max      = 2.5
	var cgrad := Gradient.new()
	cgrad.colors = PackedColorArray([Color(0.85, 0.80, 0.65), Color(0.50, 0.45, 0.38)])
	p.color_initial_ramp = cgrad
	var lgrad := Gradient.new()
	lgrad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = lgrad
	p.z_index = 5
	get_parent().add_child(p)
	p.global_position = global_position
	p.emitting = true
	p.finished.connect(p.queue_free)

func _nearest_enemy() -> Node:
	var nearest: Node = null
	var nearest_dist = INF
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var d = global_position.distance_to(enemy.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = enemy
	return nearest
