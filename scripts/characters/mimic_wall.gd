extends "res://scripts/characters/base_enemy.gd"

var _awakened := false

func _ready() -> void:
	SPEED = 65.0
	CHASE_SPEED = 145.0
	ACCELERATION = 120.0
	DAMAGE = 20
	max_health = 350
	super._ready()
	_start_awaken()

func _start_awaken() -> void:
	var sprite := $AnimatedSprite2D
	if sprite.sprite_frames.has_animation("Awaken") \
			and sprite.sprite_frames.get_frame_count("Awaken") > 0:
		_play_anim("Awaken")
		sprite.animation_finished.connect(_on_awaken_finished, CONNECT_ONE_SHOT)
	else:
		_awakened = true  # no animation defined yet — go live immediately

func _on_awaken_finished() -> void:
	_awakened = true

func _physics_process(delta: float) -> void:
	if frozen:
		velocity = Vector2.ZERO
		return
	if not _awakened:
		velocity = Vector2.ZERO
		return
	super._physics_process(delta)

func get_death_color() -> Color:
	return Color(0.55, 0.50, 0.40)  # stone/rubble gray

func _get_shadow_offset_y() -> float:
	return 16.0

func _get_melee_range() -> float:
	return 40.0

func _get_attack_duration() -> float:
	return 0.9
