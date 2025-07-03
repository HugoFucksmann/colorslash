extends CanvasLayer

const CardUI = preload("res://scenes/card_ui.tscn")

# Signal to be emitted when the player confirms a tower placement
signal place_tower_at(card_data, screen_position)

# --- State ---
var player_deck: Array[CardData] = []
var selected_card: CardData = null # The card we are currently trying to place
var placement_ghost: Node2D = null # The visual "ghost" of the tower on the cursor

# --- Node References ---
@onready var card_container: HBoxContainer = $CardContainer
@onready var energy_bar: ProgressBar = $MarginContainer/VBoxContainer/EnergyBar
@onready var time_label: Label = $MarginContainer/VBoxContainer/TimeLabel
@onready var player_territory_label: Label = $MarginContainer/VBoxContainer/PlayerTerritoryLabel
@onready var opponent_territory_label: Label = $MarginContainer/VBoxContainer/OpponentTerritoryLabel
@onready var game_manager = get_tree().get_first_node_in_group("game_manager")

func _ready():
	var default_card = load("res://assets/cards/basic_tower_card.tres")
	if default_card:
		set_deck([default_card, default_card, default_card, default_card])

func _unhandled_input(event: InputEvent):
	# Handle touch screen presses and mouse clicks universally
	if selected_card and event is InputEventScreenTouch and event.is_pressed():
		handle_placement_attempt(event.position)
	elif selected_card and event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_LEFT:
			handle_placement_attempt(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_placement()

func handle_placement_attempt(screen_position: Vector2):
	if game_manager == null:
		push_error("Game manager is null")
		cancel_placement()
		return
	
	var tile_map = game_manager.tile_map
	if tile_map == null:
		push_error("TileMap is null")
		cancel_placement()
		return
	
	# Convert screen coordinates to tile map coordinates
	var tile_pos = tile_map.local_to_map(tile_map.to_local(screen_position))
	
	emit_signal("place_tower_at", selected_card, screen_position) # Pass screen_position instead of tile_pos
	cancel_placement()

func _process(delta):
	# If we are in placement mode, make the ghost follow the cursor/touch
	if placement_ghost and game_manager != null:
		var tile_map = game_manager.tile_map
		if tile_map != null:
			var screen_pos = get_viewport().get_mouse_position()
			var tile_pos = tile_map.local_to_map(tile_map.to_local(screen_pos))
			placement_ghost.global_position = tile_map.map_to_local(tile_pos)
			# TODO: Add visual feedback (green/red) if placement is valid
		else:
			# Fallback if tile_map is null - just follow mouse position
			placement_ghost.global_position = get_viewport().get_mouse_position()

func set_deck(deck: Array[CardData]):
	player_deck = deck
	for child in card_container.get_children():
		child.queue_free()
	
	for card_data in player_deck:
		var card_ui_instance = CardUI.instantiate()
		card_container.add_child(card_ui_instance)
		card_ui_instance.set_card_data(card_data)
		card_ui_instance.card_selected.connect(_on_card_selected)

func update_ui(data: Dictionary):
	# This part remains the same
	pass # For brevity, assuming no changes here

func _on_card_selected(card_data: CardData):
	# If we are already placing a card, cancel it first
	if placement_ghost:
		cancel_placement()
		
	# Enter placement mode
	selected_card = card_data
	
	# Create the placement ghost
	if selected_card.tower_scene:
		placement_ghost = selected_card.tower_scene.instantiate()
		# Make it semi-transparent
		placement_ghost.modulate = Color(1, 1, 1, 0.5)
		add_child(placement_ghost)

func cancel_placement():
	if placement_ghost:
		placement_ghost.queue_free()
		placement_ghost = null
	selected_card = null
