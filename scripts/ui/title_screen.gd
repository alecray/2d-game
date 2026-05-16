extends Node2D

const FONT          := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const BG_TEXTURE    := preload("res://assets/sprites/backgrounds/background-1.png")
const LOGO_TEXTURE  := preload("res://assets/sprites/alec-ray-logo.png")
const SpiderScene   := preload("res://prefabs/enemies/spider.tscn")
const BlobScene     := preload("res://prefabs/enemies/blob.tscn")
const WaterShader   := preload("res://assets/shaders/water_text.gdshader")

const SCREEN_W    := 1280.0
const SCREEN_H    := 720.0
const GROUND_Y    := 545.0
const CRITTER_SPEED := 38.0

var _critters: Array = []
var _navigating := false

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.53, 0.81, 0.92))
	_build_world()
	_spawn_critters()
	_build_logo_watermark()
	_build_ui()
	_fade_in()

func _process(delta: float) -> void:
	for c in _critters:
		var node := c["node"] as Node2D
		node.position.x += c["dir"] * CRITTER_SPEED * c["speed"] * delta
		if node.position.x > SCREEN_W + 80.0:
			node.position.x = -80.0
		elif node.position.x < -80.0:
			node.position.x = SCREEN_W + 80.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_go_to_map_select()

# ── World ────────────────────────────────────────────────────────────────────

func _build_world() -> void:
	var tex_size := BG_TEXTURE.get_size()
	var ground := Sprite2D.new()
	ground.texture = BG_TEXTURE
	ground.position = Vector2(SCREEN_W * 0.5, GROUND_Y + 95.0)
	ground.scale = Vector2(SCREEN_W / tex_size.x, 210.0 / tex_size.y)
	add_child(ground)

	# Horizon shadow strip
	var shadow := ColorRect.new()
	shadow.color = Color(0.0, 0.0, 0.0, 0.20)
	shadow.size = Vector2(SCREEN_W, 6.0)
	shadow.position = Vector2(0.0, GROUND_Y - 3.0)
	add_child(shadow)

func _spawn_critters() -> void:
	var xs: Array = []
	for i in 6:
		xs.append(randf_range(60.0, SCREEN_W - 60.0))
	xs.sort()
	var scenes := [SpiderScene, BlobScene, SpiderScene, BlobScene, SpiderScene, BlobScene]
	for i in 6:
		var critter: Node2D = scenes[i].instantiate()
		critter.set_physics_process(false)
		critter.set_process(false)
		critter.position = Vector2(xs[i], GROUND_Y + randf_range(4.0, 50.0))
		critter.scale = Vector2(3.0, 3.0)
		add_child(critter)
		var sprite := critter.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		var dir := 1.0 if randf() < 0.5 else -1.0
		if sprite:
			sprite.play("Walk")
			sprite.flip_h = dir < 0
		_critters.append({"node": critter, "dir": dir, "speed": randf_range(0.65, 1.35)})

# ── Logo watermark (sits between world and UI) ───────────────────────────────

func _build_logo_watermark() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var logo := TextureRect.new()
	logo.texture = LOGO_TEXTURE
	var logo_size := LOGO_TEXTURE.get_size()
	logo.position = Vector2(
		(SCREEN_W - logo_size.x) * 0.5,
		(SCREEN_H - logo_size.y) * 0.5 - 20.0
	)
	# Tint toward sky-blue so the white bg blends in; dark outlines become faint shadows
	logo.modulate = Color(0.55, 0.76, 0.90, 0.14)
	layer.add_child(logo)

# ── UI ───────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_add_title(layer)
	_add_subtitle(layer)
	_add_play_button(layer)
	_add_hint(layer)
	_add_credit(layer)

