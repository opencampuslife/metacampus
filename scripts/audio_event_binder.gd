extends Node
class_name AudioEventBinder

## Phase 2.8A — 音频事件绑定器
## 监听 UI 面板可见性变化，触发 AudioManager.play_event()
## 不修改任何业务状态，只负责音频触发

var _audio: AudioManager
var _ui_bindings: Array = []  # {path: NodePath, on_open: String, on_close: String}

func _ready() -> void:
	_audio = get_node("/root/AudioManager") as AudioManager

	# 注册面板可见性回调
	_register_panel("Dashboard", "^Dashboard", "dashboard_open", "dashboard_close")
	_register_panel("QuestBoard", "^QuestBoard", "quest_board_open", "quest_board_close")
	_register_panel("SettlementReportPanel", "^SettlementReportPanel", "settlement_open", "settlement_continue")
	_register_panel("DebugCommandPanel", "^DebugCommandPanel", "ui_open_dialog", "ui_close_dialog")
	_register_panel("LocationCalibrationPanel", "^LocationCalibrationPanel", "ui_open_dialog", "ui_close_dialog")

	# 连接 QuestManager 信号（如果有）
	_setup_quest_signals()
	_setup_metric_signals()
	_setup_dialogue_signals()

	print("[AudioEventBinder] Ready — bindings=%d" % _ui_bindings.size())


func _process(_delta: float) -> void:
	# 每帧检查面板可见性变化（因为 GDScript 没有 visibility_changed 统一信号）
	for b in _ui_bindings:
		_check_visibility(b)


func _register_panel(label: String, path: String, on_open: String, on_close: String) -> void:
	var node = get_node_or_null(path)
	if node == null:
		push_warning("[AudioEventBinder] Panel not found: " + path)
		return
	var binding = {
		"node": node,
		"prev_visible": null,   # null = 尚未记录
		"on_open": on_open,
		"on_close": on_close,
	}
	_ui_bindings.append(binding)


func _check_visibility(binding: Dictionary) -> void:
	var node: Node = binding["node"]
	var curr: bool = node.visible
	var prev = binding["prev_visible"]

	if prev == null:
		binding["prev_visible"] = curr
		return

	if curr != prev:
		binding["prev_visible"] = curr
		if curr:
			_audio.play_event(binding["on_open"])
		else:
			_audio.play_event(binding["on_close"])


func _setup_quest_signals() -> void:
	# QuestManager 作为 Autoload 注册到 scene tree
	# 通过树搜索找到它（因为不是所有 manager 都是 Godot autoload）
	var qm = get_tree().get_first_node_in_group("quest_manager")
	if qm == null:
		# QuestManager 可能还没加载，不算 warning
		return

	if qm.has_signal("QuestStarted"):
		qm.connect("QuestStarted", _on_quest_started)
	if qm.has_signal("QuestCompleted"):
		qm.connect("QuestCompleted", _on_quest_completed)
	if qm.has_signal("QuestFailed"):
		qm.connect("QuestFailed", _on_quest_failed)


func _setup_metric_signals() -> void:
	var mm = get_tree().get_first_node_in_group("metric_manager")
	if mm == null:
		return

	if mm.has_signal("ThresholdTriggered"):
		mm.connect("ThresholdTriggered", _on_metric_threshold)
	if mm.has_signal("MetricChanged"):
		mm.connect("MetricChanged", _on_metric_changed)


func _setup_dialogue_signals() -> void:
	var dm = get_tree().get_first_node_in_group("dialogue_manager")
	if dm == null:
		return

	if dm.has_signal("dialogue_ended"):
		dm.connect("dialogue_ended", _on_dialogue_ended)
	if dm.has_signal("choice_made"):
		dm.connect("choice_made", _on_choice_made)


# ══════════════════════════════════════════════════════════════════
# Signal Callbacks
# ══════════════════════════════════════════════════════════════════

func _on_quest_started(qid: String) -> void:
	_audio.play_event("quest_start")

func _on_quest_completed(qid: String) -> void:
	_audio.play_event("quest_complete")

func _on_quest_failed(qid: String) -> void:
	_audio.play_event("quest_fail")

func _on_metric_threshold(metric_id: String, consequence_id: String) -> void:
	if consequence_id == "system_outage" or consequence_id == "critical":
		_audio.play_event("critical_alert")
	else:
		_audio.play_event("risk_warning")

func _on_metric_changed(metric_id: String, old_val: float, new_val: float) -> void:
	if new_val > old_val:
		_audio.play_event("metric_up")
	elif new_val < old_val:
		_audio.play_event("metric_down")

func _on_dialogue_ended() -> void:
	_audio.play_event("ui_close_dialog")

func _on_choice_made(choice_data: Dictionary) -> void:
	# 对话选项可能导致多种结果，这里不做具体判断
	# 实际音效由 quest/compliance/metric 等系统决定
	pass