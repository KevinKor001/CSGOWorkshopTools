extends Control

@export var default_icon: Texture2D
@export var default_asset_name: String
@export var default_status_label: String

# UI Node references
@onready var insert_button: Button = $Panel/HBoxContainer/Button
@onready var asset_name_label: Label = $Panel/HBoxContainer/VBoxContainer/Label
@onready var path_edit: LineEdit = $Panel/HBoxContainer/VBoxContainer/LineEdit
@onready var relative_path_edit: LineEdit = $Panel/HBoxContainer/VBoxContainer/LineEdit2
@onready var progress_bar: ProgressBar = $Panel/HBoxContainer/VBoxContainer/ProgressBar
@onready var status_label: Label = $Panel/HBoxContainer/VBoxContainer/ProgressBar/Label

var file_dialog: FileDialog
var conversion_process: int = -1
var current_input_file: String = ""
var current_output_file: String = ""
var current_output_mp3: String = ""
var progress_file_path: String = ""
var progress_timer: Timer
var music_editor: Node
var config_key: String = ""
var original_filename: String = ""

func _ready() -> void:
	# Get reference to MusicEditor parent
	music_editor = $"../../../../../.."
	
	# Create file dialog
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.add_filter("*.wav;WAV Audio")
	file_dialog.add_filter("*.mp3;MP3 Audio")
	file_dialog.add_filter("*.mp4;MP4 Audio")
	file_dialog.file_selected.connect(_on_file_selected)
	add_child(file_dialog)
	
	# Connect button signal
	insert_button.pressed.connect(_on_insert_button_pressed)
	
	# Connect to MusicEditor asset selection signal - use call_deferred to ensure MusicEditor is ready
	call_deferred("_connect_music_editor_signals")
	
	# Apply the defaults configured on this reusable entry scene.
	if default_icon:
		insert_button.icon = default_icon
	if not default_asset_name.is_empty():
		asset_name_label.text = default_asset_name
	if not default_status_label.is_empty():
		_set_status(default_status_label, 0.0)
	else:
		_set_status("Idle", 0.0)

func _connect_music_editor_signals() -> void:
	if music_editor and music_editor.has_signal("asset_selected"):
		if not music_editor.asset_selected.is_connected(_on_asset_selected):
			music_editor.asset_selected.connect(_on_asset_selected)

func _on_asset_selected(config_key: String, display_name: String) -> void:
	print("[AssetInputEntry] Asset selected: %s (%s)" % [display_name, config_key])
	
	# Update config key
	self.config_key = config_key
	
	# Get project data path
	var data_path = music_editor.get_data_path()
	if data_path.is_empty():
		print("[AssetInputEntry] No project loaded")
		return
	
	# Construct path to WAV file
	var wav_path = data_path + "/" + config_key + ".wav"
	print("[AssetInputEntry] Checking for WAV: ", wav_path)
	
	if FileAccess.file_exists(wav_path):
		# File exists, update UI
		original_filename = config_key + ".wav"
		_update_paths(wav_path, wav_path)
		_update_asset_label()
		_set_status("Idle", 100.0)
		print("[AssetInputEntry] Loaded existing file")
	else:
		# File doesn't exist, clear UI
		path_edit.text = ""
		relative_path_edit.text = ""
		asset_name_label.text = display_name
		_set_status("No file imported", 0.0)
		print("[AssetInputEntry] No file found for this asset")

func _on_insert_button_pressed() -> void:
	print("[AssetInputEntry] Insert button pressed")
	# Get selected tree item and config key
	config_key = _get_selected_config_key()
	print("[AssetInputEntry] Config key: ", config_key)
	if config_key.is_empty():
		_set_status("Error: No asset selected", 0.0)
		print("[AssetInputEntry] Error: No asset selected")
		return
	
	print("[AssetInputEntry] Showing file dialog")
	file_dialog.show()

func _on_file_selected(path: String) -> void:
	print("[AssetInputEntry] File selected: ", path)
	current_input_file = path
	original_filename = path.get_file()
	var extension = path.get_extension().to_lower()
	print("[AssetInputEntry] File extension: ", extension)
	
	# Get project data path
	var data_path = music_editor.get_data_path()
	print("[AssetInputEntry] Data path: ", data_path)
	if data_path.is_empty():
		_set_status("Error: No project loaded", 0.0)
		push_error("No project loaded")
		print("[AssetInputEntry] Error: No project loaded")
		return
	
	# Set output paths in project data directory
	current_output_file = data_path + "/" + config_key + ".wav"
	current_output_mp3 = data_path + "/" + config_key + ".mp3"
	print("[AssetInputEntry] WAV output path: ", current_output_file)
	print("[AssetInputEntry] MP3 output path: ", current_output_mp3)
	
	if extension == "wav":
		# No conversion needed, just copy to project
		print("[AssetInputEntry] WAV file detected, copying to project")
		_copy_file_to_project(path, current_output_file)
		# Also convert to MP3 for game
		_start_mp3_conversion(current_output_file)
	else:
		# Need to convert to WAV first
		print("[AssetInputEntry] Non-WAV file detected, starting conversion")
		_start_conversion(path)

