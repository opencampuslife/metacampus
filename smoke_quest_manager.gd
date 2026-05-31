extends Node

## Verify QuestManager GDScript stub is functional
func _ready() -> void:
	print("=== QuestManager Smoke ===")
	_check_autoload()
	_check_signals()
	_check_methods()
	_check_quest_data()
	_check_audio_wiring()
	print("=== Smoke done ===")
	_start_exit_timer()

func _start_exit_timer():
	var t = Timer.new()
	t.wait_time = 1.0
	t.one_shot = true
	t.timeout.connect(func(): get_tree().quit())
	add_child(t)
	t.start()

func _check_autoload() -> void:
	var qm = get_node("/root/QuestManager")
	if qm == null:
		print("[FAIL] QuestManager Autoload not found")
		return
	print("[PASS] QuestManager Autoload found")
	print("  Quest count: " + str(qm.get("_all_quests", {}).size()))

func _check_signals() -> void:
	var qm = get_node("/root/QuestManager")
	var signals = ["quest_available", "quest_started", "quest_updated",
				   "quest_completed", "quest_failed", "quest_expired"]
	for s in signals:
		if qm.has_signal(s):
			print("[PASS] Signal: " + s)
		else:
			print("[FAIL] Missing signal: " + s)

func _check_methods() -> void:
	var qm = get_node("/root/QuestManager")
	var methods = ["start_quest", "complete_quest", "fail_quest",
				  "get_quest_status", "get_quests_for_npc", "get_active_quests"]
	for m in methods:
		if qm.has_method(m):
			print("[PASS] Method: " + m)
		else:
			print("[FAIL] Missing method: " + m)

func _check_quest_data() -> void:
	var qm = get_node("/root/QuestManager")
	var quests = qm.get("_all_quests", {})
	if quests.size() > 0:
		print("[PASS] Quest data loaded: %d quests" % quests.size())
		var first_id = quests.keys()[0]
		var first_q = quests[first_id]
		print("  Sample: " + first_id + " - " + str(first_q.get("title", "")))
	else:
		print("[FAIL] No quest data loaded")

func _check_audio_wiring() -> void:
	var am = get_node("/root/AudioManager")
	var binder = get_node_or_null("/root/Main/AudioEventBinder")
	if binder == null:
		binder = get_node_or_null("/root/Main/AudioEventBinder")
		if binder == null:
			print("[INFO] AudioEventBinder not found via root path")
			return
	print("[PASS] AudioEventBinder found in scene")
	# Manually trigger quest signals and check audio
	print("[INFO] Triggering quest signals...")
	qm = get_node("/root/QuestManager")
	qm.quest_started.connect(_on_qs)
	qm.quest_completed.connect(_on_qc)
	qm.quest_failed.connect(_on_qf)
	# Simulate quest events
	qm.start_quest("daily_admission_001")

func _on_qs(qid: String) -> void:
	print("[Audio] quest_started signal fired: " + qid)

func _on_qc(qid: String) -> void:
	print("[Audio] quest_completed signal fired: " + qid)

func _on_qf(qid: String) -> void:
	print("[Audio] quest_failed signal fired: " + qid)