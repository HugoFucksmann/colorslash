extends Node

# --- Player Resources ---
var gold: int = 1000
var diamonds: int = 50

# --- Player Inventory & Deck ---
# Structure: { "res://path/to/card.tres": { "count": 5, "level": 1 } }
var card_inventory: Dictionary = {}
# An array of card resource paths that are in the current battle deck
var battle_deck: Array[String] = []
const MAX_DECK_SIZE = 8

var all_card_paths: Array[String] = []

# --- Save/Load ---
const SAVE_FILE_PATH = "user://player_data.save"

func _ready():
	_discover_all_cards()
	load_data()
	# Populate with some default cards for testing if the inventory is empty
	if card_inventory.is_empty():
		print("Player data is empty. Populating with default cards for testing.")
		add_card("res://assets/cards/basic_tower_card.tres", 15)
		add_card("res://assets/cards/fan_tower_card.tres", 5)
		
		# Auto-populate the deck with the first available cards
		for card_path in card_inventory.keys():
			if battle_deck.size() < MAX_DECK_SIZE:
				battle_deck.append(card_path)

func _discover_all_cards():
	all_card_paths.clear()
	var dir = DirAccess.open("res://assets/cards")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				all_card_paths.append(dir.get_current_dir() + "/" + file_name)
			file_name = dir.get_next()
	else:
		print("ERROR: Could not open directory res://assets/cards")

# --- Public API ---

## Adds a specified amount of a card to the inventory.
func add_card(card_resource_path: String, amount: int):
	if not card_inventory.has(card_resource_path):
		card_inventory[card_resource_path] = { "count": 0, "level": 1 }
	
	card_inventory[card_resource_path]["count"] += amount
	print("Added %d of %s. New count: %d" % [amount, card_resource_path.get_file(), get_card_count(card_resource_path)])
	save_data()

## Returns the current level of a specific card.
func get_card_level(card_resource_path: String) -> int:
	if card_inventory.has(card_resource_path):
		return card_inventory[card_resource_path]["level"]
	return 1 # Default to level 1 if not found

## Returns the number of duplicates for a specific card.
func get_card_count(card_resource_path: String) -> int:
	if card_inventory.has(card_resource_path):
		return card_inventory[card_resource_path]["count"]
	return 0

## Checks if a card has enough duplicates to be upgraded.
func can_upgrade_card(card_data: CardData) -> bool:
	var card_path = card_data.resource_path
	if not card_inventory.has(card_path):
		return false
	
	var current_level = get_card_level(card_path)
	var current_count = get_card_count(card_path)
	
	# Check if there is a next level defined
	if current_level -1 >= card_data.cards_to_upgrade.size():
		return false # Max level reached
	
	var cards_needed = card_data.cards_to_upgrade[current_level - 1]
	var gold_needed = card_data.gold_to_upgrade[current_level - 1]
	return current_count >= cards_needed and gold >= gold_needed

## Upgrades a card to the next level if possible.
func upgrade_card(card_data: CardData) -> bool:
	if not can_upgrade_card(card_data):
		print("Cannot upgrade card: %s" % card_data.card_name)
		return false
	
	var card_path = card_data.resource_path
	var current_level = get_card_level(card_path)
	var cards_needed = card_data.cards_to_upgrade[current_level - 1]
	var gold_needed = card_data.gold_to_upgrade[current_level - 1]

	# Consume cards and gold, then increase level
	card_inventory[card_path]["count"] -= cards_needed
	gold -= gold_needed
	card_inventory[card_path]["level"] += 1
	
	print("Upgraded %s to level %d" % [card_data.card_name, get_card_level(card_path)])
	save_data()
	return true

# --- Deck Management ---

func add_card_to_deck(card_path: String) -> bool:
	if not battle_deck.has(card_path) and battle_deck.size() < MAX_DECK_SIZE:
		battle_deck.append(card_path)
		save_data()
		return true
	return false

func remove_card_from_deck(card_path: String) -> bool:
	if battle_deck.has(card_path):
		battle_deck.erase(card_path)
		save_data()
		return true
	return false

# --- Currency Management ---

func add_gold(amount: int):
	gold += amount
	save_data()

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		save_data()
		return true
	return false

func add_diamonds(amount: int):
	diamonds += amount
	save_data()

func spend_diamonds(amount: int) -> bool:
	if diamonds >= amount:
		diamonds -= amount
		save_data()
		return true
	return false

# --- Data Persistence ---

func save_data():
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		var data_to_save = {
			"gold": gold,
			"diamonds": diamonds,
			"card_inventory": card_inventory,
			"battle_deck": battle_deck
		}
		var json_string = JSON.stringify(data_to_save)
		file.store_string(json_string)
		file.close()
		print("Player data saved.")

func load_data():
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		print("No save file found.")
		return

	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		var parse_result = JSON.parse_string(json_string)
		if parse_result:
			var data = parse_result
			gold = data.get("gold", 1000)
			diamonds = data.get("diamonds", 50)
			card_inventory = data.get("card_inventory", {})
			# The array from JSON is generic, so we rebuild it to be a typed Array[String].
			var loaded_deck = data.get("battle_deck", [])
			battle_deck.clear()
			for card_path in loaded_deck:
				battle_deck.append(card_path)
			print("Player data loaded.")
		else:
			print("Failed to parse save file: %s" % parse_result.get_error_string())
		file.close()
