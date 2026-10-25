extends Control
var gamedir :String

func checkInstalation():
	if ArgParser.csgo_dir != "":
		gamedir = ArgParser.csgo_dir
	else:
		gamedir = "."
	print(DirAccess.get_directories_at(gamedir))
	print(DirAccess.get_files_at(gamedir))
	
	if "CSP_Data" in DirAccess.get_directories_at(gamedir):
		if "projects.json" in DirAccess.get_files_at(gamedir + "/CSP_Data"):
			AppData.IsToolChainInstalled = true


func setupWindow():
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	get_window().size = Vector2i(850, 630)
	get_window().borderless = false
	get_window().unresizable = true

	get_window().move_to_center()
	
	if AppData.IsToolChainInstalled:
		$Panel/MissingSDK.hide()
		$Panel/VBoxContainer/HBoxContainer2/OpenHammer.disabled = false
	

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	if ArgParser.csgo_dir != "":
			print("Found CSGO Path: ", ArgParser.csgo_dir.left(54))
	else:
			print("No CSGO Path specified on launch.")
	checkInstalation()
	setupWindow()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
