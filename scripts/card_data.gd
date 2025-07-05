extends Resource
class_name CardData

enum AttackType { ROTATING, FAN }

@export var card_name: String = "Unnamed Card"
@export var cost: int = 1
@export var description: String = "Card description here."
@export var texture: Texture2D

# Tower Properties
@export var tower_scene: PackedScene
@export var size: Vector2i = Vector2i(1, 1)
@export var health: int = 100
@export var attack_type: AttackType = AttackType.ROTATING
@export var fire_rate: float = 1.5 # Shots per second

# Projectile Properties
@export var projectile_scene: PackedScene
@export var num_projectiles: int = 1
@export var spread_angle: float = 0.0
@export var projectile_speed: float = 300.0
@export var projectile_damage: int = 20

# --- Leveling System ---
@export var current_level: int = 1
@export var card_duplicates: int = 0
@export var cards_to_upgrade: Array[int] = [10, 20, 50, 100, 200] # Duplicates needed for each level-up
@export var gold_to_upgrade: Array[int] = [50, 150, 400, 1000, 2500] # Gold needed for each level-up
@export var health_increase_per_level: int = 25
@export var damage_increase_per_level: int = 5
