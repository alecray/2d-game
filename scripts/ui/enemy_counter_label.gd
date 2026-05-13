extends Label

func _ready() -> void:
	add_to_group("boss_token_counter")

func _process(_delta: float) -> void:
	var tokens: int = get_node("/root/GameState").boss_tokens
	text = str(tokens) + " / 5"
	var color := Color(1.0, 0.3, 0.15) if tokens >= 4 else Color(1.0, 0.75, 0.0)
	add_theme_color_override("font_color", color)
