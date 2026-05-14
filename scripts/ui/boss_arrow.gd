extends Node2D

## Orbits the screen centre, pointing toward the boss.
## Replace the AnimatedSprite2D frames with your own art — the node rotates automatically.
## The sprite should point RIGHT in its default/rest frame; adjust rotation_offset otherwise.

const ORBIT_RADIUS := 130.0
const FADE_SPEED := 5.0  # alpha units per second when fading in/out
var rotation_offset := 0.0  # radians; tweak if your sprite's "forward" isn't pointing right

var _boss: Node = null
var _fading_out := false

func setup(boss: Node) -> void:
	_boss = boss
	boss.boss_died.connect(_on_boss_died)
	$AnimatedSprite2D.play("default")
	modulate.a = 0.0

func _on_boss_died() -> void:
	_fading_out = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.tween_callback(get_parent().queue_free)

func _process(delta: float) -> void:
	if _fading_out:
		return
	if not is_instance_valid(_boss):
		get_parent().queue_free()
		return
	var player := get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return

	var dir: Vector2 = (_boss.global_position - player.global_position).normalized()
	var screen_center := get_viewport().get_visible_rect().size * 0.5
	position = screen_center + dir * ORBIT_RADIUS
	rotation = dir.angle() + rotation_offset

	# Fade out while boss is on screen, fade in when off screen
	var boss_screen_pos: Vector2 = get_viewport().get_canvas_transform() * _boss.global_position
	var visible_on_screen := get_viewport().get_visible_rect().has_point(boss_screen_pos)
	var target_alpha := 0.0 if visible_on_screen else 1.0
	modulate.a = move_toward(modulate.a, target_alpha, FADE_SPEED * delta)
