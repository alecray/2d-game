extends Area2D

const BOB_SPEED = 2.8
const BOB_AMPLITUDE = 3.0
const COLLECT_RISE = 18.0
const COLLECT_TIME = 0.3
const AMMO_AMOUNT = 50

const FloatingText = preload("res://scripts/utils/floating_text.gd")
const GroundShadow = preload("res://scripts/effects/ground_shadow.gd")

var _time: float = 0.0
var _collecting: bool = false
var _shadow: Node2D

func _ready() -> void:
	_time = randf() * TAU
	collision_mask = 2  # detect player body (layer 2)
	body_entered.connect(_on_body_entered)
	if $AnimatedSprite2D.sprite_frames and $AnimatedSprite2D.sprite_frames.has_animation("default"):
		$AnimatedSprite2D.play("default")
	add_to_group("pickup")
	_shadow = Node2D.new()
	_shadow.set_script(GroundShadow)
	_shadow.position = Vector2(0.0, 23.0)
	_shadow.scale = Vector2(0.9, 0.28)
	_shadow.modulate = Color(0, 0, 0, 0.3)
	_shadow.z_index = -1
	add_child(_shadow)

func _process(delta: float) -> void:
	_time += delta
	if not _collecting:
		var bob := sin(_time * BOB_SPEED) * BOB_AMPLITUDE
		$AnimatedSprite2D.position.y = bob
		var bob_t := (bob + BOB_AMPLITUDE) / (BOB_AMPLITUDE * 2.0)
		_shadow.scale.x = lerp(0.55, 0.9, bob_t)
		_shadow.modulate.a = lerp(0.12, 0.32, bob_t)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or _collecting:
		return
	_collecting = true
	_shadow.visible = false
	var gained := mini(AMMO_AMOUNT, body.MAX_AMMO - body.ammo)
	body.ammo = mini(body.MAX_AMMO, body.ammo + AMMO_AMOUNT)

	var popup := FloatingText.new()
	popup.text = "+" + str(gained) + " ammo"
	popup.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2, 1.0))
	popup.add_theme_font_size_override("font_size", 8)
	get_parent().add_child(popup)
	popup.global_position = global_position

	$AnimatedSprite2D.speed_scale = 4.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property($AnimatedSprite2D, "position:y",
			$AnimatedSprite2D.position.y - COLLECT_RISE, COLLECT_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property($AnimatedSprite2D, "modulate:a", 0.0, COLLECT_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
