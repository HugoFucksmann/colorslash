extends CanvasLayer

const CardUI = preload("res://scenes/card_ui.tscn")

# --- State ---
var player_deck: Array[CardData] = []
var placement_ghost: ColorRect = null
var dragged_card_data: CardData = null
var drop_zone_instance: Control = null
const DropZoneScript = preload("res://scripts/drop_zone.gd")

# --- Node References ---
@onready var card_container: HBoxContainer = %CardContainer
@onready var energy_bar: ProgressBar = %EnergyBar
@onready var time_label: Label = %TimeLabel
@onready var player_territory_label: Label = %PlayerTerritoryLabel
@onready var opponent_territory_label: Label = %OpponentTerritoryLabel
@onready var game_manager = get_tree().get_first_node_in_group("game_manager")

func _ready():


	# Esperar un frame para asegurarnos de que todos los nodos estén listos
	await get_tree().process_frame
	
	# Cargar las cartas disponibles
	var basic_card = load("res://assets/cards/basic_tower_card.tres")
	var fan_card = load("res://assets/cards/fan_tower_card.tres")
	
	var deck: Array[CardData] = []
	if basic_card:
		print("Carta básica cargada correctamente: " + basic_card.card_name)
		deck.append(basic_card)
		deck.append(basic_card) # Add another basic card
	if fan_card:
		print("Carta de abanico cargada correctamente: " + fan_card.card_name)
		deck.append(fan_card)
		
	# Configurar el mazo
	set_deck(deck)
	
	# Verificar que el contenedor de cartas sea visible
	print("CardContainer visible: " + str(card_container.visible))
	print("CardContainer rect_size: " + str(card_container.size))

func _can_drop_data(_pos, data):
	return data is CardData

func _drop_data(_pos, data):
	if game_manager.is_placement_valid(1, data, get_tile_pos_from_mouse()):
		if game_manager.spend_energy(1, data.cost):
			game_manager.place_tower(1, data, get_tile_pos_from_mouse())
		else:
			print("No hay suficiente energía para colocar la torre.")
	handle_drag_end()

func _process(_delta):
	if placement_ghost:
		update_placement_ghost()

func set_deck(deck: Array[CardData]):
	player_deck = deck
	print("Configurando mazo con %d cartas" % deck.size())
	
	# Limpiar el contenedor de cartas
	for child in card_container.get_children():
		child.queue_free()
	
	# Añadir las nuevas cartas
	for card_data in player_deck:
		var card_ui_instance = CardUI.instantiate()
		card_container.add_child(card_ui_instance)
		card_ui_instance.set_card_data(card_data)
		card_ui_instance.drag_started.connect(_on_card_drag_started)
		print("Carta añadida: %s (Coste: %d)" % [card_data.card_name, card_data.cost])
	
	# Verificar que las cartas se hayan añadido
	print("Total de cartas en UI: %d" % card_container.get_child_count())

func update_ui(data: Dictionary):
	if not is_node_ready(): return

	if data.has("player_energy"):
		energy_bar.max_value = game_manager.MAX_ENERGY
		energy_bar.value = data.player_energy
	
	if data.has("time_left"):
		var minutes = floor(data.time_left / 60)
		var seconds = int(fmod(data.time_left, 60))
		time_label.text = "%02d:%02d" % [minutes, seconds]

	if data.has("player_tiles") and data.has("total_tiles") and data.total_tiles > 0:
		var player_percentage = (float(data.player_tiles) / data.total_tiles) * 100.0
		player_territory_label.text = "Player: %.1f%%" % player_percentage

	if data.has("opponent_tiles") and data.has("total_tiles") and data.total_tiles > 0:
		var opponent_percentage = (float(data.opponent_tiles) / data.total_tiles) * 100.0
		opponent_territory_label.text = "Opponent: %.1f%%" % opponent_percentage

func _on_card_drag_started(card_data: CardData):
	if placement_ghost:
		placement_ghost.queue_free()

	dragged_card_data = card_data
	placement_ghost = ColorRect.new()
	placement_ghost.size = Vector2(dragged_card_data.size) * Vector2(32, 32)
	# Add ghost to the main scene tree to use global coordinates
	get_tree().root.add_child(placement_ghost)

	# Create and configure the drop zone
	drop_zone_instance = Control.new()
	drop_zone_instance.set_script(DropZoneScript)
	drop_zone_instance.battle_ui = self
	drop_zone_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(drop_zone_instance)

func handle_drag_end():
	if is_instance_valid(placement_ghost):
		placement_ghost.queue_free()
		placement_ghost = null
	
	if is_instance_valid(drop_zone_instance):
			drop_zone_instance.queue_free()
			drop_zone_instance = null

	dragged_card_data = null

func update_placement_ghost():
	if not game_manager or not game_manager.tile_map or not is_instance_valid(placement_ghost):
		return

	var tile_map = game_manager.tile_map
	var tile_pos = get_tile_pos_from_mouse()

	# Snap ghost to grid
	placement_ghost.global_position = tile_map.map_to_local(tile_pos)

	# Check for validity and change color
	if game_manager.is_placement_valid(1, dragged_card_data, tile_pos):
		placement_ghost.color = Color(0, 1, 0, 0.5) # Green
	else:
		placement_ghost.color = Color(1, 0, 0, 0.5) # Red

func get_tile_pos_from_mouse() -> Vector2i:
	var tile_map = game_manager.tile_map
	# Convert screen coordinates to world coordinates
	var screen_pos = get_viewport().get_mouse_position()
	var world_pos = get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	# Convert world coordinates to tilemap's local coordinates, then to map coordinates
	var local_pos = tile_map.to_local(world_pos)
	return tile_map.local_to_map(local_pos)
