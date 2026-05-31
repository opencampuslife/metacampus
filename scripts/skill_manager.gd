extends Node


## 技能/升级管理器
## 管理 6 项技能（招生/教务/合规/运维/数据/沟通）的 XP 和等级
## 以及升级项目（upgrades.json）

signal skill_xp_changed(skill_id: String, xp: int, level: int)
signal skill_leveled_up(skill_id: String, level: int, unlock: String)
signal upgrade_available(upgrade_id: String)
signal upgrade_purchased(upgrade_id: String)

const SKILLS_PATH := "res://data/skills.json"
const UPGRADES_PATH := "res://data/upgrades.json"

var _skills: Dictionary = {}       # skill_id → definition
var _skill_xp: Dictionary = {}     # skill_id → accumulated xp
var _skill_levels: Dictionary = {} # skill_id → current level (1-based)
var _upgrades: Dictionary = {}     # upgrade_id → definition
var _purchased_upgrades: Array = []

func _ready() -> void:
	add_to_group("skill_manager")
	_load_skills()
	_load_upgrades()
	print("[SkillManager] Ready — %d skills, %d upgrades" % [_skills.size(), _upgrades.size()])

# ── Skills API ──────────────────────────────────────────────────

func add_xp(skill_id: String, amount: int) -> void:
	if not _skills.has(skill_id):
		push_warning("[SkillManager] Unknown skill: " + skill_id)
		return
	_skill_xp[skill_id] = _skill_xp.get(skill_id, 0) + amount
	var new_level = _calculate_level(skill_id)
	if new_level > _skill_levels.get(skill_id, 1):
		_skill_levels[skill_id] = new_level
		var defn = _skills[skill_id]
		var unlock = defn.get("levels", {}).get(str(new_level), {}).get("unlock", "")
		skill_leveled_up.emit(skill_id, new_level, unlock)
		_check_upgrade_unlocks()
	skill_xp_changed.emit(skill_id, _skill_xp[skill_id], _skill_levels.get(skill_id, 1))

func get_xp(skill_id: String) -> int:
	return _skill_xp.get(skill_id, 0)

func get_level(skill_id: String) -> int:
	return _skill_levels.get(skill_id, 1)

func get_skill_data(skill_id: String) -> Dictionary:
	return _skills.get(skill_id, {}).duplicate(true)

func get_all_skills() -> Array:
	var out = []
	for sid in _skills.keys():
		out.append({
			"skill_id": sid,
			"name": _skills[sid].get("name", sid),
			"level": _skill_levels.get(sid, 1),
			"xp": _skill_xp.get(sid, 0),
			"xp_for_next": _xp_for_level(sid, _skill_levels.get(sid, 1) + 1),
			"description": _skills[sid].get("description", ""),
		})
	return out

func get_current_unlock(skill_id: String) -> String:
	var level = _skill_levels.get(skill_id, 1)
	var defn = _skills.get(skill_id, {})
	return defn.get("levels", {}).get(str(level), {}).get("unlock", "")

func get_next_unlock(skill_id: String) -> String:
	var level = _skill_levels.get(skill_id, 1) + 1
	var defn = _skills.get(skill_id, {})
	return defn.get("levels", {}).get(str(level), {}).get("unlock", "")

# ── Upgrades API ────────────────────────────────────────────────

func get_upgrades() -> Array:
	var out = []
	for uid in _upgrades.keys():
		var data = _upgrades[uid].duplicate(true)
		data["purchased"] = uid in _purchased_upgrades
		data["can_afford"] = _can_purchase_upgrade(uid)
		out.append(data)
	return out

func purchase_upgrade(upgrade_id: String) -> bool:
	if not _upgrades.has(upgrade_id):
		return false
	if upgrade_id in _purchased_upgrades:
		return false
	if not _can_purchase_upgrade(upgrade_id):
		return false

	var defn = _upgrades[upgrade_id]
	var cost = defn.get("cost", 0)
	var rm = get_node_or_null("/root/ResourceManager")
	if rm and not rm.can_afford("budget", cost):
		return false

	if rm:
		rm.modify("budget", -cost)

	_purchased_upgrades.append(upgrade_id)

	# Apply upgrade effects to metrics
	var effects = defn.get("effects", {})
	var mm = get_node_or_null("/root/MetricManager")
	if mm:
		mm.apply_effects(effects)

	upgrade_purchased.emit(upgrade_id)
	return true

# ── Private ─────────────────────────────────────────────────────

func _load_skills() -> void:
	if not FileAccess.file_exists(SKILLS_PATH):
		return
	var file = FileAccess.open(SKILLS_PATH, FileAccess.READ)
	if not file:
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data = json.data
	for s in data.get("skills", []):
		var sid = s.get("skill_id", "")
		if not sid.is_empty():
			_skills[sid] = s
			_skill_xp[sid] = 0
			_skill_levels[sid] = 1

func _load_upgrades() -> void:
	if not FileAccess.file_exists(UPGRADES_PATH):
		return
	var file = FileAccess.open(UPGRADES_PATH, FileAccess.READ)
	if not file:
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data = json.data
	for u in data.get("upgrades", []):
		var uid = u.get("upgrade_id", "")
		if not uid.is_empty():
			_upgrades[uid] = u

func _calculate_level(skill_id: String) -> int:
	var defn = _skills.get(skill_id, {})
	var xp = _skill_xp.get(skill_id, 0)
	var current_level = _skill_levels.get(skill_id, 1)
	# Check if enough XP to level up
	for lvl in range(current_level + 1, 11):
		var req = _xp_for_level(skill_id, lvl)
		if xp >= req:
			current_level = lvl
		else:
			break
	return current_level

func _xp_for_level(skill_id: String, level: int) -> int:
	if level <= 1:
		return 0
	if level > 10:
		return 999999
	var defn = _skills.get(skill_id, {})
	return defn.get("levels", {}).get(str(level), {}).get("xp_required", 999999)

func _can_purchase_upgrade(upgrade_id: String) -> bool:
	var defn = _upgrades.get(upgrade_id, {})
	var reqs = defn.get("unlock_requirement", {})
	for key in reqs.keys():
		if key == "budget":
			var rm = get_node_or_null("/root/ResourceManager")
			if rm and not rm.can_afford("budget", int(reqs[key])):
				return false
		elif key.ends_with("_skill"):
			var sid = key.replace("_skill", "")
			if get_level(sid) < int(reqs[key]):
				return false
		else:
			# Unknown requirement — skip (assume not met for safety)
			return false
	return true

func _check_upgrade_unlocks() -> void:
	for uid in _upgrades.keys():
		if uid in _purchased_upgrades:
			continue
		if _can_purchase_upgrade(uid):
			upgrade_available.emit(uid)
