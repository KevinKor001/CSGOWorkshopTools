extends Node

@export var gameDir = ""
@export var runningDir = OS.get_executable_path()
@export var VERSION = "1.0.0"
@export var IsSupramacyInstall = false
@export var IsToolChainInstalled = false
@export var gameLaunchArgs = ["-windowed", "+echo TEST"]
@export var protonPath = ""
@export var protonPrefix = ""
@export var cleanupOnClose = true
@export var launchGameEnabled = true
@export var disableGameCommunication = false


func getGameDir():
	if gameDir:
		return gameDir.strip_edges()
	return ""
func getToolDir():
	if getGameDir().is_empty():
		# Fallback: use app directory if no game dir is set
		return runningDir.get_base_dir() + "/CSP_Data"
	return getGameDir() + "/CSP_Data"
	
func getToolConfigPath():
	return getToolDir() + "/config.cfg"

func getProtonExec():
	return protonPath + "/proton"

func getFFmpegPath() -> String:
	if OS.get_name() == "Windows":
		# On Windows, assume ffmpeg.exe is in the same directory as the application
		var exe_path = OS.get_executable_path()
		var exe_dir = exe_path.get_base_dir()
		return exe_dir + "/ffmpeg.exe"
	else:
		# On Linux, assume ffmpeg is in PATH
		return "ffmpeg"

func detectCSGOPath() -> String:
	if OS.get_name() == "Windows":
		# Windows: Look for Steam and find CSGO in library folders
		var steam_root = _find_windows_steam_root()
		if steam_root != "":
			var library_folders = _get_windows_steam_library_folders(steam_root)
			for lib_path in library_folders:
				var csgo_path = lib_path + "/steamapps/common/csgo legacy"
				if DirAccess.dir_exists_absolute(csgo_path):
					return csgo_path
	else:
		# Linux: Could be implemented similarly if needed
		pass
	return ""

func _find_windows_steam_root() -> String:
	var possible_paths = [
		OS.get_environment("ProgramFiles(x86)") + "/Steam",
		OS.get_environment("ProgramFiles") + "/Steam",
		OS.get_environment("ProgramW6432") + "/Steam",
		"C:/Program Files (x86)/Steam",
		"C:/Program Files/Steam",
	]
	
	for path in possible_paths:
		if DirAccess.dir_exists_absolute(path):
			return path
	return ""

func _get_windows_steam_library_folders(steam_root: String) -> Array:
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
						# Convert backslashes to forward slashes for Godot
						lib_path = lib_path.replace("\\", "/")
						if DirAccess.dir_exists_absolute(lib_path):
							libraries.append(lib_path)
	
	return libraries

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Start with command line argument if provided
	gameDir = ArgParser.csgo_dir

	var config = ConfigFile.new()
	var config_path = getToolConfigPath()
	print("loading from "+ config_path)
	var load_result = config.load(config_path)

	if load_result == OK:
		# Only use config value if command line argument wasn't provided
		if gameDir.is_empty():
			gameDir = config.get_value("General", "csgo_install", "")
		IsSupramacyInstall = config.get_value("General", "supremacy_install", false)
		launchGameEnabled = config.get_value("General", "launch_game", true)
		disableGameCommunication = config.get_value("General", "disable_communication", false)
		gameLaunchArgs = config.get_value("General", "launch_args", ["-windowed", "+echo TEST"])
		protonPath = config.get_value("Linux", "ProtonPath", "")
		protonPrefix = config.get_value("Linux", "ProtonPrefix", "")
	else:
		print("Config file not found or failed to load: ", config_path)

	print("Final gameDir: ", gameDir)

	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
