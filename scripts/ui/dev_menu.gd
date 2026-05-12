extends CanvasLayer

func _ready() -> void:
	visible = false
	$Panel/VBox/BtnKillPlayer.pressed.connect(_on_kill_player)
	$Panel/VBox/BtnGiveCoins.pressed.connect(_on_give_coins)
	$Panel/VBox/BtnClose.pressed.connect(_toggle)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_U:
		_toggle()
		get_viewport().set_input_as_handled()

func _toggle() -> void:
	visible = not visible
	get_tree().paused = visible

func _on_kill_player() -> void:
	_toggle()
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.take_damage(player.MAX_HEALTH)

func _on_give_coins() -> void:
	get_node("/root/PlayerStats").add_coins(1000)
