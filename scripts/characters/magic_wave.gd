## Expanding purple energy wave that kills any enemy it passes through.
## Spawn it at the player's position and it handles everything itself.
extends Node2D

const EXPAND_SPEED = 250.0  # pixels per second the wave grows
const MAX_RADIUS = 350.0

var radius = 0.0
var _hit = {}  # tracks enemies already killed so we don't double-hit

func _process(delta: float) -> void:
	radius += EXPAND_SPEED * delta
	queue_redraw()

	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy in _hit:
			continue
		if global_position.distance_to(enemy.global_position) <= radius:
			_hit[enemy] = true
			enemy.die()

	if radius >= MAX_RADIUS:
		queue_free()

func _draw() -> void:
	var t = radius / MAX_RADIUS
	var alpha = 1.0 - t
	# solid filled disc that fades as it expands
	draw_circle(Vector2.ZERO, radius, Color(0.55, 0.0, 1.0, alpha * 0.45))
	# bright leading edge so the boundary reads clearly
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(0.9, 0.6, 1.0, alpha), 3.0)
