extends Node
class_name NpcScheduleVisualizer

var _npc_markers: Dictionary = {}  # npc_id → Label

func _ready() -> void:
	var tm = get_node_or_null("/root/TimeManager")
	if tm:
		tm.time_advanced.connect(_on_time_advanced)
	var nr = get_node_or_null("/root/NpcRegistry")
	if nr:
		nr.npc_data_ready.connect(_on_npc_data_ready)

func _on_npc_data_ready(_ids: Array) -> void:
	_create_markers()

func _create_markers() -> void:
	var nr = get_node_or_null("/root/NpcRegistry")
	if not nr:
		return
	for npc in nr.get_all_npcs():
		var npc_id = npc.get("npc_id", "")
		if npc_id.is_empty():
			continue
		var name = npc.get("name", npc_id)
		var label = Label.new()
		label.text = name
		label.add_theme_color_override("font_color", Color("#10b981"))
		label.add_theme_font_size_override("font_size", 10)
		label.visible = false
		add_child(label)
		_npc_markers[npc_id] = label

func _on_time_advanced(day: int, hour: int, minute: int, phase: String) -> void:
	var tm = get_node_or_null("/root/TimeManager")
	if not tm:
		return
	var nr = get_node_or_null("/root/NpcRegistry")
	if not nr:
		return
	var location_map = get_node_or_null("/root/Main/CampusMap")
	if not location_map:
		return

	var current_minutes = hour * 60 + minute
	for npc_id in _npc_markers.keys():
		var marker = _npc_markers[npc_id]
		var loc = nr.get_npc_location(npc_id)
		if loc.is_empty():
			marker.visible = false
			continue
		var pos = _get_location_position(location_map, loc)
		if pos != Vector2.ZERO:
			marker.position = pos
			marker.visible = true
		else:
			marker.visible = false

func _get_location_position(map_node: Node, location_id: String) -> Vector2:
	var loc_node = map_node.get_node_or_null("Locations/" + location_id)
	if loc_node:
		return loc_node.position
	return Vector2.ZERO
