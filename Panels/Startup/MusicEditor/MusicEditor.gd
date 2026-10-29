extends Control
var config = ConfigFile.new()
@export var packageConfigIcon : Texture2D
@onready var tree = $Panel/VBoxContainer/HSplitContainer/AssetPanel/ScrollContainer/VBoxContainer/Tree
@onready var file_dialog = $FileDialog
@onready var popup = $PopUp
@onready var preview_button = $Panel/VBoxContainer/Panel/HBoxContainer/Preview
@onready var audio_editor = $Panel/VBoxContainer/HSplitContainer/AudioEditor
@onready var config_editor = $Panel/VBoxContainer/HSplitContainer/ConfigEditor
@onready var package_config = $Panel/VBoxContainer/HSplitContainer/ConfigEditor/ScrollContainer/PackageConfig
@onready var game_music_sounds = $Panel/VBoxContainer/HSplitContainer/ConfigEditor/ScrollContainer/game_music_sounds

signal asset_selected(config_key: String, display_name: String)

var temp_project_dir = ""
var use_supremacy = false
var current_project_path = ""
var project_config = ConfigFile.new()
var game_sounds_entries: Array = []
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	setupWindow()
	#await get_tree().create_timer(20).timeout
	$Panel2.hide()
	setup_musicKit_tree(tree)
	
	# Connect tree selection signal
	tree.item_selected.connect(_on_tree_item_selected)
	
	# Connect preview button to hot reload
	var hot_reload_callable = Callable(self, "hot_reload_to_game")
	if not preview_button.pressed.is_connected(hot_reload_callable):
		preview_button.pressed.connect(hot_reload_callable)
	
	# Connect to node exiting signal for cleanup
	tree_exiting.connect(cleanup_on_editor_close)

func _on_tree_item_selected() -> void:
	var selected = tree.get_selected()
	if not selected:
		return
	
	var selected_text = selected.get_text(0)
	
	# Check if root (game_sounds_music) is selected
	if selected_text == "game_sounds_music":
		_show_game_music_sounds()
		return
	
	# Check if Package Config is selected
	if selected_text.contains("Package Config"):
		_show_package_config()
		return
	
	# Otherwise, show audio editor for the selected asset
	_show_audio_editor()
	
	# Look up the config key
	var config_key = _get_config_key_from_display_name(selected_text)
	if not config_key.is_empty():
		asset_selected.emit(config_key, selected_text)
		print("[MusicEditor] Asset selected: %s (%s)" % [selected_text, config_key])

func _show_audio_editor() -> void:
	audio_editor.show()
	config_editor.hide()

func _show_game_music_sounds() -> void:
	audio_editor.hide()
	config_editor.show()
	package_config.hide()
	game_music_sounds.show()
	_populate_game_music_sounds()

func _show_package_config() -> void:
	audio_editor.hide()
	config_editor.show()
	package_config.show()
	game_music_sounds.hide()

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






func open_game():
	
	print("Game launch Sequence")

	var exe_path = AppData.gameDir + "/csgo.exe"
	
	# Check if project is loaded and uses supremacy
	if not current_project_path.is_empty() and is_supremacy():
		exe_path = AppData.gameDir + "/SupremacyRenewed/csgo.exe"
		print("Launching Supremacy version: ", exe_path)
	
	var args = ["-netconport", "2121", "-windowed -w 1280 -h 720", "-novid", "-nojoy", "-insecure", "+name", "Dev", "-offline"]
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

	# Generate game_sounds_music.txt in data folder
	var gsm_path = data_path + "/game_sounds_music.txt"
	print("Generating game_sounds_music.txt: ", gsm_path)
	generate_game_sounds_music_template(gsm_path)

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
		
		# Ensure game_sounds_music.txt exists in data folder
		var data_path = get_data_path()
		var gsm_path = data_path + "/game_sounds_music.txt"
		if not FileAccess.file_exists(gsm_path):
			print("game_sounds_music.txt not found, generating from template")
			generate_game_sounds_music_template(gsm_path)
		
		# Recreate custom_01 directory
		var custom_music_path = get_custom_music_path()
		if not custom_music_path.is_empty():
			if not DirAccess.dir_exists_absolute(custom_music_path):
				print("Recreating custom_01 directory: ", custom_music_path)
				var csgo_path = get_csgo_path()
				var dir = DirAccess.open(csgo_path)
				if dir:
					dir.make_dir_recursive("sound/music/custom_01")
					print("custom_01 directory recreated")
					
					# Also recreate manifest directory
					var manifest_path = custom_music_path + "/manifest"
					if not DirAccess.dir_exists_absolute(manifest_path):
						DirAccess.make_dir_absolute(manifest_path)
						print("manifest directory recreated")
				else:
					print("Failed to open CSGO directory for recreation")
			else:
				print("custom_01 directory already exists")
		open_game()
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

