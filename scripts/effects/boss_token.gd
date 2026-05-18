extends Area2D

const TOKENS_TO_SPAWN = 5
const BOB_SPEED = 1.8
const BOB_AMPLITUDE = 5.0
const FONT = preload("res://assets/fonts/PressStart2P-Regular.ttf")
const GroundShadow = preload("res://scripts/effects/ground_shadow.gd")

var force_single_pickup := false  # set true by Pedestal so one pickup immediately spawns the boss
var sprite_y_offset: float = 0.0  # base Y for the AnimatedSprite2D; bob animates around this
var _time := 0.0
var _shadow: Node2D

func _ready() -> void:
	_time = randf() * TAU
	collision_mask = 2  # detect player body (layer 2)
	body_entered.connect(_on_body_entered)
	add_to_group("pickup")
	$AnimatedSprite2D.play("default")
	_shadow = Node2D.new()
	_shadow.set_script(GroundShadow)
	_shadow.position = Vector2(0.0, 25.0)
	_shadow.scale = Vector2(1.0, 0.28)
	_shadow.modulate = Color(0, 0, 0, 0.3)
	_shadow.z_index = -1
	add_child(_shadow)

func _process(delta: float) -> void:
	_time += delta
	var bob := sin(_time * BOB_SPEED) * BOB_AMPLITUDE
	$AnimatedSprite2D.position.y = sprite_y_offset + bob
	var bob_t := (bob + BOB_AMPLITUDE) / (BOB_AMPLITUDE * 2.0)
	_shadow.scale.x = lerp(0.6, 1.0, bob_t)
	_shadow.modulate.a = lerp(0.12, 0.35, bob_t)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if force_single_pickup:
		_spawn_horde_banner()
		get_tree().call_group_flags(SceneTree.GROUP_CALL_DEFERRED, "main_scene", "start_horde")
		queue_free()
		return
	var state := get_node("/root/GameState")
	state.boss_tokens += 1
	_spawn_pickup_popup(state.boss_tokens)
	if state.boss_tokens >= TOKENS_TO_SPAWN:
		state.boss_tokens = 0
		_spawn_horde_banner()
		get_tree().call_group_flags(SceneTree.GROUP_CALL_DEFERRED, "main_scene", "start_horde")
	queue_free()

func _spawn_pickup_popup(count: int) -> void:
	var label := Label.new()
	label.text = "BOSS TOKEN! (%d/%d)" % [count, TOKENS_TO_SPAWN]
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.0, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 10
	get_parent().add_child(label)
	label.global_position = global_position + Vector2(-80.0, -30.0)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - 60.0, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0).set_delay(0.3)
	tween.tween_callback(label.queue_free).set_delay(1.0)


func _spawn_horde_banner() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 15
	get_tree().root.add_child(layer)
	var lbl := Label.new()
	lbl.text = "HORDE INCOMING!"
	lbl.add_theme_font_override("font", FONT)
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.0))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(lbl)
	var tween := lbl.create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.8)
	tween.tween_callback(layer.queue_free)
