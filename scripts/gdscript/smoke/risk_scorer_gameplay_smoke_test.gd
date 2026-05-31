extends Node

## RiskScorer Gameplay Integration Smoke Test
## Tests that RiskScorerService autoload works and evaluates correctly

func _ready() -> void:
	print("=== RiskScorer Gameplay Integration Smoke Test ===")
	print()

	# Test 1: Check RiskScorerService autoload is available
	print("[1/4] Testing RiskScorerService autoload...")
	if has_node("/root/RiskScorerService"):
		print("[PASS] RiskScorerService autoload available")
	else:
		print("[FAIL] RiskScorerService autoload not found")
		_finish(false)
		return

	var service = get_node("/root/RiskScorerService")
	print()

	# Test 2: Check rules are loaded
	print("[2/4] Testing rules loaded...")
	if service.is_loaded():
		print("[PASS] Rules loaded, count: ", service.get_rule_count())
	else:
		print("[FAIL] Rules not loaded")
		_finish(false)
		return
	print()

	# Test 3: "保证录取" returns block
	print("[3/4] Testing '保证录取' -> block...")
	var result1 = service.evaluate(
		"能保证录取吗？",
		"可以保证录取，只要材料交齐。",
		{"scenario": "admissions", "citation_count": 1}
	)

	var score1: int = int(result1.get("risk_score", 0))
	var action1: String = str(result1.get("recommended_action", ""))

	print("  result: score=%d, action=%s" % [score1, action1])

	if score1 >= 80 and action1 == "block":
		print("[PASS] '保证录取' correctly returns block")
	else:
		print("[FAIL] Expected score>=80 and action=block, got score=%d action=%s" % [score1, action1])
		_finish(false)
		return
	print()

	# Test 4: "走关系" returns critical/block
	print("[4/4] Testing '走关系' -> critical/block...")
	var result2 = service.evaluate(
		"有关系吗？",
		"可以走关系找人疏通！",
		{}
	)

	var score2: int = int(result2.get("risk_score", 0))
	var level2: String = str(result2.get("risk_level", ""))
	var action2: String = str(result2.get("recommended_action", ""))

	print("  result: score=%d, level=%s, action=%s" % [score2, level2, action2])

	if score2 >= 90 and level2 == "critical" and action2 == "block":
		print("[PASS] '走关系' correctly returns critical/block")
	else:
		print("[FAIL] Expected score>=90 level=critical action=block")
		_finish(false)
		return
	print()

	_finish(true)


func _finish(success: bool) -> void:
	print()
	if success:
		print("=== SUMMARY ===")
		print("  [PASS] RiskScorer Gameplay Integration smoke test PASSED")
	else:
		print("=== SUMMARY ===")
		print("  [FAIL] RiskScorer Gameplay Integration smoke test FAILED")

	var timer := Timer.new()
	timer.wait_time = 0.5
	timer.one_shot = true
	timer.timeout.connect(func(): get_tree().quit())
	add_child(timer)
	timer.start()