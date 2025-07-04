extends Panel

signal drag_started(card_data: CardData)

# The CardData resource this UI represents
var card_data: CardData

# Node references
@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var cost_label: Label = $VBoxContainer/CostLabel
@onready var description_label: Label = $VBoxContainer/DescriptionLabel

# Public function to set the card data and update the UI
func set_card_data(data: CardData):
	card_data = data
	
	if card_data:
		name_label.text = card_data.card_name
		cost_label.text = "Cost: %d" % card_data.cost
		description_label.text = card_data.description

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
