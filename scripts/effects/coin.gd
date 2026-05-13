extends Area2D

const BOB_SPEED = 2.8
const BOB_AMPLITUDE = 3.0
const COLLECT_RISE = 18.0    # pixels to float upward during the collect animation
const COLLECT_TIME = 0.3     # seconds the collect animation lasts

const FloatingText = preload("res://scripts/utils/floating_text.gd")

var _time: float = 0.0
var _collecting: bool = false

func _ready() -> void:
	_time = randf() * TAU
	body_entered.connect(_on_body_entered)
	if $AnimatedSprite2D.sprite_frames:
		$AnimatedSprite2D.play("default")
	add_to_group("pickup")

func _process(delta: float) -> void:
	_time += delta
	if not _collecting:
		$AnimatedSprite2D.position.y = sin(_time * BOB_SPEED) * BOB_AMPLITUDE

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or _collecting:
		return
	_collecting = true
	get_node("/root/PlayerStats").add_coins(1)

	var popup := FloatingText.new()
	popup.text = "+1"
	popup.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1, 1.0))
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
