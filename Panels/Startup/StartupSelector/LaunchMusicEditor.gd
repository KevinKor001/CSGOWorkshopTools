extends Button


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_pressed() -> void:
	
	get_tree().root.get_node("/root/Control").queue_free()
	get_tree().get_root().add_child(load("res://Panels/Startup/MusicEditor/MusicEditor.tscn").instantiate())
	pass # Replace with function body.
