extends Node

# --- Game Settings ---
const MAP_WIDTH = 20
const MAP_HEIGHT = 12
const GAME_DURATION_SECONDS = 120

# --- Player State ---
var player_energy = 6.0
var opponent_energy = 3.0
const MAX_ENERGY = 12
const ENERGY_REGEN_RATE = 1.0

# --- Game State ---
var time_left = GAME_DURATION_SECONDS
var player_tile_count = 0
var opponent_tile_count = 0
var total_tiles = MAP_WIDTH * MAP_HEIGHT
var occupied_tiles = {} # {Vector2i: Node}
var play_area_rect: Rect2

# Game timer variables
var game_time = 120 # 2 minutes in seconds
var timer_label
var game_timer

# --- Node References ---
@export var tile_map: TileMap
@export var battle_ui: CanvasLayer
@onready var opponent_timer: Timer = $OpponentTimer

# --- Opponent AI ---
var opponent_cards: Array[CardData]
var opponent_card_to_play: CardData

func _ready():
	print("GameManager _ready() called.")
	# Ensure TileMap has a tile_set
	if tile_map.tile_set == null:
		var tile_set_resource = load("res://assets/tiles.tres")
		if tile_set_resource:
			tile_map.tile_set = tile_set_resource
			print("Loaded tile_set from resource")
		else:
			# Create a new TileSet programmatically if we can't load it
			print("Creating new TileSet programmatically")
			var new_tile_set = TileSet.new()
			new_tile_set.tile_size = Vector2i(32, 32)
			
			# Create a source for the tile set
			var atlas_source = TileSetAtlasSource.new()
			atlas_source.texture_region_size = Vector2i(32, 32)
			
			# Create a simple texture for the tiles with visible grid
			var img = Image.create(96, 32, false, Image.FORMAT_RGBA8)
			
			# Fill with base colors: gray, blue, red
			img.fill(Color(0.5, 0.5, 0.5, 1)) # Gray for neutral
			
			# Create the three colored tiles with borders
			for tile_idx in range(3):
				var base_x = tile_idx * 32
				var color = Color(0.5, 0.5, 0.5, 1) # Gray (neutral)
				
				if tile_idx == 1:
					color = Color(0.2, 0.4, 1, 1) # Blue (player)
				elif tile_idx == 2:
					color = Color(1, 0.2, 0.2, 1) # Red (opponent)
				
				# Fill the tile area with the base color
				for x in range(32):
					for y in range(32):
						img.set_pixel(base_x + x, y, color)
				
				# Add a darker border to make the grid visible
				var border_color = color.darkened(0.3)
				for x in range(32):
					# Horizontal borders
					img.set_pixel(base_x + x, 0, border_color)
					img.set_pixel(base_x + x, 31, border_color)
				
				for y in range(32):
					# Vertical borders
					img.set_pixel(base_x, y, border_color)
					img.set_pixel(base_x + 31, y, border_color)
			
			# Create texture from image
			var texture = ImageTexture.create_from_image(img)
			atlas_source.texture = texture
			
			# Add tiles to the atlas source
			atlas_source.create_tile(Vector2i(0, 0)) # Neutral (gray)
			atlas_source.create_tile(Vector2i(1, 0)) # Player (blue)
			atlas_source.create_tile(Vector2i(2, 0)) # Opponent (red)
			
			# Add the atlas source to the tile set
			new_tile_set.add_source(atlas_source, 0)
			
			# Assign the new tile set to the tile map
			tile_map.tile_set = new_tile_set
	
	generate_map()
	print("Map generation completed in _ready().")

	# Define the playable area based on the TileMap's used rectangle
	var used_rect = tile_map.get_used_rect()
	play_area_rect = Rect2(tile_map.map_to_local(used_rect.position), tile_map.map_to_local(used_rect.end) - tile_map.map_to_local(used_rect.position) + Vector2(32,32))
	
	# Make sure battle_ui exists before connecting
	if battle_ui != null:
		battle_ui.place_tower_at.connect(_on_place_tower_at)
	else:
		push_error("BattleUI not found!")
	
	opponent_cards.append(load("res://assets/cards/basic_tower_card.tres"))
	opponent_cards.append(load("res://assets/cards/fan_tower_card.tres"))
	
	# Create game timer
	game_timer = get_tree().create_timer(GAME_DURATION_SECONDS)
	game_timer.timeout.connect(_on_game_over)
	
	# Start opponent timer
	opponent_timer.timeout.connect(_on_opponent_timer_timeout)
	opponent_timer.start()
	
	# Create UI for game stats
	create_game_ui()

