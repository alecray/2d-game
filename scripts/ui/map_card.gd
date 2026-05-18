extends Button

signal map_selected(map_data: Dictionary)
signal unlock_finished

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

func animate_unlock() -> void:
	disabled = true
	modulate = Color(0.55, 0.55, 0.55, 1.0)
	var overlay := ColorRect.new()
	overlay.name = "_LockOverlay"
	overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var lock_lbl := Label.new()
	lock_lbl.name = "_LockLabel"
	lock_lbl.text = "LOCKED"
	lock_lbl.add_theme_font_override("font", preload("res://assets/fonts/PressStart2P-Regular.ttf"))
	lock_lbl.add_theme_font_size_override("font_size", 10)
	lock_lbl.add_theme_color_override("font_color", Color(0.9, 0.15, 0.15))
	lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lock_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(lock_lbl)
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(func():
		var ov := get_node_or_null("_LockOverlay")
		var lbl := get_node_or_null("_LockLabel")
		if ov: ov.queue_free()
		if lbl: lbl.queue_free()
	)
	tween.tween_property(self, "modulate", Color(2.2, 1.8, 0.4), 0.2).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "modulate", Color.WHITE, 0.6).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func():
		disabled = false
		unlock_finished.emit()
	)

func _on_pressed() -> void:
	map_selected.emit(map_data)
