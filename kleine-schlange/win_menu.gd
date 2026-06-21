extends CanvasLayer

signal replay



func _on_replay_pressed() -> void:
	replay.emit()