func _process(delta):
	time_left -= delta
	player_energy = min(player_energy + ENERGY_REGEN_RATE * delta, MAX_ENERGY)
	opponent_energy = min(opponent_energy + ENERGY_REGEN_RATE * delta, MAX_ENERGY)
	
	# Update UI
	if timer_label:
		var minutes = int(time_left) / 60
		var seconds = int(time_left) % 60
		timer_label.text = "%02d:%02d" % [minutes, seconds]
	
	# Calculate territory percentages
	var player_percentage = (float(player_tile_count) / total_tiles) * 100.0
	var opponent_percentage = (float(opponent_tile_count) / total_tiles) * 100.0
	
	# Update territory percentages in UI
	if get_node_or_null("../UI/PlayerPercentage"):
		get_node("../UI/PlayerPercentage").text = "Player: %.1f%%" % player_percentage
	
	if get_node_or_null("../UI/OpponentPercentage"):
		get_node("../UI/OpponentPercentage").text = "Opponent: %.1f%%" % opponent_percentage
	
	# Check for 90% victory condition during gameplay
	if player_percentage >= 90.0 or opponent_percentage >= 90.0:
		print("Game over condition met in _process(). Player: %.1f%%, Opponent: %.1f%%" % [player_percentage, opponent_percentage])
		_on_game_over()
	
	# Update battle UI data
	var ui_data = {
		"player_energy": player_energy,
		"time_left": time_left,
		"player_tiles": player_tile_count,
		"opponent_tiles": opponent_tile_count,
		"total_tiles": total_tiles
	}
	
	if battle_ui:
		battle_ui.update_ui(ui_data)

func generate_map():
	# Reset tile counts
	player_tile_count = 0
	opponent_tile_count = 0
	total_tiles = MAP_WIDTH * MAP_HEIGHT
	
	# Define tile coordinates in the atlas
	var neutral_tile = Vector2i(0, 0) # Gray
	var player_tile = Vector2i(1, 0)  # Blue
	var opponent_tile = Vector2i(2, 0) # Red
	
	# Create the map with player territories
	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			var tile_pos = Vector2i(x, y)
			var player_area_y_limit = MAP_HEIGHT / 2
			
			if y >= player_area_y_limit: # Bottom half - Player (blue)
				tile_map.set_cell(0, tile_pos, 0, player_tile)
				player_tile_count += 1
			else: # Top half - Opponent (red)
				tile_map.set_cell(0, tile_pos, 0, opponent_tile)
				opponent_tile_count += 1
	
	print("Map generated with ", player_tile_count, " player tiles and ", opponent_tile_count, " opponent tiles")

