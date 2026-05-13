extends Control

const SHOP_ENTRY_SCENE = preload("res://prefabs/shop_entry.tscn")


@onready var _entry_list: VBoxContainer = $VBox/Scroll/EntryList
@onready var _coins_label: Label = $VBox/LabelCoins

var _stats: Node
var _entries: Array = []

func _ready() -> void:
	_stats = get_node("/root/PlayerStats")
	$VBox/BtnBack.pressed.connect(_on_back)
	for id in PlayerStats.GUN_DEFS:
		var gun: Dictionary = PlayerStats.GUN_DEFS[id].duplicate()
		gun["id"] = id
		_add_entry(gun)
	_refresh_coins()

func _add_entry(gun: Dictionary) -> void:
	var entry = SHOP_ENTRY_SCENE.instantiate()
	_entry_list.add_child(entry)
	entry.setup(gun, _stats)
	entry.purchased.connect(_on_purchased)
	entry.equipped.connect(_on_equipped)
	_entries.append(entry)

func _refresh_coins() -> void:
	_coins_label.text = "COINS: " + str(_stats.coins)

func _refresh_all_entries() -> void:
	for entry in _entries:
		entry._refresh()

func _on_purchased(_gun_id: String) -> void:
	_refresh_coins()
	_refresh_all_entries()

func _on_equipped(_gun_id: String) -> void:
	_refresh_all_entries()

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/stats_screen.tscn")

