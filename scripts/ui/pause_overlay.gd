extends CanvasLayer

const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")

var _quit_btn: Button

func _ready() -> void:
	visible = false
	_build_quit_button()

func _build_quit_button() -> void:
	var sn := StyleBoxFlat.new()
	sn.bg_color = Color(0.12, 0.04, 0.04, 0.90)
	sn.set_border_width_all(2)
	sn.border_color = Color(0.85, 0.20, 0.20, 0.70)
	sn.set_content_margin_all(10.0)

	var sh := StyleBoxFlat.new()
	sh.bg_color = Color(0.22, 0.06, 0.06, 0.95)
	sh.set_border_width_all(3)
	sh.border_color = Color(1.0, 0.30, 0.30, 1.0)
	sh.set_content_margin_all(10.0)

	var sp := StyleBoxFlat.new()
	sp.bg_color = Color(0.07, 0.02, 0.02, 0.95)
	sp.set_border_width_all(2)
	sp.border_color = Color(0.85, 0.20, 0.20, 0.40)
	sp.set_content_margin_all(10.0)

	_quit_btn = Button.new()
	_quit_btn.text = "QUIT TO DESKTOP"
	_quit_btn.add_theme_font_override("font", FONT)
	_quit_btn.add_theme_font_size_override("font_size", 10)
	_quit_btn.add_theme_color_override("font_color",         Color(1.0, 0.55, 0.55))
	_quit_btn.add_theme_color_override("font_hover_color",   Color(1.0, 0.75, 0.75))
	_quit_btn.add_theme_color_override("font_pressed_color", Color(0.80, 0.30, 0.30))
	_quit_btn.add_theme_color_override("font_focus_color",   Color(1.0, 0.55, 0.55))
	_quit_btn.add_theme_stylebox_override("normal",  sn)
	_quit_btn.add_theme_stylebox_override("hover",   sh)
	_quit_btn.add_theme_stylebox_override("pressed", sp)
	_quit_btn.add_theme_stylebox_override("focus",   sn)
	_quit_btn.custom_minimum_size = Vector2(220.0, 44.0)
	_quit_btn.anchor_left   = 0.5
	_quit_btn.anchor_right  = 0.5
	_quit_btn.anchor_top    = 0.5
	_quit_btn.anchor_bottom = 0.5
	_quit_btn.offset_left   = -110.0
	_quit_btn.offset_right  =  110.0
	_quit_btn.offset_top    =  40.0
	_quit_btn.offset_bottom =  84.0
	_quit_btn.pressed.connect(_on_quit)
	add_child(_quit_btn)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		get_tree().paused = !get_tree().paused
		visible = get_tree().paused

func _on_quit() -> void:
	get_tree().paused = false
	get_tree().quit()
