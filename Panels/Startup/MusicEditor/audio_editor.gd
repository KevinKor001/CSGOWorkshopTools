extends Panel

# UI Node references
@onready var waveform: TextureRect = \
		$VBoxContainer/Panel/ScrollContainer/TextureRect
@onready var waveform_panel: Panel = \
		$VBoxContainer/Panel/ScrollContainer/TextureRect/Panel
@onready var playhead: Panel = \
		$VBoxContainer/Panel/ScrollContainer/TextureRect/Panel/Playhead
@onready var clock_label: Label = $VBoxContainer/ToolBar/Clock/ClockLabel
@onready var total_track_time: Label = \
		$VBoxContainer/Panel/ScrollContainer/TextureRect/Panel/TotalTrackTime
@onready var play_button: Button = $VBoxContainer/ToolBar/Play
@onready var pause_button: Button = $VBoxContainer/ToolBar/Pause
@onready var stop_button: Button = $VBoxContainer/ToolBar/top
@onready var save_button: Button = $VBoxContainer/ToolBar/Save

# Track Config UI references
@onready var priority_spinbox: SpinBox = \
		$VBoxContainer/TrackConfig/Panel/Data/Priority
@onready var priority_override_check: CheckBox = \
		$VBoxContainer/TrackConfig/Panel/Data/PriorityOverride
@onready var track_start_point: LineEdit = \
		$VBoxContainer/TrackConfig/Panel/Data/TrackStartPoint
@onready var lock_start_to_playhead: Button = \
		$VBoxContainer/TrackConfig/Panel/Data/HBoxContainer/LockEndToPlayhead
@onready var set_start_to_playhead: Button = \
		$VBoxContainer/TrackConfig/Panel/Data/HBoxContainer/SetStartToPlayhead
@onready var track_end_point: LineEdit = \
		$VBoxContainer/TrackConfig/Panel/Data/TrackEndPoint
@onready var lock_end_to_playhead: Button = \
		$VBoxContainer/TrackConfig/Panel/Data/HBoxContainer2/LockEndToPlayhead
@onready var set_end_to_playhead: Button = \
		$VBoxContainer/TrackConfig/Panel/Data/HBoxContainer2/SetEndToPlayhead

# Audio playback
var audio_player: AudioStreamPlayer
var is_playing: bool = false
var is_dragging_playhead: bool = false
var current_time: float = 0.0
var total_duration: float = 0.0

# Track config state
var lock_start_enabled: bool = false
var lock_end_enabled: bool = false
var current_config_key: String = ""
var has_start_point: bool = false
var has_end_point: bool = false
var has_priority: bool = false
var has_priority_override: bool = false

