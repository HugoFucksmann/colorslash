extends Control

const CardDisplayScene = preload("res://scenes/card_display.tscn")

# --- UI Node References ---
@onready var deck_grid: HBoxContainer = $VBoxContainer/Panel_Deck/VBoxContainer/DeckGrid
@onready var collection_grid: GridContainer = $VBoxContainer/Panel_Collection/ScrollContainer/CollectionGrid

# --- Internal State ---
var _player_data

func _ready():
	if get_tree().has_node("/root/PlayerData"):
		_player_data = get_tree().get_root().get_node("PlayerData")
	else:
		push_error("PlayerData singleton not found!")
		return
		
	populate_collection_grid()
	populate_deck_grid()

func populate_collection_grid():
	# Clear previous cards
	for child in collection_grid.get_children():
		child.queue_free()

	for card_path in _player_data.all_card_paths:
		var card_display = CardDisplayScene.instantiate()
		collection_grid.add_child(card_display)
		card_display.setup(card_path)
		
		# Connect signals from the card display instance
		card_display.upgrade_requested.connect(_on_card_upgrade_requested)
		card_display.selected.connect(_on_collection_card_selected)

func populate_deck_grid():
	# Clear previous cards
	for child in deck_grid.get_children():
		child.queue_free()
		
	for card_path in _player_data.battle_deck:
		var card_display = CardDisplayScene.instantiate()
		deck_grid.add_child(card_display)
		card_display.setup(card_path)
		
		# Make deck cards non-interactive for simplicity, or add remove logic
		card_display.get_node("UpgradeButton").disabled = true

# --- Signal Handlers ---

func _on_card_upgrade_requested(card_path: String):
	var card_data: CardData = load(card_path)
	if _player_data.upgrade_card(card_data):
		# Refresh both grids to show updated levels and progress
		populate_collection_grid()
		populate_deck_grid()

func _on_collection_card_selected(card_path: String):
	# Logic to add the selected card to the deck
	if not _player_data.battle_deck.has(card_path):
		if _player_data.battle_deck.size() < _player_data.MAX_DECK_SIZE:
			_player_data.battle_deck.append(card_path)
			populate_deck_grid() # Refresh the deck display
		else:
			print("Deck is full!")
	else:
		# Optional: Logic to remove card from deck by tapping it in the collection
		_player_data.battle_deck.erase(card_path)
		populate_deck_grid()
