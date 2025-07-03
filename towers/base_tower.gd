extends Node2D

# --- Properties ---
var health: int = 100
var fire_rate: float = 1.5
var projectile_scene: PackedScene
var size: Vector2i
var origin_tile: Vector2i

# --- Internal State ---
var player_id: int = 1

# --- Node References ---
@onready var fire_timer: Timer = $FireTimer
@onready var game_manager = get_tree().get_first_node_in_group("game_manager")

func _ready():
	fire_timer.timeout.connect(shoot)

func setup(card: CardData, p_id: int, tile_pos: Vector2i):
	# Set properties from the card
	health = card.health
	fire_rate = card.fire_rate
	projectile_scene = card.projectile_scene
	size = card.size
	player_id = p_id
	origin_tile = tile_pos
	
	# Configure and start the firing timer
	fire_timer.wait_time = 1.0 / fire_rate
	fire_timer.start()
	
	# Adjust visual size
	var visual = $ColorRect
	visual.size = size * game_manager.tile_map.tile_set.tile_size
	# Adjust color based on player
	if player_id == 2:
		visual.color = Color(1, 0.2, 0.2, 0.7) # Red
	else:
		visual.color = Color(0.2, 0.4, 1, 0.7) # Blue

func shoot():
	if not projectile_scene: return
	
	# Simple targeting: fire straight ahead
	var target_y = -100 if player_id == 1 else game_manager.tile_map.get_used_rect().end.y * 32 + 100
	var target_pos = Vector2(position.x, target_y)
	
	var projectile = projectile_scene.instantiate()
	get_parent().add_child(projectile)
	projectile.position = position
	projectile.setup(player_id, target_pos)

func take_damage(amount: int):
	health -= amount
	if health <= 0:
		destroy()

func destroy():
	# Notify the GameManager to free up the tiles this tower occupied
	game_manager.free_up_tiles(origin_tile, size)
	queue_free()
