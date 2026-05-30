extends Node
class_name QuestManager

## Phase 2.8A — QuestManager GDScript Stub
## 等效替换 C# QuestManager.cs，功能覆盖：
## - 4 层任务系统（main/daily/npc/random_event）
## - Quest state: locked/available/active/completed/failed
## - Signals: QuestStarted, QuestCompleted, QuestFailed, QuestExpired, QuestAvailable, QuestUpdated
## - Methods: start_quest, complete_quest, fail_quest, get_quest_status, get_quests_for_npc...

signal quest_available(qid: String)
signal quest_started(qid: String)
signal quest_updated(qid: String)
signal quest_completed(qid: String)
signal quest_failed(qid: String)
signal quest_expired(qid: String)
signal daily_quests_refreshed(ids: Array)

const QUEST_FILES = [
	"res://data/quests/main_quests.json",
	"res://data/quests/daily_quests.json",
	"res://data/quests/npc_quests.json",
	"res://data/quests/random_event_quests.json",
]

var _all_quests: Dictionary = {}   # quest_id → quest data
var _quest_states: Dictionary = {} # quest_id → state dict
var _active: Array = []
var _completed: Array = []
var _failed: Array = []

enum QuestStatus { LOCKED, AVAILABLE, ACTIVE, COMPLETED, FAILED }

func _ready() -> void:
	add_to_group("quest_manager")
	_load_all_quests()
	_init_states()
	_check_available()
	print("[QuestManager] Ready — %d quests loaded" % _all_quests.size())

# ══════════════════════════════════════════════════════════════════
# Public API (matching C# interface used by dialogue_manager/taskboard/etc)
# ══════════════════════════════════════════════════════════════════

func start_quest(qid: String) -> bool:
	if not _all_quests.has(qid): return false
	var st = _get_or_create_state(qid)
	if st["status"] != QuestStatus.AVAILABLE: return false
	st["status"] = QuestStatus.ACTIVE
	if not qid in _active:
		_active.append(qid)
	quest_started.emit(qid)
	return true

func complete_quest(qid: String) -> void:
	if not _all_quests.has(qid): return
	var st = _get_or_create_state(qid)
	if st["status"] == QuestStatus.COMPLETED: return
	st["status"] = QuestStatus.COMPLETED
	_active.erase(qid)
	if not qid in _completed:
		_completed.append(qid)
	_apply_rewards(qid)
	quest_completed.emit(qid)
	_check_available()

func fail_quest(qid: String) -> void:
	if not _all_quests.has(qid): return
	var st = _get_or_create_state(qid)
	if st["status"] == QuestStatus.FAILED: return
	st["status"] = QuestStatus.FAILED
	_active.erase(qid)
	if not qid in _failed:
		_failed.append(qid)
	_apply_penalties(qid)
	quest_failed.emit(qid)

func get_quest_status(qid: String) -> String:
	if not _quest_states.has(qid): return "locked"
	match _quest_states[qid]["status"]:
		QuestStatus.LOCKED: return "locked"
		QuestStatus.AVAILABLE: return "available"
		QuestStatus.ACTIVE: return "active"
		QuestStatus.COMPLETED: return "completed"
		QuestStatus.FAILED: return "failed"
	return "locked"

func get_quests_for_npc(npc_id: String) -> Array:
	var result = []
	for qid in _all_quests.keys():
		var q = _all_quests[qid]
		if q.get("npc_id", "") == npc_id:
			result.append(q)
	return result

func get_active_quests() -> Array:
	var out = []
	for qid in _active:
		if _all_quests.has(qid):
			out.append(_all_quests[qid])
	return out

func get_completed_quests() -> Array:
	var out = []
	for qid in _completed:
		if _all_quests.has(qid):
			out.append(_all_quests[qid])
	return out

func get_all_quests() -> Array:
	return _all_quests.values()

func get_quest_progress_text(qid: String) -> String:
	if not _all_quests.has(qid): return ""
	var st = _quest_states.get(qid, {})
	var status = get_quest_status(qid)
	if status == "completed": return "[完成]"
	if status == "failed": return "[失败]"
	if status == "active":
		return "[进行中]"
	return "[%s]" % status

# ══════════════════════════════════════════════════════════════════
# Private
# ══════════════════════════════════════════════════════════════════

func _load_all_quests() -> void:
	_all_quests.clear()
	for path in QUEST_FILES:
		_load_quest_file(path)

func _load_quest_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_warning("[QuestManager] File not found: " + path)
		return
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("[QuestManager] JSON parse error: " + path)
		return
	var data = json.data
	var quests = data.get("quests", [])
	for q in quests:
		var qid = str(q.get("id", ""))
		if qid.is_empty(): continue
		_all_quests[qid] = q

func _init_states() -> void:
	for qid in _all_quests.keys():
		if not _quest_states.has(qid):
			_quest_states[qid] = {"status": QuestStatus.LOCKED}

func _check_available() -> void:
	for qid in _all_quests.keys():
		var st = _get_or_create_state(qid)
		if st["status"] != QuestStatus.LOCKED: continue
		# 默认全部 available（简化版，完整版检查 requirements）
		st["status"] = QuestStatus.AVAILABLE
		quest_available.emit(qid)

func _get_or_create_state(qid: String) -> Dictionary:
	if not _quest_states.has(qid):
		_quest_states[qid] = {"status": QuestStatus.LOCKED}
	return _quest_states[qid]

func _apply_rewards(qid: String) -> void:
	var quest = _all_quests.get(qid, {})
	var rewards = quest.get("rewards", {})
	var effects = rewards.get("effects", {})
	var metrics = effects.get("metrics", {})
	_apply_metric_effects(metrics)

func _apply_penalties(qid: String) -> void:
	var quest = _all_quests.get(qid, {})
	var penalties = quest.get("failure_effects", {})
	var effects = penalties.get("effects", {})
	var metrics = effects.get("metrics", {})
	_apply_metric_effects(metrics)

func _apply_metric_effects(metrics: Dictionary) -> void:
	var mm = get_tree().get_first_node_in_group("metric_manager")
	if mm == null or not mm.has_method("apply_change"): return
	for key in metrics.keys():
		mm.apply_change(key, int(metrics[key]))