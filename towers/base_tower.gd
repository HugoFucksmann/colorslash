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

var num_projectiles: int = 1
var spread_angle: float = 0.0
var projectile_speed: float = 300.0
var projectile_damage: int = 20

func setup(card: CardData, p_id: int, tile_pos: Vector2i):
	# Set properties from the card
	health = card.health
	fire_rate = card.fire_rate
	projectile_scene = card.projectile_scene
	size = card.size
	player_id = p_id
	origin_tile = tile_pos
	num_projectiles = card.num_projectiles
	spread_angle = card.spread_angle
	projectile_speed = card.projectile_speed
	projectile_damage = card.projectile_damage
	
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

	var base_direction = Vector2.UP if player_id == 1 else Vector2.DOWN
	
	if num_projectiles == 1:
		var projectile = projectile_scene.instantiate()
		get_parent().add_child(projectile)
		projectile.position = position
		projectile.setup(player_id, base_direction, projectile_speed, projectile_damage)
	else:
		var start_angle = -spread_angle / 2.0
		var angle_step = spread_angle / (num_projectiles - 1) if num_projectiles > 1 else 0.0
		
		for i in range(num_projectiles):
			var current_angle = start_angle + i * angle_step
			var rotated_direction = base_direction.rotated(deg_to_rad(current_angle))
			
			var projectile = projectile_scene.instantiate()
			get_parent().add_child(projectile)
			projectile.position = position
			projectile.setup(player_id, rotated_direction, projectile_speed, projectile_damage)

func take_damage(amount: int):
	health -= amount
	if health <= 0:
		destroy()

func destroy():
	# Notify the GameManager to free up the tiles this tower occupied
	game_manager.free_up_tiles(origin_tile, size)
	queue_free()
