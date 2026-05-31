extends Node
## CanarySimulatorService — Autoload service wrapping native CanarySimulator GDExtension
##
## Manages native object lifecycle and provides canary release simulation API.
## Used by CanaryConsole and T8 dialogue integration.

var _simulator = null  # CanarySimulator (GDExtension, type not available to parser)
var _loaded := false

## Current canary state (persisted across simulations)
var current_state: Dictionary = {
	"current_percentage": 0,
	"next_percentage": 1,
	"stability": 68.0,
	"compliance": 74.0,
	"parent_trust": 61.0,
	"error_rate": 0.018,
	"complaint_rate": 0.004,
	"latency_ms": 420.0,
	"risk_score": 35
}

## History of stage transitions for rollback support
var stage_history: Array[Dictionary] = []

## Signal emitted after each simulation step
signal stage_completed(recommendation: String, result: Dictionary)
## Signal emitted when a warning is triggered
signal warning_triggered(warning: String)
## Signal emitted on rollback
signal rollback_executed(from_pct: int, to_pct: int)


func _ready() -> void:
	_simulator = ClassDB.instantiate("CanarySimulator")
	if _simulator != null:
		_loaded = true
		print("CanarySimulatorService: native instance created")
	else:
		push_error("CanarySimulatorService: failed to instantiate CanarySimulator")


func is_loaded() -> bool:
	return _loaded


## Reset state to defaults
func reset_state() -> void:
	current_state = {
		"current_percentage": 0,
		"next_percentage": 1,
		"stability": 68.0,
		"compliance": 74.0,
		"parent_trust": 61.0,
		"error_rate": 0.018,
		"complaint_rate": 0.004,
		"latency_ms": 420.0,
		"risk_score": 35
	}
	stage_history.clear()
	print("CanarySimulatorService: state reset")


## Initialize state from external data (e.g. quest dialogue)
func init_state(base: Dictionary) -> void:
	reset_state()
	for key in base:
		if current_state.has(key):
			current_state[key] = base[key]


## Run the next stage (current_percentage → next_percentage)
## Returns result Dictionary with recommendation and predictions
func proceed_to_stage(next_pct: int = -1) -> Dictionary:
	if not _loaded or _simulator == null:
		return _empty_result()

	# Build input from current_state
	var input := current_state.duplicate()
	if next_pct > 0:
		input["next_percentage"] = next_pct

	var result: Dictionary = _simulator.simulate_stage(input)

	# Save history before updating state
	stage_history.append(current_state.duplicate())

	# Apply deltas to current state metrics
	var s_delta: int = int(result.get("stability_delta", 0))
	var c_delta: int = int(result.get("compliance_delta", 0))
	var p_delta: int = int(result.get("parent_trust_delta", 0))

	current_state["current_percentage"] = int(input["next_percentage"])
	current_state["stability"] = clamp(float(current_state["stability"]) + s_delta, 0.0, 100.0)
	current_state["compliance"] = clamp(float(current_state["compliance"]) + c_delta, 0.0, 100.0)
	current_state["parent_trust"] = clamp(float(current_state["parent_trust"]) + p_delta, 0.0, 100.0)
	current_state["error_rate"] = float(result.get("predicted_error_rate", 0.0))
	current_state["complaint_rate"] = float(result.get("predicted_complaint_rate", 0.0))

	# Prepare next stage
	current_state["next_percentage"] = _next_stage(int(current_state["current_percentage"]))
	current_state["risk_score"] = _calculate_risk()

	# Emit signals
	var recommendation: String = str(result.get("recommendation", "continue"))
	stage_completed.emit(recommendation, result)

	var warnings: PackedStringArray = result.get("triggered_warnings", [])
	for w in warnings:
		warning_triggered.emit(str(w))

	return result


## Evaluate a proposed rollout without executing
func evaluate(next_pct: int) -> Dictionary:
	if not _loaded or _simulator == null:
		return _empty_result()
	return _simulator.evaluate_rollout(current_state, next_pct)


## Execute rollback to previous safe stage
func execute_rollback() -> Dictionary:
	if not _loaded or _simulator == null:
		return _empty_result()

	var from_pct: int = int(current_state["current_percentage"])

	# Try native rollback first
	var new_state: Dictionary = _simulator.rollback(current_state)

	# If history available, try restoring from it
	if stage_history.size() > 0:
		var prev: Dictionary = stage_history.pop_back()
		new_state["stability"] = clamp(float(prev.get("stability", 68)) - 2.0, 0.0, 100.0)
		new_state["compliance"] = clamp(float(prev.get("compliance", 74)) - 1.0, 0.0, 100.0)
		new_state["parent_trust"] = clamp(float(prev.get("parent_trust", 61)) - 1.0, 0.0, 100.0)

	# Update current state
	for key in new_state:
		if current_state.has(key):
			current_state[key] = new_state[key]

	current_state["next_percentage"] = _next_stage(int(new_state["current_percentage"]))
	current_state["risk_score"] = _calculate_risk()

	var to_pct: int = int(new_state["current_percentage"])
	rollback_executed.emit(from_pct, to_pct)

	return new_state


## Check if direct full release would trigger high risk
func check_full_release_risk() -> Dictionary:
	return evaluate(100)


## Get a human-readable recommendation text
func get_recommendation_text(result: Dictionary) -> String:
	var rec: String = str(result.get("recommendation", "continue"))
	match rec:
		"continue":
			return "可以继续发布 —— 指标在安全范围内"
		"pause":
			return "建议暂停 —— 需要调查指标异常"
		"rollback":
			return "必须回滚 —— 风险过高，立即回退"
		_:
			return "未知状态"


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _next_stage(current_pct: int) -> int:
	match current_pct:
		0: return 1
		1: return 5
		5: return 25
		25: return 50
		50: return 100
		100: return 100
		_: return 1


func _calculate_risk() -> int:
	var err: float = float(current_state["error_rate"])
	var comp: float = float(current_state["complaint_rate"])
	var lat: float = float(current_state["latency_ms"])
	var pct: int = int(current_state["current_percentage"])

	var risk := 0
	if err > 0.05: risk += 25
	elif err > 0.03: risk += 15
	elif err > 0.02: risk += 5

	if comp > 0.015: risk += 20
	elif comp > 0.008: risk += 10

	if lat > 600: risk += 15
	elif lat > 400: risk += 8

	if pct >= 50: risk += 10
	if pct >= 100: risk += 5

	return risk


func _empty_result() -> Dictionary:
	return {
		"recommendation": "continue",
		"predicted_error_rate": 0.0,
		"predicted_complaint_rate": 0.0,
		"stability_delta": 0,
		"compliance_delta": 0,
		"parent_trust_delta": 0,
		"triggered_warnings": PackedStringArray()
	}
