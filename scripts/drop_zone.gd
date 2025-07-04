extends Control

# This script will act as a proxy for the drop events.
# It needs a reference to the main BattleUI script to call the actual logic.
var battle_ui

func _can_drop_data(pos, data):
	if battle_ui:
		return battle_ui._can_drop_data(pos, data)
	return false

func _drop_data(pos, data):
	if battle_ui:
		battle_ui._drop_data(pos, data)