func _ready() -> void:
	# Create audio player for playback
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	
	# Connect signals
	waveform_panel.gui_input.connect(_on_waveform_input)
	play_button.pressed.connect(_on_play_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	stop_button.pressed.connect(_on_stop_pressed)
	save_button.pressed.connect(_on_save_pressed)
	
	# Connect track config buttons
	lock_start_to_playhead.pressed.connect(_on_lock_start_toggled)
	set_start_to_playhead.pressed.connect(_on_set_start_to_playhead)
	lock_end_to_playhead.pressed.connect(_on_lock_end_toggled)
	set_end_to_playhead.pressed.connect(_on_set_end_to_playhead)
	
	# Connect to MusicEditor asset selection signal
	var music_editor = $"../../../.."
	music_editor.asset_selected.connect(_on_asset_selected)
	
	# Load audio from waveform renderer
	if waveform.audio_stream:
		audio_player.stream = waveform.audio_stream
		total_duration = waveform.audio_stream.get_length()
		_update_total_time_label()

func _process(_delta: float) -> void:
	if is_playing and audio_player.playing:
		current_time = audio_player.get_playback_position()
		_update_playhead_from_time()
		_update_clock_label()
	
	# Update locked start/end points if enabled
	if lock_start_enabled:
		track_start_point.text = _format_config_time(current_time)
	if lock_end_enabled:
		track_end_point.text = _format_config_time(current_time)

func _on_waveform_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging_playhead = true
				_update_playhead_from_mouse(event.position.x)
			else:
				is_dragging_playhead = false
	elif event is InputEventMouseMotion and is_dragging_playhead:
		_update_playhead_from_mouse(event.position.x)

func _update_playhead_from_mouse(mouse_x: float) -> void:
	var waveform_width = waveform.size.x
	var clamped_x = clamp(mouse_x, 0, waveform_width)
	var ratio = clamped_x / waveform_width
	
	# Update playhead position
	playhead.position.x = clamped_x
	
	# Update time
	current_time = ratio * total_duration
	if audio_player.stream:
		audio_player.seek(current_time)
	
	_update_clock_label()

func _update_playhead_from_time() -> void:
	if total_duration > 0:
		var ratio = current_time / total_duration
		var waveform_width = waveform.size.x
		playhead.position.x = ratio * waveform_width

func _update_clock_label() -> void:
	clock_label.text = _format_time(current_time)

func _update_total_time_label() -> void:
	total_track_time.text = _format_time(total_duration) + "E"

func _format_time(seconds: float) -> String:
	var mins = int(seconds / 60)
	var secs = int(seconds) % 60
	var centis = int((seconds - int(seconds)) * 100)
	return "%02d:%02d:%02d" % [mins, secs, centis]

func _on_play_pressed() -> void:
	if audio_player.stream:
		if not audio_player.playing:
			audio_player.play(current_time)
		is_playing = true

func _on_pause_pressed() -> void:
	if audio_player.playing:
		audio_player.stop()
		is_playing = false

func _on_stop_pressed() -> void:
	if audio_player.playing:
		audio_player.stop()
	is_playing = false
	current_time = 0.0
	_update_playhead_from_time()
	_update_clock_label()

func _on_lock_start_toggled() -> void:
	lock_start_enabled = lock_start_to_playhead.button_pressed
	print("[AudioEditor] Lock start to playhead: ", lock_start_enabled)

func _on_set_start_to_playhead() -> void:
	track_start_point.text = _format_config_time(current_time)
	print("[AudioEditor] Set start point to: ", current_time)

func _on_lock_end_toggled() -> void:
	lock_end_enabled = lock_end_to_playhead.button_pressed
	print("[AudioEditor] Lock end to playhead: ", lock_end_enabled)

func _on_set_end_to_playhead() -> void:
	track_end_point.text = _format_config_time(current_time)
	print("[AudioEditor] Set end point to: ", current_time)

func _format_config_time(time: float) -> String:
	return "%.6f" % maxf(time, 0.0)

func _on_save_pressed() -> void:
	if current_config_key.is_empty():
		print("[AudioEditor] No track selected, cannot save config")
		return

	var start_point = _parse_point(track_start_point.text, 0.0)
	var end_point = _parse_point(track_end_point.text, total_duration)
	if end_point < start_point:
		end_point = start_point
	track_start_point.text = _format_config_time(start_point)
	track_end_point.text = _format_config_time(end_point)

	var music_editor = $"../../../.."
	var saved = music_editor.save_track_config(
		current_config_key,
		track_start_point.text,
		track_end_point.text,
		int(priority_spinbox.value),
		priority_override_check.button_pressed,
		has_start_point,
		has_end_point,
		has_priority,
		has_priority_override
	)
	print("[AudioEditor] Track config save result: ", saved)

func _parse_point(value: String, fallback: float) -> float:
	var parsed = value.to_float()
	if value.strip_edges().is_empty():
		return fallback
	return maxf(parsed, 0.0)

func _on_asset_selected(config_key: String, display_name: String) -> void:
	print("[AudioEditor] Asset selected: %s (%s)" % [display_name, config_key])
	
	current_config_key = config_key
	
	# Get music editor reference
	var music_editor = $"../../../.."
	var data_path = music_editor.get_data_path()
	
	if data_path.is_empty():
		print("[AudioEditor] No project loaded")
		return

	# Load configuration independently of the audio asset. A track can have
	# valid track_data even when its WAV has not been imported yet.
	_load_track_config(data_path, config_key)
	
	# Construct path to WAV file in project data directory
	var wav_path = data_path + "/" + config_key + ".wav"
	print("[AudioEditor] Loading WAV from: ", wav_path)
	
	if not FileAccess.file_exists(wav_path):
		print("[AudioEditor] WAV file does not exist: ", wav_path)
		return
	
	# Load the WAV file - read raw data and set it manually for external files
	var file = FileAccess.open(wav_path, FileAccess.READ)
	if not file:
		print("[AudioEditor] Failed to open file for reading")
		return
	
	var file_data = file.get_buffer(file.get_length())
	file.close()
	print("[AudioEditor] Read %d bytes from file" % file_data.size())
	
	var audio_stream = AudioStreamWAV.new()
	audio_stream.data = file_data
	
	# Explicitly set format for PCM 16-bit stereo
	audio_stream.format = AudioStreamWAV.FORMAT_16_BITS
	audio_stream.stereo = true
	
	# Check if stream has data
	if audio_stream.data.size() > 0:
		# Update waveform renderer
		waveform.audio_stream = audio_stream
		waveform.generate_waveform(audio_stream)
		
		# Update audio player
		audio_player.stream = audio_stream
		total_duration = audio_stream.get_length()
		_update_total_time_label()
		
		# Reset playhead
		current_time = 0.0
		_update_playhead_from_time()
		_update_clock_label()
		
		print("[AudioEditor] Successfully loaded: ", wav_path)
		print("[AudioEditor] Data size: ", audio_stream.data.size())
		print("[AudioEditor] Format: ", audio_stream.format, " Stereo: ", audio_stream.stereo)
	else:
		print("[AudioEditor] Failed to load WAV - no data after manual load")
	
func _load_track_config(data_path: String, config_key: String) -> void:
	var gsm_path = data_path + "/game_sounds_music.txt"
	if not FileAccess.file_exists(gsm_path):
		print("[AudioEditor] game_sounds_music.txt not found, using defaults")
		_set_default_track_config()
		return
	
	var file = FileAccess.open(gsm_path, FileAccess.READ)
	if not file:
		print("[AudioEditor] Failed to open game_sounds_music.txt, using defaults")
		_set_default_track_config()
		return
	
	var content = file.get_as_text()
	file.close()
	
	# Find the entry for this config key
	var entry_name = "Music." + config_key + ".custom_01"
	var entry_start = _find_music_entry_start(content, config_key)
	
	if entry_start == -1:
		# The project copy can predate newer entries in the bundled template.
		var default_file = FileAccess.open("res://data/game_sounds_music.txt", FileAccess.READ)
		if default_file:
			content = default_file.get_as_text()
			default_file.close()
			entry_start = _find_music_entry_start(content, config_key)
		if entry_start == -1:
			print("[AudioEditor] Entry not found in game_sounds_music.txt: ", entry_name)
			_set_default_track_config()
			return
		print("[AudioEditor] Loaded track config from bundled default: ", entry_name)
	
	# Find the track_data section within this entry
	var entry_end = _find_entry_end(content, entry_start)
	if entry_end == -1:
		print("[AudioEditor] Could not find entry end: ", entry_name)
		_set_default_track_config()
		return
	var track_data_start = content.find('"track_data"', entry_start)
	if track_data_start == -1 or track_data_start > entry_end:
		track_data_start = -1
	if track_data_start == -1:
		print("[AudioEditor] track_data not found for entry: ", entry_name)
		_set_default_track_config()
		return
	
	# Find the closing brace for track_data
	var brace_count = 0
	var in_track_data = false
	var track_data_end = -1
	
	for i in range(track_data_start, content.length()):
		var char = content[i]
		if char == '{':
			brace_count += 1
			in_track_data = true
		elif char == '}':
			brace_count -= 1
			if in_track_data and brace_count == 0:
				track_data_end = i
				break
	
	if track_data_end == -1:
		print("[AudioEditor] Could not find track_data end")
		_set_default_track_config()
		return
	
	var track_data_section = content.substr(track_data_start, track_data_end - track_data_start + 1)
	
	# Parse values from track_data
	var start_point = _parse_config_value(track_data_section, "start_point")
	var end_point = _parse_config_value(track_data_section, "end_point")
	var priority = _parse_config_value(track_data_section, "priority")
	var priority_override = _parse_config_value(track_data_section, "priority_override")
	has_start_point = not start_point.is_empty()
	has_end_point = not end_point.is_empty()
	has_priority = not priority.is_empty()
	has_priority_override = not priority_override.is_empty()
	
	# Set UI values
	track_start_point.text = start_point if not start_point.is_empty() else "0.0"
	track_end_point.text = end_point if not end_point.is_empty() else str(total_duration)
	priority_spinbox.value = priority.to_int() if not priority.is_empty() else 2
	priority_override_check.button_pressed = (priority_override == "true")
	lock_start_enabled = false
	lock_end_enabled = false
	lock_start_to_playhead.button_pressed = false
	lock_end_to_playhead.button_pressed = false
	_update_config_controls()
	
	print("[AudioEditor] Loaded track config - start: %s, end: %s, priority: %s, override: %s" 
		% [track_start_point.text, track_end_point.text, 
		priority_spinbox.value, priority_override_check.button_pressed])

func _parse_config_value(section: String, key: String) -> String:
	var key_pattern = '"' + key + '"'
	var key_pos = section.find(key_pattern)
	if key_pos == -1:
		return ""
	
	var value_start = key_pos + key_pattern.length()
	var value_section = section.substr(value_start)
	
	# Find the value (it should be in quotes)
	var quote_start = value_section.find('"')
	if quote_start == -1:
		return ""
	
	var quote_end = value_section.find('"', quote_start + 1)
	if quote_end == -1:
		return ""
	
	return value_section.substr(quote_start + 1, quote_end - quote_start - 1)

func _set_default_track_config() -> void:
	track_start_point.text = "0.0"
	track_end_point.text = str(total_duration)
	priority_spinbox.value = 2
	priority_override_check.button_pressed = false
	lock_start_enabled = false
	lock_end_enabled = false
	lock_start_to_playhead.button_pressed = false
	lock_end_to_playhead.button_pressed = false
	has_start_point = false
	has_end_point = false
	has_priority = false
	has_priority_override = false
	_update_config_controls()
	print("[AudioEditor] Set default track config")

func _update_config_controls() -> void:
	track_start_point.editable = has_start_point
	lock_start_to_playhead.disabled = not has_start_point
	set_start_to_playhead.disabled = not has_start_point
	track_end_point.editable = has_end_point
	lock_end_to_playhead.disabled = not has_end_point
	set_end_to_playhead.disabled = not has_end_point
	priority_spinbox.editable = has_priority
	priority_override_check.disabled = not has_priority_override

func _find_entry_end(content: String, entry_start: int) -> int:
	var open_brace = content.find("{", entry_start)
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

	# Some display/config names differ from the sound-entry name. Match the
	# imported audio filename used by the entry as a fallback.
	var wave_name = '"*music/custom_01/' + config_key.to_lower() + '.mp3"'
	var wave_start = lower_content.find(wave_name)
	if wave_start != -1:
		var header_start = lower_content.rfind('"music.', wave_start)
		while header_start != -1:
			if header_start == 0 or content[header_start - 1] == "\n":
				return header_start
			header_start = lower_content.rfind('"music.', header_start - 1)
	return -1
