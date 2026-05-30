extends Control

## RiskReviewPanel - UI for displaying risk evaluation results

@onready var question_label: Label = $MarginContainer/VBox/QuestionSection/QuestionLabel
@onready var answer_label: Label = $MarginContainer/VBox/AnswerSection/AnswerLabel
@onready var score_label: Label = $MarginContainer/VBox/ScoreSection/ScoreLabel
@onready var level_label: Label = $MarginContainer/VBox/LevelSection/LevelLabel
@onready var rules_label: Label = $MarginContainer/VBox/RulesSection/RulesLabel
@onready var action_label: Label = $MarginContainer/VBox/ActionSection/ActionLabel
@onready var deltas_label: Label = $MarginContainer/VBox/DeltasSection/DeltasLabel

@onready var send_btn: Button = $MarginContainer/VBox/ButtonRow/SendButton
@onready var modify_btn: Button = $MarginContainer/VBox/ButtonRow/ModifyButton
@onready var escalate_btn: Button = $MarginContainer/VBox/ButtonRow/EscalateButton
@onready var block_btn: Button = $MarginContainer/VBox/ButtonRow/BlockButton

signal action_selected(action: String, result: Dictionary)

var _current_result: Dictionary = {}

func _ready() -> void:
	send_btn.pressed.connect(_on_send_pressed)
	modify_btn.pressed.connect(_on_modify_pressed)
	escalate_btn.pressed.connect(_on_escalate_pressed)
	block_btn.pressed.connect(_on_block_pressed)

	# Initially hide
	visible = false


func show_result(question: String, answer: String, result: Dictionary) -> void:
	_current_result = result

	question_label.text = "问题: " + question
	answer_label.text = "回答: " + answer

	var score: int = int(result.get("risk_score", 0))
	score_label.text = "风险分数: %d" % score

	var level: String = str(result.get("risk_level", "low"))
	level_label.text = "风险等级: " + level

	# Color code level
	var level_color: Color
	match level:
		"critical":
			level_color = Color(0.9, 0.1, 0.1)
		"high":
			level_color = Color(1.0, 0.5, 0.1)
		"medium":
			level_color = Color(1.0, 0.85, 0.1)
		_:
			level_color = Color(0.3, 0.9, 0.3)
	level_label.add_theme_color_override("font_color", level_color)

	# Show triggered rules
	var rules: Array = Array(result.get("triggered_rules", []))
	var rules_text: String = "触发规则: " if rules.size() > 0 else "触发规则: (无)"
	for i in range(rules.size()):
		rules_text += str(rules[i])
		if i < rules.size() - 1:
			rules_text += ", "
	rules_label.text = rules_text

	# Show recommended action
	var action: String = str(result.get("recommended_action", "allow"))
	var action_text: String
	match action:
		"allow":
			action_text = "推荐: 直接发送"
		"revise":
			action_text = "推荐: 修改后发送"
		"escalate":
			action_text = "推荐: 转人工"
		"block":
			action_text = "推荐: 阻止发送"
		_:
			action_text = "推荐: " + action
	action_label.text = action_text

	# Show metric deltas
	var compliance: int = int(result.get("compliance_delta", 0))
	var parent_trust: int = int(result.get("parent_trust_delta", 0))
	var stability: int = int(result.get("stability_delta", 0))
	deltas_label.text = "指标影响: 合规=%d, 信任=%d, 稳定=%d" % [compliance, parent_trust, stability]

	# Update button states based on recommended action
	_update_button_states(action)

	visible = true


func _update_button_states(recommended: String) -> void:
	# Default: all enabled but styled based on recommendation
	match recommended:
		"allow":
			send_btn.modulate = Color(0.6, 1.0, 0.6)
			send_btn.disabled = false
		"revise":
			send_btn.modulate = Color(1.0, 1.0, 1.0)
			send_btn.disabled = false
			modify_btn.modulate = Color(1.0, 0.9, 0.4)
			modify_btn.disabled = false
		"escalate":
			send_btn.modulate = Color(1.0, 1.0, 1.0)
			send_btn.disabled = false
			escalate_btn.modulate = Color(1.0, 0.6, 0.3)
			escalate_btn.disabled = false
		"block":
			send_btn.modulate = Color(0.6, 0.6, 0.6)
			send_btn.disabled = true
			block_btn.modulate = Color(1.0, 0.4, 0.4)
			block_btn.disabled = false


func _on_send_pressed() -> void:
	emit_signal("action_selected", "send", _current_result)
	visible = false


func _on_modify_pressed() -> void:
	emit_signal("action_selected", "modified_send", _current_result)
	visible = false


func _on_escalate_pressed() -> void:
	emit_signal("action_selected", "escalate", _current_result)
	visible = false


func _on_block_pressed() -> void:
	emit_signal("action_selected", "block", _current_result)
	visible = false


func hide_panel() -> void:
	visible = false


## Show from NPC dialogue - evaluates choice through RiskScorerService
func show_from_npc(question: String, choice_text: String, context: Dictionary = {}) -> void:
	if not has_node("/root/RiskScorerService"):
		push_error("RiskReviewPanel: RiskScorerService not found")
		return

	var service = get_node("/root/RiskScorerService")
	var result = service.evaluate(question, choice_text, context)
	show_result(question, choice_text, result)