extends Node


## 随机事件管理器
## 根据时间阶段按概率触发随机事件，提供玩家选择

signal event_triggered(event_id: String, event_data: Dictionary)
signal event_resolved(event_id: String, choice_index: int)
signal event_expired(event_id: String)

const EVENTS_PATH := "res://data/random_events.json"

var _all_events: Dictionary = {}  # event_id → event data
var _active_events: Array = []    # currently active events
var _triggered_events: Array = [] # events triggered this day (prevent repeat)
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("random_event_manager")
	_rng.randomize()
	_load_events()

	var tm = get_node_or_null("/root/TimeManager")
	if tm:
		tm.phase_changed.connect(_on_phase_changed)
		tm.day_changed.connect(_on_day_changed)

	print("[RandomEventManager] Ready — %d events" % _all_events.size())

# ── Public API ──────────────────────────────────────────────────

func get_active_events() -> Array:
	return _active_events.duplicate()

func resolve_event(event_id: String, choice_index: int) -> bool:
	var idx = -1
	for i in _active_events.size():
		if _active_events[i].get("event_id") == event_id:
			idx = i
			break
	if idx < 0:
		return false

	var evt = _active_events[idx]
	var choices = evt.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return false

	var choice = choices[choice_index]
	_apply_choice_effects(choice)
	_active_events.remove_at(idx)
	event_resolved.emit(event_id, choice_index)
	return true

func dismiss_event(event_id: String) -> void:
	for i in _active_events.size():
		if _active_events[i].get("event_id") == event_id:
			_active_events.remove_at(i)
			event_expired.emit(event_id)
			break

# ── Private ─────────────────────────────────────────────────────

func _load_events() -> void:
	if not FileAccess.file_exists(EVENTS_PATH):
		push_warning("[RandomEventManager] random_events.json not found")
		return

	var file = FileAccess.open(EVENTS_PATH, FileAccess.READ)
	if not file:
		return

	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return

	var data = json.data
	for evt in data.get("random_events", []):
		var eid = evt.get("event_id", "")
		if not eid.is_empty():
			_all_events[eid] = evt

func _on_phase_changed(phase: String) -> void:
	_try_trigger_events(phase)

func _on_day_changed(_day: int) -> void:
	_triggered_events.clear()

func _try_trigger_events(phase: String) -> void:
	for eid in _all_events.keys():
		var evt = _all_events[eid]

		# Already triggered this day?
		if eid in _triggered_events:
			continue

		# Check phase
		var phases = evt.get("trigger_phase", [])
		if not phase in phases:
			continue

		# Probability check
		var prob = evt.get("probability", 0.0)
		if _rng.randf() > prob:
			continue

		# Check if already active
		var already_active = false
		for ae in _active_events:
			if ae.get("event_id") == eid:
				already_active = true
				break
		if already_active:
			continue

		_triggered_events.append(eid)
		_active_events.append(evt.duplicate(true))
		event_triggered.emit(eid, evt)
		print("[RandomEventManager] Event triggered: %s (%s)" % [evt.get("name", eid), phase])

func _apply_choice_effects(choice: Dictionary) -> void:
	# Resource costs
	var ap_cost = choice.get("ap_cost", 0)
	var compute_cost = choice.get("compute_cost", 0)
	var rm = get_node_or_null("/root/ResourceManager")
	if rm:
		if ap_cost > 0:
			rm.modify("ap", -ap_cost)
		if compute_cost > 0:
			rm.modify("compute", -compute_cost)

	# Metric effects
	var effects = choice.get("effects", {})
	var mm = get_node_or_null("/root/MetricManager")
	if mm:
		mm.apply_effects(effects)

	# Skill XP
	for key in effects.keys():
		if key.ends_with("_xp"):
			var skill_id = key.replace("_xp", "")
			var sm = get_node_or_null("/root/SkillManager")
			if sm:
				sm.add_xp(skill_id, effects[key])

	# Audio
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_event("ui_click")
