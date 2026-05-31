extends CanvasLayer
class_name HudController

## HUD 控制器
## 显示时间、资源、核心指标、当前任务

@onready var time_label: Label = $RootMargin/Panel/VBox/TopRow/TimeLabel
@onready var ap_label: Label = $RootMargin/Panel/VBox/TopRow/ApLabel
@onready var compute_label: Label = $RootMargin/Panel/VBox/TopRow/ComputeLabel
@onready var budget_label: Label = $RootMargin/Panel/VBox/TopRow/BudgetLabel
@onready var eff_label: Label = $RootMargin/Panel/VBox/MetricRow/EfficiencyBox/EfficiencyLabel
@onready var eff_bar: ProgressBar = $RootMargin/Panel/VBox/MetricRow/EfficiencyBox/EfficiencyBar
@onready var trust_label: Label = $RootMargin/Panel/VBox/MetricRow/ParentTrustBox/ParentTrustLabel
@onready var trust_bar: ProgressBar = $RootMargin/Panel/VBox/MetricRow/ParentTrustBox/ParentTrustBar
@onready var comp_label: Label = $RootMargin/Panel/VBox/MetricRow/ComplianceBox/ComplianceLabel
@onready var comp_bar: ProgressBar = $RootMargin/Panel/VBox/MetricRow/ComplianceBox/ComplianceBar
@onready var stab_label: Label = $RootMargin/Panel/VBox/MetricRow/StabilityBox/StabilityLabel
@onready var stab_bar: ProgressBar = $RootMargin/Panel/VBox/MetricRow/StabilityBox/StabilityBar
@onready var quest_hint: Label = $RootMargin/Panel/VBox/QuestRow/QuestHintLabel

func _ready() -> void:
	_wire_signals()
	_refresh_all()

func _wire_signals() -> void:
	var tm = get_node_or_null("/root/TimeManager")
	if tm:
		tm.time_advanced.connect(_on_time_changed)
		tm.day_changed.connect(_on_day_changed)

	var rm = get_node_or_null("/root/ResourceManager")
	if rm:
		rm.resource_changed.connect(_on_resource_changed)

	var mm = get_node_or_null("/root/MetricManager")
	if mm:
		mm.all_metrics_updated.connect(_on_metrics_updated)

	var qm = get_node_or_null("/root/QuestManager")
	if qm:
		qm.quest_started.connect(_on_quest_started)
		qm.quest_completed.connect(_on_quest_changed)

func _refresh_all() -> void:
	_on_time_changed(1, 8, 0, "morning")
	_on_resource_changed("ap", 10, 0)
	_on_resource_changed("compute", 50, 0)
	_on_resource_changed("budget", 1000, 0)
	_update_metrics()

func _on_time_changed(_day: int, h: int, m: int, phase: String) -> void:
	var day_str = "第 %d 天" % get_node_or_null("/root/TimeManager").day if get_node_or_null("/root/TimeManager") else "第 1 天"
	time_label.text = "春季学期 · %s · %02d:%02d" % [day_str, h, m]

func _on_day_changed(day: int) -> void:
	_refresh_all()

func _on_resource_changed(rid: String, val: int, _delta: int) -> void:
	match rid:
		"ap": ap_label.text = "AP %d/%d" % [val, _get_max("ap")]
		"compute": compute_label.text = "算力 %d/%d" % [val, _get_max("compute")]
		"budget": budget_label.text = "预算 ¥%d" % val

func _get_max(rid: String) -> int:
	var rm = get_node_or_null("/root/ResourceManager")
	return rm.get_max(rid) if rm else 99999

func _on_metrics_updated(_metrics: Dictionary) -> void:
	_update_metrics()

func _update_metrics() -> void:
	var mm = get_node_or_null("/root/MetricManager")
	if not mm:
		return
	var data = mm.get_all_with_metadata()
	for mid in data.keys():
		var m = data[mid]
		var val = m.get("value", 0)
		match mid:
			"school_efficiency":
				eff_label.text = "效率 %d" % val
				eff_bar.value = val
			"parent_trust":
				trust_label.text = "家长信任 %d" % val
				trust_bar.value = val
			"compliance_safety":
				comp_label.text = "合规 %d" % val
				comp_bar.value = val
			"system_stability":
				stab_label.text = "稳定 %d" % val
				stab_bar.value = val

func _on_quest_started(qid: String) -> void:
	var qm = get_node_or_null("/root/QuestManager")
	if not qm:
		return
	var quests = qm.get_active_quests()
	if quests.size() > 0:
		quest_hint.text = "当前任务：%s" % quests[0].get("name", qid)
	else:
		quest_hint.text = "当前任务：暂无"

func _on_quest_changed(_qid: String) -> void:
	_on_quest_started("")
