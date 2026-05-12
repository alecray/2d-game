## Listens for health_changed on the player and updates itself.
## Attach this to any Label node — it finds the player by group so it works anywhere in the tree.
extends Label

func _ready() -> void:
	await get_tree().process_frame  # wait for player's _ready() to run and register its group
	var player = get_tree().get_first_node_in_group("player")
	if player:
		text = str(player.health)
		player.health_changed.connect(func(value): text = str(value))
