extends Node2D

const base_enemy := preload("uid://dp7qcvgcmvebd")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("left_mouse"):
		var glo_pos := get_global_mouse_position()
		var enemy := base_enemy.instantiate()
		enemy.global_position = glo_pos
		self.add_child(enemy)
			
