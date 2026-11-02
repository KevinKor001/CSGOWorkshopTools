extends Window

@onready var _file_dialog = $FileDialog
@onready var _proton_options = $Panel/ScrollContainer/VBoxContainer/SelectProton/ProtonOptions
@onready var _prefix_path = $Panel/ScrollContainer/VBoxContainer/SelectProtonPrefix/Path
@onready var _launch_game_checkbox = $Panel/ScrollContainer/VBoxContainer/CheckBox
@onready var _fullscreen_checkbox = $Panel/ScrollContainer/VBoxContainer/CheckBox2
@onready var _launch_args = $Panel/ScrollContainer/VBoxContainer/LineEdit
@onready var _disable_comm_checkbox = $Panel/ScrollContainer/VBoxContainer/CheckBox3

var _proton_installations: Array = []





func _ready() -> void:
	detect_proton_installations()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_file_dialog.dir_selected.connect(_on_prefix_folder_selected)
	_load_settings()

func detect_proton_installations() -> void:
	_proton_installations.clear()
	_proton_options.clear()
	
	var steam_paths = []
	
	if OS.get_name() == "Windows":
		# Windows doesn't use Proton, but we check anyway for future compatibility
		steam_paths = []
	else:
		# Linux Steam Proton paths
		var flatpak_path = OS.get_environment("HOME")
		flatpak_path += "/.var/app/com.valvesoftware.Steam/data/Steam/compatibilitytools.d"
		
		steam_paths = [
			OS.get_environment("HOME") + "/.steam/steam/compatibilitytools.d",
			OS.get_environment("HOME") + "/.local/share/Steam/compatibilitytools.d",
			OS.get_environment("HOME") + "/.steam/root/compatibilitytools.d",
			"/usr/share/steam/compatibilitytools.d",
			flatpak_path,
		]
	
	for path in steam_paths:
		if DirAccess.dir_exists_absolute(path):
			var dir = DirAccess.open(path)
			if dir:
				dir.list_dir_begin()
				var dir_name = dir.get_next()
				while dir_name != "":
					if dir.current_is_dir():
						var proton_path = path + "/" + dir_name
						_proton_installations.append(proton_path)
					dir_name = dir.get_next()
	
	# Add built-in Proton versions from Steam
	var steam_root = _find_steam_root()
	print("[Proton Detector] Steam root: ", steam_root)
	if steam_root != "":
		var library_folders = _get_steam_library_folders(steam_root)
		for library_path in library_folders:
			var builtin_proton_path = library_path + "/steamapps/common"
			print("[Proton Detector] Checking library: ", builtin_proton_path)
			if DirAccess.dir_exists_absolute(builtin_proton_path):
				var dir = DirAccess.open(builtin_proton_path)
				if dir:
					dir.list_dir_begin()
					var dir_name = dir.get_next()
					while dir_name != "":
						var is_proton = dir_name.contains("Proton") or dir_name.contains("proton")
						if dir.current_is_dir() and is_proton:
							var proton_path = builtin_proton_path + "/" + dir_name
							_proton_installations.append(proton_path)
#							print("[Proton Detector] Found built-in: ", proton_path)
						dir_name = dir.get_next()
	
	# Remove duplicates
	var unique_protons: Array = []
	for proton_path in _proton_installations:
		if not proton_path in unique_protons:
			unique_protons.append(proton_path)
	_proton_installations = unique_protons
	
	# Populate OptionButton
	if _proton_installations.is_empty():
		_proton_options.add_item("- No protons Detected :( -")
	else:
		for proton_path in _proton_installations:
			var display_name = proton_path.get_file()
			# Add parent directory to distinguish duplicates
			var parent_dir = proton_path.get_base_dir().get_file()
			display_name = "%s (%s)" % [display_name, parent_dir]
			_proton_options.add_item(display_name)
			_proton_options.set_item_metadata(_proton_options.get_item_count() - 1, proton_path)

