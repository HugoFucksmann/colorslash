extends Panel

signal card_selected(card_data)

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

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if card_data:
			emit_signal("card_selected", card_data)
			print("Card UI: %s selected." % card_data.card_name)
