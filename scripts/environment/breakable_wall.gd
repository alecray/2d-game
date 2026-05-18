extends "res://scripts/environment/wall.gd"

const WALL2_TEX        := preload("res://assets/sprites/environment/wall2.png")
const WALL3_TEX        := preload("res://assets/sprites/environment/wall3.png")
const MIMIC_WALL_SCENE := preload("res://prefabs/enemies/mimic_wall.tscn")
const MAX_HEALTH       := 100
const MIMIC_CHANCE     := 0.25  # 1-in-4 breakable walls becomes a mimic at half HP

var health := MAX_HEALTH
var _mimic_spawned := false

func _ready() -> void:
	texture = WALL2_TEX
	super._ready()
	add_to_group("breakable_wall")

func take_damage(amount: int, hit_normal: Vector2 = Vector2.ZERO) -> void:
	health -= amount
	if health <= 0:
		_die()
		return
	_spawn_chip_particles(hit_normal)
	if health <= MAX_HEALTH / 2 and texture != WALL3_TEX:
		texture = WALL3_TEX
		if not _mimic_spawned and (get_node("/root/GameState").dev_mimic_force or randf() < MIMIC_CHANCE):
			_mimic_spawned = true
			_spawn_mimic()
			return  # wall is gone; don't redraw
	queue_redraw()

func _draw() -> void:
	super._draw()
	if health >= MAX_HEALTH:
		return
	var bar_w: float = size.x
	var bar_h: float = 4.0
	var bar_x: float = -bar_w * 0.5
	var bar_y: float = -size.y * 0.5 - 7.0
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.1, 0.1, 0.1, 0.92))
	var fill: float = bar_w * (float(health) / MAX_HEALTH)
	var col := Color(0.2, 0.85, 0.2) if health > MAX_HEALTH * 0.5 else Color(0.9, 0.2, 0.2)
	draw_rect(Rect2(bar_x, bar_y, fill, bar_h), col)

func _spawn_mimic() -> void:
	_spawn_explode_particles()
	var mimic := MIMIC_WALL_SCENE.instantiate()
	get_parent().add_child(mimic)
	mimic.global_position = global_position
	queue_free()

func _die() -> void:
	_spawn_explode_particles()
	queue_free.call_deferred()

func _spawn_chip_particles(hit_normal: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot       = true
	p.explosiveness  = 0.9
	p.amount         = 6
	p.lifetime       = 0.35
	p.gravity        = Vector2(0.0, 220.0)
	p.direction      = hit_normal if hit_normal.length() > 0.1 else Vector2.UP
	p.spread         = 60.0
	p.initial_velocity_min = 70.0
	p.initial_velocity_max = 180.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.5
	var cgrad := Gradient.new()
	cgrad.colors = PackedColorArray([Color(0.65, 0.60, 0.50), Color(0.40, 0.36, 0.30)])
	p.color_initial_ramp = cgrad
	var lgrad := Gradient.new()
	lgrad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = lgrad
	p.z_index = 3
	get_parent().add_child(p)
	p.global_position = global_position
	p.emitting = true
	p.finished.connect(p.queue_free)

func _spawn_explode_particles() -> void:
	var p := CPUParticles2D.new()
	p.one_shot       = true
	p.explosiveness  = 1.0
	p.amount         = 36
	p.lifetime       = 0.7
	p.gravity        = Vector2(0.0, 280.0)
	p.spread         = 180.0
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 340.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.5
	var cgrad := Gradient.new()
	cgrad.colors = PackedColorArray([Color(0.70, 0.65, 0.52), Color(0.42, 0.38, 0.32)])
	p.color_initial_ramp = cgrad
	var lgrad := Gradient.new()
	lgrad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = lgrad
	p.z_index = 3
	get_parent().add_child(p)
	p.global_position = global_position
	p.emitting = true
	p.finished.connect(p.queue_free)
