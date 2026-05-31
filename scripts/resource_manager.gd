extends Node


## 资源管理器（AP/算力/预算）
## 管理玩家行动资源和 budget

signal resource_changed(resource_id: String, value: int, delta: int)
signal resource_empty(resource_id: String)
signal resource_max_changed(resource_id: String, max: int)

var _resources: Dictionary = {
	"ap": 10,
	"compute": 50,
	"budget": 1000,
}

var _max_resources: Dictionary = {
	"ap": 20,
	"compute": 100,
	"budget": 99999,
}

var _min_resources: Dictionary = {
	"ap": 0,
	"compute": 0,
	"budget": 0,
}

func _ready() -> void:
	add_to_group("resource_manager")
	print("[ResourceManager] Ready — AP:%d Compute:%d Budget:%d" % [_resources.ap, _resources.compute, _resources.budget])

# ── Public API ──────────────────────────────────────────────────

func get_value(resource_id: String) -> int:
	return _resources.get(resource_id, 0)

func get_max(resource_id: String) -> int:
	return _max_resources.get(resource_id, 99999)

func set_max(resource_id: String, value: int) -> void:
	_max_resources[resource_id] = maxi(value, _min_resources.get(resource_id, 0))
	resource_max_changed.emit(resource_id, _max_resources[resource_id])
	# Clamp current value
	if _resources.get(resource_id, 0) > _max_resources[resource_id]:
		_resources[resource_id] = _max_resources[resource_id]

func modify(resource_id: String, delta: int) -> int:
	if not _resources.has(resource_id):
		push_warning("[ResourceManager] Unknown resource: " + resource_id)
		return 0

	var old = _resources[resource_id]
	var new_val = clampi(old + delta, _min_resources.get(resource_id, 0), _max_resources.get(resource_id, 99999))
	_resources[resource_id] = new_val
	var actual_delta = new_val - old

	if actual_delta != 0:
		resource_changed.emit(resource_id, new_val, actual_delta)
		if new_val <= _min_resources.get(resource_id, 0):
			resource_empty.emit(resource_id)

	return actual_delta

func can_afford(resource_id: String, amount: int) -> bool:
	return _resources.get(resource_id, 0) >= amount

func can_afford_all(costs: Dictionary) -> bool:
	for rid in costs.keys():
		if not can_afford(rid, int(costs[rid])):
			return false
	return true

func spend_all(costs: Dictionary) -> bool:
	if not can_afford_all(costs):
		return false
	for rid in costs.keys():
		modify(rid, -int(costs[rid]))
	return true

func get_all() -> Dictionary:
	return _resources.duplicate()

func reset_all() -> void:
	_resources = {"ap": 10, "compute": 50, "budget": 1000}
	_max_resources = {"ap": 20, "compute": 100, "budget": 99999}
	for rid in _resources.keys():
		resource_changed.emit(rid, _resources[rid], 0)
