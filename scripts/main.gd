extends Node2D

func _ready():
	print("=== Phase 2.8A Smoke ===")
	_smoke()
	print("=== done ===")
	get_tree().quit()

func _smoke() -> void:
	var am = get_node_or_null("/root/AudioManager")
	var qm = get_node_or_null("/root/QuestManager")
	if not am or not qm:
		print("[FAIL] Autoloads")
		return
	print("[PASS] AudioManager events=%d" % am._events.size())
	print("[PASS] QuestManager quests=%d" % qm._all_quests.size())
	am.play_event("ui_click")
	am.play_event("quest_start")
	am.play_event("quest_complete")
	am.play_event("risk_warning")
	am.play_event("dashboard_open")
	am.play_npc_voice("principal", "greeting")
	am.validate_audio_events()
	var binder = get_node_or_null("AudioEventBinder")
	if binder: print("[PASS] AudioEventBinder")
	var ns = load("res://scenes/NPCs/NpcScene.tscn")
	if ns and ns.instantiate():
		print("[PASS] NpcScene.tscn")