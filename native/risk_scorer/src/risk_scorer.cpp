#include "risk_scorer.h"
#include <godot_cpp/core/method_bind.hpp>

namespace godot {

using namespace godot;

Dictionary RiskScorer::evaluate_text(const String& p_question,
                                       const String& p_answer,
                                       const Dictionary& p_context) {
    Dictionary result;

    if (rules.size() == 0) {
        if (!load_rules()) {
            return result;
        }
    }

    String combined = p_question + String(" ") + p_answer;
    String scenario = p_context.get("scenario", "");
    int citation_count = int(p_context.get("citation_count", 0));

    int best_score = 0;
    String best_level = "low";
    String best_action = "allow";
    int compliance_delta = 0;
    int parent_trust_delta = 0;
    int stability_delta = 0;

    PackedStringArray triggered_rules;

    for (int ri = 0; ri < rules.size(); ri++) {
        const RiskRule& rule = rules[ri];
        bool matched = false;

        // 1. keyword rules
        if (!matched && rule.keywords.size() > 0) {
            for (int ki = 0; ki < rule.keywords.size(); ki++) {
                String keyword = rule.keywords[ki];
                if (keyword.is_empty()) {
                    continue;
                }
                if (combined.contains(keyword)) {
                    matched = true;
                    break;
                }
            }
        }

        // 2. scenario + citation rule
        if (!matched && !rule.scenario.is_empty()) {
            if (rule.scenario == scenario && rule.requires_citation_min >= 0) {
                if (citation_count < rule.requires_citation_min) {
                    matched = true;
                }
            }
        }

        // 3. short answer fallback
        if (!matched && rule.min_answer_length > 0) {
            if (p_answer.length() < rule.min_answer_length) {
                matched = true;
            }
        }

        if (!matched) {
            continue;
        }

        triggered_rules.append(rule.triggered_rule);

        if (rule.risk_score > best_score) {
            best_score = rule.risk_score;
            best_level = rule.risk_level;
            best_action = rule.recommended_action;
            compliance_delta = rule.compliance_delta;
            parent_trust_delta = rule.parent_trust_delta;
            stability_delta = rule.stability_delta;
        }
    }

    result["risk_score"] = best_score;
    result["risk_level"] = best_level;
    result["triggered_rules"] = triggered_rules;
    result["recommended_action"] = best_action;
    result["compliance_delta"] = compliance_delta;
    result["parent_trust_delta"] = parent_trust_delta;
    result["stability_delta"] = stability_delta;

    return result;
}

} // namespace godot