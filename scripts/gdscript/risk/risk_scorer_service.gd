extends Node

## RiskScorerService - Autoload service for RiskScorer GDExtension
## Manages native RiskScorer object lifecycle and provides evaluation API

var _scorer: RiskScorer = null
var _loaded := false

func _ready() -> void:
	_scorer = ClassDB.instantiate("RiskScorer")
	if _scorer != null:
		_loaded = _scorer.load_rules("res://data/rules/risk_rules.json")
		if not _loaded:
			push_error("RiskScorerService: failed to load risk_rules.json")
		else:
			print("RiskScorerService: loaded ", get_rule_count(), " rules")
	else:
		push_error("RiskScorerService: failed to instantiate RiskScorer")


## Evaluate question+answer against risk rules
func evaluate(question: String, answer: String, context: Dictionary = {}) -> Dictionary:
	if not _loaded or _scorer == null:
		return _empty_result()

	return _scorer.evaluate_text(question, answer, context)


## Check if rules are loaded
func is_loaded() -> bool:
	return _loaded


## Get rule count from loaded rules
func get_rule_count() -> int:
	if _scorer == null:
		return 0
	return _scorer.get_rule_count()


## Get all rule IDs
func get_rule_ids() -> Array:
	if _scorer == null:
		return []
	return Array(_scorer.get_rule_ids())


## Apply metric effects based on player's action
func apply_action_effects(result: Dictionary, action: String) -> Dictionary:
	var compliance_delta: int = int(result.get("compliance_delta", 0))
	var parent_trust_delta: int = int(result.get("parent_trust_delta", 0))
	var stability_delta: int = int(result.get("stability_delta", 0))

	var recommended_action: String = str(result.get("recommended_action", "allow"))
	var risk_level: String = str(result.get("risk_level", "low"))

	# Player ignored block warning - apply extra penalty
	if recommended_action == "block" and action == "send_anyway":
		compliance_delta = int(compliance_delta * 1.5)
		parent_trust_delta = int(parent_trust_delta * 1.2)
		print("RiskScorerService: player ignored block warning, applying 1.5x penalty")

	# Player modified and sent - halve penalty
	elif recommended_action == "revise" and action == "modified_send":
		compliance_delta /= 2
		parent_trust_delta /= 2
		stability_delta /= 2
		print("RiskScorerService: player modified content, halving penalty")

	# Player escalated to human
	elif recommended_action == "escalate" or action == "escalate":
		compliance_delta += 2
		parent_trust_delta += 1
		stability_delta -= 2
		print("RiskScorerService: player escalated to human")

	return {
		"compliance_delta": compliance_delta,
		"parent_trust_delta": parent_trust_delta,
		"stability_delta": stability_delta
	}


func _empty_result() -> Dictionary:
	return {
		"risk_score": 0,
		"risk_level": "low",
		"triggered_rules": PackedStringArray(),
		"recommended_action": "allow",
		"compliance_delta": 0,
		"parent_trust_delta": 0,
		"stability_delta": 0
	}