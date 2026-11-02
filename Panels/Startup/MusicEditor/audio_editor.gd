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
@onready var add_sync_point_button: Button = $VBoxContainer/ToolBar/AddSyncPoint
@onready var remove_sync_point_button: Button = $VBoxContainer/ToolBar/RemoveSyncPoint
@onready var sync_point_list: Tree = $VBoxContainer/TrackConfig/SyncPointList
@onready var this_sync_point_time: LineEdit = \
		$VBoxContainer/TrackConfig/Panel/Data/ThisSyncPointTime
@onready var sync_point_info: Label = $VBoxContainer/ToolBar/InfoPanel/SyncPointTimer
@onready var sync_point_timer: Label = $VBoxContainer/ToolBar/Clock/SyncPointTimer
@onready var sync_point_mode: TextureRect = $VBoxContainer/ToolBar/Clock/SyncPointMode
@onready var lock_sync_point_to_playhead: Button = \
		$VBoxContainer/TrackConfig/Panel/Data/HBoxContainer3/LockSyncPointToPlayhead
@onready var set_sync_point_to_playhead: Button = \
		$VBoxContainer/TrackConfig/Panel/Data/HBoxContainer3/SetSyncPointToPlayhead

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
var lock_sync_point_enabled: bool = false
var current_config_key: String = ""
var has_start_point: bool = false
var has_end_point: bool = false
var has_priority: bool = false
var has_priority_override: bool = false
var sync_points_supported: bool = false

const MAX_SYNC_POINTS := 32
const SYNC_POINT_SCENE := preload("res://Panels/Startup/MusicEditor/SyncPointLine.tscn")
const DEFAULT_SYNC_POINT_COLOR_START := Color("ff9500")
const DEFAULT_SYNC_POINT_COLOR_END := Color("6600ff")
const DEFAULT_SYNC_POINT_ALPHA := 150.0 / 255.0
const DEFAULT_SYNC_POINT_HOVER_ALPHA := 200.0 / 255.0
const DEFAULT_SYNC_POINT_NEAR_DISTANCE := 12.0
var sync_point_color_start: Color = DEFAULT_SYNC_POINT_COLOR_START
var sync_point_color_end: Color = DEFAULT_SYNC_POINT_COLOR_END
var sync_point_alpha: float = DEFAULT_SYNC_POINT_ALPHA
var sync_point_hover_alpha: float = DEFAULT_SYNC_POINT_HOVER_ALPHA
var sync_point_near_distance: float = DEFAULT_SYNC_POINT_NEAR_DISTANCE
var sync_points: Array[Dictionary] = []
var selected_sync_point_index: int = -1
var hovered_sync_point_index: int = -1
var dragging_sync_point_index: int = -1

