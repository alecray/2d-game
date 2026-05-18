extends CanvasLayer

const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")

var _quit_btn: Button
var _map_btn: Button

func _ready() -> void:
	visible = false
	_build_buttons()

func _make_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(2)
	s.border_color = border
	s.set_content_margin_all(10.0)
	return s

func _build_buttons() -> void:
	# Map selection button
	_map_btn = Button.new()
	_map_btn.text = "QUIT TO MAP SELECTION"
	_map_btn.add_theme_font_override("font", FONT)
	_map_btn.add_theme_font_size_override("font_size", 8)
	_map_btn.add_theme_color_override("font_color",         Color(0.55, 0.80, 1.0))
	_map_btn.add_theme_color_override("font_hover_color",   Color(0.75, 0.92, 1.0))
	_map_btn.add_theme_color_override("font_pressed_color", Color(0.30, 0.55, 0.80))
	_map_btn.add_theme_color_override("font_focus_color",   Color(0.55, 0.80, 1.0))
	_map_btn.add_theme_stylebox_override("normal",  _make_style(Color(0.04, 0.08, 0.18, 0.90), Color(0.25, 0.50, 0.85, 0.70)))
	_map_btn.add_theme_stylebox_override("hover",   _make_style(Color(0.06, 0.14, 0.28, 0.95), Color(0.45, 0.70, 1.00, 1.00)))
	_map_btn.add_theme_stylebox_override("pressed", _make_style(Color(0.02, 0.05, 0.12, 0.95), Color(0.25, 0.50, 0.85, 0.40)))
	_map_btn.add_theme_stylebox_override("focus",   _make_style(Color(0.04, 0.08, 0.18, 0.90), Color(0.25, 0.50, 0.85, 0.70)))
	_map_btn.custom_minimum_size = Vector2(260.0, 44.0)
	_map_btn.anchor_left   = 0.5
	_map_btn.anchor_right  = 0.5
	_map_btn.anchor_top    = 0.5
	_map_btn.anchor_bottom = 0.5
	_map_btn.offset_left   = -130.0
	_map_btn.offset_right  =  130.0
	_map_btn.offset_top    = -32.0
	_map_btn.offset_bottom =  12.0
	_map_btn.pressed.connect(_on_quit_to_map)
	add_child(_map_btn)

	# Quit to desktop button
	_quit_btn = Button.new()
	_quit_btn.text = "QUIT TO DESKTOP"
	_quit_btn.add_theme_font_override("font", FONT)
	_quit_btn.add_theme_font_size_override("font_size", 10)
	_quit_btn.add_theme_color_override("font_color",         Color(1.0, 0.55, 0.55))
	_quit_btn.add_theme_color_override("font_hover_color",   Color(1.0, 0.75, 0.75))
	_quit_btn.add_theme_color_override("font_pressed_color", Color(0.80, 0.30, 0.30))
	_quit_btn.add_theme_color_override("font_focus_color",   Color(1.0, 0.55, 0.55))
	_quit_btn.add_theme_stylebox_override("normal",  _make_style(Color(0.12, 0.04, 0.04, 0.90), Color(0.85, 0.20, 0.20, 0.70)))
	_quit_btn.add_theme_stylebox_override("hover",   _make_style(Color(0.22, 0.06, 0.06, 0.95), Color(1.00, 0.30, 0.30, 1.00)))
	_quit_btn.add_theme_stylebox_override("pressed", _make_style(Color(0.07, 0.02, 0.02, 0.95), Color(0.85, 0.20, 0.20, 0.40)))
	_quit_btn.add_theme_stylebox_override("focus",   _make_style(Color(0.12, 0.04, 0.04, 0.90), Color(0.85, 0.20, 0.20, 0.70)))
	_quit_btn.custom_minimum_size = Vector2(220.0, 44.0)
	_quit_btn.anchor_left   = 0.5
	_quit_btn.anchor_right  = 0.5
	_quit_btn.anchor_top    = 0.5
	_quit_btn.anchor_bottom = 0.5
	_quit_btn.offset_left   = -110.0
	_quit_btn.offset_right  =  110.0
	_quit_btn.offset_top    =  22.0
	_quit_btn.offset_bottom =  66.0
	_quit_btn.pressed.connect(_on_quit)
	add_child(_quit_btn)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		get_tree().paused = !get_tree().paused
		visible = get_tree().paused

func _on_quit_to_map() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/map_selection.tscn")

func _on_quit() -> void:
	get_tree().paused = false
	get_tree().quit()