func save_track_config(config_key: String, start_point: String, end_point: String,
		priority: int, priority_override: bool, save_start_point: bool = true,
		save_end_point: bool = true, save_priority: bool = true,
		save_priority_override: bool = true) -> bool:
	var data_path = get_data_path()
	if data_path.is_empty():
		print("[MusicEditor] No project loaded, cannot save track config")
		return false
	var gsm_path = data_path + "/game_sounds_music.txt"
	if not FileAccess.file_exists(gsm_path):
		print("[MusicEditor] game_sounds_music.txt not found: ", gsm_path)
		return false

	var file = FileAccess.open(gsm_path, FileAccess.READ)
	if not file:
		return false
	var content = file.get_as_text()
	file.close()

	var entry_name = '"Music.' + config_key + '.custom_01"'
	var entry_start = _find_music_entry_start(content, config_key)
	if entry_start == -1:
		print("[MusicEditor] Entry not found, cannot save: ", entry_name)
		return false
	var entry_end = _find_braced_section_end(content, entry_start)
	if entry_end == -1:
		return false

	var track_data_start = content.find('"track_data"', entry_start)
	if track_data_start != -1 and track_data_start < entry_end:
		var track_data_end = _find_braced_section_end(content, track_data_start)
		if track_data_end == -1 or track_data_end > entry_end:
			return false
		var section = content.substr(track_data_start, track_data_end - track_data_start + 1)
		if save_start_point:
			section = _set_or_insert_config_value(section, "start_point", start_point)
		if save_end_point:
			section = _set_or_insert_config_value(section, "end_point", end_point)
		if save_priority:
			section = _set_or_insert_config_value(section, "priority", str(priority))
		if save_priority_override:
			section = _set_or_insert_config_value(section, "priority_override", "true" if priority_override else "false")
		content = content.substr(0, track_data_start) + section + content.substr(track_data_end + 1)
	else:
		if not save_start_point and not save_end_point and not save_priority and not save_priority_override:
			print("[MusicEditor] Track has no editable track config fields: ", config_key)
			return true
		var operator_data_start = content.find('"soundentry_operator_data"', entry_start)
		var insert_at = -1
		if operator_data_start != -1 and operator_data_start < entry_end:
			insert_at = content.find("{", operator_data_start) + 1
		else:
			var operator_stacks_start = content.find('"operator_stacks"', entry_start)
			if operator_stacks_start == -1 or operator_stacks_start > entry_end:
				print("[MusicEditor] No operator_stacks for: ", entry_name)
				return false
			insert_at = content.find("{", operator_stacks_start) + 1
		var fields = ""
		if save_start_point:
			fields += "\n\t\t\t\t\"start_point\" \"%s\"" % start_point
		if save_end_point:
			fields += "\n\t\t\t\t\"end_point\" \"%s\"" % end_point
		if save_priority:
			fields += "\n\t\t\t\t\"priority\" \"%d\"" % priority
		if save_priority_override:
			fields += "\n\t\t\t\t\"priority_override\" \"%s\"" % ("true" if priority_override else "false")
		var new_data = "\n\t\t\t\"track_data\"\n\t\t\t{" + fields + "\n\t\t\t}"
		if operator_data_start == -1:
			new_data = "\n\t\t\"soundentry_operator_data\"\n\t\t{" + new_data + "\n\t\t}"
		content = content.substr(0, insert_at) + new_data + content.substr(insert_at)

	var output = FileAccess.open(gsm_path, FileAccess.WRITE)
	if not output:
		return false
	output.store_string(content)
	output.close()
	print("[MusicEditor] Saved track config for: ", config_key)
	return true

