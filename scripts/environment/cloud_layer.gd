extends Node2D

const CLOUD_COUNT = 8
const WIND = Vector2(22.0, 3.5)       # pixels/sec
const BLOCK_SIZE_MIN = 70.0
const BLOCK_SIZE_MAX = 160.0
const WORLD_HALF = 1350.0

# altitude 0.0 = low (near ground), 1.0 = high
const SHADOW_OFFSET_LOW  = 80.0
const SHADOW_OFFSET_HIGH = 280.0
const SHADOW_ALPHA_LOW   = 0.07
const SHADOW_ALPHA_HIGH  = 0.01
const CLOUD_ALPHA_LOW    = 0.20
const CLOUD_ALPHA_HIGH   = 0.09

var _clouds: Array = []

func _ready() -> void:
	z_index = -5
	z_as_relative = false
	for _i in CLOUD_COUNT:
		_clouds.append(_make_cloud(_random_pos()))

func _random_pos() -> Vector2:
	return Vector2(
		randf_range(-WORLD_HALF, WORLD_HALF),
		randf_range(-WORLD_HALF, WORLD_HALF)
	)

func _make_cloud(pos: Vector2) -> Dictionary:
	var size := randf_range(BLOCK_SIZE_MIN, BLOCK_SIZE_MAX)
	var altitude := randf()
	var blocks: Array = []
	for _i in randi_range(4, 7):
		var bx := randf_range(-size * 0.4, size * 0.35)
		var by := randf_range(-size * 0.12, size * 0.12)
		var bw := randf_range(size * 0.55, size * 1.05)
		var bh := randf_range(size * 0.35, size * 0.65)
		blocks.append(Rect2(bx, by, bw, bh))
	return {"pos": pos, "blocks": blocks, "size": size, "altitude": altitude}

func _process(delta: float) -> void:
	for cloud in _clouds:
		cloud["pos"] += WIND * delta
		var half: float = cloud["size"] * 1.2
		if cloud["pos"].x - half > WORLD_HALF:
			cloud["pos"].x = -WORLD_HALF - half
			cloud["pos"].y = randf_range(-WORLD_HALF, WORLD_HALF)
			cloud["altitude"] = randf()
	queue_redraw()

func _draw() -> void:
	for cloud in _clouds:
		var p: Vector2 = cloud["pos"]
		var alt: float = cloud["altitude"]
		var shadow_offset := lerpf(SHADOW_OFFSET_LOW, SHADOW_OFFSET_HIGH, alt)
		var shadow_alpha  := lerpf(SHADOW_ALPHA_LOW,  SHADOW_ALPHA_HIGH,  alt)
		var cloud_alpha   := lerpf(CLOUD_ALPHA_LOW,   CLOUD_ALPHA_HIGH,   alt)
		var shadow_p := p + Vector2(0.0, shadow_offset)
		for b in cloud["blocks"]:
			draw_rect(Rect2(shadow_p + b.position, b.size), Color(0.0, 0.0, 0.0, shadow_alpha))
		for b in cloud["blocks"]:
			draw_rect(Rect2(p + b.position, b.size), Color(1.0, 1.0, 1.0, cloud_alpha))
