extends Node


## 核心指标管理器
## 从 data/metrics.json 加载 4 大核心指标 + 12 子指标
## 提供数值变更、阈值告警、Dashboard 数据源

signal all_metrics_updated(metrics: Dictionary)
signal metric_changed(metric_id: String, value: int, delta: int)
signal metric_warning(metric_id: String, value: int)
signal metric_danger(metric_id: String, value: int)

const METRICS_PATH := "res://data/metrics.json"
const DEFAULT_WARNING := 30
const DEFAULT_DANGER := 20

var _definitions: Dictionary = {}   # metric_id → definition dict
var _values: Dictionary = {}        # metric_id → current int value
var _sub_values: Dictionary = {}    # sub_metric_id → current int value
var _sub_parent: Dictionary = {}    # sub_metric_id → parent_metric_id

func _ready() -> void:
	add_to_group("metric_manager")
	_load_definitions()
	_init_values()
	print("[MetricManager] Ready — %d core metrics, %d sub-metrics" % [_definitions.size(), _sub_values.size()])

# ── Public API ──────────────────────────────────────────────────

## 应用变更（quest_manager、dialogue_manager、random_events 都调用这个）
func apply_change(metric_id: String, delta: int) -> void:
	if not _values.has(metric_id) and not _sub_values.has(metric_id):
		push_warning("[MetricManager] Unknown metric: " + metric_id)
		return

	var is_sub = _sub_values.has(metric_id)
	var old_val = _sub_values[metric_id] if is_sub else _values[metric_id]
	var defn = _definitions[_sub_parent[metric_id]] if is_sub else _definitions[metric_id]
	var min_val = defn.get("min", 0)
	var max_val = defn.get("max", 100)

	var new_val = clampi(old_val + delta, min_val, max_val)

	if is_sub:
		_sub_values[metric_id] = new_val
	else:
		_values[metric_id] = new_val

	metric_changed.emit(metric_id, new_val, delta)
	_check_thresholds(metric_id, new_val, defn)
	all_metrics_updated.emit(get_all_with_metadata())

## 批量应用变更（来自 quest rewards/penalties）
func apply_effects(effects: Dictionary) -> void:
	for key in effects.keys():
		apply_change(key, int(effects[key]))

## 获取当前值
func get_value(metric_id: String) -> int:
	if _values.has(metric_id):
		return _values[metric_id]
	if _sub_values.has(metric_id):
		return _sub_values[metric_id]
	return 0

## 获取所有核心指标数据（含元数据——Dashboard 需要这个）
func get_all_with_metadata() -> Dictionary:
	var result: Dictionary = {}
	for metric_id in _values.keys():
		var defn = _definitions.get(metric_id, {})
		result[metric_id] = {
			"value": _values[metric_id],
			"name": defn.get("name", metric_id),
			"min": defn.get("min", 0),
			"max": defn.get("max", 100),
			"description": defn.get("description", ""),
			"danger_threshold": defn.get("thresholds", {}).get("danger", DEFAULT_DANGER),
			"warning_threshold": defn.get("thresholds", {}).get("warning", DEFAULT_WARNING),
		}
	return result

## 获取子指标
func get_sub_metrics(parent_id: String) -> Dictionary:
	var result: Dictionary = {}
	var defn = _definitions.get(parent_id, {})
	var subs = defn.get("sub_metrics", {})
	for sub_id in subs.keys():
		var full_id = parent_id + "." + sub_id
		var sub_def = subs[sub_id]
		result[sub_id] = {
			"value": _sub_values.get(full_id, sub_def.get("initial", 50)),
			"name": sub_def.get("name", sub_id),
			"min": sub_def.get("min", 0),
			"max": sub_def.get("max", 100),
			"description": sub_def.get("description", ""),
		}
	return result

## 重置到初始值
func reset_all() -> void:
	_init_values()
	all_metrics_updated.emit(get_all_with_metadata())

# ── Private ─────────────────────────────────────────────────────

func _load_definitions() -> void:
	if not FileAccess.file_exists(METRICS_PATH):
		push_error("[MetricManager] metrics.json not found")
		return

	var file = FileAccess.open(METRICS_PATH, FileAccess.READ)
	if not file:
		return

	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return

	var data = json.data
	var metrics_list = data.get("metrics", [])
	for m in metrics_list:
		var mid = m.get("metric_id", "")
		if mid.is_empty():
			continue
		_definitions[mid] = m

func _init_values() -> void:
	_values.clear()
	_sub_values.clear()
	_sub_parent.clear()

	for mid in _definitions.keys():
		var defn = _definitions[mid]
		_values[mid] = defn.get("initial", 50)

		var subs = defn.get("sub_metrics", {})
		for sub_id in subs.keys():
			var full_id = mid + "." + sub_id
			var sub_def = subs[sub_id]
			_sub_values[full_id] = sub_def.get("initial", 50)
			_sub_parent[full_id] = mid

func _check_thresholds(metric_id: String, value: int, defn: Dictionary) -> void:
	var thresholds = defn.get("thresholds", {})
	var danger = thresholds.get("danger", DEFAULT_DANGER)
	var warning = thresholds.get("warning", DEFAULT_WARNING)

	if value <= danger:
		metric_danger.emit(metric_id, value)
	elif value <= warning:
		metric_warning.emit(metric_id, value)