func _replace_config_value(section: String, key: String, value: String) -> String:
	var regex = RegEx.new()
	regex.compile('("' + key + '"\\s+")[^"]*(")')
	var found_match = regex.search(section)
	if found_match == null:
		return section
	var replacement = found_match.get_string(1) + value + found_match.get_string(2)
	return section.substr(0, found_match.get_start()) + replacement + section.substr(found_match.get_end())

func _set_or_insert_config_value(section: String, key: String, value: String) -> String:
	var regex = RegEx.new()
	regex.compile('"' + key + '"\\s+"[^"]*"')
	if regex.search(section) != null:
		return _replace_config_value(section, key, value)
	var closing_brace = section.rfind("}")
	if closing_brace == -1:
		return section
	return section.substr(0, closing_brace) + "\n\t\t\"%s\" \"%s\"\n\t" % [key, value] + section.substr(closing_brace)

func _find_braced_section_end(content: String, section_start: int) -> int:
	var open_brace = content.find("{", section_start)
	if open_brace == -1:
		return -1
	var depth = 0
	for i in range(open_brace, content.length()):
		if content[i] == "{":
			depth += 1
		elif content[i] == "}":
			depth -= 1
			if depth == 0:
				return i
	return -1

func _find_music_entry_start(content: String, config_key: String) -> int:
	var lower_content = content.to_lower()
	var exact_name = '"music.' + config_key.to_lower() + '.custom_01"'
	var entry_start = lower_content.find(exact_name)
	while entry_start != -1:
		if entry_start == 0 or content[entry_start - 1] == "\n":
			return entry_start
		entry_start = lower_content.find(exact_name, entry_start + 1)

	var wave_name = '"*music/custom_01/' + config_key.to_lower() + '.mp3"'
	var wave_start = lower_content.find(wave_name)
	if wave_start != -1:
		var header_start = lower_content.rfind('"music.', wave_start)
		while header_start != -1:
			if header_start == 0 or content[header_start - 1] == "\n":
				return header_start
			header_start = lower_content.rfind('"music.', header_start - 1)
	return -1

func is_supremacy() -> bool:
	return project_config.get_value("Project", "use_supremacy", false)

func set_project_value(section: String, key: String, value) -> void:
	project_config.set_value(section, key, value)

func get_project_value(section: String, key: String, default_value = null):
	return project_config.get_value(section, key, default_value)

# game_sounds_music.txt parsing
func parse_game_sounds_music(file_path: String) -> Array:
	var entries = []
	
	if not FileAccess.file_exists(file_path):
		print("[MusicEditor] game_sounds_music.txt not found: ", file_path)
		return entries
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("[MusicEditor] Failed to open game_sounds_music.txt")
		return entries
	
	var content = file.get_as_text()
	file.close()
	
	var lines = content.split("\n")
	var current_entry = {}
	var in_entry = false
	var entry_name = ""
	
	for line in lines:
		var trimmed = line.strip_edges()
		
		# Check for entry start (quoted name)
		if trimmed.begins_with("\"") and trimmed.ends_with("\""):
			# Save previous entry if exists
			if in_entry and not entry_name.is_empty():
				entries.append({
					"name": entry_name,
					"data": current_entry.duplicate()
				})
			
			# Start new entry
			entry_name = trimmed.substr(1, trimmed.length() - 2)
			current_entry = {}
			in_entry = true
		
		elif in_entry:
			# Parse key-value pairs
			if trimmed.begins_with("\"") and trimmed.contains("\""):
				var parts = trimmed.split("\"")
				if parts.size() >= 4:
					var key = parts[1]
					var value = parts[3]
					current_entry[key] = value
	
	# Save last entry
	if in_entry and not entry_name.is_empty():
		entries.append({
			"name": entry_name,
			"data": current_entry.duplicate()
		})
	
	print("[MusicEditor] Parsed %d entries from game_sounds_music.txt" % entries.size())
	return entries