func _on_game_over():
	print("Entering _on_game_over() function.")
	print("Game Over!")
	
	# Calculate percentage of territory for each player
	var player_percentage = (float(player_tile_count) / total_tiles) * 100.0
	var opponent_percentage = (float(opponent_tile_count) / total_tiles) * 100.0
	
	print("Final territory - Player: %d tiles (%.1f%%), Opponent: %d tiles (%.1f%%)" % 
		[player_tile_count, player_percentage, opponent_tile_count, opponent_percentage])
	
	var winner_text = "It's a draw!"
	
	# Check for 90% territory victory condition
	if player_percentage >= 90.0:
		winner_text = "Player wins with dominant territory control!"
	elif opponent_percentage >= 90.0:
		winner_text = "Opponent wins with dominant territory control!"
	# Otherwise, check who has more territory
	elif player_tile_count > opponent_tile_count:
		winner_text = "Player wins with majority territory!"
	elif opponent_tile_count > player_tile_count:
		winner_text = "Opponent wins with majority territory!"
	
	# Create a game over display
	var game_over_panel = ColorRect.new()
	get_parent().add_child(game_over_panel)
	game_over_panel.color = Color(0, 0, 0, 0.7)
	game_over_panel.size = Vector2(600, 400)
	game_over_panel.position = Vector2(512, 300) - game_over_panel.size / 2
	
	# Add game over text
	var game_over_label = Label.new()
	game_over_panel.add_child(game_over_label)
	game_over_label.text = "GAME OVER\n\n" + winner_text + "\n\nPlayer: %.1f%%\nOpponent: %.1f%%" % [player_percentage, opponent_percentage]
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.size = game_over_panel.size
	
	print(winner_text)
	get_tree().paused = true

func _on_place_tower_at(card_data: CardData, screen_position: Vector2):
	var tile_pos = tile_map.local_to_map(tile_map.to_local(screen_position))
	if not is_placement_valid(1, card_data, tile_pos):
		print("Placement is not valid.")
		return
	if spend_energy(1, card_data.cost):
		place_tower(1, card_data, tile_pos)
	else:
		print("Not enough energy.")

func is_placement_valid(player_id: int, card: CardData, origin_tile: Vector2i) -> bool:
	var player_area_y_limit = MAP_HEIGHT / 2
	if player_id == 1 and origin_tile.y < player_area_y_limit: return false
	if player_id == 2 and origin_tile.y >= player_area_y_limit: return false
	for x in range(card.size.x):
		for y in range(card.size.y):
			var current_tile = origin_tile + Vector2i(x, y)
			if not tile_map.get_used_rect().has_point(current_tile): return false
			if occupied_tiles.has(current_tile): return false
	return true

func place_tower(player_id: int, card: CardData, origin_tile: Vector2i):
	var tower_scene = card.tower_scene
	if not tower_scene: return
	
	var tower_instance = tower_scene.instantiate()
	get_parent().add_child(tower_instance)
	
	# Add to the correct group for targeting
	var group_name = "player%d_towers" % player_id
	tower_instance.add_to_group(group_name)
	
	# Get tile size safely with fallback to default size if tile_set is null
	var tile_size = Vector2i(32, 32) # Default fallback size
	if tile_map.tile_set != null:
		tile_size = tile_map.tile_set.tile_size
	
	var size_offset = Vector2(card.size) * Vector2(tile_size) / 2.0
	var world_pos = tile_map.map_to_local(origin_tile) + size_offset
	tower_instance.setup(card, player_id, origin_tile)
	tower_instance.global_position = world_pos
	
	for x in range(card.size.x):
		for y in range(card.size.y):
			var current_tile = origin_tile + Vector2i(x, y)
			occupied_tiles[current_tile] = tower_instance
			claim_tile(player_id, current_tile)

func free_up_tiles(origin_tile: Vector2i, size: Vector2i):
	for x in range(size.x):
		for y in range(size.y):
			var current_tile = origin_tile + Vector2i(x, y)
			if occupied_tiles.has(current_tile):
				occupied_tiles.erase(current_tile)
				tile_map.set_cell(0, current_tile, 0, Vector2i(0, 0))

func _on_opponent_timer_timeout():
	# Select a random card from the opponent's available cards
	var card = opponent_cards[randi() % opponent_cards.size()]
	
	if opponent_energy >= card.cost:
		var spawn_x = randi_range(0, MAP_WIDTH - card.size.x)
		var spawn_y = randi_range(0, MAP_HEIGHT / 2 - card.size.y)
		var tile_pos = Vector2i(spawn_x, spawn_y)
		if is_placement_valid(2, card, tile_pos):
			if spend_energy(2, card.cost):
				place_tower(2, card, tile_pos)

