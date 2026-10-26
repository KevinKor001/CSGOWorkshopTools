extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func launchGame(args):
	pass

func launch_with_proton(exe_path: String, arguments: PackedStringArray, proton_path: String, prefix_path: String) -> int:
	var global_path = ProjectSettings.globalize_path(exe_path)
	var global_proton = ProjectSettings.globalize_path(proton_path)
	var global_prefix = ProjectSettings.globalize_path(prefix_path)
	
	print("[GameManager] Exe path: ", global_path)
	print("[GameManager] Proton path: ", global_proton)
	print("[GameManager] Prefix path: ", global_prefix)
	
	# Set environment variables for Proton
	var steam_root = _get_steam_root()
	OS.set_environment("STEAM_COMPAT_DATA_PATH", global_prefix)
	OS.set_environment("STEAM_COMPAT_CLIENT_INSTALL_PATH", steam_root)
	OS.set_environment("SteamAppId", "730")
	OS.set_environment("SteamGameId", "730")
	OS.set_environment("PROTON_LOG", "1")
	OS.set_environment("PROTON_USE_WOW64", "1")
	OS.set_environment("DXVK_ASYNC", "1")
	print("[GameManager] Set STEAM_COMPAT_DATA_PATH: ", global_prefix)
	print("[GameManager] Set STEAM_COMPAT_CLIENT_INSTALL_PATH: ", steam_root)
	print("[GameManager] Set SteamAppId: 730")
	print("[GameManager] Set SteamGameId: 730")
	print("[GameManager] Set DXVK_ASYNC: 1")
	
	# Build command: proton run <exe> [args]
	var full_args = PackedStringArray()
	full_args.append("run")
	full_args.append(global_path)
	full_args.append_array(arguments)
	
	var proton_exec = global_proton + "/proton"
	print("[GameManager] Executing: ", proton_exec)
	print("[GameManager] Arguments: ", full_args)
	
	# Build shell command with environment variables
	# Use quoted paths like the working command
	var shell_cmd = "SteamAppId=\"730\" SteamGameId=\"730\" STEAM_COMPAT_CLIENT_INSTALL_PATH=\"%s\" STEAM_COMPAT_DATA_PATH=\"%s\" PROTON_LOG=1 PROTON_USE_WOW64=1 DXVK_ASYNC=1 \"%s\" run \"%s\" %s" % [steam_root, global_prefix, proton_exec, global_path, " ".join(arguments)]
	print("[GameManager] Shell command: ", shell_cmd)
	
	var pid = OS.create_process("/bin/sh", ["-c", shell_cmd])
	
	if pid != -1:
		print("Game launched via Proton. PID: ", pid)
		return pid
	else:
		push_error("Failed to launch via Proton")
		return -1

func _find_steam_runtime(search_path: String) -> String:
	print("[GameManager] Searching for runtime in: ", search_path)
	
	# Try to find Steam Linux Runtime in the search path
	var runtime_names = ["SteamLinuxRuntime_sniper", "SteamLinuxRuntime_soldier", "SteamLinuxRuntime"]
	for name in runtime_names:
		var test_path = search_path + "/" + name
		print("[GameManager] Checking: ", test_path)
		if DirAccess.dir_exists_absolute(test_path):
			print("[GameManager] Found runtime: ", test_path)
			return test_path
	
	# Try Steam's default runtime location
	var steam_root = _get_steam_root()
	if steam_root != "":
		var default_runtime = steam_root + "/ubuntu12_32/steam-runtime"
		print("[GameManager] Checking fallback: ", default_runtime)
		if DirAccess.dir_exists_absolute(default_runtime):
			print("[GameManager] Using fallback runtime: ", default_runtime)
			return default_runtime
	
	print("[GameManager] No runtime found!")
	return ""

func _get_steam_root() -> String:
	var possible_paths = [
		OS.get_environment("HOME") + "/.steam/steam",
		OS.get_environment("HOME") + "/.local/share/Steam",
	]
	for path in possible_paths:
		if DirAccess.dir_exists_absolute(path):
			return path
	return ""
