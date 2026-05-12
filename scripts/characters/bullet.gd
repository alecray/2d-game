extends Area2D

const SPEED = 400.0
const LIFETIME = 2.5
const MAX_BOUNCES = 3
const DAMAGE = 5
const FADE_START = 0.8  # begin fading when this many seconds of lifetime remain
const ENEMY_KNOCKBACK = 200.0
const EXPLOSION_RADIUS = 80.0
const HOMING_STRENGTH = 2.5  # lerp factor toward target per second

const HitParticles = preload("res://scripts/effects/hit_particles.gd")

var direction = Vector2.ZERO
var lifetime = LIFETIME
var bounces = 0
var damage = DAMAGE         # can be overridden by the shooter
var speed = SPEED           # boosted by Velocity upgrade
var max_bounces = MAX_BOUNCES  # boosted by Ricochet upgrade
var piercing = false        # Penetrator: pass through enemies
var explosive = false       # Volatile: AOE damage on hit
var homing = false          # Seeker: curve toward nearest enemy
var _hit_enemies: Dictionary = {}

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat

func _physics_process(delta: float) -> void:
	if homing:
		var nearest = _nearest_enemy()
		if nearest:
			var to_target = (nearest.global_position - global_position).normalized()
			direction = direction.lerp(to_target, HOMING_STRENGTH * delta).normalized()

	var motion = direction * speed * delta

	# raycast ahead to detect walls before moving
	var space = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + motion)
	query.exclude = [get_rid()]
	query.collide_with_areas = false  # ignore Area2D hitboxes — those are handled by area_entered
	var result = space.intersect_ray(query)

	if result and result.collider is StaticBody2D:
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

	if lifetime <= 0:
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
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy in _hit_enemies:
			continue
		if global_position.distance_to(enemy.global_position) <= EXPLOSION_RADIUS:
			if enemy.has_method("take_damage"):
				enemy.take_damage(maxi(1, int(damage * 0.5)))
			_hit_enemies[enemy] = true

func _nearest_enemy() -> Node:
	var nearest: Node = null
	var nearest_dist = INF
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var d = global_position.distance_to(enemy.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = enemy
	return nearest