func claim_tile(player_id: int, tile_pos: Vector2i):
	# Check if the tile position is valid
	if not tile_map.get_used_rect().has_point(tile_pos):
		print("Cannot claim tile outside map bounds: ", tile_pos)
		return
	
	# Get the current owner of the tile
	var current_tile_coords = tile_map.get_cell_atlas_coords(0, tile_pos)
	var source_id = tile_map.get_cell_source_id(0, tile_pos)

	if source_id == -1:
		# This can happen if the tile is empty. Assume source 0 for setting new tile.
		source_id = 0
		if current_tile_coords == Vector2i(-1,-1):
			# Tile is completely empty, no previous owner
			pass 

	var current_owner_id = current_tile_coords.x
	
	# If the tile already belongs to this player, do nothing
	if current_owner_id == player_id:
		return
	
	# Update tile counts
	if current_owner_id == 1: 
		player_tile_count -= 1
		print("Player lost a tile, now has: ", player_tile_count)
	elif current_owner_id == 2: 
		opponent_tile_count -= 1
		print("Opponent lost a tile, now has: ", opponent_tile_count)
	
	# Set the new tile owner
	var new_tile_coords = Vector2i(player_id, 0)
	tile_map.set_cell(0, tile_pos, source_id, new_tile_coords)
	
	# Update tile counts for the new owner
	if player_id == 1: 
		player_tile_count += 1
		print("Player gained a tile, now has: ", player_tile_count)
	elif player_id == 2: 
		opponent_tile_count += 1
		print("Opponent gained a tile, now has: ", opponent_tile_count)
	
	# Create a visual effect to show the tile being claimed
	var tile_center = tile_map.map_to_local(tile_pos)
	var claim_effect = ColorRect.new()
	get_parent().add_child(claim_effect)
	claim_effect.size = Vector2(32, 32) # Same as tile size
	claim_effect.position = tile_center - claim_effect.size / 2
	
	# Set color based on player
	if player_id == 1:
		claim_effect.color = Color(0.2, 0.4, 1, 0.5) # Blue
	else:
		claim_effect.color = Color(1, 0.2, 0.2, 0.5) # Red
	
	# Animate and remove the effect
	var tween = get_tree().create_tween()
	tween.tween_property(claim_effect, "size", Vector2(40, 40), 0.3)
	tween.parallel().tween_property(claim_effect, "position", tile_center - Vector2(20, 20), 0.3)
	tween.parallel().tween_property(claim_effect, "modulate:a", 0.0, 0.3)
	tween.tween_callback(claim_effect.queue_free)

func spend_energy(player_id: int, amount: float) -> bool:
	if player_id == 1:
		if player_energy >= amount:
			player_energy -= amount
			return true
	elif player_id == 2:
		if opponent_energy >= amount:
			opponent_energy -= amount
			return true
	return false

func create_game_ui():
	# Create a UI container
	var ui_container = Control.new()
	ui_container.name = "UI"
	get_parent().add_child(ui_container)
	
	# Create timer display
	timer_label = Label.new()
	timer_label.name = "TimerLabel"
	ui_container.add_child(timer_label)
	timer_label.text = "02:00"
	timer_label.position = Vector2(512, 30)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_color_override("font_color", Color(1, 1, 1))
	timer_label.add_theme_font_size_override("font_size", 24)
	
	# Create player territory percentage display
	var player_percentage_label = Label.new()
	player_percentage_label.name = "PlayerPercentage"
	ui_container.add_child(player_percentage_label)
	player_percentage_label.text = "Player: 50.0%"
	player_percentage_label.position = Vector2(100, 30)
	player_percentage_label.add_theme_color_override("font_color", Color(0.2, 0.4, 1))
	player_percentage_label.add_theme_font_size_override("font_size", 18)
	
	# Create opponent territory percentage display
	var opponent_percentage_label = Label.new()
	opponent_percentage_label.name = "OpponentPercentage"
	ui_container.add_child(opponent_percentage_label)
	opponent_percentage_label.text = "Opponent: 50.0%"
	opponent_percentage_label.position = Vector2(900, 30)
	opponent_percentage_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	opponent_percentage_label.add_theme_font_size_override("font_size", 18)
