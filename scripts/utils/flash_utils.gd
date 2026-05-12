class_name FlashUtils

static func flash_white(sprite: Node2D) -> void:
	var mat = sprite.material as ShaderMaterial
	var tween = sprite.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(
		func(v): mat.set_shader_parameter("flash_amount", v),
		0.0, 1.0, 0.1
	)
	tween.tween_method(
		func(v): mat.set_shader_parameter("flash_amount", v),
		1.0, 0.0, 0.1
	)
	tween.tween_method(
		func(v): mat.set_shader_parameter("flash_amount", v),
		0.0, 1.0, 0.1
	)
	tween.tween_method(
		func(v): mat.set_shader_parameter("flash_amount", v),
		1.0, 0.0, 0.1
	)
