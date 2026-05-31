extends Node

func _ready() -> void:
	print("=== CanaryQuick: Starting ===")
	print("Checking ClassDB for CanarySimulator...")
	var classes = ClassDB.get_class_list()
	var found := false
	for c in classes:
		if c == "CanarySimulator":
			found = true
			break
	print("CanarySimulator in ClassDB: ", found)

	if not found:
		print("FAIL: Class not found")
		get_tree().quit(1)
		return

	var sim = ClassDB.instantiate("CanarySimulator")
	if sim == null:
		print("FAIL: instantiation returned null")
		get_tree().quit(1)
		return

	print("Instantiation OK")
	print("Has simulate_stage: ", sim.has_method("simulate_stage"))
	print("Has evaluate_rollout: ", sim.has_method("evaluate_rollout"))
	print("Has rollback: ", sim.has_method("rollback"))

	# Quick test
	var input = {
		"current_percentage": 1,
		"next_percentage": 5,
		"stability": 68.0,
		"compliance": 74.0,
		"parent_trust": 61.0,
		"error_rate": 0.018,
		"complaint_rate": 0.004,
		"latency_ms": 420.0,
		"risk_score": 35
	}
	var result = sim.simulate_stage(input)
	print("simulate_stage result: ", result)
	print("recommendation: ", result.get("recommendation", "MISSING"))

	print("=== CanaryQuick: PASS ===")
	get_tree().quit(0)
