extends HBoxContainer

func _on_main_screen_button_pressed():
	SceneManager.switch_screen("res://scenes/main_screen.tscn")

func _on_deck_builder_button_pressed():
	SceneManager.switch_screen("res://scenes/deck_builder_screen.tscn")
