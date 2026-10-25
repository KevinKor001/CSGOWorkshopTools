extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func launchGame(args):
	pass
func launch_windows_exe_via_wine(exe_path: String, arguments: PackedStringArray) -> int:
	var global_path = ProjectSettings.globalize_path(exe_path)
	
	#make the argument list: [path_to_exe, arg1, arg2, ...]
	var wine_args = PackedStringArray([global_path])
	wine_args.append_array(arguments)
	
	# Call 'wine' and pass the Windows executable and its flags to it <------------------------ TUD
	var pid = OS.create_process("wine", wine_args)
	
	if pid != -1:
		print("Windows executable launched via Wine. PID: ", pid)
		return pid
	else:
		push_error("Failed to run via Wine. Is Wine installed and in your PATH?")
		return -1
