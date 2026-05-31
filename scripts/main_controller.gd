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
	# TimeManager → QuestManager (daily refresh)
	var tm = get_node_or_null("/root/TimeManager")
	var qm = get_node_or_null("/root/QuestManager")
	if tm and qm:
		tm.day_changed.connect(_on_day_changed)

	# MetricManager → dashboard (already wired in dashboard.gd via group)

	# Time events (future: random events, NPC schedule updates)

func _start_game() -> void:
	var tm = get_node_or_null("/root/TimeManager")
	if tm:
		tm.start()

# ── Callbacks ───────────────────────────────────────────────────

func _on_day_changed(day: int) -> void:
	print("[MainController] Day changed to %d" % day)
	var qm = get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("refresh_daily_quests"):
		qm.refresh_daily_quests()

# ── Pause / Resume ──────────────────────────────────────────────

func pause_game() -> void:
	get_tree().paused = true

func resume_game() -> void:
	get_tree().paused = false
