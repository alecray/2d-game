extends Control

@onready var _label_title: Label = $VBoxContainer/VBox_Title/Label_Title
@onready var _label_score: Label = $VBoxContainer/VBox_Title/Label_Score
@onready var _vbox_menu: VBoxContainer = $VBoxContainer/VBox_Menu

func _ready() -> void:
	$VBoxContainer/VBox_Title/Label_Score.text = "Enemies killed: " + str(get_node("/root/GameState").kills)

	$VBoxContainer/VBox_Menu/Button_Stats.pressed.connect(_on_stats_pressed)
	$VBoxContainer/VBox_Menu/Button_Shop.pressed.connect(_on_shop_pressed)
	$VBoxContainer/VBox_Menu/Button_Restart.pressed.connect(_on_restart_pressed)

	var tween = create_tween()
	tween.tween_property(_label_title, "modulate:a", 1.0, 0.8)
	tween.tween_interval(0.3)
	tween.tween_property(_label_score, "modulate:a", 1.0, 0.5)
	tween.tween_interval(0.4)
	tween.tween_property(_vbox_menu, "modulate:a", 1.0, 0.5)

func _on_stats_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/stats_screen.tscn")

func _on_shop_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/shop.tscn")

func _on_restart_pressed() -> void:
	get_node("/root/GameState").reset()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
