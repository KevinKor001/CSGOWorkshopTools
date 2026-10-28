extends Control
var config = ConfigFile.new()
@export var packageConfigIcon : Texture2D
@onready var tree = $Panel/VBoxContainer/HSplitContainer/AssetPanel/ScrollContainer/VBoxContainer/Tree
@onready var file_dialog = $FileDialog
@onready var popup = $PopUp

signal asset_selected(config_key: String, display_name: String)

var temp_project_dir = ""
var use_supremacy = false
var current_project_path = ""
var project_config = ConfigFile.new()
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	setupWindow()
	#await get_tree().create_timer(20).timeout
	$Panel2.hide()
	setup_musicKit_tree(tree)
	
	# Connect tree selection signal
	tree.item_selected.connect(_on_tree_item_selected)

func _on_tree_item_selected() -> void:
	var selected = tree.get_selected()
	if not selected:
		return
	
	var selected_text = selected.get_text(0)
	
	# Skip package config item
	if selected_text.contains("Package Config"):
		return
	
	# Look up the config key
	var config_key = _get_config_key_from_display_name(selected_text)
	if not config_key.is_empty():
		asset_selected.emit(config_key, selected_text)
		print("[MusicEditor] Asset selected: %s (%s)" % [selected_text, config_key])

func _get_config_key_from_display_name(display_name: String) -> String:
	var config = ConfigFile.new()
	config.load("res://data/data.cfg")
	var keys = config.get_section_keys("MusicKitEntry")
	
	for key in keys:
		var name = config.get_value("MusicKitEntry", key, key)
		if name == display_name:
			return key
	
	return ""

func setupWindow():
	#open_game()
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
		
	var config = tree.create_item(root)
	config.set_text(0, "      Package Config")
	config.set_custom_color(0, Color.GREEN_YELLOW)
	config.set_icon(0,packageConfigIcon)
	config.set_icon_max_width(0,25)
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


func _on_audio_editor_resized() -> void:
	pass


func _on_new_music_kit_pressed() -> void:
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	file_dialog.title = "Select Project Directory"
	file_dialog.show()

func _on_open_project_pressed() -> void:
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	file_dialog.title = "Open Existing Project"
	file_dialog.show()

func _on_file_dialog_dir_selected(dir: String) -> void:
	# Check if this is a valid project directory (has project.cfg)
	var project_cfg_path = dir + "/project.cfg"
	if FileAccess.file_exists(project_cfg_path):
		# Load existing project
		print("Loading existing project from: ", dir)
		load_project(dir)
	else:
		# New project - ask for setup type
		temp_project_dir = dir
		popup.dialog_text = "Setup for Supremacy install or regular CSGO?"

		# Add custom buttons
		popup.add_button("Regular CSGO", false, "regular")
		popup.add_button("Supremacy", true, "supremacy")
		popup.get_ok_button().hide()

		popup.show()

func _on_popup_custom_button(action: String) -> void:
	use_supremacy = (action == "supremacy")
	popup.hide()
	create_music_project(temp_project_dir)

func create_music_project(project_dir: String) -> void:
	print("=== Creating Music Project ===")
	print("Project directory: ", project_dir)

	# Create project.cfg
	var project_config = ConfigFile.new()
	project_config.set_value("Project", "name", project_dir.get_file())
	project_config.set_value("Project", "version", "1.0")
	project_config.set_value("Project", "created", Time.get_datetime_string_from_system())

	# Store CSGO path in config
	var csgo_dir = AppData.gameDir
	print("Base CSGO dir from AppData: ", csgo_dir)

	if use_supremacy:
		csgo_dir = csgo_dir + "/SupremacyRenewed/csgo"
		print("Using Supremacy path: ", csgo_dir)

	project_config.set_value("Project", "csgo_path", csgo_dir)
	project_config.set_value("Project", "use_supremacy", use_supremacy)
	project_config.save(project_dir + "/project.cfg")
	print("Saved project.cfg to: ", project_dir + "/project.cfg")

	# Create data folder
	var data_path = project_dir + "/data"
	print("Creating data folder: ", data_path)
	var data_err = DirAccess.make_dir_absolute(data_path)
	print("Data folder creation result: ", data_err)

	# Create custom_01 directory in actual CSGO folder (recursive)
	var custom_music_dir = csgo_dir + "/sound/music/custom_01"
	print("Creating custom music directory recursively: ", custom_music_dir)

	var dir = DirAccess.open(csgo_dir)
	if dir:
		dir.make_dir_recursive("sound/music/custom_01")
		print("Custom music dir creation complete")
	else:
		print("Failed to open base directory: ", csgo_dir)

	var manifest_path = custom_music_dir + "/manifest"
	print("Creating manifest directory: ", manifest_path)
	var manifest_err = DirAccess.make_dir_absolute(manifest_path)
	print("Manifest dir creation result: ", manifest_err)

	print("=== Music Project Creation Complete ===")

	# Load the newly created project
	load_project(project_dir)

# Project API Functions
func load_project(project_path: String) -> bool:
	current_project_path = project_path
	var config_path = project_path + "/project.cfg"
	var result = project_config.load(config_path)
	if result == OK:
		print("Project loaded from: ", config_path)
		return true
	print("Failed to load project from: ", config_path)
	return false

func save_project() -> bool:
	if current_project_path.is_empty():
		print("No project loaded")
		return false
	var config_path = current_project_path + "/project.cfg"
	var result = project_config.save(config_path)
	if result == OK:
		print("Project saved to: ", config_path)
		return true
	print("Failed to save project to: ", config_path)
	return false

func get_project_name() -> String:
	return project_config.get_value("Project", "name", "")

func get_project_version() -> String:
	return project_config.get_value("Project", "version", "1.0")

func get_project_created() -> String:
	return project_config.get_value("Project", "created", "")

func get_csgo_path() -> String:
	return project_config.get_value("Project", "csgo_path", "")

func get_custom_music_path() -> String:
	var csgo_path = get_csgo_path()
	if not csgo_path.is_empty():
		return csgo_path + "/sound/music/custom_01"
	return ""

func get_manifest_path() -> String:
	return get_custom_music_path() + "/manifest"

func get_data_path() -> String:
	if not current_project_path.is_empty():
		return current_project_path + "/data"
	return ""

func is_supremacy() -> bool:
	return project_config.get_value("Project", "use_supremacy", false)

func set_project_value(section: String, key: String, value) -> void:
	project_config.set_value(section, key, value)

func get_project_value(section: String, key: String, default_value = null):
	return project_config.get_value(section, key, default_value)
