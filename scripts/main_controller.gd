extends Node2D
class_name MainController

## 游戏主控制器
## 初始化所有系统、编排场景、管理游戏主循环

func _ready() -> void:
	print("[MainController] Initializing game systems...")
	_wire_autoloads()
	_start_game()
	print("[MainController] Game started — Day 1, 08:00")

# ── Initialization ──────────────────────────────────────────────

func _wire_autoloads() -> void:
	var tm = get_node_or_null("/root/TimeManager")
	var qm = get_node_or_null("/root/QuestManager")
	if tm and qm:
		tm.day_changed.connect(_on_day_changed)
		tm.day_ended.connect(_on_day_ended)

	var mm = get_node_or_null("/root/MetricManager")
	if mm:
		mm.metric_danger.connect(_on_metric_danger)

	# Time events (future: random events, NPC schedule updates)

func _start_game() -> void:
	var tm = get_node_or_null("/root/TimeManager")
	if tm:
		tm.start()

	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_music("res://assets/audio/music/campus_theme.ogg")

# ── Callbacks ───────────────────────────────────────────────────

func _on_day_changed(day: int) -> void:
	print("[MainController] Day changed to %d" % day)
	var qm = get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("refresh_daily_quests"):
		qm.refresh_daily_quests()

func _on_day_ended(day: int) -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("auto_save"):
		sm.auto_save()

func _on_metric_danger(metric_id: String, value: int) -> void:
	if value <= 20:
		var gp = get_node_or_null("GameOverPanel")
		if gp and gp.has_method("show_ending"):
			gp.show_ending(metric_id)

# ── Pause / Resume ──────────────────────────────────────────────

func pause_game() -> void:
	get_tree().paused = true

func resume_game() -> void:
	get_tree().paused = false
