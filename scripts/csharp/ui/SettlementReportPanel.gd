extends CanvasLayer
class_name SettlementReportPanel

@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var resource_before_label: Label = $Panel/VBox/ResourceBeforeLabel
@onready var resource_after_label: Label = $Panel/VBox/ResourceAfterLabel
@onready var eff_label: Label = $Panel/VBox/MetricsGrid/EfficiencyBox/EfficiencyLabel
@onready var eff_bar: ProgressBar = $Panel/VBox/MetricsGrid/EfficiencyBox/EfficiencyBar
@onready var trust_label: Label = $Panel/VBox/MetricsGrid/ParentTrustBox/ParentTrustLabel
@onready var trust_bar: ProgressBar = $Panel/VBox/MetricsGrid/ParentTrustBox/ParentTrustBar
@onready var comp_label: Label = $Panel/VBox/MetricsGrid/ComplianceBox/ComplianceLabel
@onready var comp_bar: ProgressBar = $Panel/VBox/MetricsGrid/ComplianceBox/ComplianceBar
@onready var stab_label: Label = $Panel/VBox/MetricsGrid/StabilityBox/StabilityLabel
@onready var stab_bar: ProgressBar = $Panel/VBox/MetricsGrid/StabilityBox/StabilityBar
@onready var quest_summary_label: Label = $Panel/VBox/QuestSummaryLabel
@onready var consequences_label: Label = $Panel/VBox/ConsequencesLabel
@onready var events_label: Label = $Panel/VBox/EventsLabel
@onready var continue_btn: Button = $Panel/VBox/ContinueBtn

var _snapshot: Dictionary = {}

func _ready() -> void:
	visible = false
	continue_btn.pressed.connect(_on_continue)
	var tm = get_node_or_null("/root/TimeManager")
	if tm:
		tm.day_ended.connect(_on_day_ended)

func _on_day_ended(day: int) -> void:
	_snapshot = _take_snapshot()
	_populate(day)
	visible = true
	get_tree().paused = true

func _take_snapshot() -> Dictionary:
	var snap = {}
	var mm = get_node_or_null("/root/MetricManager")
	if mm:
		snap["metrics"] = mm.get_all_with_metadata()
	var rm = get_node_or_null("/root/ResourceManager")
	if rm:
		snap["resources"] = rm.get_all()
	return snap

func _populate(day: int) -> void:
	title_label.text = "第 %d 天 结算报告" % day

	var rm = get_node_or_null("/root/ResourceManager")
	if rm:
		var r = rm.get_all()
		var snap_res = _snapshot.get("resources", {})
		resource_before_label.text = "资源变化前：AP %d / 算力 %d / 预算 ¥%d" % [
			snap_res.get("ap", 0), snap_res.get("compute", 0), snap_res.get("budget", 0),
		]
		resource_after_label.text = "资源变化后：AP %d / 算力 %d / 预算 ¥%d" % [
			r.get("ap", 0), r.get("compute", 0), r.get("budget", 0),
		]

	var mm = get_node_or_null("/root/MetricManager")
	if mm:
		var data = mm.get_all_with_metadata()
		var snap_metrics = _snapshot.get("metrics", {})
		for mid in ["school_efficiency", "parent_trust", "compliance_safety", "system_stability"]:
			var old_val = snap_metrics.get(mid, {}).get("value", 50)
			var new_val = data.get(mid, {}).get("value", 50)
			var delta = new_val - old_val
			var sign = "+" if delta >= 0 else ""
			match mid:
				"school_efficiency":
					eff_label.text = "效率: %d → %d (%s%d)" % [old_val, new_val, sign, delta]
					eff_bar.value = new_val
				"parent_trust":
					trust_label.text = "家长信任: %d → %d (%s%d)" % [old_val, new_val, sign, delta]
					trust_bar.value = new_val
				"compliance_safety":
					comp_label.text = "合规: %d → %d (%s%d)" % [old_val, new_val, sign, delta]
					comp_bar.value = new_val
				"system_stability":
					stab_label.text = "稳定: %d → %d (%s%d)" % [old_val, new_val, sign, delta]
					stab_bar.value = new_val

	var qm = get_node_or_null("/root/QuestManager")
	if qm:
		var completed = qm.get_completed_quests()
		var text_parts = []
		if completed.size() > 0:
			text_parts.append("完成 %d 个任务" % completed.size())
		var active = qm.get_active_quests()
		if active.size() > 0:
			text_parts.append("%d 个进行中" % active.size())
		if text_parts.is_empty():
			text_parts.append("无变化")
		quest_summary_label.text = "任务总结：" + "，".join(text_parts)

	consequences_label.text = "阈值后果：无"
	events_label.text = "次日事件：无"

func _on_continue() -> void:
	visible = false
	get_tree().paused = false
