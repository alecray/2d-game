extends Area2D

const SPEED = 400.0
const LIFETIME = 2.5
const MAX_BOUNCES = 3
const DAMAGE = 5
const FADE_START = 0.8  # begin fading when this many seconds of lifetime remain

var direction = Vector2.ZERO
var lifetime = LIFETIME
var bounces = 0
var damage = DAMAGE  # can be overridden by the shooter

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	var motion = direction * SPEED * delta

	# raycast ahead to detect walls before moving
	var space = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + motion)
	query.exclude = [get_rid()]
	query.collide_with_areas = false  # ignore Area2D hitboxes — those are handled by area_entered
	var result = space.intersect_ray(query)

	if result and result.collider is StaticBody2D:
		if bounces < MAX_BOUNCES:
			direction = direction.bounce(result.normal)
			bounces += 1
		else:
			queue_free()
			return

	position += direction * SPEED * delta
	lifetime -= delta

	# fade out as lifetime runs low so disappearance feels gradual
	if lifetime < FADE_START:
		modulate.a = lifetime / FADE_START

	if lifetime <= 0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_hitbox"):
		var enemy = area.get_parent()
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage)
		queue_free()
