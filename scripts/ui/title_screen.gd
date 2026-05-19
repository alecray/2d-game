extends Node2D

var _selected    := -1
var _navigating  := false
var _btns: Array  = []
var _reset_armed := false

@onready var _title_label  : Label      = $UILayer/TitleLabel
@onready var _btn_play     : Button     = $UILayer/BtnPlay
@onready var _btn_quit     : Button     = $UILayer/BtnQuit
@onready var _ver_label    : Label      = $UILayer/VersionLabel
@onready var _reset_btn    : Button     = $UILayer/DevResetBtn
@onready var _gun          : Sprite2D   = $GunLayer/Gun
@onready var _atmo_layer   : CanvasLayer = $AtmosphereLayer

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color.BLACK)
	_setup_ui()
	_start_gun_float()
	_spawn_title_particles()
	_fade_in()

func _setup_ui() -> void:
	_title_label.text = ProjectSettings.get_setting("application/config/name", "2D GAME").to_upper()

	var ver_str: String = ProjectSettings.get_setting("application/config/version", "")
	if not ver_str.is_empty():
		_ver_label.text = "v" + ver_str
	else:
		_ver_label.visible = false

	_btns = [_btn_play, _btn_quit]
	for i in _btns.size():
		var idx := i
		var btn : Button = _btns[i]
		btn.mouse_entered.connect(func():
			if not _navigating:
				_selected = idx
				_refresh_buttons()
		)
		btn.mouse_exited.connect(func():
			if not _navigating and _selected == idx:
				_selected = -1
				_refresh_buttons()
		)
		btn.pressed.connect(func():
			if not _navigating:
				_selected = idx
				_animate_click(btn, idx)
		)
	_refresh_buttons()

	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0)
	for sn in ["normal", "hover", "pressed", "focus"]:
		_reset_btn.add_theme_stylebox_override(sn, flat)
	_reset_btn.pressed.connect(_on_dev_reset_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if _navigating:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_UP, KEY_W:
				_move_selection(-1)
				get_viewport().set_input_as_handled()
			KEY_DOWN, KEY_S:
				_move_selection(1)
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_confirm()
				get_viewport().set_input_as_handled()

func _move_selection(dir: int) -> void:
	if _selected < 0:
		_selected = 0 if dir > 0 else _btns.size() - 1
	else:
		_selected = (_selected + dir + _btns.size()) % _btns.size()
	_refresh_buttons()

func _refresh_buttons() -> void:
	for i in _btns.size():
		_style_btn(_btns[i], i == _selected)

func _confirm() -> void:
	var idx := maxi(_selected, 0)
	_animate_click(_btns[idx], idx)

func _animate_click(btn: Button, idx: int) -> void:
	if _navigating:
		return
	_navigating = true
	_selected = idx
	_refresh_buttons()

	btn.pivot_offset = btn.size * 0.5

	var tw := btn.create_tween()
	tw.tween_property(btn, "scale", Vector2(1.10, 0.82), 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.set_parallel(true)
	tw.tween_property(btn, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.07)
	tw.set_parallel(false)
	tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	tw.set_parallel(true)
	tw.tween_property(btn, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.14)
	tw.set_parallel(false)
	tw.tween_callback(func():
		if idx == 0:
			_do_play()
		else:
			get_tree().quit()
	)

func _style_btn(btn: Button, active: bool) -> void:
	var s := StyleBoxFlat.new()
	if active:
		s.bg_color = Color(0.07, 0.10, 0.20, 0.88)
		s.border_width_left   = 4
		s.border_width_right  = 0
		s.border_width_top    = 0
		s.border_width_bottom = 0
		s.border_color = Color(0.30, 0.55, 1.0, 1.0)
		s.content_margin_left   = 26.0
		s.content_margin_top    = 14.0
		s.content_margin_right  = 12.0
		s.content_margin_bottom = 14.0
	else:
		s.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		s.border_width_left = 0
		s.content_margin_left   = 30.0
		s.content_margin_top    = 14.0
		s.content_margin_right  = 12.0
		s.content_margin_bottom = 14.0

	for style_name in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(style_name, s)

	var col := Color(1.0, 0.92, 0.15) if active else Color(0.50, 0.53, 0.62)
	for col_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(col_name, col)

func _start_gun_float() -> void:
	var base_y := _gun.position.y
	var tw := _gun.create_tween().set_loops()
	tw.tween_property(_gun, "position:y", base_y - 12.0, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_gun, "position:y", base_y + 12.0, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _spawn_title_particles() -> void:
	var p := CPUParticles2D.new()
	p.amount = 55
	p.lifetime = 10.0
	p.preprocess = 10.0
	p.randomness = 0.5

	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(640, 360)
	p.position = Vector2(640, 360)

	p.direction = Vector2(1.0, 0.0)
	p.spread = 22.0
	p.gravity = Vector2(0.0, 0.0)
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 28.0

	p.scale_amount_min = 3.5
	p.scale_amount_max = 10.0
	p.scale_amount_curve = _make_particle_scale_curve()

	var init_grad := Gradient.new()
	init_grad.colors = PackedColorArray([
		Color(0.70, 0.85, 1.00, 1.0),
		Color(0.55, 0.72, 1.00, 1.0),
		Color(0.90, 0.96, 1.00, 1.0),
		Color(0.65, 0.80, 1.00, 1.0),
	])
	p.color_initial_ramp = init_grad

	var life_grad := Gradient.new()
	life_grad.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.0),
		Color(1.0, 1.0, 1.0, 0.45),
		Color(1.0, 1.0, 1.0, 0.45),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	life_grad.offsets = PackedFloat32Array([0.0, 0.12, 0.78, 1.0])
	p.color_ramp = life_grad

	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat

	p.z_index = 3
	_atmo_layer.add_child(p)

func _make_particle_scale_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.0))
	c.add_point(Vector2(0.08, 1.0))
	c.add_point(Vector2(0.88, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	return c

func _fade_in() -> void:
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 99
	add_child(fade_layer)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(black)
	var tween := black.create_tween()
	tween.tween_property(black, "modulate:a", 0.0, 1.6).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(fade_layer.queue_free)

func _do_play() -> void:
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 99
	get_tree().root.add_child(fade_layer)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.modulate.a = 0.0
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(black)
	var tween := black.create_tween()
	tween.tween_property(black, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/map_selection.tscn"))
	tween.tween_property(black, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(fade_layer.queue_free)

func _on_dev_reset_pressed() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_btn.text = "CONFIRM RESET?"
		_reset_btn.add_theme_color_override("font_color",       Color(1.0, 0.25, 0.25, 0.90))
		_reset_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.35, 0.35, 1.00))
		get_tree().create_timer(3.0).timeout.connect(_disarm_reset, CONNECT_ONE_SHOT)
	else:
		get_node("/root/PlayerStats").reset()
		_reset_armed = false
		_reset_btn.text = "SAVE CLEARED"
		_reset_btn.add_theme_color_override("font_color",       Color(0.35, 1.0, 0.55, 0.80))
		_reset_btn.add_theme_color_override("font_hover_color", Color(0.35, 1.0, 0.55, 0.80))
		get_tree().create_timer(1.8).timeout.connect(_disarm_reset, CONNECT_ONE_SHOT)

func _disarm_reset() -> void:
	_reset_armed = false
	_reset_btn.text = "[ DEV ] RESET SAVE"
	_reset_btn.add_theme_color_override("font_color",       Color(0.85, 0.50, 0.15, 0.70))
	_reset_btn.add_theme_color_override("font_hover_color", Color(1.00, 0.65, 0.20, 1.00))
