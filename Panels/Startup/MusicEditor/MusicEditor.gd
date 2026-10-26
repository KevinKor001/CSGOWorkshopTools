extends Control
var config = ConfigFile.new()

@onready var tree = $Panel/VBoxContainer/HSplitContainer/AssetPanel/ScrollContainer/VBoxContainer/Tree
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	setupWindow()
	
	setup_musicKit_tree(tree)

	
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
func setupWindow():
	open_game()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	

	get_window().size = Vector2i(1280, 720)
	get_window().borderless = false
	get_window().unresizable = false
	

	get_window().move_to_center()


func setup_musicKit_tree(tree : Tree):
	
	config.load("res://data/data.cfg")
	
	var root = tree.create_item()
	root.set_text(0,"Config")
	var event_keys = config.get_section_keys("MusicKitEntry")
	for key in event_keys:
		var item = tree.create_item(root)
		
		var display_name = config.get_value("MusicKitEntry",key,key)
		item.set_text(0,display_name)
		


	root.set_text(0, "game_sounds_music")
	
	
	
	
	pass


func _on_test_pressed() -> void:
	pass
	
func open_game():
	print("Game launch Sequence")
	
	var exe_path = AppData.gameDir + "/csgo.exe"
	var args = ["-netconport", "2121", "-windowed", "-novid", "-nojoy", "-insecure", "+name", "Dev", "-offline"]
	var proton_path = AppData.protonPath
	var prefix_path = AppData.protonPrefix
	
	if proton_path.is_empty() or prefix_path.is_empty():
		push_error("Proton path or prefix not configured in settings")
		return
	
	GameManager.launch_with_proton(exe_path, args, proton_path, prefix_path)
