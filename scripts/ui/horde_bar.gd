extends Control

const FONT  = preload("res://assets/fonts/PressStart2P-Regular.ttf")
const BAR_W = 520.0
const BAR_H = 22.0
const BAR_Y = 36.0

var _kills_needed:  int = 1
var _kills_current: int = 0

func setup(kills_needed: int) -> void:
	_kills_needed = kills_needed
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)

func update_kills(current: int) -> void:
	_kills_current = current
	queue_redraw()

func _draw() -> void:
	var pct := clampf(float(_kills_current) / float(_kills_needed), 0.0, 1.0)
	var bar_x := (get_viewport_rect().size.x - BAR_W) * 0.5

	draw_rect(Rect2(bar_x - 4, BAR_Y - 18, BAR_W + 8, BAR_H + 22), Color(0, 0, 0, 0.82))
	draw_string(FONT, Vector2(bar_x, BAR_Y - 5),
			"SURVIVE THE HORDE  %d / %d" % [_kills_current, _kills_needed],
			HORIZONTAL_ALIGNMENT_CENTER, BAR_W, 9, Color(1.0, 0.55, 0.15))
	draw_rect(Rect2(bar_x, BAR_Y, BAR_W, BAR_H), Color(0.08, 0.04, 0.00))
	if pct > 0.0:
		var fill_col := Color(1.0, 0.65, 0.0) if pct < 1.0 else Color(1.0, 0.25, 0.1)
		draw_rect(Rect2(bar_x, BAR_Y, BAR_W * pct, BAR_H), fill_col)
	draw_rect(Rect2(bar_x, BAR_Y, BAR_W, BAR_H), Color(1, 1, 1, 0.22), false, 1.5)
