extends Button

signal map_selected(map_data: Dictionary)

var map_data: Dictionary = {}

@onready var _texture_rect: TextureRect = $VBox/TextureRect
@onready var _label_name: Label = $VBox/Label_Name

func _ready() -> void:
	pressed.connect(_on_pressed)

func setup(data: Dictionary) -> void:
	map_data = data
	_label_name.text = data.get("name", "Unknown")
	var tex = load(data.get("texture", ""))
	if tex:
		_texture_rect.texture = tex
	if data.get("locked", false):
		_apply_locked_state()

func _apply_locked_state() -> void:
	disabled = true
	modulate = Color(0.55, 0.55, 0.55, 1.0)
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var lock_lbl := Label.new()
	lock_lbl.text = "LOCKED"
	lock_lbl.add_theme_font_override("font", preload("res://assets/fonts/PressStart2P-Regular.ttf"))
	lock_lbl.add_theme_font_size_override("font_size", 10)
	lock_lbl.add_theme_color_override("font_color", Color(0.9, 0.15, 0.15))
	lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lock_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(lock_lbl)

func _on_pressed() -> void:
	map_selected.emit(map_data)
