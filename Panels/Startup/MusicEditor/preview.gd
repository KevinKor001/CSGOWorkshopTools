extends Button


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_pressed() -> void:
	
	var interface = PortalInterface.new("127.0.0.1", 2121)
	add_child(interface)
	
	interface.connected.connect(func(): print("Connected!"))
	interface.message_received.connect(func(line): print("Got:", line))
	 
	await interface.connect_to_server()
	interface.send_command("echo hello")
