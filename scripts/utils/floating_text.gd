## Reusable floating text popup — spawn one, set its text and global_position, and it handles the rest.
## The label floats upward and fades out over 0.8 seconds, then removes itself.
## Usage: var label = FloatingText.new(); get_parent().add_child(label); label.global_position = ...
extends Label

const FONT = preload("res://assets/fonts/PressStart2P-Regular.ttf")

func _ready() -> void:
	add_theme_font_override("font", FONT)
	z_index = 100          # render on top of game world objects
	pivot_offset = size / 2  # center the label on its spawn point
	var tween = create_tween()
	tween.tween_interval(1.0)  # hold visible for 1 second before fading
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)  # remove from scene once animation finishes
