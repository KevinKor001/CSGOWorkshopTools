extends TextureRect
@export var audio_stream: AudioStreamWAV
@export var waveform_color: Color = Color.WHITE
@export var background_color: Color = Color(0.1, 0.1, 0.1, 1.0)

func _ready() -> void:
	# Ensure the TextureRect has a minimum size set so width/height aren't 0
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(400, 100)
	
	# Wait one frame for layout to compute, or call directly if size is already > 0
	await get_tree().process_frame
	
	if audio_stream:
		generate_waveform(audio_stream)
var oldsize = 0.0

func _process(delta: float) -> void:
	if size.x != oldsize:
		oldsize = size.x
		print(oldsize)
		generate_waveform(audio_stream)

func generate_waveform(stream: AudioStreamWAV) -> void:
	# 1. Get the size of the TextureRect (fallback to defaults if uninitialized)
	var width = int(size.x) if size.x > 0 else 400
	var height = int(size.y) if size.y > 0 else 100

	# 2. Extract raw byte data from the WAV stream
	var byte_data = stream.get_data()
	if byte_data.is_empty():
		push_warning("AudioStreamWAV has no data!")
		return

	var format = stream.format
	var is_stereo = stream.stereo

	# 3. Determine byte layout parameters
	var bytes_per_sample = 2 if format == AudioStreamWAV.FORMAT_16_BITS else 1
	var channels = 2 if is_stereo else 1
	var bytes_per_frame = bytes_per_sample * channels
	var total_frames = byte_data.size() / bytes_per_frame

	if total_frames == 0:
		return

	# 4. Create an image to draw the waveform onto
	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(background_color)

	var mid_y = height / 2.0

	# 5. Loop through every horizontal pixel column of the TextureRect
	for x in range(width):
		# Map pixel column to a range of audio frames
		var start_frame = int((float(x) / width) * total_frames)
		var end_frame = int((float(x + 1) / width) * total_frames)
		end_frame = maxi(start_frame + 1, end_frame)
		end_frame = mini(end_frame, total_frames)

		var min_val = 1.0
		var max_val = -1.0

		# Find the minimum and maximum peaks in this chunk for accurate amplitude
		for f in range(start_frame, end_frame):
			var byte_offset = f * bytes_per_frame
			var sample = 0.0

			if format == AudioStreamWAV.FORMAT_16_BITS:
				# 16-bit signed integer (-32768 to 32767)
				var raw_sample = byte_data.decode_s16(byte_offset)
				sample = float(raw_sample) / 32768.0
			else:
				# 8-bit signed integer (-128 to 127)
				var raw_sample = byte_data.decode_s8(byte_offset)
				sample = float(raw_sample) / 128.0

			if sample < min_val:
				min_val = sample
			if sample > max_val:
				max_val = sample

		# Fallback if chunk is empty
		if min_val > max_val:
			min_val = 0.0
			max_val = 0.0

		# Map normalized audio range (-1.0 to 1.0) to screen pixel Y coordinates
		# (Y coordinates invert in UI space, so positive goes up, negative goes down)
		var y_min = int(mid_y - (max_val * (height * 0.45)))
		var y_max = int(mid_y - (min_val * (height * 0.45)))
		
		y_min = clampi(y_min, 0, height - 1)
		y_max = clampi(y_max, 0, height - 1)

		# Draw a vertical line representing the amplitude range for this column
		for y in range(y_min, y_max + 1):
			image.set_pixel(x, y, waveform_color)

	# 6. Convert the Image into an ImageTexture and assign it to the TextureRect
	var texture = ImageTexture.create_from_image(image)
	self.texture = texture
	
	print("Total frames: ", total_frames)
	print("Byte data size: ", byte_data.size())
	print("Format (0=8bit, 1=16bit): ", format)