func generate_game_sounds_music_template(output_path: String) -> void:
	var template_file = FileAccess.open(output_path, FileAccess.WRITE)
	if not template_file:
		print("[MusicEditor] Failed to create game_sounds_music.txt")
		return
	
	# Copy from the sample file
	var sample_path = "res://data/game_sounds_music.txt"
	if FileAccess.file_exists(sample_path):
		var sample_file = FileAccess.open(sample_path, FileAccess.READ)
		if sample_file:
			var content = sample_file.get_as_text()
			sample_file.close()
			template_file.store_string(content)
			print("[MusicEditor] Generated game_sounds_music.txt from template")
	else:
		print("[MusicEditor] Sample file not found, creating empty file")
	
	template_file.close()

func _populate_game_music_sounds() -> void:
	# Clear existing children (except the first Label and LineEdit)
	var children = game_music_sounds.get_children()
	for i in range(2, children.size()):
		children[i].queue_free()
	
	# Wait for nodes to be freed
	await get_tree().process_frame
	
	# Get data path
	var data_path = get_data_path()
	if data_path.is_empty():
		print("[MusicEditor] No project loaded")
		return
	
	var gsm_path = data_path + "/game_sounds_music.txt"
	
	# Parse the file
	game_sounds_entries = parse_game_sounds_music(gsm_path)
	
	# Add separator
	var separator = HSeparator.new()
	separator.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	game_music_sounds.add_child(separator)
	
	# Add "Open in External Editor" button
	var open_button = Button.new()
	open_button.text = "Open game_sounds_music.txt in External Editor"
	open_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open_button.pressed.connect(_on_open_external_editor_pressed.bind(gsm_path))
	game_music_sounds.add_child(open_button)
	
	# Add separator
	var separator2 = HSeparator.new()
	separator2.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	game_music_sounds.add_child(separator2)
	
	# Add info label
	var info_label = Label.new()
	info_label.text = "Total entries: %d" % game_sounds_entries.size()
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_music_sounds.add_child(info_label)
	
	# Add description
	var desc_label = Label.new()
	desc_label.text = "Use the external editor for detailed configuration."
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.modulate = Color.GRAY
	game_music_sounds.add_child(desc_label)
	
	print("[MusicEditor] Populated game_music_sounds with %d total entries" % game_sounds_entries.size())

func _on_open_external_editor_pressed(file_path: String) -> void:
	print("[MusicEditor] Opening file in external editor: ", file_path)
	
	# Use xdg-open on Linux to open the file with default application
	var output = []
	var exit_code = OS.execute("xdg-open", [file_path], output)
	
	if exit_code != 0:
		print("[MusicEditor] Failed to open file, exit code: ", exit_code)
		# Fallback: try opening the directory
		OS.execute("xdg-open", [file_path.get_base_dir()], output)

func _on_go_to_track_pressed(entry_name: String) -> void:
	print("[MusicEditor] Go to track pressed for: ", entry_name)
	# TODO: Hook this up later to navigate to the track in the tree

