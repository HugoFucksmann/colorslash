extends Panel

signal drag_started(card_data: CardData)

# The CardData resource this UI represents
var card_data: CardData

# Node references
@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var cost_label: Label = $MarginContainer/VBoxContainer/CostLabel
@onready var description_label: Label = $MarginContainer/VBoxContainer/DescriptionLabel
@onready var texture_rect: TextureRect = $TextureRect
@onready var level_label: Label = $MarginContainer/VBoxContainer/LevelLabel
@onready var progress_bar: ProgressBar = $MarginContainer/VBoxContainer/LevelProgressBar
@onready var upgrade_button: Button = $MarginContainer/VBoxContainer/UpgradeButton

# Public function to set the card data and update the UI
func set_card_data(data: CardData):
	card_data = data
	
	if card_data:
		name_label.text = card_data.card_name
		cost_label.text = "Cost: %d" % card_data.cost
		description_label.text = card_data.description
		# Generate and apply a solid color texture if none is provided
		if card_data.texture:
			texture_rect.texture = card_data.texture
		else:
			texture_rect.texture = _generate_solid_color_texture(card_data.card_name)
		level_label.text = "Level %d" % card_data.current_level

		# Update progress bar
		if card_data.current_level -1 < card_data.cards_to_upgrade.size():
			var needed = card_data.cards_to_upgrade[card_data.current_level - 1]
			var have = card_data.card_duplicates
			progress_bar.max_value = needed
			progress_bar.value = have
		else:
			# Max level
			progress_bar.value = progress_bar.max_value

		# Handle upgrade button visibility
		upgrade_button.visible = PlayerData.can_upgrade_card(card_data)
		upgrade_button.text = "Upgrade for %d G" % card_data.gold_to_upgrade[card_data.current_level - 1] if upgrade_button.visible else "Upgrade"

func _ready():
	upgrade_button.pressed.connect(_on_upgrade_button_pressed)

func _on_upgrade_button_pressed():
	if PlayerData.upgrade_card(card_data):
		# Refresh the UI after upgrade
		set_card_data(card_data)

func _generate_solid_color_texture(seed: String) -> ImageTexture:
	var h = hash(seed)
	var color = Color.from_hsv(
		(h & 0xFF) / 255.0, # Hue
		0.7, # Saturation
		0.9 # Value
	)
	
	var img = Image.create(64, 64, false, Image.FORMAT_RGB8)
	img.fill(color)
	var tex = ImageTexture.create_from_image(img)
	return tex


func _get_drag_data(_at_position):
	if card_data:
		# Create a preview that represents the tower's footprint
		var preview = ColorRect.new()
		preview.size = Vector2(card_data.size) * Vector2(32, 32) # Assuming 32x32 tiles
		preview.color = Color(0, 0.8, 1, 0.5) # A semi-transparent blue
		
		set_drag_preview(preview)

		# Emit the local signal to notify battle_ui
		drag_started.emit(card_data)

		return card_data
	return null
