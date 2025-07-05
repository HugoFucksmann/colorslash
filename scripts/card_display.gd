extends PanelContainer

signal upgrade_requested(card_path)
signal selected(card_path)

@onready var card_name_label: Label = $VBoxContainer/CardNameLabel
@onready var level_label: Label = $VBoxContainer/LevelLabel
@onready var progress_bar: ProgressBar = $VBoxContainer/UpgradeProgressBar
@onready var progress_label: Label = $VBoxContainer/UpgradeProgressBar/ProgressLabel
@onready var upgrade_button: Button = $VBoxContainer/UpgradeButton
@onready var card_visual: ColorRect = $VBoxContainer/CardVisual

var card_path: String
var _player_data

func _ready():
	if get_tree().has_node("/root/PlayerData"):
		_player_data = get_tree().get_root().get_node("PlayerData")
	else:
		push_error("PlayerData not found!")
		return
		
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	
	# Add a GUI input handler to detect clicks on the panel
	gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			emit_signal("selected", card_path)
	)

func setup(p_card_path: String):
	self.card_path = p_card_path
	var card_data: CardData = load(card_path)
	if not card_data:
		push_error("Failed to load card data from path: " + card_path)
		return

	card_name_label.text = card_data.card_name
	
	if _player_data.card_inventory.has(card_path):
		# Player owns the card
		var card_info = _player_data.card_inventory[card_path]
		var current_level = card_info.level
		var current_count = card_info.count
		
		level_label.text = "Level " + str(current_level)
		
		# Check if max level
		if current_level - 1 >= card_data.cards_to_upgrade.size():
			progress_bar.visible = false
			progress_label.text = "MAX LEVEL"
			upgrade_button.visible = false
		else:
			var cards_needed = card_data.cards_to_upgrade[current_level - 1]
			progress_bar.max_value = cards_needed
			progress_bar.value = current_count
			progress_label.text = "%d / %d" % [current_count, cards_needed]
			
			if _player_data.can_upgrade_card(card_data):
				upgrade_button.disabled = false
				upgrade_button.text = "Upgrade"
			else:
				upgrade_button.disabled = true
				upgrade_button.text = "Upgrade"
		
		modulate = Color.WHITE # Make sure it's visible
	else:
		# Player does not own the card
		level_label.text = ""
		progress_bar.visible = false
		progress_label.text = "Locked"
		upgrade_button.visible = false
		modulate = Color(0.5, 0.5, 0.5, 1) # Grayed out

func _on_upgrade_pressed():
	emit_signal("upgrade_requested", card_path)
