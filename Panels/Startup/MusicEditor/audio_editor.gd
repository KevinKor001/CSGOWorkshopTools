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

# Audio playback
var audio_player: AudioStreamPlayer
var is_playing: bool = false
var is_dragging_playhead: bool = false
var current_time: float = 0.0
var total_duration: float = 0.0

func _ready() -> void:
	# Create audio player for playback
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	
	# Connect signals
	waveform_panel.gui_input.connect(_on_waveform_input)
	play_button.pressed.connect(_on_play_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	stop_button.pressed.connect(_on_stop_pressed)
	
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

func _on_asset_selected(config_key: String, display_name: String) -> void:
	print("[AudioEditor] Asset selected: %s (%s)" % [display_name, config_key])
	
	# Get music editor reference
	var music_editor = $"../../../.."
	var data_path = music_editor.get_data_path()
	
	if data_path.is_empty():
		print("[AudioEditor] No project loaded")
		return
	
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
