extends Node2D

var speed: float = 300.0
var target_pos: Vector2
var player_id: int = 1

@onready var game_manager = get_tree().get_first_node_in_group("game_manager")

func _process(delta):
	# Move towards the target
	position = position.move_toward(target_pos, speed * delta)
	
	# Check if the target is reached
	if position.is_equal_approx(target_pos):
		print("[PROJECTILE] Target reached, processing impact...")
		impact()
	
	# Check for collisions with tiles during movement
	check_tile_collision()

func setup(p_id: int, t_pos: Vector2):
	player_id = p_id
	target_pos = t_pos
	
	# Set color based on player_id
	if player_id == 1:
		modulate = Color(0.2, 0.4, 1, 1) # Blue
	else:
		modulate = Color(1, 0.2, 0.2, 1) # Red

func impact():
	print("[PROJECTILE] Impact at position: %s" % target_pos)
	
	# Get the tile map coordinates of the impact
	var tile_map = game_manager.tile_map
	if tile_map == null:
		print("[ERROR] TileMap is null, destroying projectile")
		create_impact_effect(Color(1, 0, 0, 0.8)) # Red error effect
		queue_free()
		return
	
	var tile_pos = tile_map.local_to_map(target_pos)
	print("[PROJECTILE] Hit tile at map position: ", tile_pos)
	
	# Check if the tile is within the map bounds
	if not tile_map.get_used_rect().has_point(tile_pos):
		print("[PROJECTILE] Hit outside map bounds, destroying projectile")
		create_impact_effect(Color(0.5, 0.5, 0.5, 0.8)) # Gray effect for out of bounds
		queue_free()
		return
	
	# Get the current tile owner
	var current_tile_coords = tile_map.get_cell_atlas_coords(0, tile_pos)
	var current_owner_id = current_tile_coords.x if current_tile_coords != Vector2i(-1, -1) else 0
	
	print("[PROJECTILE] Tile current owner: Player ", current_owner_id, ", Projectile from Player ", player_id)
	
	# Create appropriate impact effect based on what was hit
	var impact_color = Color(1, 1, 0, 0.8) # Default yellow
	
	# Only proceed if this is an enemy tile or neutral tile
	if current_owner_id != player_id:
		# Check if there is an enemy tower on the tile
		var damage_dealt = false
		if game_manager.occupied_tiles.has(tile_pos):
			var tower = game_manager.occupied_tiles[tile_pos]
			# Check if it's an enemy tower
			if tower.player_id != player_id:
				# Deal damage to the tower
				tower.take_damage(20) # Deal 20 damage per hit
				damage_dealt = true
				print("[PROJECTILE] Hit enemy tower! Remaining health: %d" % tower.health)
				impact_color = Color(1, 0.3, 0, 0.8) # Orange for tower hit
				
				# Create a damage number effect
				var damage_label = Label.new()
				get_parent().add_child(damage_label)
				damage_label.text = "-20"
				damage_label.position = target_pos - Vector2(10, 20)
				damage_label.modulate = Color(1, 0, 0)
				
				# Animate and remove the damage number
				var damage_tween = get_tree().create_tween()
				damage_tween.tween_property(damage_label, "position:y", damage_label.position.y - 30, 0.5)
				damage_tween.parallel().tween_property(damage_label, "modulate:a", 0.0, 0.5)
				damage_tween.tween_callback(damage_label.queue_free)
		
		# Claim the tile for the player - always do this when hitting enemy territory
		game_manager.claim_tile(player_id, tile_pos)
		print("[PROJECTILE] Claiming tile at ", tile_pos, " for player ", player_id)
		
		# Create an impact effect
		create_impact_effect(impact_color)
		
		# Check for victory condition after each hit (90% territory)
		var player_percentage = (float(game_manager.player_tile_count) / game_manager.total_tiles) * 100.0
		var opponent_percentage = (float(game_manager.opponent_tile_count) / game_manager.total_tiles) * 100.0
		print("[GAME] Territory - Player: %.1f%%, Opponent: %.1f%%" % [player_percentage, opponent_percentage])
		
		# If either player reaches 90% territory, end the game immediately
		if player_percentage >= 90.0 or opponent_percentage >= 90.0:
			print("[GAME] 90% territory reached, ending game")
			game_manager._on_game_over()
	else:
		print("[PROJECTILE] Hit own territory, no effect")
		create_impact_effect(Color(0.5, 0.5, 1, 0.5)) # Light blue for own territory
	
	# Always destroy the projectile on impact
	print("[PROJECTILE] Destroying projectile after impact")
	queue_free()

func create_impact_effect(color: Color):
	# Create a visual effect at impact location
	var impact_effect = ColorRect.new()
	get_parent().add_child(impact_effect)
	impact_effect.size = Vector2(16, 16)
	impact_effect.position = target_pos - impact_effect.size / 2
	impact_effect.color = color
	
	# Make the effect disappear after a short time
	var tween = get_tree().create_tween()
	tween.tween_property(impact_effect, "size", Vector2(24, 24), 0.2)
	tween.parallel().tween_property(impact_effect, "position", target_pos - Vector2(12, 12), 0.2)
	tween.tween_property(impact_effect, "modulate:a", 0.0, 0.3)
	tween.tween_callback(impact_effect.queue_free)


func check_tile_collision():
	# Check if we're over an enemy tile during movement
	var tile_map = game_manager.tile_map
	if tile_map == null:
		return
	
	# Get current tile position
	var current_tile_pos = tile_map.local_to_map(position)
	
	# Check if this is a valid tile
	if not tile_map.get_used_rect().has_point(current_tile_pos):
		return
	
	# Get the current tile owner
	var current_tile_coords = tile_map.get_cell_atlas_coords(0, current_tile_pos)
	if current_tile_coords == Vector2i(-1, -1):
		return
	
	var current_owner_id = current_tile_coords.x
	
	# If we're over an enemy tile or tower, trigger impact
	if current_owner_id != player_id:
		# Check if there's an enemy tower here
		if game_manager.occupied_tiles.has(current_tile_pos):
			var tower = game_manager.occupied_tiles[current_tile_pos]
			if tower.player_id != player_id:
				print("[PROJECTILE] Collided with enemy tower during movement")
				target_pos = position # Set impact position to current position
				impact()
				return
