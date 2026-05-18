extends Node2D

const SHOP_SCENE  := preload("res://scenes/shop.tscn")
const FONT        := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const TorchLight  := preload("res://scripts/environment/torch_light.gd")
const GroundShadow := preload("res://scripts/effects/ground_shadow.gd")

const INTERACT_RADIUS := 96.0
const GLOW_COLOR      := Color(1.0, 0.72, 0.28)
const GLOW_ENERGY     := 0.60
const GLOW_SCALE      := 16.5   # world-space radius of the candle glow

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

var _player: Node2D
var _player_nearby := false
var _shop_open     := false
var _shop_layer    : CanvasLayer
var _prompt_layer  : CanvasLayer
var _prompt_label  : Label
var _glow          : PointLight2D
var _glow_time     := 0.0

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	add_to_group("merchant")
	if _sprite.sprite_frames:
		_sprite.play("default")
	_build_shadow()
	_build_glow()
	_build_prompt()

func _build_shadow() -> void:
	var shadow := Node2D.new()
	shadow.set_script(GroundShadow)
	shadow.position  = Vector2(0.0, 22.0)
	shadow.scale     = Vector2(3.2, 1.1)
	shadow.modulate  = Color(0.0, 0.0, 0.0, 0.28)
	shadow.z_index   = -1
	add_child(shadow)

func _build_glow() -> void:
	_glow = PointLight2D.new()
	_glow.texture       = TorchLight._make_radial_texture()
	_glow.texture_scale = GLOW_SCALE
	_glow.color         = GLOW_COLOR
	_glow.energy        = GLOW_ENERGY
	_glow.blend_mode    = Light2D.BLEND_MODE_ADD
	_glow.position      = Vector2(0.0, -8.0)
	add_child(_glow)

func _build_prompt() -> void:
	_prompt_layer = CanvasLayer.new()
	_prompt_layer.layer = 15
	_prompt_layer.visible = false
	add_child(_prompt_layer)

	_prompt_label = Label.new()
	_prompt_label.text = "[E] SHOP"
	_prompt_label.add_theme_font_override("font", FONT)
	_prompt_label.add_theme_font_size_override("font_size", 8)
	_prompt_label.add_theme_color_override("font_color", Color.WHITE)
	_prompt_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_prompt_label.add_theme_constant_override("shadow_offset_x", 1)
	_prompt_label.add_theme_constant_override("shadow_offset_y", 1)
	_prompt_layer.add_child(_prompt_label)

func _process(delta: float) -> void:
	# Candle flicker — two overlapping sine waves plus a small random nudge
	_glow_time += delta
	var flicker := sin(_glow_time * 7.3) * 0.06 + sin(_glow_time * 17.1) * 0.03
	_glow.energy = GLOW_ENERGY + flicker + randf_range(-0.015, 0.015)

	if _shop_open:
		return
	var player := _player if is_instance_valid(_player) else null
	if not player:
		return

	var near := global_position.distance_to(player.global_position) <= INTERACT_RADIUS
	if near != _player_nearby:
		_player_nearby = near
		_prompt_layer.visible = near

	if near:
		_update_prompt_pos()

func _update_prompt_pos() -> void:
	var ct         := get_viewport().get_canvas_transform()
	var screen_pos := ct * get_global_position()
	var lw         := _prompt_label.size.x if _prompt_label.size.x > 0.0 else 64.0
	_prompt_label.position = Vector2(screen_pos.x - lw * 0.5, screen_pos.y - 80.0)

func _unhandled_input(event: InputEvent) -> void:
	if not _player_nearby or _shop_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			_open_shop()
			get_viewport().set_input_as_handled()

func _open_shop() -> void:
	_shop_open = true
	_prompt_layer.visible = false

	_shop_layer = CanvasLayer.new()
	_shop_layer.layer = 50
	_shop_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_shop_layer)

	var shop := SHOP_SCENE.instantiate()
	shop.in_game_mode = true
	shop.process_mode = Node.PROCESS_MODE_ALWAYS
	shop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shop.shop_closed.connect(_on_shop_closed)
	_shop_layer.add_child(shop)

	get_tree().paused = true

func _on_shop_closed() -> void:
	_shop_open = false
	get_tree().paused = false
	if is_instance_valid(_shop_layer):
		_shop_layer.queue_free()
	_shop_layer = null
	if _player_nearby:
		_prompt_layer.visible = true
