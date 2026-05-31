extends Node


## 时间管理系统
## 管理游戏内日期/时间推进，时间段划分，NPC schedule 联动

signal time_advanced(day: int, hour: int, minute: int, phase: String)
signal day_changed(day: int)
signal phase_changed(phase: String)
signal day_ended(day: int)

const MINUTES_PER_TICK := 10
const TICK_INTERVAL := 2.0  # real seconds per game tick

const PHASES := {
	"dawn":    { "start": 360, "name": "黎明" },    # 06:00
	"morning": { "start": 480, "name": "上午" },    # 08:00
	"forenoon": { "start": 600, "name": "午前" },   # 10:00
	"afternoon": { "start": 720, "name": "下午" },  # 12:00
	"evening": { "start": 1020, "name": "傍晚" },   # 17:00
	"night":   { "start": 1200, "name": "夜间" },   # 20:00
}

var day: int = 1
var hour: int = 8
var minute: int = 0
var total_minutes: int = 480  # 08:00
var running: bool = false
var speed_multiplier: float = 1.0

var _timer: float = 0.0
var _current_phase: String = "morning"

func _ready() -> void:
	add_to_group("time_manager")
	print("[TimeManager] Ready — Day %d, %02d:%02d" % [day, hour, minute])

# ── Public API ──────────────────────────────────────────────────

func start() -> void:
	running = true

func pause() -> void:
	running = false

func set_time(d: int, h: int, m: int) -> void:
	day = d
	hour = h
	minute = m
	total_minutes = h * 60 + m
	_update_phase()

func advance_minutes(m: int) -> void:
	total_minutes += m
	hour = (total_minutes / 60) % 24
	minute = total_minutes % 60
	var new_phase = _get_phase(total_minutes)
	if new_phase != _current_phase:
		_current_phase = new_phase
		phase_changed.emit(_current_phase)
	time_advanced.emit(day, hour, minute, _current_phase)

func get_phase() -> String:
	return _current_phase

func get_phase_name() -> String:
	var p = PHASES.get(_current_phase, {})
	return p.get("name", _current_phase)

func get_time_string() -> String:
	return "%02d:%02d" % [hour, minute]

func get_day_string() -> String:
	return "Day %d" % day

# ── Process ─────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not running:
		return

	_timer += delta * speed_multiplier
	if _timer >= TICK_INTERVAL:
		_timer -= TICK_INTERVAL
		_tick()

func _tick() -> void:
	advance_minutes(MINUTES_PER_TICK)

	# End of day at 22:00 (1320 min)
	if total_minutes >= 1320:
		_end_day()

func _end_day() -> void:
	running = false
	day_ended.emit(day)
	day += 1
	total_minutes = 360  # 06:00 next day
	hour = 6
	minute = 0
	_current_phase = "dawn"
	day_changed.emit(day)
	running = true

func _get_phase(minutes: int) -> String:
	var best = "morning"
	var best_start = -1
	for pid in PHASES.keys():
		var start = PHASES[pid]["start"]
		if minutes >= start and start > best_start:
			best = pid
			best_start = start
	return best

func _update_phase() -> void:
	_current_phase = _get_phase(total_minutes)
