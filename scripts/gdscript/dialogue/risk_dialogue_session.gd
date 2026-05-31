extends Node

## RiskDialogueSession - Manages a single risk dialogue session lifecycle
## Tracks question/choices/state and coordinates with RiskScorerService + RiskReviewPanel

signal session_started(question: String, npc_id: String)
signal session_ended(action: String, effects: Dictionary)
signal choice_selected(choice_data: Dictionary, risk_result: Dictionary)

enum State { IDLE, SHOWING_QUESTION, EVALUATING, SHOWING_REVIEW, APPLYING }

var state: State = State.IDLE
var npc_id: String = ""
var npc_name: String = ""
var current_question: String = ""
var current_scenario: String = "general"
var choices_data: Array = []
var current_choice_index: int = -1
var _pending_risk_result: Dictionary = {}

var _driver: Node = null
var _review_panel: Control = null

func _ready() -> void:
	add_to_group("risk_dialogue_session")

	# Get RiskDialogueDriver autoload
	if has_node("/root/RiskDialogueDriver"):
		_driver = get_node("/root/RiskDialogueDriver")

	# Setup review panel
	_setup_review_panel()


func _setup_review_panel() -> void:
	var scene_path = "res://scenes/risk/RiskReviewPanel.tscn"
	var packed = load(scene_path)
	if packed != null:
		var panel = packed.instantiate()
		if _driver and _driver.has_method("add_child"):
			_driver.add_child(panel)
		else:
			add_child(panel)
		panel.action_selected.connect(_on_review_action)
		panel.visible = false
		_review_panel = panel


## Start a new risk dialogue session with an NPC
func start_session(npc_id: String, npc_name: String, question: String,
		choices: Array, scenario: String = "general") -> void:
	self.npc_id = npc_id
	self.npc_name = npc_name
	self.current_question = question
	self.current_scenario = scenario
	self.choices_data = choices
	self.current_choice_index = -1
	self.state = State.SHOWING_QUESTION

	session_started.emit(question, npc_id)


## Evaluate a specific choice and show risk review if needed
func evaluate_choice(choice_index: int) -> Dictionary:
	if choice_index < 0 or choice_index >= choices_data.size():
		push_warning("RiskDialogueSession: invalid choice index %d" % choice_index)
		return {}

	current_choice_index = choice_index
	var choice = choices_data[choice_index]
	var choice_text = str(choice.get("text", ""))

	state = State.EVALUATING

	var context = {
		"scenario": current_scenario,
		"npc_id": npc_id,
		"citation_count": int(choice.get("context", {}).get("citation_count", 1))
	}

	var result = _evaluate_through_driver(current_question, choice_text, context)
	_pending_risk_result = result
	state = State.SHOWING_REVIEW

	# Show review panel if risk score is meaningful
	var score: int = int(result.get("risk_score", 0))
	if score > 0 and _review_panel != null:
		_review_panel.show_result(current_question, choice_text, result)
	elif _review_panel != null:
		_review_panel.visible = false

	return result


## Apply player's action from risk review
func apply_action(action: String) -> Dictionary:
	if _pending_risk_result.is_empty():
		return {}

	var effects = _apply_effects(action, _pending_risk_result)
	_pending_risk_result = {}
	state = State.IDLE

	session_ended.emit(action, effects)
	return effects


## Get current state
func get_state() -> State:
	return state


## Get pending risk result
func get_pending_result() -> Dictionary:
	return _pending_risk_result


## Check if session is active
func is_active() -> bool:
	return state != State.IDLE


## Reset session
func reset() -> void:
	state = State.IDLE
	npc_id = ""
	npc_name = ""
	current_question = ""
	choices_data.clear()
	current_choice_index = -1
	_pending_risk_result = {}
	if _review_panel:
		_review_panel.visible = false


func _evaluate_through_driver(question: String, choice_text: String,
		context: Dictionary) -> Dictionary:
	if _driver != null and _driver.has_method("evaluate_choice"):
		return _driver.evaluate_choice(question, choice_text, context)

	# Fallback: direct RiskScorerService call
	if has_node("/root/RiskScorerService"):
		var service = get_node("/root/RiskScorerService")
		return service.evaluate(question, choice_text, context)

	# Return empty result if no driver/service available
	return {
		"risk_score": 0,
		"risk_level": "low",
		"recommended_action": "allow",
		"triggered_rules": [],
		"compliance_delta": 0,
		"parent_trust_delta": 0,
		"stability_delta": 0
	}


func _apply_effects(action: String, result: Dictionary) -> Dictionary:
	# Apply through driver
	if _driver != null and _driver.has_method("apply_action"):
		return _driver.apply_action(action)

	# Fallback: direct RiskScorerService
	if has_node("/root/RiskScorerService"):
		var service = get_node("/root/RiskScorerService")
		if service.has_method("apply_action_effects"):
			return service.apply_action_effects(result, action)

	return {}


func _on_review_action(action: String, result: Dictionary) -> void:
	emit_signal("choice_selected", choices_data[current_choice_index], result)
	var effects = apply_action(action)

	# Emit for external listeners (MetricManager, QuestManager integration)
	emit_signal("session_ended", action, effects)