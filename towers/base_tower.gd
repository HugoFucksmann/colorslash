extends Node2D

const CardDataScript = preload("res://scripts/card_data.gd")

# --- Properties ---
var health: int = 100
var fire_rate: float = 1.5
var projectile_scene: PackedScene
var attack_type: CardDataScript.AttackType
var size: Vector2i
var origin_tile: Vector2i

# --- Internal State ---
var player_id: int = 1

# --- Rotation ---
var rotation_speed: float = 1.5 # Radians per second
var max_angle: float = deg_to_rad(80) # 160 degrees total arc
var rotation_direction: int = 1

# --- Node References ---
@onready var fire_timer: Timer = $FireTimer
@onready var game_manager = get_tree().get_first_node_in_group("game_manager")

func _ready():
		fire_timer.timeout.connect(shoot)

func _physics_process(delta):
	if attack_type == CardDataScript.AttackType.ROTATING:
		# Update rotation
		rotation += rotation_speed * rotation_direction * delta

		# Change direction if limits are reached
		if rotation > max_angle:
			rotation = max_angle
			rotation_direction = -1
		elif rotation < -max_angle:
			rotation = -max_angle
			rotation_direction = 1

var num_projectiles: int = 1
var spread_angle: float = 0.0
var projectile_speed: float = 300.0
var projectile_damage: int = 20

func setup(card: CardData, p_id: int, tile_pos: Vector2i):
	# --- Base Properties from Card ---
	fire_rate = card.fire_rate
	projectile_scene = card.projectile_scene
	size = card.size
	player_id = p_id
	origin_tile = tile_pos
	num_projectiles = card.num_projectiles
	spread_angle = card.spread_angle
	projectile_speed = card.projectile_speed
	attack_type = card.attack_type

	# --- Calculate Leveled Stats ---
	var card_level = 1
	# Check if the PlayerData singleton is available in the scene tree
	var root = get_tree().get_root()
	if root.has_node("PlayerData"):
		var player_data = root.get_node("PlayerData")
		# For the opponent, we can simulate a level or keep it at 1. For now, let's assume level 1.
		if player_id == 1:
			card_level = player_data.get_card_level(card.resource_path)
	
	# Base stats from the card resource
	var base_health = card.health
	var base_damage = card.projectile_damage
	
	# Calculate final stats based on level
	health = base_health + (card_level - 1) * card.health_increase_per_level
	projectile_damage = base_damage + (card_level - 1) * card.damage_increase_per_level
	
	print("Tower %s (Lvl %d) placed. Health: %d, Damage: %d" % [card.card_name, card_level, health, projectile_damage])

	# --- Setup Tower ---
	# Configure and start the firing timer
	fire_timer.wait_time = 1.0 / fire_rate
	fire_timer.start()
	
	# Adjust visual size
	var visual = $ColorRect
	# The visual size is the card's size multiplied by the tile size from the TileSet.
	visual.size = size * game_manager.tile_map.tile_set.tile_size
	# Adjust color based on player
	if player_id == 2:
		visual.color = Color(1, 0.2, 0.2, 0.7) # Red
	else:
		visual.color = Color(0.2, 0.4, 1, 0.7) # Blue

func shoot():
	if not projectile_scene: return

	var base_direction = Vector2.UP if player_id == 1 else Vector2.DOWN

	match attack_type:
		CardDataScript.AttackType.ROTATING:
			var shoot_direction = base_direction.rotated(rotation)
			var projectile = projectile_scene.instantiate()
			get_parent().add_child(projectile)
			projectile.position = position
			projectile.setup(player_id, shoot_direction, projectile_speed, projectile_damage)

		CardDataScript.AttackType.FAN:
			var total_angle = deg_to_rad(spread_angle)
			var angle_step = total_angle / (num_projectiles - 1) if num_projectiles > 1 else 0.0
			var start_angle = -total_angle / 2.0

			for i in range(num_projectiles):
				var current_angle = start_angle + i * angle_step
				var shoot_direction = base_direction.rotated(current_angle)
				var projectile = projectile_scene.instantiate()
				get_parent().add_child(projectile)
				projectile.position = position
				projectile.setup(player_id, shoot_direction, projectile_speed, projectile_damage)

func take_damage(amount: int):
	health -= amount
	if health <= 0:
		destroy()

func destroy():
	# Notify the GameManager to free up the tiles this tower occupied
	game_manager.free_up_tiles(origin_tile, size)
	queue_free()
