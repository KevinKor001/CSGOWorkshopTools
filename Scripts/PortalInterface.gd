extends Node
class_name PortalInterface

signal connected
signal disconnected
signal message_received(line: String)
signal vector_received(x: float, y: float, z: float)

var _socket: StreamPeerTCP = null
var _host: String = "127.0.0.1"
var _port: int = 2121
var _timeout: float = 5.0
var _connected: bool = false
var _running: bool = false
var _last_vector: Dictionary = {}

func _init(host: String = "127.0.0.1", port: int = 2121, timeout: float = 5.0) -> void:
	_host = host
	_port = port
	_timeout = timeout

func connect_to_server(max_retries: int = 5, retry_delay: float = 2.0) -> void:
	for attempt in range(max_retries):
		_socket = StreamPeerTCP.new()
		_socket.set_no_delay(true)
		
		var error = _socket.connect_to_host(_host, _port)
		
		if error != OK:
			push_error("Attempt %d: Failed to connect to %s:%d - Error: %d" % [attempt + 1, _host, _port, error])
			_socket = null
			if attempt < max_retries - 1:
				print("[PortalInterface] Retrying in %.1f seconds..." % retry_delay)
				await get_tree().create_timer(retry_delay).timeout
			continue
		
		# Wait for connection with timeout
		var start_time = Time.get_ticks_msec()
		while _socket.get_status() == StreamPeerTCP.STATUS_CONNECTING:
			_socket.poll()
			await get_tree().process_frame
			if Time.get_ticks_msec() - start_time > _timeout * 1000:
				push_error("Attempt %d: Connection timeout" % (attempt + 1))
				_socket = null
				if attempt < max_retries - 1:
					print("[PortalInterface] Retrying in %.1f seconds..." % retry_delay)
					await get_tree().create_timer(retry_delay).timeout
				break
		
		# Check final status
		_socket.poll()
		if _socket and _socket.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			_connected = true
			_running = true
			_listen_loop()
			send_command("clear")
			send_command("echo ---> PortalScript Interface Connected! <---")
			print("[PortalInterface] Connected to netconsole on %s:%d!" % [_host, _port])
			connected.emit()
			return
		else:
			push_error("Attempt %d: Connection failed - status: %d" % [attempt + 1, _socket.get_status() if _socket else -1])
			_socket = null
			if attempt < max_retries - 1:
				print("[PortalInterface] Retrying in %.1f seconds..." % retry_delay)
				await get_tree().create_timer(retry_delay).timeout
	
	push_error("Failed to connect after %d attempts" % max_retries)
	_socket = null

func send_command(command: String) -> void:
	print("[PortalInterface] send_command called. _connected: %s, _socket: %s" % [_connected, _socket != null])
	
	if not _connected or not _socket:
		push_error("Not connected to server")
		return
	
	var payload = command + "\n"
	var error = _socket.put_data(payload.to_utf8_buffer())
	
	if error != OK:
		push_error("Failed to send command: %d" % error)
	else:
		print("[PortalInterface] Sent: %s" % command.strip_edges())
		_socket.poll()

func _listen_loop() -> void:
	var buffer: PackedByteArray = []
	
	while _running and _connected and _socket:
		_socket.poll()
		
		if _socket.get_available_bytes() > 0:
			var data = _socket.get_data(_socket.get_available_bytes())
			if data[0] == OK:
				buffer.append_array(data[1])
				
				# Process complete lines
				var text = buffer.get_string_from_utf8()
				var lines = text.split("\n")
				
				# Keep the last incomplete line in buffer
				if lines.size() > 1:
					buffer = lines[-1].to_utf8_buffer()
					lines = lines.slice(0, -1)
					
					for line in lines:
						_process_line(line)
		
		await get_tree().process_frame

func _process_line(line: String) -> void:
	line = line.strip_edges()
	if line.is_empty():
		return
	
	message_received.emit(line)
	print("[PortalInterface] Received: %s" % line)
	
	# Parse vector data from Source engine output
	var regex = RegEx.new()
	regex.compile(r"\(vector\s*:\s*\(\s*([-\d.]+)\s*,\s*([-\d.]+)\s*,\s*([-\d.]+)\s*\)\)")
	var result = regex.search(line)
	
	if result:
		var x = result.get_string(1).to_float()
		var y = result.get_string(2).to_float()
		var z = result.get_string(3).to_float()
		_last_vector = {"x": x, "y": y, "z": z}
		vector_received.emit(x, y, z)

func get_player_position(timeout: float = 1.0) -> Dictionary:
	_last_vector.clear()
	send_command("script printl(GetPlayer().GetOrigin())")
	
	var start_time = Time.get_ticks_msec()
	while _last_vector.is_empty():
		await get_tree().process_frame
		if Time.get_ticks_msec() - start_time > timeout * 1000:
			push_error("Timeout waiting for player position")
			return {}
	
	return _last_vector

func get_player_rotation(timeout: float = 1.0) -> Dictionary:
	_last_vector.clear()
	send_command("script printl(GetPlayer().GetAngles())")
	
	var start_time = Time.get_ticks_msec()
	while _last_vector.is_empty():
		await get_tree().process_frame
		if Time.get_ticks_msec() - start_time > timeout * 1000:
			push_error("Timeout waiting for player rotation")
			return {}
	
	return _last_vector

func get_player_velocity(timeout: float = 1.0) -> Dictionary:
	_last_vector.clear()
	send_command("script printl(GetPlayer().GetVelocity())")
	
	var start_time = Time.get_ticks_msec()
	while _last_vector.is_empty():
		await get_tree().process_frame
		if Time.get_ticks_msec() - start_time > timeout * 1000:
			push_error("Timeout waiting for player velocity")
			return {}
	
	return _last_vector

func disconnect_from_server() -> void:
	_running = false
	_connected = false
	
	if _socket:
		send_command("echo ---> PortalScript (for CSGO) Interface Disconnected! <---")
		_socket.close()
		_socket = null
	
	print("[PortalInterface] Disconnected")
	disconnected.emit()

func has_connection() -> bool:
	return _connected and _socket != null and _socket.get_status() == StreamPeerTCP.STATUS_CONNECTED

func _exit_tree() -> void:
	disconnect_from_server()
