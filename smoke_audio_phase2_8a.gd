extends Node

## Phase 2.8A Audio System Smoke Test
## 测试：AudioManager Autoload + audio_events.json + AudioEventBinder

func _ready() -> void:
	print("=== Phase 2.8A Audio Smoke ===")
	_smoke_audio_manager()
	_smoke_audio_events_json()
	_smoke_audio_binder()
	# 验证 UI 面板注册
	_smoke_ui_bindings()
	print("=== Smoke done — quitting ===")
	_start_exit_timer()

func _start_exit_timer():
	var t = Timer.new()
	t.wait_time = 1.5
	t.one_shot = true
	t.timeout.connect(func(): get_tree().quit())
	add_child(t)
	t.start()

func _smoke_audio_manager() -> void:
	var am = get_node("/root/AudioManager")
	if am == null:
		print("[FAIL] AudioManager Autoload not found")
		return

	print("[PASS] AudioManager Autoload found")

	# 检查方法存在
	var methods = ["play_event", "play_npc_voice", "play_interact_prompt",
				   "play_dialog_open", "play_quest_start", "play_quest_complete",
				   "set_master_volume", "validate_audio_events"]
	for m in methods:
		if not am.has_method(m):
			print("[FAIL] AudioManager missing method: " + m)
		else:
			print("[PASS] AudioManager." + m + " exists")

	# 测试 play_event（DEBUG_AUDIO=true，会打印日志）
	am.play_event("ui_click")
	am.play_event("quest_start")
	am.play_event("quest_complete")
	am.play_event("risk_warning")
	am.play_event("dashboard_open")
	am.play_event("quest_board_open")
	# 测试未知事件（不崩溃）
	am.play_npc_voice("principal", "greeting")

func _smoke_audio_events_json() -> void:
	var path = "res://data/audio/audio_events.json"
	if not FileAccess.file_exists(path):
		print("[FAIL] audio_events.json not found")
		return

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		print("[FAIL] Cannot open audio_events.json")
		return

	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		print("[FAIL] JSON parse error")
		return

	var data = json.data
	if not data.has("events"):
		print("[FAIL] missing 'events' key")
		return

	var events = data["events"]
	print("[PASS] audio_events.json: " + str(events.size()) + " events")

	# 检查所有 event 都有 path
	var broken = []
	for e in events.keys():
		if not events[e].has("path") or str(events[e]["path"]).is_empty():
			broken.append(e)
	if broken:
		print("[WARN] Events missing path: " + str(broken))
	else:
		print("[PASS] All events have valid path field")

func _smoke_audio_binder() -> void:
	var binder = get_node_or_null("AudioEventBinder")
	if binder == null:
		print("[FAIL] AudioEventBinder not in scene")
		return
	print("[PASS] AudioEventBinder node found")

func _smoke_ui_bindings() -> void:
	# 检查所有 panel 是否存在
	var panels = ["Dashboard", "QuestBoard", "SettlementReportPanel",
				  "DebugCommandPanel", "LocationCalibrationPanel"]
	var found = 0
	for p in panels:
		var node = get_node_or_null("^" + p)
		if node != null:
			found += 1
			print("[PASS] Panel registered: " + p)
		else:
			print("[WARN] Panel not found: " + p)
	print("[INFO] Panels registered: %d/%d" % [found, panels.size()])