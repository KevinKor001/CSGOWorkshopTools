extends Node

@export var gameDir = ""
@export var runningDir = OS.get_executable_path()
@export var VERSION = "1.0.0"
@export var IsSupramacyInstall = false
@export var IsToolChainInstalled = false
@export var gameLaunchArgs = ""



func getGameDir():
	return  gameDir.strip_edges()
func getToolDir():
	return  getGameDir() + "/CSP_Data"
	
func getToolConfigPath():
	return getToolDir() + "/config.cfg"
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	gameDir = ArgParser.csgo_dir 


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
