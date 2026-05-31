extends Node

## RiskDialogueDriver - Intercepts dialogue choices and applies risk evaluation
## Connects RiskScorerService to gameplay dialogue flow

signal risk_review_requested(result: Dictionary, context: Dictionary)
signal risk_action_applied(action: String, effects: Dictionary)

var _review_panel: Control = null
var _current_context: Dictionary = {}
var _pending_result: Dictionary = {}

func _ready() -> void:
	# Load RiskReviewPanel as child for display
	_setup_review_panel()


func _setup_review_panel() -> void:
	var scene_path = "res://scenes/risk/RiskReviewPanel.tscn"
	var packed_scene = load(scene_path)
	if packed_scene != null:
		var panel = packed_scene.instantiate()
		panel.action_selected.connect(_on_action_selected)
		add_child(panel)
		_review_panel = panel
		print("RiskDialogueDriver: RiskReviewPanel loaded")
	else:
		push_warning("RiskDialogueDriver: RiskReviewPanel.tscn not found")


## Evaluate a dialogue choice text through RiskScorer
func evaluate_choice(question: String, choice_text: String, context: Dictionary = {}) -> Dictionary:
	var result = RiskScorerService.evaluate(question, choice_text, context)
	_pending_result = result
	_current_context = context
	return result


## Show risk review panel for a dialogue choice
func show_risk_review(question: String, choice_text: String, context: Dictionary = {}) -> void:
	var result = evaluate_choice(question, choice_text, context)
	
	if _review_panel != null and result.get("risk_score", 0) > 0:
		_review_panel.show_result(question, choice_text, result)
		emit_signal("risk_review_requested", result, context)


## Apply effects based on player's action from risk review
func apply_action(action: String) -> Dictionary:
	if _pending_result.is_empty():
		push_warning("RiskDialogueDriver: no pending result to apply")
		return {}
	
	var effects = RiskScorerService.apply_action_effects(_pending_result, action)
	emit_signal("risk_action_applied", action, effects)
	
	# Clear pending state
	_pending_result = {}
	_current_context = {}
	
	return effects


## Get current risk level for a choice text
func get_risk_level(question: String, choice_text: String, context: Dictionary = {}) -> String:
	var result = evaluate_choice(question, choice_text, context)
	return str(result.get("risk_level", "low"))


## Check if choice should be auto-blocked
func should_block(question: String, choice_text: String, context: Dictionary = {}) -> bool:
	var result = evaluate_choice(question, choice_text, context)
	return str(result.get("recommended_action", "allow")) == "block"


func _on_action_selected(action: String, result: Dictionary) -> void:
	print("RiskDialogueDriver: action_selected=", action, " result=", result)
	var effects = RiskScorerService.apply_action_effects(result, action)
	emit_signal("risk_action_applied", action, effects)
	
	# Here you would integrate with MetricManager to apply effects
	# For now, just log
	print("RiskDialogueDriver: applied effects=", effects)