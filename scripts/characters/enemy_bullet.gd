## Projectile fired by ranged enemies — damages the player on contact.
extends Area2D

const SPEED = 180.0
const LIFETIME = 4.0
const DAMAGE = 15
const FADE_START = 0.8

var direction = Vector2.ZERO
var lifetime = LIFETIME

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	var motion = direction * SPEED * delta
	var space = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + motion)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var result = space.intersect_ray(query)
	if result and result.collider is StaticBody2D:
		queue_free.call_deferred()
		return

	position += motion
	lifetime -= delta

	if lifetime < FADE_START:
		modulate.a = lifetime / FADE_START

	if lifetime <= 0:
		queue_free.call_deferred()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_hitbox"):
		var player = area.get_parent()
		if player.has_method("take_damage"):
			player.take_damage(DAMAGE)
		queue_free.call_deferred()