func _start_conversion(input_path: String) -> void:
	print("[AssetInputEntry] Starting conversion for: ", input_path)
	# Create progress file in temp location
	progress_file_path = input_path.get_basename() + "_progress.txt"
	print("[AssetInputEntry] Progress file: ", progress_file_path)
	
	_set_status("Starting ffmpeg", 0.0)
	
	# Build ffmpeg command for Linux - output directly to project data directory
	# Use WAV container with PCM 16-bit for Godot compatibility
	var args = [
		"-i", input_path,
		"-y",  # Overwrite output file if exists
		"-f", "wav",  # Force WAV container
		"-acodec", "pcm_s16le",  # PCM 16-bit little-endian for Godot
		"-ar", "44100",  # Sample rate 44.1kHz
		"-ac", "2",  # Stereo
		"-map_metadata", "-1",  # Remove metadata
		"-progress", progress_file_path,
		"-nostats",
		"-loglevel", "error",
		current_output_file
	]
	print("[AssetInputEntry] FFmpeg args: ", args)
	
	# Start ffmpeg process
	conversion_process = OS.create_process("ffmpeg", args)
	print("[AssetInputEntry] Conversion process ID: ", conversion_process)
	
	if conversion_process == -1:
		_set_status("Error: Failed to start ffmpeg", 0.0)
		push_error("Failed to start ffmpeg process")
		print("[AssetInputEntry] Error: Failed to start ffmpeg process")
		return
	
	# Start monitoring the process
	print("[AssetInputEntry] Starting conversion monitoring")
	_monitor_conversion()

func _monitor_conversion() -> void:
	print("[AssetInputEntry] Monitoring conversion")
	_set_status("Converting", 10.0)
	
	# Create timer to monitor progress
	progress_timer = Timer.new()
	progress_timer.wait_time = 0.2
	progress_timer.timeout.connect(_check_conversion_status)
	add_child(progress_timer)
	progress_timer.start()
	print("[AssetInputEntry] Progress timer started")

func _check_conversion_status() -> void:
	if conversion_process == -1:
		return
	
	# Read progress file
	_read_ffmpeg_progress()
	
	# Check if process is still running
	var exit_code = OS.get_process_exit_code(conversion_process)
	print("[AssetInputEntry] Process exit code: ", exit_code)
	
	if exit_code != -1:  # Process has exited
		print("[AssetInputEntry] Process exited with code: ", exit_code)
		progress_timer.queue_free()
		progress_timer = null
		
		if exit_code == 0:
			# Success - convert to MP3 for game
			_set_status("Converting to MP3", 95.0)
			await get_tree().process_frame
			_start_mp3_conversion(current_output_file)
		else:
			# Error
			_set_status("Error: Conversion failed", 0.0)
			push_error("ffmpeg exited with code: %d" % exit_code)
			
			# Clean up progress file
			if FileAccess.file_exists(progress_file_path):
				DirAccess.remove_absolute(progress_file_path)
		
		conversion_process = -1

func _read_ffmpeg_progress() -> void:
	if not FileAccess.file_exists(progress_file_path):
		return
	
	var file = FileAccess.open(progress_file_path, FileAccess.READ)
	if not file:
		return
	
	var content = file.get_as_text()
	file.close()
	
	# Parse ffmpeg progress format
	# Looking for lines like: out_time_ms=12345678
	var lines = content.split("\n")
	var out_time_ms: String = ""
	var total_duration_ms: String = ""
	
	for line in lines:
		if line.begins_with("out_time_ms="):
			out_time_ms = line.split("=")[1]
		elif line.begins_with("duration="):
			var duration_str = line.split("=")[1]
			# Convert duration (HH:MM:SS.mmm) to milliseconds
			total_duration_ms = _parse_duration_to_ms(duration_str)
	
	if out_time_ms != "" and total_duration_ms != "":
		var current_ms = out_time_ms.to_int()
		var total_ms = total_duration_ms.to_int()
		
		if total_ms > 0:
			var progress = (float(current_ms) / float(total_ms)) * 100.0
			progress = clamp(progress, 10.0, 90.0)  # Keep between 10-90% during conversion
			_set_status("Converting", progress)

