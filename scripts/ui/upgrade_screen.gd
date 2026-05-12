extends CanvasLayer

const FONT = preload("res://assets/fonts/PressStart2P-Regular.ttf")

const UPGRADES := [
	{"id": "haste",       "name": "HASTE",       "desc": "+40 move speed"},
	{"id": "rapid_fire",  "name": "RAPID FIRE",  "desc": "Shoot 25% faster"},
	{"id": "marksman",    "name": "MARKSMAN",    "desc": "+8 bullet damage"},
	{"id": "toughness",   "name": "TOUGHNESS",   "desc": "+30 max HP\n& restore 30"},
	{"id": "ammo_cache",  "name": "AMMO CACHE",  "desc": "+150 max ammo\n& refill"},
	{"id": "vital_surge", "name": "VITAL SURGE", "desc": "Fully restore HP"},
	{"id": "volatile",    "name": "VOLATILE",    "desc": "Bullets explode\non impact"},
	{"id": "seeker",      "name": "SEEKER",      "desc": "Bullets home\ntoward enemies"},
	{"id": "penetrator",  "name": "PENETRATOR",  "desc": "Bullets pierce\nthrough enemies"},
	{"id": "payload",     "name": "PAYLOAD",     "desc": "Fire 3 bullets\nin a spread"},
	{"id": "velocity",    "name": "VELOCITY",    "desc": "+60% bullet\nspeed"},
]

func _ready() -> void:
	add_to_group("upgrade_screen")
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_build_ui()

func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.75)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "CHOOSE AN UPGRADE"
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(hbox)

	var pool := UPGRADES.duplicate()
	pool.shuffle()
	for upgrade in pool.slice(0, 3):
		hbox.add_child(_make_card(upgrade))

func _make_card(upgrade: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(165, 145)
	btn.process_mode = Node.PROCESS_MODE_ALWAYS

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.08, 0.14)
	normal.set_border_width_all(2)
	normal.border_color = Color(0.35, 0.35, 0.6)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.13, 0.13, 0.22)
	hover.border_color = Color(1.0, 0.85, 0.1)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)

	var pressed_style := normal.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(0.18, 0.18, 0.3)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	var name_lbl := Label.new()
	name_lbl.text = upgrade.name
	name_lbl.add_theme_font_override("font", FONT)
	name_lbl.add_theme_font_size_override("font_size", 8)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	name_lbl.offset_top = 16
	name_lbl.offset_bottom = 40
	btn.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = upgrade.desc
	desc_lbl.add_theme_font_override("font", FONT)
	desc_lbl.add_theme_font_size_override("font_size", 6)
	desc_lbl.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	desc_lbl.offset_top = 56
	desc_lbl.offset_bottom = 135
	desc_lbl.offset_left = 8
	desc_lbl.offset_right = -8
	btn.add_child(desc_lbl)

	btn.pressed.connect(func(): _on_chosen(upgrade))
	return btn

func _on_chosen(upgrade: Dictionary) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		_apply(player, upgrade)
	get_tree().paused = false
	queue_free()

func _apply(player: Node, upgrade: Dictionary) -> void:
	match upgrade.id:
		"haste":
			player.SPEED += 40.0
		"rapid_fire":
			player.FIRE_RATE = maxf(0.05, player.FIRE_RATE * 0.75)
		"marksman":
			player.bullet_damage += 8
		"toughness":
			player.MAX_HEALTH += 30
			player.health = min(player.health + 30, player.MAX_HEALTH)
		"ammo_cache":
			player.MAX_AMMO += 150
			player.ammo = min(player.ammo + 150, player.MAX_AMMO)
		"vital_surge":
			player.health = player.MAX_HEALTH
		"volatile":
			player.bullet_explosive = true
		"seeker":
			player.bullet_homing = true
		"penetrator":
			player.bullet_piercing = true
		"payload":
			player.bullet_count = 3
		"velocity":
			player.bullet_speed_multiplier = minf(player.bullet_speed_multiplier * 1.6, 3.0)
