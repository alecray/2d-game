## Offsets this Control node opposite to the player's movement direction,
## giving the UI a weighted, bouncy feel. Attach to any Control node.
extends Control

const BOB_STRENGTH = 8.0   # max pixel offset in each direction
const BOB_SPEED = 10.0     # how quickly it snaps back to the rest position

var rest_position: Vector2

func _ready() -> void:
	rest_position = position

func _process(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var bob_offset = Vector2.ZERO
	if player.velocity.length() > 10.0:
		bob_offset = -player.velocity.normalized() * BOB_STRENGTH

	position = position.lerp(rest_position + bob_offset, delta * BOB_SPEED)
