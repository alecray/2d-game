## Listens for mana_changed on the player and updates itself.
## Attach this to any Label node — it finds the player by group so it works anywhere in the tree.
extends Label

func _ready() -> void:
	await get_tree().process_frame
	var player = get_tree().get_first_node_in_group("player")
	if player:
		text = str(player.mana)
		player.mana_changed.connect(func(value): text = str(value))
		player.magic_ready_changed.connect(func(is_ready): modulate.a = 1.0 if is_ready else 0.1)
