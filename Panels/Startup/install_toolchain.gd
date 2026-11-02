extends Button


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass



func runORinstallSourceSDK():
	const SDK_APPID = "745"
	
	var error = OS.shell_open("steam://run/"+SDK_APPID)
	# <------------------- TUD
	if error == OK:
		$"../../../Window".dialog_text = """Check over to your steam and launch 745
		Make sure you install it 
		in the same directory as your game """
		$"../../../Window".show()
	else:
		$"../../../Window".dialog_text = "Error :  " + error
		$"../../../Window".show()


func _on_pressed() -> void:
	runORinstallSourceSDK()


func _on_pressed_minimal() -> void:
	var NewConfig = ConfigFile.new()
	print("Making Config")
	
	# Use auto-detected path if available, otherwise use current gameDir
	var csgo_path = AppData.getGameDir()
	if csgo_path.is_empty():
		csgo_path = AppData.detectCSGOPath()
		if csgo_path != "":
			print("Using auto-detected CSGO path: ", csgo_path)
	
	NewConfig.set_value("General","csgo_install", csgo_path)
	
	if DirAccess.dir_exists_absolute(csgo_path + "/SupremacyRenewed"):
		$"../../../Window".dialog_text = """
		Hey! , looks like your game directory
		contains a Supramacy Instance.. would you
		like to create content for '/SupremacyRenewed'?"""
		$"../../../Window".ok_button_text = 'Yes (There is no no because i couldnt figure it out :P)'
		NewConfig.set_value("General","supremacy_install",true)
		
		$"../../../Window".show()
	print(csgo_path)
	
	var config_path = AppData.getToolConfigPath()
	print("Config path: ", config_path)
	
	# Ensure directory exists
	var config_dir = config_path.get_base_dir()
	print("Config dir: ", config_dir)
	if not DirAccess.dir_exists_absolute(config_dir):
		print("Creating directory: ", config_dir)
		var dir = DirAccess.open(config_dir.get_base_dir())
		if dir:
			var error = dir.make_dir(config_dir.get_file())
			if error != OK:
				print("Error creating directory: ", error)
				push_error("Failed to create config directory: " + str(error))
				return
		else:
			print("Failed to open parent directory")
			push_error("Failed to open parent directory for: " + config_dir)
			return
	
	# Save config
	var save_error = NewConfig.save(config_path)
	if save_error != OK:
		print("Error saving config: ", save_error)
		push_error("Failed to save config: " + str(save_error))
	else:
		print("Config saved successfully!")
		# Reload the config in AppData
		AppData._ready()
