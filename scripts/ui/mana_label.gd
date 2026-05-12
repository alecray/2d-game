## Displays the player's current mana and shows a floating "-50" popup when magic is cast.
## Attach this to any Label node — it finds the player by group so it works anywhere in the tree.
extends Label

const FONT = preload("res://assets/fonts/PressStart2P-Regular.ttf")
const POPUP_FONT_SIZE = 10
const POPUP_OFFSET_Y = 10.0
const POPUP_FLOAT_DISTANCE = 30.0
const POPUP_DURATION = 0.6
const POPUP_ROTATION_START = 10
const POPUP_ROTATION_END = -15

func _ready() -> void:
	# wait one frame so the player node has finished its own _ready() and joined the group
	await get_tree().process_frame
	var player = get_tree().get_first_node_in_group("player")
	if player:
		text = str(player.mana)
		player.mana_changed.connect(func(value): text = str(value))
		player.magic_used.connect(_spawn_cost_popup)

## Spawns a short-lived cost label that floats upward and tilts left, then fades out.
## Added as a sibling so it lives in the same UI layer as this label.
func _spawn_cost_popup(cost: int) -> void:
	var label = Label.new()
	label.text = "-" + str(cost)
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", POPUP_FONT_SIZE)
	label.add_theme_color_override("font_color", Color(0.6, 0.0, 1.0, 1.0))
	# start just above this label's position
	label.position = position + Vector2(0, -POPUP_OFFSET_Y)
	# slight clockwise tilt so it can animate counter-clockwise as it rises
	label.rotation = deg_to_rad(POPUP_ROTATION_START)
	get_parent().add_child(label)
	var tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - POPUP_FLOAT_DISTANCE, POPUP_DURATION)
	tween.tween_property(label, "rotation", deg_to_rad(POPUP_ROTATION_END), POPUP_DURATION).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, POPUP_DURATION)
	tween.tween_callback(label.queue_free).set_delay(POPUP_DURATION)
