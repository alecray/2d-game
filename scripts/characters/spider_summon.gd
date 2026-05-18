## Summoned spider companion — follows the player and attacks nearby enemies for LIFETIME seconds.
extends CharacterBody2D

const SPIDER_TSCN     := preload("res://prefabs/enemies/spider.tscn")
const GroundShadow    := preload("res://scripts/effects/ground_shadow.gd")
const FloatingText    := preload("res://scripts/utils/floating_text.gd")

const LIFETIME        := 60.0
const FOLLOW_DIST     := 90.0   # don't move if already this close to the player
const TELEPORT_DIST   := 400.0  # snap to player if further than this
const CHASE_DIST      := 220.0  # engage enemies within this radius
const SPEED_FOLLOW    := 170.0
const SPEED_CHASE     := 210.0
const ATTACK_RANGE    := 36.0
const ATTACK_DAMAGE   := 12
const ATTACK_COOLDOWN := 1.4

var _player:       Node2D = null
var _target:       Node2D = null
var _sprite:       AnimatedSprite2D
var _attack_timer: float = 0.0

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")

	# Grab the spider's SpriteFrames without running its _ready()
	var ref := SPIDER_TSCN.instantiate()
	var frames: SpriteFrames = ref.get_node("AnimatedSprite2D").sprite_frames
	ref.free()

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_sprite.play("Idle")

	scale    = Vector2(0.65, 0.65)
	modulate = Color(0.75, 0.90, 1.0)  # blue tint marks it as summoned

	var shadow := Node2D.new()
	shadow.set_script(GroundShadow)
	shadow.position = Vector2(0.0, 14.0)
	shadow.scale    = Vector2(0.65, 0.25)
	shadow.modulate = Color(0.0, 0.0, 0.0, 0.18)
	shadow.z_index  = -1
	add_child(shadow)

	var shape := CircleShape2D.new()
	shape.radius = 7.0
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

	collision_layer = 0  # other things don't collide with us
	collision_mask  = 1  # we still stop at walls

	add_to_group("player_companion")

	var popup := FloatingText.new()
	popup.text = "SPIDER ALLY!"
	popup.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	popup.add_theme_font_size_override("font_size", 8)
	get_parent().add_child(popup)
	popup.global_position = global_position

	get_tree().create_timer(LIFETIME - 3.0).timeout.connect(_start_fade, CONNECT_ONE_SHOT)
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free, CONNECT_ONE_SHOT)

func _start_fade() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 3.0)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	_attack_timer = maxf(_attack_timer - delta, 0.0)

	if global_position.distance_to(_player.global_position) > TELEPORT_DIST:
		global_position = _player.global_position
		velocity = Vector2.ZERO

	_refresh_target()

	var target_vel := Vector2.ZERO

	if is_instance_valid(_target):
		var dist_to_enemy := global_position.distance_to(_target.global_position)
		if dist_to_enemy <= ATTACK_RANGE:
			if _attack_timer <= 0.0:
				_attack_timer = ATTACK_COOLDOWN
				_target.take_damage(ATTACK_DAMAGE)
		else:
			target_vel = (_target.global_position - global_position).normalized() * SPEED_CHASE
	elif global_position.distance_to(_player.global_position) > FOLLOW_DIST:
		target_vel = (_player.global_position - global_position).normalized() * SPEED_FOLLOW

	velocity = velocity.lerp(target_vel, delta * 12.0)
	move_and_slide()

	if velocity.x != 0.0:
		_sprite.flip_h = velocity.x < 0.0
	var anim := "Walk" if velocity.length() > 5.0 else "Idle"
	if _sprite.animation != anim:
		_sprite.play(anim)

func _refresh_target() -> void:
	if is_instance_valid(_target) and _target.is_in_group("enemy") \
			and global_position.distance_to(_target.global_position) <= CHASE_DIST:
		return
	_target = null
	var closest := CHASE_DIST
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue
		var d := global_position.distance_to(enemy.global_position)
		if d < closest:
			closest = d
			_target = enemy as Node2D
