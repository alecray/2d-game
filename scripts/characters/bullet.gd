extends Area2D

const SPEED = 400.0
const LIFETIME = 5.0

var direction = Vector2.ZERO
var lifetime = LIFETIME

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_hitbox"):
		var enemy = area.get_parent()
		if enemy.has_method("take_damage"):
			enemy.take_damage(5)
		queue_free()
