## Listens for health_changed on the player and updates itself.
## Attach this to any Label node — it finds the player by group so it works anywhere in the tree.
extends Label

const FONT = preload("res://assets/fonts/PressStart2P-Regular.ttf")

func _ready() -> void:
	await get_tree().process_frame  # wait for player's _ready() to run and register its group
	var player = get_tree().get_first_node_in_group("player")
	if player:
		text = str(player.health)
		player.health_changed.connect(func(value): text = str(value))
		player.damage_taken.connect(_spawn_damage_popup)

func _spawn_damage_popup(amount: int) -> void:
	var label = Label.new()
	label.text = "-" + str(amount)
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1.0))
	label.position = position + Vector2(0, -10)
	label.rotation = deg_to_rad(10)
	get_parent().add_child(label)
	var tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 30, 0.6)
	tween.tween_property(label, "rotation", deg_to_rad(-15), 0.6).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free).set_delay(0.6)
