extends Area2D

const UPGRADE_SCREEN_SCENE = preload("res://prefabs/upgrade_screen.tscn")
const FONT = preload("res://assets/fonts/PressStart2P-Regular.ttf")

const BAD_CRATE_CHANCE = 0.2

const BOB_SPEED = 2.2
const BOB_AMPLITUDE = 4.0
const TILT_SPEED = 1.6
const TILT_AMOUNT = 0.12  # radians (~7 degrees)

var _time := 0.0
var _shadow: Sprite2D

const CURSES := [
	{"id": "slowness", "name": "SLOWNESS", "desc": "-40 speed"},
	{"id": "jam",      "name": "JAM",      "desc": "Fire 25% slower"},
	{"id": "fumble",   "name": "FUMBLE",   "desc": "-8 bullet damage"},
	{"id": "frail",    "name": "FRAIL",    "desc": "-30 max HP"},
	{"id": "disarmed", "name": "DISARMED", "desc": "-150 max ammo"},
	{"id": "cursed",   "name": "CURSED",   "desc": "HP halved"},
]

func _ready() -> void:
	_time = randf() * TAU  # stagger phase so crates don't all bob in sync
	body_entered.connect(_on_body_entered)
	add_to_group("pickup")

	_shadow = Sprite2D.new()
	_shadow.texture = $Sprite2D.texture
	_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shadow.modulate = Color(0.0, 0.0, 0.0, 0.35)
	_shadow.scale = Vector2(0.85, 0.22)
	_shadow.z_index = -1
	add_child(_shadow)

func _process(delta: float) -> void:
	_time += delta
	var bob := sin(_time * BOB_SPEED) * BOB_AMPLITUDE
	var tilt := sin(_time * TILT_SPEED) * TILT_AMOUNT

	$Sprite2D.position.y = bob
	$Sprite2D.rotation = tilt

	# shadow creeps down and shrinks as the crate rises
	var bob_t := (bob + BOB_AMPLITUDE) / (BOB_AMPLITUDE * 2.0)
	_shadow.position = Vector2(0.0, 16.0 - bob * 0.25)
	_shadow.scale.x = lerp(0.65, 0.85, bob_t)
	_shadow.modulate.a = lerp(0.18, 0.38, bob_t)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var bad_chance: float = get_node("/root/PlayerStats").bad_crate_chance()
	if randf() < bad_chance:
		_apply_curse(body)
	else:
		if get_tree().get_nodes_in_group("upgrade_screen").size() > 0:
			return
		var screen = UPGRADE_SCREEN_SCENE.instantiate()
		get_tree().root.add_child(screen)
	queue_free()

func _apply_curse(player: Node2D) -> void:
	var curse: Dictionary = CURSES[randi() % CURSES.size()]
	match curse.id:
		"slowness": player.SPEED = maxf(60.0, player.SPEED - 40.0)
		"jam":      player.FIRE_RATE = minf(2.0, player.FIRE_RATE * 1.33)
		"fumble":   player.bullet_damage = maxi(1, player.bullet_damage - 8)
		"frail":
			player.MAX_HEALTH = maxi(10, player.MAX_HEALTH - 30)
			player.health = mini(player.health, player.MAX_HEALTH)
		"disarmed":
			player.MAX_AMMO = maxi(30, player.MAX_AMMO - 150)
			player.ammo = mini(player.ammo, player.MAX_AMMO)
		"cursed":   player.health = maxi(1, player.health / 2)
	_spawn_curse_popup(player.global_position, curse)
	_spawn_explosion(player.global_position)
	_shake_camera(player)

func _spawn_curse_popup(pos: Vector2, curse: Dictionary) -> void:
	var label := Label.new()
	label.text = curse.name + "!\n" + curse.desc
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.15, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 10
	get_parent().add_child(label)
	label.global_position = pos + Vector2(-50.0, -30.0)
	label.rotation = deg_to_rad(-8.0)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - 55.0, 0.9)
	tween.tween_property(label, "rotation", deg_to_rad(8.0), 0.9).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tween.tween_callback(label.queue_free).set_delay(0.9)

func _shake_camera(player: Node2D) -> void:
	var camera := player.get_viewport().get_camera_2d()
	if not camera:
		return
	var intensity := 22.0
	var steps := 14
	var duration := 0.65
	var tween := camera.create_tween()
	for i in steps:
		var fade: float = intensity * (1.0 - float(i) / steps)
		var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * fade
		tween.tween_property(camera, "offset", offset, duration / steps)
	tween.tween_property(camera, "offset", Vector2.ZERO, duration / steps)

func _spawn_explosion(pos: Vector2) -> void:
	var chunks := CPUParticles2D.new()
	chunks.one_shot = true
	chunks.explosiveness = 0.92
	chunks.amount = 22
	chunks.lifetime = 0.85
	chunks.direction = Vector2(0.0, -1.0)
	chunks.spread = 180.0
	chunks.gravity = Vector2(0.0, 200.0)
	chunks.initial_velocity_min = 60.0
	chunks.initial_velocity_max = 180.0
	chunks.scale_amount_min = 4.0
	chunks.scale_amount_max = 9.0
	var chunk_init := Gradient.new()
	chunk_init.colors = PackedColorArray([Color(1.0, 0.1, 0.1), Color(0.7, 0.1, 0.9), Color(1.0, 0.4, 0.1)])
	chunks.color_initial_ramp = chunk_init
	var chunk_life := Gradient.new()
	chunk_life.colors = PackedColorArray([Color(1,1,1,1), Color(1,1,1,0.6), Color(1,1,1,0)])
	chunk_life.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	chunks.color_ramp = chunk_life
	chunks.z_index = 5
	chunks.finished.connect(chunks.queue_free)
	get_parent().add_child(chunks)
	chunks.global_position = pos
	chunks.emitting = true

	var sparks := CPUParticles2D.new()
	sparks.one_shot = true
	sparks.explosiveness = 0.95
	sparks.amount = 40
	sparks.lifetime = 0.5
	sparks.direction = Vector2(0.0, -1.0)
	sparks.spread = 180.0
	sparks.gravity = Vector2(0.0, 120.0)
	sparks.initial_velocity_min = 100.0
	sparks.initial_velocity_max = 260.0
	sparks.scale_amount_min = 1.5
	sparks.scale_amount_max = 3.5
	var spark_init := Gradient.new()
	spark_init.colors = PackedColorArray([Color(1.0, 0.9, 0.2), Color(1.0, 0.5, 0.05)])
	sparks.color_initial_ramp = spark_init
	var spark_life := Gradient.new()
	spark_life.colors = PackedColorArray([Color(1,1,1,1), Color(1,1,1,0)])
	spark_life.offsets = PackedFloat32Array([0.0, 1.0])
	sparks.color_ramp = spark_life
	sparks.z_index = 5
	sparks.finished.connect(sparks.queue_free)
	get_parent().add_child(sparks)
	sparks.global_position = pos
	sparks.emitting = true
