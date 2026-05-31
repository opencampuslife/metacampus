extends Node


## NPC 注册中心
## 从 data/npcs.json + data/npcs/*.json 加载所有 NPC 数据
## 提供按 ID 查找、列表查询、信号通知

signal npc_data_ready(npc_ids: Array)
signal npc_updated(npc_id: String)

var _all_npcs: Dictionary = {}  # npc_id → npc data dict
var _npcs_by_location: Dictionary = {}  # location_id → [npc_id]

const NPC_DATA_PATH := "res://data/npcs.json"
const NPC_DIR := "res://data/npcs/"

func _ready() -> void:
	add_to_group("npc_registry")
	_load_all()
	print("[NpcRegistry] Ready — %d NPCs loaded" % _all_npcs.size())

# ── Public API ──────────────────────────────────────────────────

func get_npc(npc_id: String) -> Dictionary:
	return _all_npcs.get(npc_id, {}).duplicate(true)

func get_all_npcs() -> Array:
	var out: Array = []
	for data in _all_npcs.values():
		out.append(data.duplicate(true))
	return out

func get_npc_ids() -> Array:
	return _all_npcs.keys()

func get_npcs_at_location(location_id: String) -> Array:
	return _npcs_by_location.get(location_id, []).duplicate()

func get_npc_count() -> int:
	return _all_npcs.size()

func npc_exists(npc_id: String) -> bool:
	return _all_npcs.has(npc_id)

func get_npc_name(npc_id: String) -> String:
	var data = _all_npcs.get(npc_id, {})
	return data.get("name", npc_id)

func get_npc_location(npc_id: String) -> String:
	var data = _all_npcs.get(npc_id, {})
	return data.get("location", "")

# ── Private ─────────────────────────────────────────────────────

func _load_all() -> void:
	_all_npcs.clear()
	_npcs_by_location.clear()

	# 从主文件加载
	_load_npc_file(NPC_DATA_PATH)

	# 从目录加载单个 NPC 文件
	var dir = DirAccess.open(NPC_DIR)
	if dir:
		dir.list_dir_begin()
		var filename = dir.get_next()
		while filename != "":
			if filename.ends_with(".json"):
				_load_npc_file(NPC_DIR + filename)
			filename = dir.get_next()

	npc_data_ready.emit(_all_npcs.keys())

func _load_npc_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		return

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return

	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return

	var data = json.data
	if typeof(data) == TYPE_ARRAY:
		for item in data:
			_register_npc(item)
	elif typeof(data) == TYPE_DICTIONARY and data.has("npc_id"):
		_register_npc(data)

func _register_npc(data: Dictionary) -> void:
	var npc_id = data.get("npc_id", "")
	if npc_id.is_empty():
		return

	_all_npcs[npc_id] = data

	var loc = data.get("location", "")
	if not loc.is_empty():
		if not _npcs_by_location.has(loc):
			_npcs_by_location[loc] = []
		if not npc_id in _npcs_by_location[loc]:
			_npcs_by_location[loc].append(npc_id)
