extends Control
## CanaryConsole — Canary 发布控制台交互界面
##
## 显示 1→5→25→50→100 各阶段进度
## 支持 pause/continue/rollback
## 接入 T8 任务 Canary 发布子系统

@onready var title_label: Label = $MarginContainer/VBox/TitleLabel
@onready var stage_label: Label = $MarginContainer/VBox/StageSection/StageLabel
@onready var progress_bar: ProgressBar = $MarginContainer/VBox/ProgressSection/ProgressBar
@onready var stability_label: Label = $MarginContainer/VBox/MetricsGrid/StabilityValue
@onready var compliance_label: Label = $MarginContainer/VBox/MetricsGrid/ComplianceValue
@onready var trust_label: Label = $MarginContainer/VBox/MetricsGrid/TrustValue
@onready var latency_label: Label = $MarginContainer/VBox/MetricsGrid/LatencyValue
@onready var error_rate_label: Label = $MarginContainer/VBox/MetricsGrid/ErrorRateValue
@onready var complaint_label: Label = $MarginContainer/VBox/MetricsGrid/ComplaintValue
@onready var risk_label: Label = $MarginContainer/VBox/MetricsGrid/RiskValue
@onready var recommendation_label: Label = $MarginContainer/VBox/RecommendationSection/RecommendationLabel
@onready var warnings_label: Label = $MarginContainer/VBox/WarningsSection/WarningsLabel
@onready var proceed_btn: Button = $MarginContainer/VBox/ButtonRow/ProceedButton
@onready var pause_btn: Button = $MarginContainer/VBox/ButtonRow/PauseButton
@onready var rollback_btn: Button = $MarginContainer/VBox/ButtonRow/RollbackButton
@onready var full_release_btn: Button = $MarginContainer/VBox/ButtonRow/FullReleaseButton
@onready var close_btn: Button = $MarginContainer/VBox/ButtonRow/CloseButton

enum State { IDLE, RUNNING, PAUSED, ROLLBACK }

var current_view_state: State = State.IDLE
var service  # CanarySimulatorService (autoload)


func _ready() -> void:
	# Get service autoload
	service = get_node_or_null("/root/CanarySimulatorService")
	if service == null:
		push_error("CanaryConsole: CanarySimulatorService autoload not found")
		hide()
		return

	# Connect service signals
	service.stage_completed.connect(_on_stage_completed)
	service.warning_triggered.connect(_on_warning)
	service.rollback_executed.connect(_on_rollback_signal)

	# Connect buttons
	proceed_btn.pressed.connect(_on_proceed)
	pause_btn.pressed.connect(_on_pause)
	rollback_btn.pressed.connect(_on_rollback)
	full_release_btn.pressed.connect(_on_full_release)
	close_btn.pressed.connect(_on_close)

	_refresh_display()
	_set_buttons(State.IDLE)


func _process(_delta: float) -> void:
	# Handle ESC to close
	if Input.is_action_just_pressed("ui_cancel") and visible:
		hide()


# ---------------------------------------------------------------------------
# Button handlers
# ---------------------------------------------------------------------------

func _on_proceed() -> void:
	var next_pct: int = int(service.current_state["next_percentage"])
	var result: Dictionary = service.proceed_to_stage(next_pct)

	current_view_state = State.RUNNING
	_refresh_display()
	_update_recommendation(result)

	var rec: String = str(result.get("recommendation", "continue"))
	match rec:
		"rollback":
			_set_buttons(State.ROLLBACK)
		"pause":
			_set_buttons(State.PAUSED)
		_:
			if next_pct >= 100:
				_set_buttons(State.IDLE) # completed
			else:
				_set_buttons(State.RUNNING)


func _on_pause() -> void:
	current_view_state = State.PAUSED
	_set_buttons(State.PAUSED)
	print("CanaryConsole: paused at ", service.current_state["current_percentage"], "%")
	# Pause does not change state - just stops further progression


func _on_rollback() -> void:
	var result: Dictionary = service.execute_rollback()
	current_view_state = State.ROLLBACK
	_refresh_display()
	_set_buttons(State.IDLE)
	print("CanaryConsole: rolled back to ", result.get("current_percentage", "?"), "%")


func _on_full_release() -> void:
	# Check risk before full release
	var risk_result: Dictionary = service.check_full_release_risk()
	var rec: String = str(risk_result.get("recommendation", "continue"))

	var warnings: PackedStringArray = risk_result.get("triggered_warnings", [])
	if rec == "rollback" or warnings.has("full_release_risk"):
		_update_recommendation(risk_result)
		recommendation_label.text = "⚠ 全量发布极度危险！\n" + service.get_recommendation_text(risk_result)
		recommendation_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1.0))
		return

	# Execute full release
	var result: Dictionary = service.proceed_to_stage(100)
	current_view_state = State.RUNNING
	_refresh_display()
	_update_recommendation(result)
	_set_buttons(State.IDLE)


