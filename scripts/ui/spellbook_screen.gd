extends CanvasLayer

const FONT           := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const SPELLBOOK_TEX  := preload("res://assets/sprites/spellbook.png")

const SPELLS := [
	{
		"id":   "magic_wave",
		"name": "MAGIC WAVE",
		"desc": "An expanding ring of\nenergy that destroys\nevery enemy it passes",
		"cost": 50,
	},
	{
		"id":   "frost_nova",
		"name": "SPIDER ALLY",
		"desc": "Summons a spider ally\nthat hunts enemies\nfor 60 seconds",
		"cost": 40,
		"source": "Dropped by Spiders",
	},
	{
		"id":   "poison_cloud",
		"name": "POISON CLOUD",
		"desc": "Releases a toxic mist\nthat lingers and damages\nenemies over time",
		"cost": 45,
		"source": "Dropped by Blobs",
	},
	{
		"id":   "shatter",
		"name": "SHATTER",
		"desc": "Freezes all nearby\nenemies, then explodes\nfor massive damage",
		"cost": 60,
		"source": "Dropped by Triangles",
	},
]

var _player: Node

func setup(player: Node) -> void:
	_player = player

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_build()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close()

func _build() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.80)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	# Title row
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 10)
	vbox.add_child(title_row)

	var icon := TextureRect.new()
	icon.texture = SPELLBOOK_TEX
	icon.custom_minimum_size = Vector2(28, 28)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	title_row.add_child(icon)

	var title := Label.new()
	title.text = "SPELLBOOK"
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.85, 0.65, 1.0))
	title_row.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "select your right-click spell"
	subtitle.add_theme_font_override("font", FONT)
	subtitle.add_theme_font_size_override("font_size", 7)
	subtitle.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	# Scrollable card row — scrollbar appears automatically when cards overflow
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_DISABLED
	# Wide enough for 4 cards without scrolling; a 5th triggers the scrollbar
	scroll.custom_minimum_size = Vector2(740, 210)
	vbox.add_child(scroll)

	var card_row := HBoxContainer.new()
	card_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	card_row.add_theme_constant_override("separation", 16)
	scroll.add_child(card_row)

	var stats := get_node("/root/PlayerStats")
	for spell in SPELLS:
		var unlocked: bool = stats.has_spell(spell.id)
		card_row.add_child(_make_card(spell, unlocked))

	var close_btn := Button.new()
	close_btn.text = "CLOSE  [ESC]"
	close_btn.add_theme_font_override("font", FONT)
	close_btn.add_theme_font_size_override("font_size", 7)
	close_btn.pressed.connect(_close)
	var close_row := HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_CENTER
	close_row.add_child(close_btn)
	vbox.add_child(close_row)

func _make_card(spell: Dictionary, unlocked: bool) -> Control:
	var is_active: bool = unlocked and _player != null and _player.get("active_spell") == spell.id

	if not unlocked:
		return _make_locked_card(spell)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(170, 195)

	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.18, 0.10, 0.28) if is_active else Color(0.10, 0.07, 0.16)
	style.border_color = Color(0.75, 0.45, 1.0)  if is_active else Color(0.30, 0.20, 0.45)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style)

	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 10)
	btn.add_child(inner)

	var name_lbl := Label.new()
	name_lbl.text = spell.name
	name_lbl.add_theme_font_override("font", FONT)
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4) if is_active else Color.WHITE)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = spell.desc
	desc_lbl.add_theme_font_override("font", FONT)
	desc_lbl.add_theme_font_size_override("font_size", 6)
	desc_lbl.add_theme_color_override("font_color", Color(0.72, 0.72, 0.82))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.custom_minimum_size = Vector2(140, 0)
	inner.add_child(desc_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = str(spell.cost) + " MANA"
	cost_lbl.add_theme_font_override("font", FONT)
	cost_lbl.add_theme_font_size_override("font_size", 6)
	cost_lbl.add_theme_color_override("font_color", Color(0.45, 0.75, 1.0))
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(cost_lbl)

	if is_active:
		var eq_lbl := Label.new()
		eq_lbl.text = "[ EQUIPPED ]"
		eq_lbl.add_theme_font_override("font", FONT)
		eq_lbl.add_theme_font_size_override("font_size", 6)
		eq_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.55))
		eq_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(eq_lbl)

	btn.pressed.connect(func(): _equip(spell))
	return btn

func _make_locked_card(spell: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(170, 195)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.10)
	style.border_color = Color(0.20, 0.15, 0.28)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)

	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 10)
	panel.add_child(inner)

	var lock_lbl := Label.new()
	lock_lbl.text = "???"
	lock_lbl.add_theme_font_override("font", FONT)
	lock_lbl.add_theme_font_size_override("font_size", 14)
	lock_lbl.add_theme_color_override("font_color", Color(0.28, 0.22, 0.38))
	lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(lock_lbl)

	var locked_lbl := Label.new()
	locked_lbl.text = "LOCKED"
	locked_lbl.add_theme_font_override("font", FONT)
	locked_lbl.add_theme_font_size_override("font_size", 7)
	locked_lbl.add_theme_color_override("font_color", Color(0.40, 0.32, 0.52))
	locked_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(locked_lbl)

	if spell.has("source"):
		var src_lbl := Label.new()
		src_lbl.text = spell.source
		src_lbl.add_theme_font_override("font", FONT)
		src_lbl.add_theme_font_size_override("font_size", 5)
		src_lbl.add_theme_color_override("font_color", Color(0.38, 0.32, 0.48))
		src_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		src_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		src_lbl.custom_minimum_size = Vector2(140, 0)
		inner.add_child(src_lbl)

	return panel

func _equip(spell: Dictionary) -> void:
	if _player:
		_player.active_spell = spell.id
	_close()

func _close() -> void:
	get_tree().paused = false
	queue_free()
