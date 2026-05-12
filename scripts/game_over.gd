extends Control

func _ready() -> void:
	var kills = get_node("/root/GameState").kills
	$VBoxContainer/Label_Score.text = "Enemies killed: " + str(kills)

func _on_stats_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/stats_screen.tscn")

func _on_restart_pressed() -> void:
	get_node("/root/GameState").reset()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
