#include "canary_simulator.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/method_bind.hpp>

namespace godot {

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

double CanarySimulator::_predict_error_rate(double current_error, int current_pct, int next_pct) {
	if (next_pct <= current_pct) {
		return current_error;
	}

	int jump = next_pct - current_pct;
	// Logarithmic scaling: each 25% step roughly doubles the error growth rate.
	double scale = double(next_pct) / Math::max(current_pct, 1);
	double log_factor = Math::log(scale + 1.0) / Math::log(2.0); // roughly 1→0, 2→1, 5→2.3

	// Base increase proportional to log factor and current error
	double base_increase = current_error * 0.4 * log_factor;

	// Jump penalty: 0.015 per 25% increment, capped at 0.12
	double jump_penalty = (double(jump) / 25.0) * 0.015;
	jump_penalty = Math::min(jump_penalty, 0.12);

	double predicted = current_error + base_increase + jump_penalty;
	return Math::clamp(predicted, 0.0, 0.6);
}

double CanarySimulator::_predict_complaint_rate(double current_complaint, int current_pct, int next_pct) {
	if (next_pct <= current_pct) {
		return current_complaint;
	}

	int jump = next_pct - current_pct;
	double scale = double(next_pct) / Math::max(current_pct, 1);
	double log_factor = Math::log(scale + 1.0) / Math::log(2.0);

	double base_increase = current_complaint * 0.3 * log_factor;
	double jump_penalty = (double(jump) / 25.0) * 0.006;
	jump_penalty = Math::min(jump_penalty, 0.05);

	double predicted = current_complaint + base_increase + jump_penalty;
	return Math::clamp(predicted, 0.0, 0.3);
}

void CanarySimulator::_compute_metric_deltas(int current_pct, int next_pct,
		double predicted_error, double predicted_complaint,
		double current_error, double current_complaint,
		int &stability_delta, int &compliance_delta, int &parent_trust_delta) {

	int jump = next_pct - current_pct;
	if (jump <= 0) {
		stability_delta = 0;
		compliance_delta = 0;
		parent_trust_delta = 0;
		return;
	}

	double jump_factor = double(jump) / 25.0; // 1 per stage

	// Error/climb spikes reduce stability more
	double error_spike = Math::max(0.0, predicted_error - current_error);
	double complaint_spike = Math::max(0.0, predicted_complaint - current_complaint);

	// Stability: most sensitive to error spikes
	stability_delta = -int(Math::ceil(jump_factor * 4.0 + error_spike * 50.0));

	// Compliance: sensitive to error + complaint
	compliance_delta = -int(Math::ceil(jump_factor * 2.5 + (error_spike + complaint_spike) * 30.0));

	// Parent trust: moderate sensitivity
	parent_trust_delta = -int(Math::ceil(jump_factor * 1.8 + complaint_spike * 40.0));

	// Full release penalty (100% directly from <=25%)
	if (next_pct >= 100 && current_pct <= 25) {
		stability_delta = int(stability_delta * 3);
		compliance_delta = int(compliance_delta * 3);
		parent_trust_delta = int(parent_trust_delta * 3);
	}

	// Ensure minimum damage for any jump
	if (stability_delta > -1) stability_delta = -1;
	if (compliance_delta > -1) compliance_delta = 0;
	if (parent_trust_delta > -1) parent_trust_delta = 0;
}

String CanarySimulator::_determine_recommendation(int current_pct, int next_pct,
		double predicted_error, double predicted_complaint,
		int stability_delta, int compliance_delta) {

	// Full release from low percentage = immediate rollback
	if (next_pct >= 100 && current_pct <= 25) {
		return "rollback";
	}

	// High error rate
	if (predicted_error > 0.08) {
		return "rollback";
	}

	// Severe delta
	if (stability_delta <= -10 || compliance_delta <= -8) {
		return "rollback";
	}

	// Moderate risk — pause and investigate
	if (predicted_error > 0.04 || stability_delta <= -5 || compliance_delta <= -4) {
		return "pause";
	}

	return "continue";
}

PackedStringArray CanarySimulator::_collect_warnings(int current_pct, int next_pct,
		double predicted_error, double predicted_complaint,
		double current_error, double latency_ms, int risk_score) {

	PackedStringArray warnings;

	int jump = next_pct - current_pct;
	if (jump <= 0) {
		return warnings;
	}

	// Error rate increase
	if (predicted_error > current_error * 2.0) {
		warnings.append("error_rate_spike");
	}
	if (predicted_error > 0.05) {
		warnings.append("high_error_rate");
	}

	// Complaint rate increase
	if (predicted_complaint > 0.01) {
		warnings.append("complaint_rate_increase");
	}

	// Latency increase
	if (latency_ms > 500.0 || (next_pct >= 50 && latency_ms > 300.0)) {
		warnings.append("latency_increase");
	}

	// Big jump
	if (jump >= 50) {
		warnings.append("large_traffic_jump");
	}

	// Full release
	if (next_pct >= 100 && current_pct <= 25) {
		warnings.append("full_release_risk");
	}

	// High risk score
	if (risk_score >= 50) {
		warnings.append("high_risk_score");
	}

	// Percentage-specific warnings
	if (next_pct == 100) {
		warnings.append("full_production");
	}

	return warnings;
}

int CanarySimulator::_rollback_percentage(int current_pct) {
	// Rollback to roughly half the current percentage
	// Follows standard canary rollback pattern: 100→50, 50→25, 25→5, 5→1
	if (current_pct >= 100) return 50;
	if (current_pct >= 50) return 25;
	if (current_pct >= 25) return 5;
	if (current_pct >= 5) return 1;
	return 0; // fully off
}

// ---------------------------------------------------------------------------
// Bind methods
// ---------------------------------------------------------------------------

void CanarySimulator::_bind_methods() {
	ClassDB::bind_method(D_METHOD("simulate_stage", "input"), &CanarySimulator::simulate_stage);
	ClassDB::bind_method(D_METHOD("evaluate_rollout", "state", "next_percentage"),
			&CanarySimulator::evaluate_rollout);
	ClassDB::bind_method(D_METHOD("rollback", "state"), &CanarySimulator::rollback);
}

// ---------------------------------------------------------------------------
// Constructor / Destructor
// ---------------------------------------------------------------------------

CanarySimulator::CanarySimulator() {}
CanarySimulator::~CanarySimulator() {}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

Dictionary CanarySimulator::simulate_stage(const Dictionary &input) {
	Dictionary result;

	int current_pct = int(input.get("current_percentage", 0));
	int next_pct = int(input.get("next_percentage", 0));
	double stability = double(input.get("stability", 60));
	double compliance = double(input.get("compliance", 70));
	double parent_trust = double(input.get("parent_trust", 50));
	double error_rate = double(input.get("error_rate", 0.0));
	double complaint_rate = double(input.get("complaint_rate", 0.0));
	double latency_ms = double(input.get("latency_ms", 200));
	int risk_score = int(input.get("risk_score", 0));

	if (next_pct <= current_pct) {
		result["recommendation"] = "continue";
		result["predicted_error_rate"] = error_rate;
		result["predicted_complaint_rate"] = complaint_rate;
		result["stability_delta"] = 0;
		result["compliance_delta"] = 0;
		result["parent_trust_delta"] = 0;
		result["triggered_warnings"] = PackedStringArray();
		return result;
	}

	double predicted_error = _predict_error_rate(error_rate, current_pct, next_pct);
	double predicted_complaint = _predict_complaint_rate(complaint_rate, current_pct, next_pct);

	int s_delta = 0, c_delta = 0, p_delta = 0;
	_compute_metric_deltas(current_pct, next_pct,
			predicted_error, predicted_complaint,
			error_rate, complaint_rate,
			s_delta, c_delta, p_delta);

	String recommendation = _determine_recommendation(current_pct, next_pct,
			predicted_error, predicted_complaint, s_delta, c_delta);

	PackedStringArray warnings = _collect_warnings(current_pct, next_pct,
			predicted_error, predicted_complaint,
			error_rate, latency_ms, risk_score);

	result["recommendation"] = recommendation;
	result["predicted_error_rate"] = predicted_error;
	result["predicted_complaint_rate"] = predicted_complaint;
	result["stability_delta"] = s_delta;
	result["compliance_delta"] = c_delta;
	result["parent_trust_delta"] = p_delta;
	result["triggered_warnings"] = warnings;

	return result;
}

Dictionary CanarySimulator::evaluate_rollout(const Dictionary &state, int next_pct) {
	// evaluate_rollout uses the same logic as simulate_stage,
	// but wraps state as the input dictionary
	Dictionary input = state.duplicate();
	input["next_percentage"] = next_pct;
	return simulate_stage(input);
}

Dictionary CanarySimulator::rollback(const Dictionary &state) {
	int current_pct = int(state.get("current_percentage", 0));
	double stability = double(state.get("stability", 60));
	double compliance = double(state.get("compliance", 70));
	double parent_trust = double(state.get("parent_trust", 50));
	double error_rate = double(state.get("error_rate", 0.0));
	double complaint_rate = double(state.get("complaint_rate", 0.0));
	double latency_ms = double(state.get("latency_ms", 200));
	int risk_score = int(state.get("risk_score", 0));

	int rollback_to = _rollback_percentage(current_pct);

	// Partial metric recovery — rollback restores about 40-60% of what was lost
	// But there is permanent scarring (trust lost, etc.)
	double stability_recovery = 3;
	double compliance_recovery = 2;
	double trust_recovery = 1;

	Dictionary new_state;
	new_state["current_percentage"] = rollback_to;
	new_state["next_percentage"] = rollback_to; // paused after rollback
	new_state["stability"] = Math::clamp(stability + stability_recovery, 0.0, 100.0);
	new_state["compliance"] = Math::clamp(compliance + compliance_recovery, 0.0, 100.0);
	new_state["parent_trust"] = Math::clamp(parent_trust + trust_recovery, 0.0, 100.0);

	// Error/complaint rates partially reset to pre-rollback levels
	double error_recovery = error_rate * 0.3; // 70% reduction
	double complaint_recovery = complaint_rate * 0.3;

	new_state["error_rate"] = Math::max(error_rate - error_recovery, 0.0);
	new_state["complaint_rate"] = Math::max(complaint_rate - complaint_recovery, 0.0);
	new_state["latency_ms"] = latency_ms * 0.85; // 15% latency improvement
	new_state["risk_score"] = Math::max(risk_score - 10, 0);

	// Warnings about the rollback
	PackedStringArray rollback_warnings;
	rollback_warnings.append("rollback_executed");
	if (current_pct >= 50) {
		rollback_warnings.append("significant_rollback");
	}
	new_state["triggered_warnings"] = rollback_warnings;

	return new_state;
}

} // namespace godot
