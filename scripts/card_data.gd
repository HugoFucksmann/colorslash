extends Resource
class_name CardData

@export var card_name: String = "Unnamed Card"
@export var cost: int = 1
@export var description: String = "Card description here."

# Tower Properties
@export var tower_scene: PackedScene
@export var size: Vector2i = Vector2i(1, 1)
@export var health: int = 100
@export var fire_rate: float = 1.5 # Shots per second

# Projectile Properties
@export var projectile_scene: PackedScene
