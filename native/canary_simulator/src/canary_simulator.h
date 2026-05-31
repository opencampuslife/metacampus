#ifndef CANARY_SIMULATOR_H
#define CANARY_SIMULATOR_H

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

class CanarySimulator : public Object {
	GDCLASS(CanarySimulator, Object)

private:
	double _predict_error_rate(double current_error, int current_pct, int next_pct);
	double _predict_complaint_rate(double current_complaint, int current_pct, int next_pct);

	void _compute_metric_deltas(int current_pct, int next_pct,
			double predicted_error, double predicted_complaint,
			double current_error, double current_complaint,
			int &stability_delta, int &compliance_delta, int &parent_trust_delta);

	String _determine_recommendation(int current_pct, int next_pct,
			double predicted_error, double predicted_complaint,
			int stability_delta, int compliance_delta);

	PackedStringArray _collect_warnings(int current_pct, int next_pct,
			double predicted_error, double predicted_complaint,
			double current_error, double latency_ms, int risk_score);

	int _rollback_percentage(int current_pct);

protected:
	static void _bind_methods();

public:
	CanarySimulator();
	~CanarySimulator();

	Dictionary simulate_stage(const Dictionary &input);
	Dictionary evaluate_rollout(const Dictionary &state, int next_percentage);
	Dictionary rollback(const Dictionary &state);
};

} // namespace godot

#endif // CANARY_SIMULATOR_H
