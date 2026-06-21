extends Control

signal start

func _on_startbutton_pressed() -> void:
	start.emit()
