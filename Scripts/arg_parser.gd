# arg_parser.gd
extends Node

# Global variables set via arguments
var csgo_dir: String = ""

# Dictionary to map flags to callables/functions
# format: "-flag_name": Callable
var function_args: Dictionary = {}

func _ready() -> void:
	#Register function callbacks here
	_register_function_args()
	
	# Parse arguments on startup
	_parse_arguments()
func escape_spaces(input: String) -> String:
	return input.replace(" ", "\\ ")

func _register_function_args() -> void:
	# Register flags that trigger functions whe in command line
	# Usage : -test_func
	register_arg_function("-test_func", _on_test_func_called)
	register_arg_function("-print_hello", func(): print("Hello from argument trigger!"))


func register_arg_function(flag: String, callback: Callable) -> void:
	function_args[flag] = callback

func _parse_arguments() -> void:

	var args: PackedStringArray = OS.get_cmdline_user_args()

	if args.is_empty():
		args = OS.get_cmdline_args()
		
	print("[ArgParser] Raw arguments detected: ", args)
	
	var i: int = 0
	while i < args.size():
		var arg: String = args[i]
		
		match arg:
			# --- VALUE ARGUMENTS ---
			"-csgo_dir":
				if i + 1 < args.size():
					csgo_dir = args[i + 1]
					csgo_dir = csgo_dir.remove_chars('"')
					print("[ArgParser] CSGO Directory set to: ", csgo_dir)
					i += 1
				else:
					push_error("[ArgParser] Missing value for -csgo_dir")
			
			# --- FUNCTION CALL ARGUMENTS ---
			_:
				if function_args.has(arg):
					print("[ArgParser] Executing function trigger for: ", arg)
					function_args[arg].call()
		
		i += 1


# Exampel function callback
func _on_test_func_called() -> void:
	print(">>> [Test Function] Executed via CLI argument! <<<")
