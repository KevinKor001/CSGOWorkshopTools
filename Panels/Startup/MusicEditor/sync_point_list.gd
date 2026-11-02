extends Tree

signal items_reordered(from_index: int, to_index: int)

func _ready() -> void:
	columns = 1
	hide_root = true
	set_drop_mode_flags(Tree.DROP_MODE_INBETWEEN)

func _get_drag_data(position: Vector2) -> Variant:
	var item := get_item_at_position(position)
	if item == null:
		return null
	var preview := Label.new()
	preview.text = item.get_text(0)
	set_drag_preview(preview)
	return {"index": int(item.get_metadata(0))}

func _can_drop_data(position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or not data.has("index"):
		return false
	var target := get_item_at_position(position)
	return target != null and int(data["index"]) != int(target.get_metadata(0))

func _drop_data(position: Vector2, data: Variant) -> void:
	if not _can_drop_data(position, data):
		return
	var target := get_item_at_position(position)
	var from_index := int(data["index"])
	var to_index := int(target.get_metadata(0))
	if get_drop_section_at_position(position) > 0:
		to_index += 1
	if from_index < to_index:
		to_index -= 1
	if from_index != to_index:
		items_reordered.emit(from_index, to_index)
