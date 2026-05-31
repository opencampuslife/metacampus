#include "register_types.h"
#include "canary_simulator.h"

namespace godot {

void initialize_canary_simulator_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
    ClassDB::register_class<CanarySimulator>();
}

void uninitialize_canary_simulator_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
}

}
