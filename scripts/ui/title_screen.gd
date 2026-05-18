extends Node2D

const FONT        := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const GUN_TEXTURE := preload("res://assets/sprites/weapons/gun5.png")

const SCREEN_W := 1280.0
const SCREEN_H := 720.0

# Gun display constants
const GUN_TARGET_W   := 720.0
const GUN_CENTER_X   := 870.0
const GUN_CENTER_Y   := 360.0
const GUN_ROTATION   := -32.0

# Menu
const MENU_LABELS := ["PLAY", "QUIT"]
const MENU_START_Y := 250.0
const MENU_ITEM_H  := 68.0

var _selected    := -1
var _navigating  := false
var _btns: Array  = []
var _reset_armed := false
var _reset_btn: Button = null

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color.BLACK)
	_build_atmosphere()
	_build_gun()
	_build_ui()
	_fade_in()

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
		_selected = 0 if dir > 0 else MENU_LABELS.size() - 1
	else:
		_selected = (_selected + dir + MENU_LABELS.size()) % MENU_LABELS.size()
	_refresh_buttons()

func _refresh_buttons() -> void:
	for i in _btns.size():
		_style_btn(_btns[i], i == _selected)

func _confirm() -> void:
	var idx := maxi(_selected, 0)
	_animate_click(_btns[idx], idx)

# ── Atmosphere ────────────────────────────────────────────────────────────────

func _build_atmosphere() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)

	# Wide diffuse cone
	var cone := Polygon2D.new()
	cone.polygon = PackedVector2Array([
		Vector2(GUN_CENTER_X - 90, -10),
		Vector2(GUN_CENTER_X + 90, -10),
		Vector2(GUN_CENTER_X + 420, SCREEN_H + 10),
		Vector2(GUN_CENTER_X - 420, SCREEN_H + 10),
	])
	cone.color = Color(1.0, 1.0, 1.0, 0.032)
	layer.add_child(cone)

	# Tight bright core
	var core := Polygon2D.new()
	core.polygon = PackedVector2Array([
		Vector2(GUN_CENTER_X - 30, -10),
		Vector2(GUN_CENTER_X + 30, -10),
		Vector2(GUN_CENTER_X + 120, SCREEN_H + 10),
		Vector2(GUN_CENTER_X - 120, SCREEN_H + 10),
	])
	core.color = Color(1.0, 1.0, 1.0, 0.028)
	layer.add_child(core)

# ── Gun ───────────────────────────────────────────────────────────────────────

func _build_gun() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)

	# Diffuse glow halo behind gun
	var halo := ColorRect.new()
	halo.color = Color(0.18, 0.38, 1.0, 0.09)
	halo.size = Vector2(660, 420)
	halo.position = Vector2(GUN_CENTER_X - 330, GUN_CENTER_Y - 210)
	layer.add_child(halo)

	# Gun sprite — scaled up with nearest-neighbour for crisp pixels
	var sf := GUN_TARGET_W / GUN_TEXTURE.get_size().x
	var gun := Sprite2D.new()
	gun.texture = GUN_TEXTURE
	gun.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	gun.scale = Vector2(sf, sf)
	gun.rotation_degrees = GUN_ROTATION
	gun.position = Vector2(GUN_CENTER_X, GUN_CENTER_Y)
	gun.modulate = Color(0.90, 0.94, 1.0)
	layer.add_child(gun)

	# Floor glow — subtle surface reflection
	var floor_glow := ColorRect.new()
	floor_glow.color = Color(0.12, 0.25, 0.70, 0.14)
	floor_glow.size = Vector2(720, 90)
	floor_glow.position = Vector2(GUN_CENTER_X - 360, GUN_CENTER_Y + 210)
	layer.add_child(floor_glow)

# ── UI ────────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_add_title(layer)
	_add_menu(layer)
	_add_credit(layer)
	_add_dev_reset(layer)

func _add_title(parent: Node) -> void:
	var lbl := Label.new()
	lbl.text = ProjectSettings.get_setting("application/config/name", "2D GAME").to_upper()
	lbl.add_theme_font_override("font", FONT)
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_shadow_color", Color(0.25, 0.50, 1.0, 0.65))
	lbl.add_theme_constant_override("shadow_offset_x", 0)
	lbl.add_theme_constant_override("shadow_offset_y", 4)
	lbl.position = Vector2(60.0, 90.0)
	parent.add_child(lbl)

	var sub := Label.new()
	sub.text = "a top-down survivor"
	sub.add_theme_font_override("font", FONT)
	sub.add_theme_font_size_override("font_size", 8)
	sub.add_theme_color_override("font_color", Color(0.55, 0.65, 0.85, 0.60))
	sub.position = Vector2(62.0, 130.0)
	parent.add_child(sub)

func _add_menu(parent: Node) -> void:
	for i in MENU_LABELS.size():
		var btn := _make_btn(MENU_LABELS[i], i)
		btn.position = Vector2(0.0, MENU_START_Y + i * MENU_ITEM_H)
		parent.add_child(btn)
		_btns.append(btn)
	_refresh_buttons()

func _make_btn(label_text: String, idx: int) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.add_theme_font_override("font", FONT)
	btn.add_theme_font_size_override("font_size", 14)
	btn.custom_minimum_size = Vector2(340.0, 56.0)
	btn.size = Vector2(340.0, 56.0)
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
	return btn

func _animate_click(btn: Button, idx: int) -> void:
	if _navigating:
		return
	_navigating = true
	_selected = idx
	_refresh_buttons()

	btn.pivot_offset = btn.size * 0.5

	var tw := btn.create_tween()
	# Squish down
	tw.tween_property(btn, "scale", Vector2(1.10, 0.82), 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.set_parallel(true)
	tw.tween_property(btn, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.07)
	tw.set_parallel(false)
	# Spring back
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

func _add_credit(parent: Node) -> void:
	var credit := Label.new()
	credit.text = "An Alec Ray Game"
	credit.add_theme_font_override("font", FONT)
	credit.add_theme_font_size_override("font_size", 8)
	credit.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.28))
	credit.position = Vector2(18.0, SCREEN_H - 22.0)
	parent.add_child(credit)

	var ver_str: String = ProjectSettings.get_setting("application/config/version", "")
	if not ver_str.is_empty():
		var ver := Label.new()
		ver.text = "v" + ver_str
		ver.add_theme_font_override("font", FONT)
		ver.add_theme_font_size_override("font_size", 7)
		ver.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.28))
		ver.position = Vector2(SCREEN_W - 110.0, SCREEN_H - 22.0)
		parent.add_child(ver)

# ── Transitions ───────────────────────────────────────────────────────────────

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

func _do_quit() -> void:
	get_tree().quit()

func _add_dev_reset(parent: Node) -> void:
	_reset_btn = Button.new()
	_reset_btn.text = "[ DEV ] RESET SAVE"
	_reset_btn.add_theme_font_override("font", FONT)
	_reset_btn.add_theme_font_size_override("font_size", 6)
	_reset_btn.add_theme_color_override("font_color",       Color(0.85, 0.50, 0.15, 0.70))
	_reset_btn.add_theme_color_override("font_hover_color", Color(1.00, 0.65, 0.20, 1.00))
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0)
	for sn in ["normal", "hover", "pressed", "focus"]:
		_reset_btn.add_theme_stylebox_override(sn, flat)
	_reset_btn.position = Vector2(SCREEN_W - 220.0, SCREEN_H - 24.0)
	_reset_btn.pressed.connect(_on_dev_reset_pressed)
	parent.add_child(_reset_btn)

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
