extends Control

var _stats: Node
var _xp_label: Label
var _coins_label: Label
var _rows: Dictionary = {}  # stat key → {level_label, cost_label, button}

func _ready() -> void:
	_stats = get_node("/root/PlayerStats")
	_xp_label = $VBox/LabelXP
	_coins_label = $VBox/LabelCoins

	for key in PlayerStats.STAT_DEFS:
		var row_path = "VBox/" + _row_node_name(key)
		_rows[key] = {
			"level_label": get_node(row_path + "/LabelLevel"),
			"cost_label":  get_node(row_path + "/LabelCost"),
			"button":      get_node(row_path + "/BtnUpgrade"),
		}
		_rows[key]["button"].pressed.connect(_on_upgrade.bind(key))

	$VBox/BtnShop.pressed.connect(_on_shop)
	$VBox/BtnPlay.pressed.connect(_on_play)
	$VBox/BtnReset.pressed.connect(_on_reset)
	_refresh()

## Converts a stat key like "max_health" → "RowMaxHealth" to match scene node names.
func _row_node_name(key: String) -> String:
	var result = "Row"
	for part in key.split("_"):
		result += part.capitalize()
	return result

func _refresh() -> void:
	_xp_label.text = "XP: " + str(_stats.xp)
	_coins_label.text = "COINS: " + str(_stats.coins)
	for key in _rows:
		var row = _rows[key]
		var level = _stats.get_level(key)
		var max_level = PlayerStats.STAT_DEFS[key]["max_level"]
		row["level_label"].text = "Lv %d/%d" % [level, max_level]
		if level >= max_level:
			row["cost_label"].text = "MAX"
			row["button"].disabled = true
		else:
			row["cost_label"].text = str(_stats.upgrade_cost(key)) + " XP"
			row["button"].disabled = not _stats.can_upgrade(key)

func _on_upgrade(stat: String) -> void:
	_stats.spend_xp(stat)
	_refresh()

func _on_shop() -> void:
	get_tree().change_scene_to_file("res://scenes/shop.tscn")

func _on_play() -> void:
	get_node("/root/GameState").reset()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_reset() -> void:
	_stats.reset()
	_refresh()
