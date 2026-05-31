extends Node2D

## RiskDialogueDemo - Non-interactive smoke test for RiskScorer integration

var _driver: Node = null
var _dialogue_index := 0
var _tests_passed := 0
var _tests_total := 0

var _risk_dialogues_data: Array = []

func _ready() -> void:
	print("=== RiskDialogueDemo Smoke Test ===")

	# Load RiskDialogueDriver
	_driver = Node.new()
	_driver.set_script(load("res://scripts/gdscript/dialogue/risk_dialogue_driver.gd"))
	add_child(_driver)

	# Load risk_dialogues.json
	_load_dialogues()
	
	# Run all tests automatically
	_run_all_tests()


func _load_dialogues() -> void:
	var path = "res://data/dialogues/risk_dialogues.json"
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("RiskDialogueDemo: failed to open " + path)
		return

	var text = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var err = json.parse(text)
	if err != OK:
		push_error("RiskDialogueDemo: JSON parse error: " + json.get_error_message())
		return

	var data = json.get_data()
	if data.get("risk_dialogues"):
		_risk_dialogues_data = Array(data["risk_dialogues"])


func _run_all_tests() -> void:
	if _risk_dialogues_data.size() == 0:
		print("[FAIL] No risk dialogues loaded")
		_finish_test(false)
		return

	for dialogue in _risk_dialogues_data:
		var question = dialogue.get("question", "")
		var scenario = dialogue.get("scenario", "general")
		var citation_count = dialogue.get("citation_count", 1)
		var name = dialogue.get("name", "")

		print("\n=== Testing: " + name)
		print("  Question: " + question)
		print("  Scenario: " + scenario + " citation_count=" + str(citation_count))

		var choices = dialogue.get("choices", [])
		for choice in choices:
			_test_choice(dialogue, choice)

	_dialogue_index += 1
	_finish_test(true)


func _test_choice(dialogue: Dictionary, choice: Dictionary) -> void:
	var question = dialogue.get("question", "")
	var scenario = dialogue.get("scenario", "general")
	var global_citation_count = dialogue.get("citation_count", 1)

	var choice_text = str(choice.get("text", ""))
	var expected_min_score = int(choice.get("expected_risk_min_score", 0))
	var expected_action = str(choice.get("expected_action", "allow"))
	
	# Per-choice context overrides global
	var choice_context = choice.get("context", {})
	var citation_count = choice_context.get("citation_count", global_citation_count)

	print("\n  Evaluating: " + choice_text)

	# Evaluate through RiskScorer
	var context = {"scenario": scenario, "citation_count": citation_count}
	var result = _driver.evaluate_choice(question, choice_text, context)

	var score: int = int(result.get("risk_score", 0))
	var level: String = str(result.get("risk_level", "low"))
	var action: String = str(result.get("recommended_action", "allow"))

	print("  Result: score=" + str(score) + " level=" + level + " action=" + action)

	# Check against expected: score must meet minimum AND action must match
	var score_ok: bool = score >= expected_min_score
	var action_ok: bool = action == expected_action
	var passed: bool = score_ok and action_ok
	
	_tests_total += 1

	if passed:
		print("  [PASS] score=" + str(score) + " >= " + str(expected_min_score) + " action=" + action)
		_tests_passed += 1
	else:
		var reason = ""
		if not score_ok:
			reason = "score=" + str(score) + " < " + str(expected_min_score)
		if not action_ok:
			reason += " action=" + action + " != " + expected_action
		print("  [FAIL] " + reason)

	# Apply correct behavior to verify effect chain
	var correct_behavior = str(choice.get("correct_behavior", "send"))
	var effects = _driver.apply_action(correct_behavior)
	print("  Effects for '" + correct_behavior + "': compliance=" + str(effects.get("compliance_delta", 0)))


func _finish_test(success: bool) -> void:
	print("\n=== SUMMARY ===")
	print("  Tests passed: " + str(_tests_passed) + "/" + str(_tests_total))

	if _tests_passed == _tests_total and _tests_total > 0:
		print("  [PASS] RiskDialogueDemo smoke test PASSED")
	else:
		print("  [FAIL] RiskDialogueDemo smoke test FAILED")

	var timer: Timer = Timer.new()
	timer.wait_time = 0.5
	timer.one_shot = true
	timer.timeout.connect(func(): get_tree().quit())
	add_child(timer)
	timer.start()