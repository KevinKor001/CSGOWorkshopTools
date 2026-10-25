extends Node

@export var gameDir = "."
@export var VERSION = "1.0.0"
@export var IsSupramacyInstall = false
@export var IsToolChainInstalled = false
@export var gameLaunchArgs = ""



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	gameDir = ArgParser.csgo_dir


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