func _on_close() -> void:
	hide()


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_stage_completed(recommendation: String, _result: Dictionary) -> void:
	_refresh_display()
	print("CanaryConsole: stage completed -> ", recommendation)


func _on_warning(warning: String) -> void:
	print("CanaryConsole: WARNING - ", warning)


func _on_rollback_signal(from_pct, to_pct):
	_refresh_display()
	print("CanaryConsole: rollback ", from_pct, "% -> ", to_pct, "%")


# ---------------------------------------------------------------------------
# Display updates
# ---------------------------------------------------------------------------

func _refresh_display() -> void:
	if service == null:
		return

	var st: Dictionary = service.current_state
	var pct: int = int(st["current_percentage"])

	stage_label.text = "当前阶段: " + str(pct) + "% → " + str(st["next_percentage"]) + "%"
	progress_bar.value = pct

	# Update metrics with color coding
	stability_label.text = "%.1f" % float(st["stability"])
	stability_label.add_theme_color_override("font_color", _metric_color(float(st["stability"]), 40, 60))

	compliance_label.text = "%.1f" % float(st["compliance"])
	compliance_label.add_theme_color_override("font_color", _metric_color(float(st["compliance"]), 40, 60))

	trust_label.text = "%.1f" % float(st["parent_trust"])
	trust_label.add_theme_color_override("font_color", _metric_color(float(st["parent_trust"]), 30, 50))

	latency_label.text = "%.0f ms" % float(st["latency_ms"])
	latency_label.add_theme_color_override("font_color", _latency_color(float(st["latency_ms"])))

	error_rate_label.text = "%.3f" % float(st["error_rate"])
	error_rate_label.add_theme_color_override("font_color", _error_color(float(st["error_rate"])))

	complaint_label.text = "%.3f" % float(st["complaint_rate"])
	complaint_label.add_theme_color_override("font_color", _error_color(float(st["complaint_rate"])))

	risk_label.text = str(int(st["risk_score"]))


func _update_recommendation(result: Dictionary) -> void:
	var rec: String = str(result.get("recommendation", "continue"))
	var text := service.get_recommendation_text(result)

	var error_rate: float = float(result.get("predicted_error_rate", 0))
	var complaint_rate: float = float(result.get("predicted_complaint_rate", 0))
	var s_delta: int = int(result.get("stability_delta", 0))
	var c_delta: int = int(result.get("compliance_delta", 0))
	var p_delta: int = int(result.get("parent_trust_delta", 0))

	recommendation_label.text = "%s\n预测错误率: %.3f | 投诉率: %.3f\nΔ稳定性: %+d | Δ合规: %+d | Δ信任: %+d" % [
		text, error_rate, complaint_rate, s_delta, c_delta, p_delta
	]

	match rec:
		"continue":
			recommendation_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3, 1.0))
		"pause":
			recommendation_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.1, 1.0))
		"rollback":
			recommendation_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1.0))

	# Update warnings
	var warnings: PackedStringArray = result.get("triggered_warnings", [])
	if warnings.size() > 0:
		var warn_texts: Array[String] = []
		for w in warnings:
			warn_texts.append(str(w))
		warnings_label.text = "⚠ 警告: " + ", ".join(warn_texts)
		warnings_label.visible = true
	else:
		warnings_label.visible = false


func _set_buttons(state: State) -> void:
	proceed_btn.disabled = (state == State.PAUSED or state == State.ROLLBACK)
	pause_btn.disabled = (state == State.PAUSED or state == State.IDLE)
	rollback_btn.disabled = (state == State.IDLE)


# ---------------------------------------------------------------------------
# Color helpers
# ---------------------------------------------------------------------------

func _metric_color(value: float, warn_threshold: float, danger_threshold: float) -> Color:
	if value < danger_threshold:
		return Color(1.0, 0.2, 0.2, 1.0)
	elif value < warn_threshold:
		return Color(0.9, 0.7, 0.1, 1.0)
	else:
		return Color(0.3, 0.9, 0.3, 1.0)


func _latency_color(ms: float) -> Color:
	if ms > 600: return Color(1.0, 0.2, 0.2, 1.0)
	if ms > 400: return Color(0.9, 0.7, 0.1, 1.0)
	return Color(0.3, 0.9, 0.3, 1.0)


func _error_color(rate: float) -> Color:
	if rate > 0.05: return Color(1.0, 0.2, 0.2, 1.0)
	if rate > 0.02: return Color(0.9, 0.7, 0.1, 1.0)
	return Color(0.3, 0.9, 0.3, 1.0)
