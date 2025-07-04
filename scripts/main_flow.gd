extends Control

@onready var screen_container = $VBoxContainer/ScreenContainer

func _ready():
	# Pass the screen container to the SceneManager so it knows where to put the screens.
	SceneManager.screen_container = screen_container
	
	# Load the initial screen.
	SceneManager.switch_screen("res://scenes/main_screen.tscn")
