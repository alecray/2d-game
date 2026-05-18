extends Node2D

const BOSS_TOKEN_SCENE = preload("res://prefabs/items/boss_token.tscn")
const PEDESTAL_TEXTURE = preload("res://assets/sprites/environment/pedestal.png")
const TorchLight       = preload("res://scripts/environment/torch_light.gd")

const GLOW_COLOR  := Color(0.62, 0.18, 1.0)
const GLOW_ENERGY := 0.65
const GLOW_SCALE  := 16.5

var _glow     : PointLight2D
var _glow_time := 0.0

func _ready() -> void:
	add_to_group("pedestal")
	var spr := Sprite2D.new()
	spr.texture = PEDESTAL_TEXTURE
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(spr)

	var token := BOSS_TOKEN_SCENE.instantiate()
	token.force_single_pickup = true
	token.sprite_y_offset = -60.0
	add_child(token)

	_glow = PointLight2D.new()
	_glow.texture       = TorchLight._make_radial_texture()
	_glow.texture_scale = GLOW_SCALE
	_glow.color         = GLOW_COLOR
	_glow.energy        = GLOW_ENERGY
	_glow.blend_mode    = Light2D.BLEND_MODE_ADD
	_glow.position      = Vector2(0.0, -20.0)
	add_child(_glow)

func _process(delta: float) -> void:
	_glow_time += delta
	var flicker := sin(_glow_time * 5.9) * 0.07 + sin(_glow_time * 13.3) * 0.03
	_glow.energy = GLOW_ENERGY + flicker + randf_range(-0.02, 0.02)
