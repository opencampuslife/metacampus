#ifndef RISK_SCORER_H
#define RISK_SCORER_H

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/classes/file_access.hpp>

namespace godot {

class RiskScorer : public Object {
    GDCLASS(RiskScorer, Object)

private:
    struct RiskRule {
        String id;
        Array keywords;
        String scenario;
        int risk_score = 0;
        String risk_level = "low";
        String recommended_action = "allow";
        String triggered_rule;
        int requires_citation_min = -1;
        int min_answer_length = -1;
        int compliance_delta = 0;
        int parent_trust_delta = 0;
        int stability_delta = 0;
    };

    Vector<RiskRule> rules;
    bool rules_loaded = false;

    bool load_rules_from_json(String path) {
        rules.clear();

        if (!FileAccess::file_exists(path)) {
            UtilityFunctions::push_error("Risk rules file not found: ", path);
            return false;
        }

        Ref<FileAccess> file = FileAccess::open(path, FileAccess::READ);
        if (file.is_null()) {
            UtilityFunctions::push_error("Failed to open risk rules file: ", path);
            return false;
        }

        String text = file->get_as_text();
        file.unref();

        Ref<JSON> json;
        json.instantiate();
        Error err = json->parse(text);

        if (err != OK) {
            UtilityFunctions::push_error("Failed to parse risk rules JSON at line: ",
                                         json->get_error_line());
            return false;
        }

        Variant data = json->get_data();
        if (data.get_type() != Variant::DICTIONARY) {
            UtilityFunctions::push_error("Risk rules root must be Dictionary.");
            return false;
        }

        Dictionary root = data;
        Array rule_array = root.get("rules", Array());

        for (int i = 0; i < rule_array.size(); i++) {
            if (rule_array[i].get_type() != Variant::DICTIONARY) {
                continue;
            }

            Dictionary item = rule_array[i];
            RiskRule rule;

            rule.id = item.get("id", "");
            rule.keywords = item.get("keywords", Array());
            rule.scenario = item.get("scenario", "");
            rule.risk_score = int(item.get("risk_score", 0));
            rule.risk_level = item.get("risk_level", "low");
            rule.recommended_action = item.get("recommended_action", "allow");
            rule.triggered_rule = item.get("triggered_rule", rule.id);
            rule.requires_citation_min = int(item.get("requires_citation_min", -1));
            rule.min_answer_length = int(item.get("min_answer_length", -1));

            Dictionary effects = item.get("metric_effects", Dictionary());
            rule.compliance_delta = int(effects.get("compliance_delta", 0));
            rule.parent_trust_delta = int(effects.get("parent_trust_delta", 0));
            rule.stability_delta = int(effects.get("stability_delta", 0));

            rules.append(rule);
        }

        UtilityFunctions::print("RiskScorer: loaded ", int(rules.size()), " rules from JSON");
        return rules.size() > 0;
    }

public:
    RiskScorer() {
        rules_loaded = load_rules_from_json("res://data/rules/risk_rules.json");
    }

    ~RiskScorer() {}

    bool load_rules(String path = "res://data/rules/risk_rules.json") {
        rules_loaded = load_rules_from_json(path);
        return rules_loaded;
    }

    int get_rule_count() const {
        return rules.size();
    }

    PackedStringArray get_rule_ids() const {
        PackedStringArray ids;
        for (int i = 0; i < rules.size(); i++) {
            ids.append(rules[i].id);
        }
        return ids;
    }

    Dictionary evaluate_text(const String& question, const String& answer,
                            const Dictionary& context);

    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("load_rules", "path"), &RiskScorer::load_rules);
        ClassDB::bind_method(D_METHOD("get_rule_count"), &RiskScorer::get_rule_count);
        ClassDB::bind_method(D_METHOD("get_rule_ids"), &RiskScorer::get_rule_ids);
        ClassDB::bind_method(D_METHOD("evaluate_text", "question", "answer", "context"),
                            &RiskScorer::evaluate_text);
    }
};

} // namespace godot

#endif // RISK_SCORER_H