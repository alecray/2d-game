## Reusable floating text popup — spawn, set text/global_position, and it handles the rest.
## Configurable vars must be set BEFORE add_child() since _ready() starts the animation.
extends Label

const FONT = preload("res://assets/fonts/PressStart2P-Regular.ttf")
const FONT_SIZE = 14

var hold_duration = 1.0    # seconds to sit still before fading
var fade_duration = 0.4    # seconds to fade out
var rise_distance = 0.0    # pixels to float upward before fading; 0 = stationary
var rise_duration = 0.25   # how long the rise takes (only used when rise_distance > 0)

func _ready() -> void:
	add_theme_font_override("font", FONT)
	add_theme_font_size_override("font_size", FONT_SIZE)
	z_index = 100
	pivot_offset = size / 2
	var tween = create_tween()
	if rise_distance > 0:
		tween.tween_property(self, "position:y", position.y - rise_distance, rise_duration)
	tween.tween_interval(hold_duration)
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	tween.tween_callback(queue_free)
