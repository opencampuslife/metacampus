extends Node

const SAVE_DIR := "user://saves"
const SLOT_COUNT := 6

signal save_created(slot: int, label: String)
signal save_loaded(slot: int)
signal save_deleted(slot: int)

func _ready() -> void:
	var dir = DirAccess.open("user://")
	if dir:
		if not dir.dir_exists("saves"):
			dir.make_dir("saves")
	print("[SaveManager] Ready — %d save slots" % SLOT_COUNT)

func save_game(slot: int) -> bool:
	if slot < 0 or slot >= SLOT_COUNT:
		return false
	var data = _collect_state()
	var path = "%s/save_%d.json" % [SAVE_DIR, slot]
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("[SaveManager] Cannot write: " + path)
		return false
	file.store_line(JSON.new().stringify(data))
	file.close()
	save_created.emit(slot, "Day %d" % data.get("day", 1))
	return true

func load_game(slot: int) -> bool:
	if slot < 0 or slot >= SLOT_COUNT:
		return false
	var path = "%s/save_%d.json" % [SAVE_DIR, slot]
	if not FileAccess.file_exists(path):
		return false
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return false
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return false
	var data = json.data
	_restore_state(data)
	save_loaded.emit(slot)
	return true

func delete_save(slot: int) -> bool:
	var path = "%s/save_%d.json" % [SAVE_DIR, slot]
	if not FileAccess.file_exists(path):
		return false
	DirAccess.remove_absolute(path)
	save_deleted.emit(slot)
	return true

func list_saves() -> Array:
	var saves = []
	var dir = DirAccess.open(SAVE_DIR)
	if not dir:
		return saves
	dir.list_dir_begin()
	var f = dir.get_next()
	while f != "":
		if f.ends_with(".json") and f.begins_with("save_"):
			var slot_str = f.trim_prefix("save_").trim_suffix(".json")
			var slot = int(slot_str)
			var meta = _read_save_meta(slot)
			saves.append(meta)
		f = dir.get_next()
	dir.list_dir_end()
	saves.sort_custom(func(a, b): return a.slot < b.slot)
	return saves

func get_save_meta(slot: int) -> Dictionary:
	return _read_save_meta(slot)

func auto_save() -> void:
	var tm = get_node_or_null("/root/TimeManager")
	if not tm:
		return
	var slot = 0  # auto-save to slot 0
	save_game(slot)

func _read_save_meta(slot: int) -> Dictionary:
	var path = "%s/save_%d.json" % [SAVE_DIR, slot]
	var meta = { "slot": slot, "exists": false, "label": "" }
	if not FileAccess.file_exists(path):
		return meta
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return meta
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return meta
	var data = json.data
	meta.exists = true
	meta.label = "Day %d, %02d:%02d" % [data.get("day", 1), data.get("hour", 8), data.get("minute", 0)]
	meta.day = data.get("day", 1)
	return meta

func _collect_state() -> Dictionary:
	var data = {}
	var tm = get_node_or_null("/root/TimeManager")
	if tm:
		data.day = tm.day
		data.hour = tm.hour
		data.minute = tm.minute

	var rm = get_node_or_null("/root/ResourceManager")
	if rm:
		data.resources = rm.get_all()

	var mm = get_node_or_null("/root/MetricManager")
	if mm:
		data.metrics = {}
		var all = mm.get_all_with_metadata()
		for mid in all.keys():
			data.metrics[mid] = all[mid].get("value", 50)

	var qm = get_node_or_null("/root/QuestManager")
	if qm:
		data.completed_quests = qm.get_completed_quests().map(func(q): return q.get("quest_id", "") or q.get("id", ""))
		data.failed_quests = []
		data.active_quests = qm.get_active_quests().map(func(q): return q.get("quest_id", "") or q.get("id", ""))

	var sm = get_node_or_null("/root/SkillManager")
	if sm and sm.has_method("get_all_skills"):
		data.skills = sm.get_all_skills()

	return data

func _restore_state(data: Dictionary) -> void:
	var tm = get_node_or_null("/root/TimeManager")
	if tm:
		tm.set_time(data.get("day", 1), data.get("hour", 8), data.get("minute", 0))

	var rm = get_node_or_null("/root/ResourceManager")
	if rm and data.has("resources"):
		for rid in ["ap", "compute", "budget"]:
			if data["resources"].has(rid):
				var target = int(data["resources"][rid])
				var current = rm.get_value(rid)
				rm.modify(rid, target - current)
