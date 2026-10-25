extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	setupWindow()
	#GameManager.launch_windows_exe_via_wine(AppData.gameDir + "csgo.exe", ["-netconport 2121"])
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
func setupWindow():
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	

	get_window().size = Vector2i(1280, 720)
	get_window().borderless = false
	get_window().unresizable = false
	

	get_window().move_to_center()
	