func _find_steam_root() -> String:
	var possible_paths = []
	
	if OS.get_name() == "Windows":
		# Windows Steam paths
		possible_paths = [
			OS.get_environment("ProgramFiles(x86)") + "/Steam",
			OS.get_environment("ProgramFiles") + "/Steam",
			OS.get_environment("ProgramW6432") + "/Steam",
			"C:/Program Files (x86)/Steam",
			"C:/Program Files/Steam",
		]
	else:
		# Linux Steam paths
		possible_paths = [
			OS.get_environment("HOME") + "/.steam/steam",
			OS.get_environment("HOME") + "/.local/share/Steam",
			OS.get_environment("HOME") + "/.steam/root",
			"/usr/share/steam",
			"/var/lib/steam",
		]
	
	for path in possible_paths:
		if DirAccess.dir_exists_absolute(path):
			return path
	return ""

func _get_steam_library_folders(steam_root: String) -> Array:
	var libraries = [steam_root]  # Always include the main Steam directory
	
	var library_folders_path = steam_root + "/steamapps/libraryfolders.vdf"
	if FileAccess.file_exists(library_folders_path):
		var file = FileAccess.open(library_folders_path, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			file.close()
			
			# Parse VDF format (simplified)
			var lines = content.split("\n")
			for line in lines:
				line = line.strip_edges()
				if line.begins_with('"path"'):
					var parts = line.split('"')
					if parts.size() >= 4:
						var lib_path = parts[3]
						if DirAccess.dir_exists_absolute(lib_path):
							libraries.append(lib_path)
#							print("[Proton Detector] Found library: ", lib_path)
	
	return libraries

func _on_proton_options_item_selected(index: int) -> void:
	if index >= 0 and index < _proton_installations.size():
		var selected_proton = _proton_installations[index]
		print("Selected Proton: ", selected_proton)

func _on_proton_refresh_pressed() -> void:
	detect_proton_installations()

func _on_proton_prefix_path_text_submitted(new_text: String) -> void:
	print("Proton prefix path: ", new_text)

func _on_pick_prefix_folder_pressed() -> void:
	_file_dialog.popup_centered()

func _on_prefix_folder_selected(dir: String) -> void:
	_prefix_path.text = dir
	print("Selected prefix folder: ", dir)


func _load_settings() -> void:
	var config_path = AppData.getToolConfigPath()
	var config = ConfigFile.new()
	var load_result = config.load(config_path)
	
	if load_result == OK:
		# Load general settings
		_launch_game_checkbox.button_pressed = config.get_value("General", "launch_game", true)
		_fullscreen_checkbox.button_pressed = config.get_value("General", "fullscreen", false)
		_launch_args.text = config.get_value("General", "launch_args", "")
		_disable_comm_checkbox.button_pressed = config.get_value("General", "disable_communication", false)
		
		# Load Linux settings
		var proton_path = config.get_value("Linux", "ProtonPath", "")
		var prefix_path = config.get_value("Linux", "ProtonPrefix", "")
		
		# Set proton prefix path
		_prefix_path.text = prefix_path
		
		# Find and select the proton option
		if not proton_path.is_empty():
			for i in range(_proton_installations.size()):
				if _proton_installations[i] == proton_path:
					_proton_options.selected = i
					break

func _save_settings() -> void:
	var config_path = AppData.getToolConfigPath()
	print("Saving config to: ", config_path)
	
	# Get current values from UI
	var current_proton_path = ""
	if _proton_options.selected >= 0 and _proton_options.selected < _proton_installations.size():
		current_proton_path = _proton_installations[_proton_options.selected]
	
	var current_prefix_path = _prefix_path.text
	
	# Ensure directory exists
	var config_dir = config_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(config_dir):
		var dir = DirAccess.open(config_dir.get_base_dir())
		if dir:
			dir.make_dir(config_dir.get_file())
			print("Created directory: ", config_dir)
		else:
			push_error("Failed to create config directory: ", config_dir)
			return
	
	var config = ConfigFile.new()
	config.load(config_path)
	
	# Save general settings
	config.set_value("General", "launch_game", _launch_game_checkbox.button_pressed)
	config.set_value("General", "fullscreen", _fullscreen_checkbox.button_pressed)
	config.set_value("General", "launch_args", _launch_args.text)
	config.set_value("General", "disable_communication", _disable_comm_checkbox.button_pressed)
	
	# Save Linux settings
	config.set_value("Linux", "ProtonPath", str(current_proton_path))
	config.set_value("Linux", "ProtonPrefix", str(current_prefix_path))
	
	var error = config.save(config_path)
	if error != OK:
		push_error("Failed to save config: ", error)
	else:
		print("Config saved successfully")

func _on_save_pressed() -> void:
	_save_settings()
	hide()
