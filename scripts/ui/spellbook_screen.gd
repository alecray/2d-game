extends CanvasLayer

const FONT           := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const SPELLBOOK_TEX  := preload("res://assets/sprites/spellbook.png")

## All spells in the game. Only those in PlayerStats.unlocked_spells are shown.
const SPELLS := [
	{
		"id":   "magic_wave",
		"name": "MAGIC WAVE",
		"desc": "An expanding ring of\nenergy that destroys\nevery enemy it passes",
		"cost": 50,
	},
	{
		"id":   "frost_nova",
		"name": "FROST NOVA",
		"desc": "A burst of ice that\nfreezes nearby enemies\nin place",
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
		"id":   "lightning_bolt",
		"name": "LIGHTNING BOLT",
		"desc": "A fast targeted strike\nthat chains between\nnearby enemies",
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

	var card_row := HBoxContainer.new()
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", 16)
	vbox.add_child(card_row)

	var stats := get_node("/root/PlayerStats")
	var known := SPELLS.filter(func(s): return stats.has_spell(s.id))
	for spell in known:
		card_row.add_child(_make_card(spell))

	var close_btn := Button.new()
	close_btn.text = "CLOSE  [ESC]"
	close_btn.add_theme_font_override("font", FONT)
	close_btn.add_theme_font_size_override("font_size", 7)
	close_btn.pressed.connect(_close)
	var close_row := HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_CENTER
	close_row.add_child(close_btn)
	vbox.add_child(close_row)

func _make_card(spell: Dictionary) -> Button:
	var is_active: bool = _player != null and _player.get("active_spell") == spell.id

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(170, 180)
	if is_active:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.18, 0.10, 0.28)
		style.border_color = Color(0.75, 0.45, 1.0)
		style.set_border_width_all(2)
		style.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	btn.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = spell.name
	name_lbl.add_theme_font_override("font", FONT)
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4) if is_active else Color.WHITE)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = spell.desc
	desc_lbl.add_theme_font_override("font", FONT)
	desc_lbl.add_theme_font_size_override("font_size", 6)
	desc_lbl.add_theme_color_override("font_color", Color(0.72, 0.72, 0.82))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.custom_minimum_size = Vector2(140, 0)
	vbox.add_child(desc_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = str(spell.cost) + " MANA"
	cost_lbl.add_theme_font_override("font", FONT)
	cost_lbl.add_theme_font_size_override("font_size", 6)
	cost_lbl.add_theme_color_override("font_color", Color(0.45, 0.75, 1.0))
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(cost_lbl)

	if is_active:
		var eq_lbl := Label.new()
		eq_lbl.text = "[ EQUIPPED ]"
		eq_lbl.add_theme_font_override("font", FONT)
		eq_lbl.add_theme_font_size_override("font_size", 6)
		eq_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.55))
		eq_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(eq_lbl)

	btn.pressed.connect(func(): _equip(spell))
	return btn

func _equip(spell: Dictionary) -> void:
	if _player:
		_player.active_spell = spell.id
	_close()

func _close() -> void:
	get_tree().paused = false
	queue_free()