func _parse_duration_to_ms(duration: String) -> String:
	# Duration format: HH:MM:SS.mmm
	var parts = duration.split(":")
	if parts.size() < 3:
		return "0"
	
	var hours = parts[0].to_int()
	var minutes = parts[1].to_int()
	var seconds_parts = parts[2].split(".")
	var seconds = seconds_parts[0].to_int()
	var millis = 0
	if seconds_parts.size() > 1:
		millis = seconds_parts[1].to_int()
	
	var total_ms = (hours * 3600000) + (minutes * 60000) + (seconds * 1000) + millis
	return str(total_ms)

func _set_status(status: String, progress: float) -> void:
	status_label.text = status
	progress_bar.value = progress

func _update_paths(_original_path: String, wav_path: String) -> void:
	path_edit.text = wav_path
	
	# Calculate relative path from project data directory
	var data_path = music_editor.get_data_path()
	if not data_path.is_empty():
		if wav_path.begins_with(data_path):
			var relative = wav_path.substr(data_path.length())
			relative_path_edit.text = "data" + relative
		else:
			relative_path_edit.text = wav_path
	else:
		relative_path_edit.text = wav_path

func _update_asset_label() -> void:
	asset_name_label.text = original_filename + " -> " + config_key

func _get_selected_config_key() -> String:
	print("[AssetInputEntry] Getting selected config key")
	var tree = music_editor.tree
	var selected = tree.get_selected()
	print("[AssetInputEntry] Selected tree item: ", selected)
	
	if not selected:
		print("[AssetInputEntry] No tree item selected")
		return ""
	
	var selected_text = selected.get_text(0)
	print("[AssetInputEntry] Selected text: ", selected_text)
	
	# Skip the package config item
	if selected_text.contains("Package Config"):
		print("[AssetInputEntry] Package Config selected, skipping")
		return ""
	
	# Look up the key from data.cfg
	var config = ConfigFile.new()
	config.load("res://data/data.cfg")
	var keys = config.get_section_keys("MusicKitEntry")
	print("[AssetInputEntry] Available keys: ", keys)
	
	for key in keys:
		var display_name = config.get_value("MusicKitEntry", key, key)
		if display_name == selected_text:
			print("[AssetInputEntry] Found matching key: ", key)
			return key
	
	print("[AssetInputEntry] No matching key found")
	return ""

func _copy_file_to_project(source: String, dest: String) -> void:
	_set_status("Copying", 50.0)
	
	var dir = DirAccess.open("/")
	if not dir:
		_set_status("Error: Failed to open directory", 0.0)
		return
	
	var error = dir.copy(source, dest)
	if error == OK:
		_set_status("Idle", 100.0)
		_update_paths(source, dest)
		_update_asset_label()
	else:
		_set_status("Error: Failed to copy file", 0.0)
		push_error("Failed to copy file: %s" % error)

func _start_mp3_conversion(wav_path: String) -> void:
	print("[AssetInputEntry] Starting MP3 conversion from: ", wav_path)
	
	var args = [
		"-i", wav_path,
		"-y",
		"-f", "mp3",
		"-acodec", "libmp3lame",
		"-ar", "44100",
		"-ac", "2",
		"-b:a", "192k",
		"-map_metadata", "-1",
		"-loglevel", "error",
		current_output_mp3
	]
	
	print("[AssetInputEntry] MP3 conversion args: ", args)
	
	var mp3_process = OS.create_process("ffmpeg", args)
	print("[AssetInputEntry] MP3 conversion process ID: ", mp3_process)
	
	if mp3_process == -1:
		_set_status("Error: Failed to start MP3 conversion", 0.0)
		push_error("Failed to start MP3 conversion process")
		return
	
	# Wait for process to complete
	while OS.get_process_exit_code(mp3_process) == -1:
		await get_tree().process_frame
	
	var exit_code = OS.get_process_exit_code(mp3_process)
	print("[AssetInputEntry] MP3 conversion exit code: ", exit_code)
	
	if exit_code == 0:
		_set_status("Idle", 100.0)
		_update_paths(current_input_file, current_output_file)
		_update_asset_label()
		print("[AssetInputEntry] MP3 conversion complete")
		# Trigger waveform update by emitting asset_selected signal
		if music_editor and music_editor.has_signal("asset_selected"):
			music_editor.asset_selected.emit(config_key, asset_name_label.text)
	else:
		_set_status("Error: MP3 conversion failed", 0.0)
		push_error("MP3 conversion failed with code: %d" % exit_code)
