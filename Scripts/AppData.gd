extends Node

@export var gameDir = ""
@export var runningDir = OS.get_executable_path()
@export var VERSION = "1.0.0"
@export var IsSupramacyInstall = false
@export var IsToolChainInstalled = false
@export var gameLaunchArgs = ""
@export var protonPath = ""
@export var protonPrefix = ""


func getGameDir():
	return  gameDir.strip_edges()
func getToolDir():
	return  getGameDir() + "/CSP_Data"
	
func getToolConfigPath():
	return getToolDir() + "/config.cfg"

func getProtonExec():
	return protonPath + "/proton"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	var config = ConfigFile.new()
	config.load(getToolConfigPath())
	gameDir = config.get_value("General", "csgo_install")
	IsSupramacyInstall = config.get_value("General", "supremacy_install")
	protonPath = config.get_value("Linux", "ProtonPath")
	protonPrefix = config.get_value("General", "ProtonPrefix")
	gameDir = ArgParser.csgo_dir 
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
