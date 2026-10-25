extends Control
var config = ConfigFile.new()

@onready var tree = $Panel/VBoxContainer/HSplitContainer/AssetPanel/ScrollContainer/VBoxContainer/Tree
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	setupWindow()
	#GameManager.launch_windows_exe_via_wine(AppData.gameDir + "csgo.exe", ["-netconport 2121"])
	setup_musicKit_tree(tree )

	
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
