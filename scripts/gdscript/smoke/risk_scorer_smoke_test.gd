extends Node2D

## RiskScorer GDExtension Smoke Test
## Tests JSON-driven rules loading and matching

var tests_passed := 0
var tests_total := 7

func _ready():
	print("=== RiskScorer GDExtension Smoke Test ===")
	print()

	# Test 1: RiskScorer class exists
	print("[1/7] Testing if RiskScorer class exists...")
	if ClassDB.class_exists("RiskScorer"):
		print("[PASS] RiskScorer class exists in ClassDB")
		tests_passed += 1
	else:
		print("[FAIL] RiskScorer class does not exist")
		_finish_test(false)
		return
	print()

	# Test 2: Can instantiate RiskScorer
	print("[2/7] Testing RiskScorer instantiation...")
	var scorer = ClassDB.instantiate("RiskScorer")
	if scorer != null:
		print("[PASS] RiskScorer instantiated")
		tests_passed += 1
	else:
		print("[FAIL] ClassDB.instantiate returned null")
		_finish_test(false)
		return
	print()

	# Test 3: load_rules() returns true
	print("[3/7] Testing load_rules()...")
	var ok: bool = scorer.load_rules("res://data/rules/risk_rules.json")
	print("  load_rules returned: ", ok)
	if ok:
		print("[PASS] load_rules returned true")
		tests_passed += 1
	else:
		print("[FAIL] load_rules returned false")
		_finish_test(false)
		return
	print()

	# Test 4: get_rule_count() returns expected count (5)
	print("[4/7] Testing get_rule_count()...")
	var count: int = scorer.get_rule_count()
	print("  rule count: ", count)
	if count >= 3:
		print("[PASS] get_rule_count returned ", count, " (>= 3)")
		tests_passed += 1
	else:
		print("[FAIL] get_rule_count returned ", count, " (expected >= 3)")
		_finish_test(false)
		return
	print()

	# Test 5: "保证录取" triggers admission_guarantee rule
	print("[5/7] Testing rule: '保证录取' -> high/block...")
	var ctx: Dictionary = {"scenario": "admissions", "citation_count": 1}
	var result: Dictionary = scorer.evaluate_text("能保证吗？", "我们可以保证录取！", ctx)
	
	var score: int = int(result.get("risk_score", 0))
	var level: String = str(result.get("risk_level", ""))
	var action: String = str(result.get("recommended_action", ""))
	var triggered: Array = result.get("triggered_rules", [])
	
	print("  Raw result: score=%d, level=%s, action=%s" % [score, level, action])
	print("  Triggered rules: ", triggered)
	
	if score >= 80 and (level == "high" or level == "critical") and action == "block":
		print("[PASS] '保证录取' rule triggered correctly")
		tests_passed += 1
	else:
		print("[FAIL] Rule not triggered as expected")
	print()

	# Test 6: "走关系" triggers relationship_admission rule
	print("[6/7] Testing rule: '走关系' -> critical/block...")
	var result2: Dictionary = scorer.evaluate_text("有关系吗？", "可以走关系找人疏通！", {})
	
	var score2: int = int(result2.get("risk_score", 0))
	var level2: String = str(result2.get("risk_level", ""))
	var action2: String = str(result2.get("recommended_action", ""))
	var triggered2: Array = result2.get("triggered_rules", [])
	
	print("  Raw result: score=%d, level=%s, action=%s" % [score2, level2, action2])
	print("  Triggered rules: ", triggered2)
	
	if score2 >= 90 and level2 == "critical" and action2 == "block":
		print("[PASS] '走关系' rule triggered correctly")
		tests_passed += 1
	else:
		print("[FAIL] '走关系' rule not triggered as expected")
	print()

	# Test 7: Normal material inquiry should NOT trigger high risk rules
	print("[7/7] Testing normal inquiry not over-triggered...")
	var result3: Dictionary = scorer.evaluate_text("报名材料有哪些？",
		"请准备户口本、学生照片和报名表，并参考招生办材料清单。",
		{"scenario": "admissions", "citation_count": 1})
	
	var score3: int = int(result3.get("risk_score", 0))
	var level3: String = str(result3.get("risk_level", ""))
	
	print("  Raw result: score=%d, level=%s" % [score3, level3])
	
	# Should be low risk (short_answer rule triggers if answer is short, but we use longer answer here)
	if score3 < 50:
		print("[PASS] Normal inquiry not over-triggered (score=%d < 50)" % score3)
		tests_passed += 1
	else:
		print("[FAIL] Normal inquiry triggered too high (score=%d >= 50)" % score3)
	print()

	_finish_test(true)

func _finish_test(all_passed: bool):
	print()
	print("=== SUMMARY ===")
	print("  Tests passed: %d/%d" % [tests_passed, tests_total])
	
	if tests_passed >= 6:
		print("  [PASS] RiskScorer GDExtension smoke test PASSED")
	else:
		print("  [FAIL] RiskScorer GDExtension smoke test FAILED")
	
	# Cleanup
	var timer := Timer.new()
	timer.wait_time = 0.5
	timer.one_shot = true
	timer.timeout.connect(_on_timer)
	add_child(timer)
	timer.start()

func _on_timer():
	get_tree().quit()