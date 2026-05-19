extends Control

const SPELLBOOK_TEX   := preload("res://assets/sprites/spellbook.png")
const SpellbookScreen := preload("res://scripts/ui/spellbook_screen.gd")

var _player: Node
var _btn: TextureButton

func setup(player: Node) -> void:
	_player = player

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_btn = TextureButton.new()
	_btn.texture_normal = SPELLBOOK_TEX
	_btn.ignore_texture_size = true
	_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_btn.custom_minimum_size = Vector2(36, 36)
	_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_btn.grow_vertical   = Control.GROW_DIRECTION_END
	_btn.grow_horizontal = Control.GROW_DIRECTION_END
	_btn.position = Vector2(12, 12)
	_btn.pivot_offset = Vector2(18, 18)
	_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_btn.pressed.connect(_on_pressed)
	add_child(_btn)

func _on_pressed() -> void:
	var tween := _btn.create_tween()
	tween.tween_property(_btn, "scale", Vector2(0.65, 0.65), 0.07).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_btn, "scale", Vector2(1.15, 1.15), 0.10).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_btn, "scale", Vector2(1.0,  1.0),  0.08).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(_open)

func _open() -> void:
	if get_tree().paused:
		return
	var screen := CanvasLayer.new()
	screen.set_script(SpellbookScreen)
	screen.setup(_player)
	get_tree().root.add_child(screen)
