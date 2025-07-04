extends Control

func _on_start_game_button_pressed():
	# This will eventually load the main game scene.
	# For now, we can just print a message.
	print("Start Game button pressed!")
	get_tree().change_scene_to_file("res://scenes/main_arena.tscn")