func _ready() -> void:
	_load_sync_point_settings()
	# Create audio player for playback
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	
	# Connect signals
	waveform_panel.gui_input.connect(_on_waveform_input)
	play_button.pressed.connect(_on_play_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	stop_button.pressed.connect(_on_stop_pressed)
	save_button.pressed.connect(_on_save_pressed)
	add_sync_point_button.pressed.connect(_on_add_sync_point_pressed)
	remove_sync_point_button.pressed.connect(_on_remove_sync_point_pressed)
	sync_point_list.item_selected.connect(_on_sync_point_selected)
	sync_point_list.connect("items_reordered", _on_sync_points_reordered)
	waveform_panel.resized.connect(_update_sync_point_positions)
	
	# Connect track config buttons
	lock_start_to_playhead.pressed.connect(_on_lock_start_toggled)
	set_start_to_playhead.pressed.connect(_on_set_start_to_playhead)
	lock_end_to_playhead.pressed.connect(_on_lock_end_toggled)
	set_end_to_playhead.pressed.connect(_on_set_end_to_playhead)
	lock_sync_point_to_playhead.pressed.connect(_on_lock_sync_point_toggled)
	set_sync_point_to_playhead.pressed.connect(_on_set_sync_point_to_playhead)
	
	# Connect to MusicEditor asset selection signal
	var music_editor = $"../../../.."
	music_editor.asset_selected.connect(_on_asset_selected)
	
	# Load audio from waveform renderer
	if waveform.audio_stream:
		audio_player.stream = waveform.audio_stream
		total_duration = waveform.audio_stream.get_length()
		_update_total_time_label()
	_refresh_sync_point_ui()

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
	if lock_sync_point_enabled:
		_set_selected_sync_point_time(current_time)

func _on_waveform_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var nearby_sync_point := _find_sync_point_near(event.position.x)
				if _is_ctrl_pressed(event) and nearby_sync_point != -1:
					_set_sync_point_mode_visible(true)
					is_dragging_playhead = false
					dragging_sync_point_index = nearby_sync_point
					selected_sync_point_index = nearby_sync_point
					_update_sync_point_time(event.position.x)
					_refresh_sync_point_selection()
					_update_sync_point_positions()
					return
				is_dragging_playhead = true
				_update_playhead_from_mouse(event.position.x)
			else:
				if dragging_sync_point_index != -1:
					dragging_sync_point_index = -1
					_update_sync_point_positions()
					return
				is_dragging_playhead = false
	elif event is InputEventMouseMotion:
		if dragging_sync_point_index != -1:
			_update_sync_point_time(event.position.x)
			_update_sync_point_positions()
		elif is_dragging_playhead:
			_update_playhead_from_mouse(event.position.x)
		else:
			var nearby_sync_point := _find_sync_point_near(event.position.x)
			var next_hovered := nearby_sync_point if _is_ctrl_pressed(event) else -1
			_set_sync_point_mode_visible(_is_ctrl_pressed(event) or dragging_sync_point_index != -1)
			if next_hovered != hovered_sync_point_index:
				hovered_sync_point_index = next_hovered
				_update_sync_point_positions()

func _is_ctrl_pressed(event: InputEvent) -> bool:
	return event is InputEventWithModifiers and event.ctrl_pressed

func _set_sync_point_mode_visible(visible: bool) -> void:
	sync_point_timer.visible = visible
	sync_point_mode.visible = visible
	_update_sync_point_timer()

func _update_sync_point_timer() -> void:
	var live_index := dragging_sync_point_index if dragging_sync_point_index != -1 else hovered_sync_point_index
	if live_index == -1:
		live_index = selected_sync_point_index
	if live_index >= 0 and live_index < sync_points.size():
		sync_point_timer.text = _format_time(sync_points[live_index]["time"])
	else:
		sync_point_timer.text = _format_time(0.0)

func _find_sync_point_near(mouse_x: float) -> int:
	var closest_index := -1
	var closest_distance := sync_point_near_distance
	for index in sync_points.size():
		var ratio := 0.0 if total_duration <= 0.0 else float(sync_points[index]["time"]) / total_duration
		var marker_x := ratio * waveform_panel.size.x
		var distance := absf(mouse_x - marker_x)
		if distance <= closest_distance:
			closest_distance = distance
			closest_index = index
	return closest_index

func _update_sync_point_time(mouse_x: float) -> void:
	if dragging_sync_point_index < 0 or dragging_sync_point_index >= sync_points.size():
		return
	var waveform_width := maxf(waveform_panel.size.x, 1.0)
	var ratio := clampf(mouse_x / waveform_width, 0.0, 1.0)
	sync_points[dragging_sync_point_index]["time"] = ratio * total_duration
	var item := sync_point_list.get_root().get_child(dragging_sync_point_index)
	if item != null:
		item.set_text(0, "#S%02d  %s" % [dragging_sync_point_index, _format_config_time(sync_points[dragging_sync_point_index]["time"])])
	_update_selected_sync_point_controls()
	_update_sync_point_timer()

func _set_selected_sync_point_time(time: float) -> void:
	if selected_sync_point_index < 0 or selected_sync_point_index >= sync_points.size():
		return
	sync_points[selected_sync_point_index]["time"] = clampf(time, 0.0, total_duration)
	var item := sync_point_list.get_root().get_child(selected_sync_point_index)
	if item != null:
		item.set_text(0, "#S%02d  %s" % [selected_sync_point_index, _format_config_time(sync_points[selected_sync_point_index]["time"])])
	_update_selected_sync_point_controls()
	_update_sync_point_positions()
	_update_sync_point_timer()

func _refresh_sync_point_selection() -> void:
	var root := sync_point_list.get_root()
	if root != null and selected_sync_point_index >= 0 and selected_sync_point_index < sync_points.size():
		sync_point_list.set_selected(root.get_child(selected_sync_point_index), 0)

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
	_update_sync_point_positions()

func _on_add_sync_point_pressed() -> void:
	if sync_points.size() >= MAX_SYNC_POINTS:
		return
	sync_points.append({"time": clampf(current_time, 0.0, total_duration)})
	selected_sync_point_index = sync_points.size() - 1
	_refresh_sync_point_ui()

func _on_remove_sync_point_pressed() -> void:
	if selected_sync_point_index < 0 or selected_sync_point_index >= sync_points.size():
		return
	sync_points.remove_at(selected_sync_point_index)
	selected_sync_point_index = mini(selected_sync_point_index, sync_points.size() - 1)
	_refresh_sync_point_ui()

func _on_sync_point_selected() -> void:
	var item := sync_point_list.get_selected()
	if item == null:
		return
	selected_sync_point_index = int(item.get_metadata(0))
	_update_selected_sync_point_controls()
	_update_sync_point_timer()

func _on_lock_sync_point_toggled() -> void:
	lock_sync_point_enabled = lock_sync_point_to_playhead.button_pressed

func _on_set_sync_point_to_playhead() -> void:
	_set_selected_sync_point_time(current_time)

func _on_sync_points_reordered(from_index: int, to_index: int) -> void:
	if from_index < 0 or from_index >= sync_points.size() or to_index < 0 or to_index >= sync_points.size():
		return
	var point: Dictionary = sync_points.pop_at(from_index)
	sync_points.insert(to_index, point)
	selected_sync_point_index = to_index
	_refresh_sync_point_ui()

func _sync_point_color(index: int, highlighted: bool = false) -> Color:
	var alpha := sync_point_hover_alpha if highlighted else sync_point_alpha
	if sync_points.size() <= 1:
		var single_color := sync_point_color_start
		single_color.a = alpha
		return single_color
	var point_color := sync_point_color_start.lerp(sync_point_color_end, float(index) / float(sync_points.size() - 1))
	point_color.a = alpha
	return point_color

func _load_sync_point_settings() -> void:
	sync_point_color_start = ProjectSettings.get_setting(
		"music_editor/sync_point_color_start", DEFAULT_SYNC_POINT_COLOR_START)
	sync_point_color_end = ProjectSettings.get_setting(
		"music_editor/sync_point_color_end", DEFAULT_SYNC_POINT_COLOR_END)
	sync_point_alpha = clampf(ProjectSettings.get_setting(
		"music_editor/sync_point_alpha", DEFAULT_SYNC_POINT_ALPHA), 0.0, 1.0)
	sync_point_hover_alpha = clampf(ProjectSettings.get_setting(
		"music_editor/sync_point_hover_alpha", DEFAULT_SYNC_POINT_HOVER_ALPHA), 0.0, 1.0)
	sync_point_near_distance = maxf(ProjectSettings.get_setting(
		"music_editor/sync_point_near_distance", DEFAULT_SYNC_POINT_NEAR_DISTANCE), 0.0)

func _refresh_sync_point_ui() -> void:
	for child in waveform_panel.get_children():
		if child.has_method("get_sync_point_index"):
			child.free()

	sync_point_list.clear()
	var root := sync_point_list.create_item()
	for index in sync_points.size():
		var item := sync_point_list.create_item(root)
		var time: float = sync_points[index]["time"]
		item.set_text(0, "#S%02d  %s" % [index, _format_config_time(time)])
		item.set_metadata(0, index)
		item.set_custom_color(0, _sync_point_color(index))

	_update_sync_point_positions()
	if selected_sync_point_index >= 0 and selected_sync_point_index < sync_points.size():
		sync_point_list.set_selected(sync_point_list.get_root().get_child(selected_sync_point_index), 0)
	_update_selected_sync_point_controls()
	_update_sync_point_timer()
	_update_config_controls()

func _update_sync_point_positions() -> void:
	var highlighted_index := dragging_sync_point_index if dragging_sync_point_index != -1 else hovered_sync_point_index
	for child in waveform_panel.get_children():
		if not child.has_method("get_sync_point_index"):
			continue
		var index: int = child.get_sync_point_index()
		if index < 0 or index >= sync_points.size():
			continue
		child.set_sync_point(index, sync_points[index]["time"], _sync_point_color(index, index == highlighted_index))

	for index in sync_points.size():
		var marker = waveform_panel.get_node_or_null("SyncPoint_%02d" % index)
		if marker == null:
			marker = SYNC_POINT_SCENE.instantiate()
			marker.name = "SyncPoint_%02d" % index
			waveform_panel.add_child(marker)
		marker.size = Vector2(15.0, waveform_panel.size.y)
		marker.set_sync_point(index, sync_points[index]["time"], _sync_point_color(index, index == highlighted_index))
		var ratio := 0.0 if total_duration <= 0.0 else float(sync_points[index]["time"]) / total_duration
		marker.position = Vector2(clampf(ratio * waveform_panel.size.x - 7.5, 0.0, maxf(waveform_panel.size.x - 15.0, 0.0)), 0.0)

func _update_selected_sync_point_controls() -> void:
	if selected_sync_point_index < 0 or selected_sync_point_index >= sync_points.size():
		this_sync_point_time.text = ""
		sync_point_info.text = "SyncPoint #-/-"
		remove_sync_point_button.disabled = true
		lock_sync_point_to_playhead.disabled = true
		set_sync_point_to_playhead.disabled = true
		return
	var time: float = sync_points[selected_sync_point_index]["time"]
	this_sync_point_time.text = _format_config_time(time)
	sync_point_info.text = "SyncPoint #%02d/%02d" % [selected_sync_point_index, sync_points.size()]
	remove_sync_point_button.disabled = not sync_points_supported
	lock_sync_point_to_playhead.disabled = not sync_points_supported
	set_sync_point_to_playhead.disabled = not sync_points_supported

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
	current_time = clampf(_parse_point(track_start_point.text, 0.0), 0.0, total_duration)
	if audio_player.stream:
		audio_player.seek(current_time)
	_update_playhead_from_time()
	_update_clock_label()

func _on_lock_start_toggled() -> void:
	lock_start_enabled = lock_start_to_playhead.button_pressed
	print("[AudioEditor] Lock start to playhead: ", lock_start_enabled)

func _on_set_start_to_playhead() -> void:
	_set_playhead_to_config_time(track_start_point.text)
	print("[AudioEditor] Moved playhead to start point: ", current_time)

func _on_lock_end_toggled() -> void:
	lock_end_enabled = lock_end_to_playhead.button_pressed
	print("[AudioEditor] Lock end to playhead: ", lock_end_enabled)

func _on_set_end_to_playhead() -> void:
	_set_playhead_to_config_time(track_end_point.text)
	print("[AudioEditor] Moved playhead to end point: ", current_time)

func _set_playhead_to_config_time(value: String) -> void:
	var target_time := _parse_point(value, current_time)
	current_time = clampf(target_time, 0.0, total_duration)
	if audio_player.stream:
		audio_player.seek(current_time)
	_update_playhead_from_time()
	_update_clock_label()

func _format_config_time(time: float) -> String:
	return "%.6f" % maxf(time, 0.0)

func _on_save_pressed() -> void:
	save_current_track_config()

func save_current_track_config() -> bool:
	if current_config_key.is_empty():
		print("[AudioEditor] No track selected, cannot save config")
		return false

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
		has_priority_override,
		sync_points.duplicate(true),
		sync_points_supported
	)
	print("[AudioEditor] Track config save result: ", saved)
	return saved

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
		
		# Start playback at the configured track start point.
		current_time = clampf(_parse_point(track_start_point.text, 0.0), 0.0, total_duration)
		if audio_player.stream:
			audio_player.seek(current_time)
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
	_load_sync_points(track_data_section)
	
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
	lock_sync_point_enabled = false
	lock_start_to_playhead.button_pressed = false
	lock_end_to_playhead.button_pressed = false
	lock_sync_point_to_playhead.button_pressed = false
	_update_config_controls()
	
	print("[AudioEditor] Loaded track config - start: %s, end: %s, priority: %s, override: %s" 
		% [track_start_point.text, track_end_point.text, 
		priority_spinbox.value, priority_override_check.button_pressed])
	_refresh_sync_point_ui()

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
	lock_sync_point_enabled = false
	lock_start_to_playhead.button_pressed = false
	lock_end_to_playhead.button_pressed = false
	lock_sync_point_to_playhead.button_pressed = false
	has_start_point = false
	has_end_point = false
	has_priority = false
	has_priority_override = false
	sync_points_supported = false
	sync_points.clear()
	_update_config_controls()
	_refresh_sync_point_ui()
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
	add_sync_point_button.disabled = not sync_points_supported or sync_points.size() >= MAX_SYNC_POINTS
	remove_sync_point_button.disabled = not sync_points_supported or selected_sync_point_index < 0
	lock_sync_point_to_playhead.disabled = not sync_points_supported or selected_sync_point_index < 0
	set_sync_point_to_playhead.disabled = not sync_points_supported or selected_sync_point_index < 0

func _load_sync_points(track_data_section: String) -> void:
	sync_points.clear()
	selected_sync_point_index = -1
	var syncpoints_start := track_data_section.find('"syncpoints"')
	sync_points_supported = syncpoints_start != -1
	if not sync_points_supported:
		_update_config_controls()
		return
	var syncpoints_end := _find_entry_end(track_data_section, syncpoints_start)
	if syncpoints_end == -1:
		_update_config_controls()
		return
	var syncpoints_section := track_data_section.substr(syncpoints_start, syncpoints_end - syncpoints_start + 1)
	var regex := RegEx.new()
	regex.compile('"(\\d+)"\\s+"([^"]+)"')
	for match in regex.search_all(syncpoints_section):
		if sync_points.size() >= MAX_SYNC_POINTS:
			break
		sync_points.append({"time": maxf(match.get_string(2).to_float(), 0.0)})
	_update_config_controls()

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
