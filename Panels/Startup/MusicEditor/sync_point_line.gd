extends Panel

var sync_point_index: int = 0
var sync_point_time: float = 0.0

@onready var marker: Panel = $"."
@onready var label: Label = $Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_sync_point(index: int, time: float, point_color: Color) -> void:
	sync_point_index = index
	sync_point_time = time
	label.text = "     #S%02d" % index
	var root_style := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	root_style.bg_color = point_color.darkened(0.15)
	add_theme_stylebox_override("panel", root_style)
	var marker_style := marker.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	marker_style.bg_color = point_color 
	marker.add_theme_stylebox_override("panel", marker_style)

func get_sync_point_index() -> int:
	return sync_point_index
