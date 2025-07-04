extends Node2D

var velocity: Vector2 = Vector2.ZERO
var player_id: int = 1
var damage: int = 20

@onready var game_manager = get_tree().get_first_node_in_group("game_manager")
func _process(delta):
	# Move the projectile
	position += velocity * delta

	# Check for game area boundaries and bounce
	var play_area = game_manager.play_area_rect
	if position.x < play_area.position.x or position.x > play_area.end.x:
		velocity.x *= -1
		position.x = clamp(position.x, play_area.position.x, play_area.end.x)

	if position.y < play_area.position.y or position.y > play_area.end.y:
		velocity.y *= -1
		position.y = clamp(position.y, play_area.position.y, play_area.end.y)

	# Check for collisions with tiles during movement
	check_tile_collision()

func setup(p_id: int, direction: Vector2, p_speed: float, p_damage: int):
	player_id = p_id
	velocity = direction.normalized() * p_speed
	damage = p_damage
	
	# Set color based on player_id
	if player_id == 1:
		modulate = Color(0.2, 0.4, 1, 1) # Blue
	else:
		modulate = Color(1, 0.2, 0.2, 1) # Red

func impact(impact_pos: Vector2):
	print("[PROJECTILE] Impact at position: %s" % impact_pos)
	
	var tile_map = game_manager.tile_map
	if tile_map == null:
		print("[ERROR] TileMap is null, destroying projectile")
		create_impact_effect(Color(1, 0, 0, 0.8), impact_pos)
		queue_free()
		return
	
	var tile_pos = tile_map.local_to_map(impact_pos)
	print("[PROJECTILE] Hit tile at map position: ", tile_pos)
	
	# Get the current tile owner
	var current_tile_coords = tile_map.get_cell_atlas_coords(0, tile_pos)
	var current_owner_id = current_tile_coords.x if current_tile_coords != Vector2i(-1, -1) else 0
	
	print("[PROJECTILE] Tile current owner: Player ", current_owner_id, ", Projectile from Player ", player_id)
	
	var impact_color = Color(1, 1, 0, 0.8) # Default yellow
	
	# Only proceed if this is an enemy tile or neutral tile
	if current_owner_id != player_id:
		# Check if there is an enemy tower on the tile
		if game_manager.occupied_tiles.has(tile_pos):
			var tower = game_manager.occupied_tiles[tile_pos]
			if tower.player_id != player_id:
				tower.take_damage(damage)
				print("[PROJECTILE] Hit enemy tower! Remaining health: %d" % tower.health)
				impact_color = Color(1, 0.3, 0, 0.8)
				
				var damage_label = Label.new()
				get_parent().add_child(damage_label)
				damage_label.text = "-%d" % damage
				damage_label.position = impact_pos - Vector2(10, 20)
				damage_label.modulate = Color(1, 0, 0)
				
				var damage_tween = get_tree().create_tween()
				damage_tween.tween_property(damage_label, "position:y", damage_label.position.y - 30, 0.5)
				damage_tween.parallel().tween_property(damage_label, "modulate:a", 0.0, 0.5)
				damage_tween.tween_callback(damage_label.queue_free)
		
		game_manager.claim_tile(player_id, tile_pos)
		print("[PROJECTILE] Claiming tile at ", tile_pos, " for player ", player_id)
		
		create_impact_effect(impact_color, impact_pos)
		
		var player_percentage = (float(game_manager.player_tile_count) / game_manager.total_tiles) * 100.0
		var opponent_percentage = (float(game_manager.opponent_tile_count) / game_manager.total_tiles) * 100.0
		print("[GAME] Territory - Player: %.1f%%, Opponent: %.1f%%" % [player_percentage, opponent_percentage])
		
		if player_percentage >= 90.0 or opponent_percentage >= 90.0:
			print("[GAME] 90% territory reached, ending game")
			game_manager._on_game_over()
		
		# Destroy the projectile on successful impact with enemy tile
		print("[PROJECTILE] Destroying projectile after impact")
		queue_free()
	else:
		# If it hits its own territory, it should just pass through, so no action needed.
		# We can add a small visual effect or sound later if desired.
		pass

func create_impact_effect(color: Color, effect_pos: Vector2):
	var impact_effect = ColorRect.new()
	get_parent().add_child(impact_effect)
	impact_effect.size = Vector2(16, 16)
	impact_effect.position = effect_pos - impact_effect.size / 2
	impact_effect.color = color
	
	var tween = get_tree().create_tween()
	tween.tween_property(impact_effect, "size", Vector2(24, 24), 0.2)
	tween.parallel().tween_property(impact_effect, "position", effect_pos - Vector2(12, 12), 0.2)
	tween.tween_property(impact_effect, "modulate:a", 0.0, 0.3)
	tween.tween_callback(impact_effect.queue_free)

func check_tile_collision():
	var tile_map = game_manager.tile_map
	if tile_map == null: return
	
	var current_tile_pos = tile_map.local_to_map(position)
	
	if not tile_map.get_used_rect().has_point(current_tile_pos):
		return
	
	var current_tile_coords = tile_map.get_cell_atlas_coords(0, current_tile_pos)
	if current_tile_coords == Vector2i(-1, -1): return
	
	var current_owner_id = current_tile_coords.x
	
	# If we're over an enemy tile, trigger impact and destroy projectile
	if current_owner_id != 0 and current_owner_id != player_id:
		print("[PROJECTILE] Collided with enemy tile during movement")
		impact(position)
		return