func _add_title(parent: Node) -> void:
	var lbl := Label.new()
	lbl.text = ProjectSettings.get_setting("application/config/name", "2D GAME").to_upper()
	lbl.add_theme_font_override("font", FONT)
	lbl.add_theme_font_size_override("font_size", 52)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.50))
	lbl.add_theme_constant_override("shadow_offset_x", 4)
	lbl.add_theme_constant_override("shadow_offset_y", 4)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(0.0, 155.0)
	lbl.size = Vector2(SCREEN_W, 80.0)
	var mat := ShaderMaterial.new()
	mat.shader = WaterShader
	mat.set_shader_parameter("wave_amount", 0.13)
	lbl.material = mat
	parent.add_child(lbl)

	# Gentle vertical bob
	var tween := lbl.create_tween().set_loops()
	tween.tween_property(lbl, "position:y", 148.0, 1.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(lbl, "position:y", 155.0, 1.6).set_trans(Tween.TRANS_SINE)

func _add_subtitle(parent: Node) -> void:
	var lbl := Label.new()
	lbl.text = "a top-down survivor"
	lbl.add_theme_font_override("font", FONT)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0, 0.72))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(0.0, 256.0)
	lbl.size = Vector2(SCREEN_W, 24.0)
	parent.add_child(lbl)

func _add_play_button(parent: Node) -> void:
	var btn_w := 280.0
	var btn_h := 64.0

	var sn := StyleBoxFlat.new()
	sn.bg_color = Color(0.07, 0.07, 0.13, 0.88)
	sn.set_border_width_all(2)
	sn.border_color = Color(1.0, 0.85, 0.15, 0.60)
	sn.set_content_margin_all(10.0)

	var sh := StyleBoxFlat.new()
	sh.bg_color = Color(0.13, 0.13, 0.22, 0.95)
	sh.set_border_width_all(3)
	sh.border_color = Color(1.0, 0.90, 0.25, 1.0)
	sh.set_content_margin_all(10.0)

	var sp := StyleBoxFlat.new()
	sp.bg_color = Color(0.04, 0.04, 0.09, 0.95)
	sp.set_border_width_all(2)
	sp.border_color = Color(1.0, 0.85, 0.15, 0.35)
	sp.set_content_margin_all(10.0)

	var btn := Button.new()
	btn.text = "PLAY"
	btn.add_theme_font_override("font", FONT)
	btn.add_theme_font_size_override("font_size", 28)
	btn.add_theme_color_override("font_color",         Color(1.00, 0.85, 0.10))
	btn.add_theme_color_override("font_hover_color",   Color(1.00, 1.00, 0.35))
	btn.add_theme_color_override("font_pressed_color", Color(0.85, 0.68, 0.05))
	btn.add_theme_color_override("font_focus_color",   Color(1.00, 0.85, 0.10))
	btn.add_theme_stylebox_override("normal",  sn)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sp)
	btn.add_theme_stylebox_override("focus",   sn)
	btn.custom_minimum_size = Vector2(btn_w, btn_h)
	btn.size = Vector2(btn_w, btn_h)
	btn.position = Vector2((SCREEN_W - btn_w) / 2.0, 325.0)
	btn.pressed.connect(_go_to_map_select)
	parent.add_child(btn)
	btn.size = Vector2(btn_w, btn_h)  # reaffirm after add_child layout pass

	# Golden pulse
	var tween := btn.create_tween().set_loops()
	tween.tween_property(btn, "modulate", Color(1.18, 1.06, 0.88, 1.0), 0.95).set_trans(Tween.TRANS_SINE)
	tween.tween_property(btn, "modulate", Color.WHITE, 0.95).set_trans(Tween.TRANS_SINE)

func _add_hint(parent: Node) -> void:
	var lbl := Label.new()
	lbl.text = "or press ENTER"
	lbl.add_theme_font_override("font", FONT)
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.38))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(0.0, 407.0)
	lbl.size = Vector2(SCREEN_W, 20.0)
	parent.add_child(lbl)

func _add_credit(parent: Node) -> void:
	var credit := Label.new()
	credit.text = "An Alec Ray Game"
	credit.add_theme_font_override("font", FONT)
	credit.add_theme_font_size_override("font_size", 8)
	credit.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.32))
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
	tween.tween_property(black, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(fade_layer.queue_free)

func _go_to_map_select() -> void:
	if _navigating:
		return
	_navigating = true
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
