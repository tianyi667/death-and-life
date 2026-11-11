extends Control


func _on_button_pressed() -> void:
	GameManager.goto_battle((GameManager.current_level))


func _on_button_3_pressed() -> void:
	get_tree().quit()
