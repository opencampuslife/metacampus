extends Node
## Smoke test for CanarySimulator GDExtension
## NOTE: Uses ClassDB.instantiate() and untyped variables because GDExtension
## classes registered at MODULE_INITIALIZATION_LEVEL_SCENE are not available
## to the GDScript parser at compilation time.

var _passed := 0
var _failed := 0
var _total := 0

func _ready() -> void:
	print("========================================")
	print("  CanarySimulator Native Smoke Test")
	print("========================================")

	test_01_class_loadable()
	test_02_simulate_stage_1_to_5()
	test_03_simulate_stage_5_to_25()
	test_04_simulate_stage_25_to_50()
	test_05_simulate_stage_50_to_100()
	test_06_full_release_risk()
	test_07_rollback()
	test_08_evaluate_rollout()
	test_09_pause_continue_flow()

	print("========================================")
	print("  RESULTS: %d/%d PASS" % [_passed, _total])
	print("========================================")

	if _failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)


func assert_eq(test_name: String, expected, actual, tolerance := 0.001) -> void:
	_total += 1
	if typeof(expected) == TYPE_FLOAT and typeof(actual) == TYPE_FLOAT:
		if abs(expected - actual) <= tolerance:
			_passed += 1
			print("  PASS: %s" % test_name)
		else:
			_failed += 1
			push_error("  FAIL: %s (expected %.4f, got %.4f)" % [test_name, expected, actual])
	elif typeof(expected) == TYPE_BOOL and expected == actual:
		_passed += 1
		print("  PASS: %s" % test_name)
	elif expected == actual:
		_passed += 1
		print("  PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("  FAIL: %s (expected %s, got %s)" % [test_name, str(expected), str(actual)])


func test_01_class_loadable() -> void:
	print("\n[Test 01] CanarySimulator class loadable")
	var sim = ClassDB.instantiate("CanarySimulator")
	assert_eq("Class instantiation", sim != null, true)
	if sim == null:
		return

	assert_eq("has simulate_stage", sim.has_method("simulate_stage"), true)
	assert_eq("has evaluate_rollout", sim.has_method("evaluate_rollout"), true)
	assert_eq("has rollback", sim.has_method("rollback"), true)
	print("  CanarySimulator API: OK")


func test_02_simulate_stage_1_to_5() -> void:
	print("\n[Test 02] simulate_stage: 1%% -> 5%%")
	var sim = ClassDB.instantiate("CanarySimulator")
	if sim == null:
		assert_eq("skip - no instance", true, false)
		return

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
	print("  Result: ", result)

	assert_eq("recommendation present", result.has("recommendation"), true)
	assert_eq("predicted_error_rate >= 0", float(result.get("predicted_error_rate", -1)) >= 0.0, true)
	assert_eq("has triggered_warnings", result.has("triggered_warnings"), true)
	assert_eq("has stability_delta", result.has("stability_delta"), true)

	var rec = str(result.get("recommendation", ""))
	print("  Recommendation: ", rec)


func test_03_simulate_stage_5_to_25() -> void:
	print("\n[Test 03] simulate_stage: 5%% -> 25%%")
	var sim = ClassDB.instantiate("CanarySimulator")
	if sim == null:
		assert_eq("skip - no instance", true, false)
		return

	var input = {
		"current_percentage": 5,
		"next_percentage": 25,
		"stability": 68.0,
		"compliance": 74.0,
		"parent_trust": 61.0,
		"error_rate": 0.018,
		"complaint_rate": 0.004,
		"latency_ms": 420.0,
		"risk_score": 35
	}

	var result = sim.simulate_stage(input)
	print("  Result: ", result)

	var error_rate = float(result.get("predicted_error_rate", 0.0))
	assert_eq("predicted_error > 0.018", error_rate > 0.018, true)

	var stability = int(result.get("stability_delta", 0))
	assert_eq("stability_delta negative", stability < 0, true)


func test_04_simulate_stage_25_to_50() -> void:
	print("\n[Test 04] simulate_stage: 25%% -> 50%%")
	var sim = ClassDB.instantiate("CanarySimulator")
	if sim == null:
		assert_eq("skip - no instance", true, false)
		return

	var input = {
		"current_percentage": 25,
		"next_percentage": 50,
		"stability": 68.0,
		"compliance": 74.0,
		"parent_trust": 61.0,
		"error_rate": 0.022,
		"complaint_rate": 0.006,
		"latency_ms": 450.0,
		"risk_score": 40
	}

	var result = sim.simulate_stage(input)
	print("  Result: ", result)

	assert_eq("has recommendation", result.has("recommendation"), true)
	var warnings = result.get("triggered_warnings", [])
	print("  Warnings: ", warnings)


func test_05_simulate_stage_50_to_100() -> void:
	print("\n[Test 05] simulate_stage: 50%% -> 100%%")
	var sim = ClassDB.instantiate("CanarySimulator")
	if sim == null:
		assert_eq("skip - no instance", true, false)
		return

	var input = {
		"current_percentage": 50,
		"next_percentage": 100,
		"stability": 64.0,
		"compliance": 72.0,
		"parent_trust": 60.0,
		"error_rate": 0.025,
		"complaint_rate": 0.008,
		"latency_ms": 480.0,
		"risk_score": 45
	}

	var result = sim.simulate_stage(input)
	print("  Result: ", result)

	var error_rate = float(result.get("predicted_error_rate", 0.0))
	assert_eq("error increased (>0.025)", error_rate > 0.025, true)

	var warnings = result.get("triggered_warnings", [])
	assert_eq("has full_production warning", warnings.has("full_production"), true)


func test_06_full_release_risk() -> void:
	print("\n[Test 06] Full release risk from 5%%")
	var sim = ClassDB.instantiate("CanarySimulator")
	if sim == null:
		assert_eq("skip - no instance", true, false)
		return

	var input = {
		"current_percentage": 5,
		"next_percentage": 100,
		"stability": 68.0,
		"compliance": 74.0,
		"parent_trust": 61.0,
		"error_rate": 0.018,
		"complaint_rate": 0.004,
		"latency_ms": 420.0,
		"risk_score": 35
	}

	var result = sim.simulate_stage(input)
	print("  Result: ", result)

	var rec = str(result.get("recommendation", ""))
	assert_eq("recommendation is rollback", rec, "rollback")

	var warnings = result.get("triggered_warnings", [])
	assert_eq("has full_release_risk", warnings.has("full_release_risk"), true)

	var stability = int(result.get("stability_delta", 0))
	assert_eq("severe stability penalty (<= -10)", stability <= -10, true)

	print("  Direct full release correctly blocked!")


func test_07_rollback() -> void:
	print("\n[Test 07] Rollback from 50%%")
	var sim = ClassDB.instantiate("CanarySimulator")
	if sim == null:
		assert_eq("skip - no instance", true, false)
		return

	var state = {
		"current_percentage": 50,
		"stability": 60.0,
		"compliance": 68.0,
		"parent_trust": 55.0,
		"error_rate": 0.035,
		"complaint_rate": 0.012,
		"latency_ms": 520.0,
		"risk_score": 50
	}

	var result = sim.rollback(state)
	print("  Rollback result: ", result)

	var pct = int(result.get("current_percentage", -1))
	assert_eq("rolled back to 25%%", pct, 25)

	var error_rate = float(result.get("error_rate", 1.0))
	assert_eq("error reduced", error_rate < 0.035, true)

	var stability = float(result.get("stability", 0.0))
	assert_eq("stability recovered", stability > 60.0, true)

	var warnings = result.get("triggered_warnings", [])
	assert_eq("has rollback_executed", warnings.has("rollback_executed"), true)
	assert_eq("has significant_rollback", warnings.has("significant_rollback"), true)


func test_08_evaluate_rollout() -> void:
	print("\n[Test 08] evaluate_rollout: preview 25%% -> 100%%")
	var sim = ClassDB.instantiate("CanarySimulator")
	if sim == null:
		assert_eq("skip - no instance", true, false)
		return

	var state = {
		"current_percentage": 25,
		"stability": 65.0,
		"compliance": 70.0,
		"parent_trust": 58.0,
		"error_rate": 0.020,
		"complaint_rate": 0.005,
		"latency_ms": 430.0,
		"risk_score": 38
	}

	var result = sim.evaluate_rollout(state, 100)
	print("  Evaluate result: ", result)

	assert_eq("has recommendation", result.has("recommendation"), true)
	# 25% -> 100% should have warnings about large jump
	var warnings = result.get("triggered_warnings", [])
	assert_eq("has large_traffic_jump", warnings.has("large_traffic_jump"), true)
	print("  Rollout preview OK")


func test_09_pause_continue_flow() -> void:
	print("\n[Test 09] Pause/Continue flow simulation")
	var sim = ClassDB.instantiate("CanarySimulator")
	if sim == null:
		assert_eq("skip - no instance", true, false)
		return

	# Simulate 1% -> 5%
	var input1 = {
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
	var r1 = sim.simulate_stage(input1)
	var rec1 = str(r1.get("recommendation", ""))
	print("  Stage 1%%->5%%: ", rec1)
	assert_eq("stage 1->5 should be continue or pause", rec1 in ["continue", "pause"], true)

	# Simulate 5% -> 25%
	var input2 = {
		"current_percentage": 5,
		"next_percentage": 25,
		"stability": 67.0,
		"compliance": 73.0,
		"parent_trust": 60.0,
		"error_rate": 0.020,
		"complaint_rate": 0.005,
		"latency_ms": 425.0,
		"risk_score": 36
	}
	var r2 = sim.simulate_stage(input2)
	var rec2 = str(r2.get("recommendation", ""))
	print("  Stage 5%%->25%%: ", rec2)

	# Rollback at 25%
	var state_at_25 = input2.duplicate()
	state_at_25["current_percentage"] = 25
	var rb = sim.rollback(state_at_25)
	var rb_pct = int(rb.get("current_percentage", -1))
	print("  Rollback to: ", rb_pct, "%%")
	assert_eq("rollback goes down to 5%%", rb_pct, 5)

	print("  Pause/continue flow OK")
