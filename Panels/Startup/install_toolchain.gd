extends Button


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass



func runORinstallSourceSDK():
	const SDK_APPID = "745"
	
	var error = OS.shell_open("steam://run/"+SDK_APPID)
	# <------------------- TUD
	if error == OK:
		$"../../../Window".dialog_text = """Check over to your steam and launch 745
		Make sure you install it 
		in the same directory as your game """
		$"../../../Window".show()
	else:
		$"../../../Window".dialog_text = "Error :  " + error
		$"../../../Window".show()


func _on_pressed() -> void:
	runORinstallSourceSDK()