# Hot Reload Functions
func hot_reload_to_game() -> void:
	print("[MusicEditor] === Starting Hot Reload ===")
	
	# Get paths
	var data_path = get_data_path()
	var custom_music_path = get_custom_music_path()
	
	if data_path.is_empty() or custom_music_path.is_empty():
		print("[MusicEditor] Error: Project not loaded or CSGO path not set")
		return
	
	var source_gsm = data_path + "/game_sounds_music.txt"
	var dest_gsm = custom_music_path + "/game_sounds_music.txt"
	
	if not FileAccess.file_exists(source_gsm):
		print("[MusicEditor] Error: game_sounds_music.txt not found in project")
		return
	
	# Copy game_sounds_music.txt to custom_01 (no processing needed, keep .mp3)
	var dest_file = FileAccess.open(dest_gsm, FileAccess.WRITE)
	if not dest_file:
		print("[MusicEditor] Error: Failed to open destination file")
		return
	
	var source_file = FileAccess.open(source_gsm, FileAccess.READ)
	var content = source_file.get_as_text()
	source_file.close()
	
	dest_file.store_string(content)
	dest_file.close()
	print("[MusicEditor] Copied game_sounds_music.txt to: ", dest_gsm)
	
	# Copy all MP3 files from data to custom_01
	var dir = DirAccess.open(data_path)
	if not dir:
		print("[MusicEditor] Error: Failed to open data directory")
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".mp3"):
			var source_file_path = data_path + "/" + file_name
			var dest_file_path = custom_music_path + "/" + file_name
			
			print("[MusicEditor] Copying: ", file_name)
			var error = dir.copy(source_file_path, dest_file_path)
			if error != OK:
				print("[MusicEditor] Error copying %s: %d" % [file_name, error])
			else:
				print("[MusicEditor] Successfully copied: ", file_name)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	print("[MusicEditor] === Hot Reload Complete ===")
	
	# Send commands to game via PortalInterface
	print("[MusicEditor] Sending commands to game...")
	var interface = PortalInterface.new("127.0.0.1", 2121)
	add_child(interface)
	
	var commands_sent = false
	interface.connected.connect(func():
		print("[MusicEditor] Connected to game, sending commands")
		commands_sent = true
		interface.send_command("sv_cheats 1")
		await get_tree().create_timer(0.2).timeout
		interface.send_command("snd_restart")
		await get_tree().create_timer(0.5).timeout
		interface.disconnect_from_server()
		interface.queue_free()
	)
	
	interface.connect_to_server(1, 0.5)
	await get_tree().create_timer(2.0).timeout
	
	if is_instance_valid(interface):
		interface.queue_free()
	
	if not commands_sent:
		print("[MusicEditor] Game not running or connection failed, commands not sent")

# Cleanup Functions
func cleanup_on_editor_close() -> void:
	if not AppData.cleanupOnClose:
		print("[MusicEditor] Cleanup disabled in AppData, skipping")
		return
	
	print("[MusicEditor] === Starting Cleanup on Editor Close ===")
	
	# Send quit command to game via PortalInterface
	var interface = PortalInterface.new("127.0.0.1", 2121)
	add_child(interface)
	
	var connection_success = false
	interface.connected.connect(func():
		print("[MusicEditor] Connected to game, sending quit command")
		connection_success = true
		interface.send_command("quit")
		await get_tree().create_timer(0.5).timeout
		interface.disconnect_from_server()
		interface.queue_free()
	)
	
	interface.connect_to_server(1, 0.5)
	await get_tree().create_timer(2.0).timeout
	
	# Clean up interface if connection failed
	if is_instance_valid(interface):
		interface.queue_free()
	
	if not connection_success:
		print("[MusicEditor] Game not running or connection failed, skipping quit command")
	
	# Delete custom_01 directory or just files inside
	var custom_music_path = get_custom_music_path()
	if custom_music_path.is_empty():
		print("[MusicEditor] No project loaded, skipping cleanup")
		return
	
	if DirAccess.dir_exists_absolute(custom_music_path):
		var dir = DirAccess.open(custom_music_path)
		if dir:
			# Delete all files and directories inside custom_01
			dir.list_dir_begin()
			var file_name = dir.get_next()
			
			while file_name != "":
				var full_path = custom_music_path + "/" + file_name
				if dir.current_is_dir():
					# Remove directory recursively
					var err = dir.remove_recursive(file_name)
					if err != OK:
						print("[MusicEditor] Error removing directory %s: %d" % [file_name, err])
				else:
					# Remove file
					var err = dir.remove(file_name)
					if err != OK:
						print("[MusicEditor] Error removing file %s: %d" % [file_name, err])
				
				file_name = dir.get_next()
			
			dir.list_dir_end()
			
			# Remove the directory itself
			var parent_dir = custom_music_path.get_base_dir()
			var dir_name = custom_music_path.get_file()
			var parent = DirAccess.open(parent_dir)
			if parent:
				var err = parent.remove(dir_name)
				if err == OK:
					print("[MusicEditor] Removed custom_01 directory")
				else:
					print("[MusicEditor] Error removing custom_01 directory: %d" % err)
		else:
			print("[MusicEditor] Error: Failed to open custom_01 directory")
	else:
		print("[MusicEditor] custom_01 directory does not exist, skipping")
	
	print("[MusicEditor] === Cleanup Complete ===")
