extends Node

# Reference to the node that will hold the current screen content.
var screen_container: Node = null

# Path to the current screen scene.
var current_screen_path: String = ""

# Changes the currently displayed screen.
func switch_screen(screen_path: String):
	if screen_path == current_screen_path:
		return # Don't reload the same screen

	# Remove the old screen if it exists.
	if screen_container.get_child_count() > 0:
		for child in screen_container.get_children():
			child.queue_free()

	# Load and instance the new screen.
	var screen_scene = load(screen_path)
	var screen_instance = screen_scene.instantiate()
	screen_container.add_child(screen_instance)
	current_screen_path = screen_path
