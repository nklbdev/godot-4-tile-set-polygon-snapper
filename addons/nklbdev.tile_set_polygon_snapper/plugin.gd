@tool
extends EditorPlugin

const TILE_SET_ATLAS_SOURCE_EDITOR_CLASS_NAME: StringName = "TileSetAtlasSourceEditor"
const POLYGON_EDITOR_CLASS_NAME: StringName = "GenericTilePolygonEditor"
const ANY_STRING_PATTERN: StringName = "*"
const PLUGIN_NAME: StringName = "tile_set_polygon_snapper"
const ENABLE_SNAPPING_SETTING_NAME: StringName = PLUGIN_NAME + "/enable_snapping"
const SNAP_SIZE_SETTING_NAME: StringName = PLUGIN_NAME + "/snap_size"
const SNAP_OFFSET_SETTING_NAME: StringName = PLUGIN_NAME + "/snap_offset"

const OTHER_CASE: Vector2i = Vector2i(-1, -1)

var __enable_snapping: bool
var __snapping_size: Vector2
var __snapping_offset: Vector2
var __tile_set_atlas_source_editor: HSplitContainer
var __polygon_editor: VBoxContainer
var __polygons: Array[PackedVector2Array]

func __on_project_settings_changed() -> void:
	__enable_snapping = ProjectSettings.get_setting(ENABLE_SNAPPING_SETTING_NAME)
	__snapping_size = ProjectSettings.get_setting(SNAP_SIZE_SETTING_NAME)
	__snapping_offset = ProjectSettings.get_setting(SNAP_OFFSET_SETTING_NAME)

func _enter_tree() -> void:
	if not ProjectSettings.has_setting(ENABLE_SNAPPING_SETTING_NAME):
		ProjectSettings.set_setting(ENABLE_SNAPPING_SETTING_NAME, true)
		ProjectSettings.set_initial_value(ENABLE_SNAPPING_SETTING_NAME, true)
		ProjectSettings.add_property_info({ name = ENABLE_SNAPPING_SETTING_NAME, type = TYPE_BOOL })
	if not ProjectSettings.has_setting(SNAP_SIZE_SETTING_NAME):
		ProjectSettings.set_setting(SNAP_SIZE_SETTING_NAME, Vector2.ONE)
		ProjectSettings.set_initial_value(SNAP_SIZE_SETTING_NAME, Vector2.ONE)
		ProjectSettings.add_property_info({ name = SNAP_SIZE_SETTING_NAME, type = TYPE_VECTOR2 })
	if not ProjectSettings.has_setting(SNAP_OFFSET_SETTING_NAME):
		ProjectSettings.set_setting(SNAP_OFFSET_SETTING_NAME, Vector2.ZERO)
		ProjectSettings.set_initial_value(SNAP_OFFSET_SETTING_NAME, Vector2.ZERO)
		ProjectSettings.add_property_info({ name = SNAP_OFFSET_SETTING_NAME, type = TYPE_VECTOR2 })
	project_settings_changed.connect(__on_project_settings_changed)

	__tile_set_atlas_source_editor = get_tree().root.find_children(ANY_STRING_PATTERN, TILE_SET_ATLAS_SOURCE_EDITOR_CLASS_NAME, true, false)[0]
#	__print_node(__tile_set_atlas_source_editor)

#func __print_node(node: Node, indent: int = 0) -> void:
#	print("%s%s: %s, text: %s" % ["\t".repeat(indent), node.name, node.get_class(), node.text if "text" in node else ""])
#	for c in node.get_children():
#		__print_node(c, indent + 1)

func _exit_tree() -> void:
	__tile_set_atlas_source_editor = null
	project_settings_changed.disconnect(__on_project_settings_changed)
	if ProjectSettings.has_setting(ENABLE_SNAPPING_SETTING_NAME):
		ProjectSettings.set_setting(ENABLE_SNAPPING_SETTING_NAME, null)
	if ProjectSettings.has_setting(SNAP_SIZE_SETTING_NAME):
		ProjectSettings.set_setting(SNAP_SIZE_SETTING_NAME, null)
	if ProjectSettings.has_setting(SNAP_OFFSET_SETTING_NAME):
		ProjectSettings.set_setting(SNAP_OFFSET_SETTING_NAME, null)

func _input(event: InputEvent) -> void:
	if __enable_snapping:
		if event is InputEventMouse:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					for polygon_editor in __tile_set_atlas_source_editor.find_children(ANY_STRING_PATTERN, POLYGON_EDITOR_CLASS_NAME, true, false):
						polygon_editor = polygon_editor as VBoxContainer
						if polygon_editor.is_visible_in_tree():
							if polygon_editor.get_global_rect().has_point(event.global_position):
								__polygon_editor = polygon_editor
								for polygon_index in __polygon_editor.get_polygon_count():
									__polygons.append(__polygon_editor.get_polygon(polygon_index))
								break
				else:
					if __polygon_editor:
						__polygon_editor = null
						__polygons.clear()
			elif event is InputEventMouseMotion:
				if __polygon_editor:
					__on_polygon_editor_polygons_changed.call_deferred()

func __get_moved_point() -> Vector2i:
	# pack polygon_index and point_index into Vector2i to return two ints together
	var result = OTHER_CASE

	var polygon_count: int = __polygon_editor.get_polygon_count()
	if polygon_count != __polygons.size():
		return OTHER_CASE
	for polygon_index in polygon_count:
		var polygon: PackedVector2Array = __polygon_editor.get_polygon(polygon_index)
		var polygon_size: int = polygon.size()
		if polygon_size == __polygons[polygon_index].size():
			for point_index in polygon_size:
				if polygon[point_index] != __polygons[polygon_index][point_index]:
					if result.x >= 0:
						return OTHER_CASE
					__polygons[polygon_index][point_index] = polygon[point_index]
					result.x = polygon_index
					result.y = point_index
		else:
			return OTHER_CASE
	return result

func __on_polygon_editor_polygons_changed() -> void:
	var moved_point: Vector2i = __get_moved_point()
	if moved_point == OTHER_CASE:
		__polygons.clear()
		for polygon_index in __polygon_editor.get_polygon_count():
			__polygons.append(__polygon_editor.get_polygon(polygon_index))
	else:
		__polygons[moved_point.x][moved_point.y] = \
			(__polygons[moved_point.x][moved_point.y] - __snapping_offset).snapped(__snapping_size) + __snapping_offset
		__polygon_editor.set_polygon(moved_point.x, __polygons[moved_point.x])
		__polygon_editor.queue_redraw()
