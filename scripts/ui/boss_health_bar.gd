extends Control

const FONT = preload("res://assets/fonts/PressStart2P-Regular.ttf")
const BAR_W  = 520.0
const BAR_H  = 22.0
const BAR_Y  = 36.0   # pixels from top of screen

var _boss: Node = null

func setup(boss: Node) -> void:
	_boss = boss
	boss.boss_died.connect(_on_boss_died)
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)

func _on_boss_died() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.tween_callback(get_parent().queue_free)

func _process(_delta: float) -> void:
	if not is_instance_valid(_boss):
		get_parent().queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var pct := clampf(float(_boss.health) / float(_boss.max_health), 0.0, 1.0)
	var bar_x := (get_viewport_rect().size.x - BAR_W) * 0.5

	# dark backdrop behind label + bar
	draw_rect(Rect2(bar_x - 4, BAR_Y - 18, BAR_W + 8, BAR_H + 22), Color(0, 0, 0, 0.82))

	# "BOSS" label centred over the bar
	draw_string(FONT, Vector2(bar_x, BAR_Y - 5), "BOSS",
			HORIZONTAL_ALIGNMENT_CENTER, BAR_W, 9, Color(1.0, 0.55, 0.55))

	# empty bar background
	draw_rect(Rect2(bar_x, BAR_Y, BAR_W, BAR_H), Color(0.12, 0.04, 0.04))

	# health fill — turns orange below 30 %
	if pct > 0.0:
		var fill_col := Color(0.85, 0.1, 0.1) if pct > 0.3 else Color(1.0, 0.4, 0.0)
		draw_rect(Rect2(bar_x, BAR_Y, BAR_W * pct, BAR_H), fill_col)

	# thin white border
	draw_rect(Rect2(bar_x, BAR_Y, BAR_W, BAR_H), Color(1, 1, 1, 0.22), false, 1.5)
