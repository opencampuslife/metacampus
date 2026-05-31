extends CanvasLayer
class_name DashboardController

@onready var root: Control = $Root
@onready var tabs: TabContainer = $Root/Panel/VBox/Tabs
@onready var metrics_vbox: VBoxContainer = $Root/Panel/VBox/Tabs/MetricsTab/MetricsVBox
@onready var skills_vbox: VBoxContainer = $Root/Panel/VBox/Tabs/SkillsTab/SkillsVBox
@onready var npc_vbox: VBoxContainer = $Root/Panel/VBox/Tabs/NpcTab/NpcVBox
@onready var upgrades_vbox: VBoxContainer = $Root/Panel/VBox/Tabs/UpgradesTab/UpgradesVBox
@onready var close_btn: Button = $Root/Panel/VBox/HeaderRow/CloseButton

var is_visible_state: bool = false

const WARNING_THRESHOLD := 30
const COLOR_NORMAL := Color("#1458ea")
const COLOR_PARENT_TRUST := Color("#10b981")
const COLOR_COMPLIANCE := Color("#7c3aed")
const COLOR_STABILITY := Color("#06b6d4")
const COLOR_WARNING := Color("#ef4444")

var _metric_colors := {
	"school_efficiency": COLOR_NORMAL,
	"parent_trust": COLOR_PARENT_TRUST,
	"compliance_safety": COLOR_COMPLIANCE,
	"system_stability": COLOR_STABILITY,
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	close_btn.pressed.connect(_hide)
	root.visible = false

	var mm = get_node_or_null("/root/MetricManager")
	if mm:
		mm.all_metrics_updated.connect(_on_metrics_updated)

	var sm = get_node_or_null("/root/SkillManager")
	if sm:
		sm.skill_xp_changed.connect(_on_skill_changed)
		sm.upgrade_purchased.connect(_on_upgrade_changed)
	var nr = get_node_or_null("/root/NpcRegistry")
	if nr:
		nr.npc_data_ready.connect(_on_npc_updated)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_dashboard"):
		_toggle()
	elif Input.is_action_just_pressed("ui_cancel") and is_visible_state:
		_hide()

func _toggle() -> void:
	if is_visible_state:
		_hide()
	else:
		_show()

func _show() -> void:
	root.visible = true
	is_visible_state = true
	_refresh_all()
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_enabled"):
		player.set_enabled(false)

func _hide() -> void:
	root.visible = false
	is_visible_state = false
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_enabled"):
		player.set_enabled(true)

func _refresh_all() -> void:
	_on_metrics_updated({})
	_on_skill_changed("", 0, 0)
	_on_upgrade_changed("")
	_on_npc_updated()

func _on_metrics_updated(_metrics: Dictionary) -> void:
	_clear_container(metrics_vbox)
	var mm = get_node_or_null("/root/MetricManager")
	if not mm:
		return
	var data = mm.get_all_with_metadata()
	for mid in data.keys():
		var m = data[mid]
		var val = m.get("value", 0)
		var name = m.get("name", mid)
		var color = _metric_colors.get(mid, COLOR_NORMAL)
		var is_warning = val < m.get("warning_threshold", WARNING_THRESHOLD)
		metrics_vbox.add_child(_make_metric_row(name, val, color if not is_warning else COLOR_WARNING))

func _on_skill_changed(_sid: String, _xp: int, _level: int) -> void:
	_clear_container(skills_vbox)
	var sm = get_node_or_null("/root/SkillManager")
	if not sm:
		return
	for s in sm.get_all_skills():
		skills_vbox.add_child(_make_skill_row(s))

func _on_upgrade_changed(_uid: String) -> void:
	_clear_container(upgrades_vbox)
	var sm = get_node_or_null("/root/SkillManager")
	if not sm:
		return
	for u in sm.get_upgrades():
		upgrades_vbox.add_child(_make_upgrade_row(u))

func _on_npc_updated() -> void:
	_clear_container(npc_vbox)
	var nr = get_node_or_null("/root/NpcRegistry")
	if not nr:
		return
	for npc in nr.get_all_npcs():
		npc_vbox.add_child(_make_npc_row(npc))

func _make_metric_row(name: String, value: int, color: Color) -> Control:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	var name_lbl = Label.new()
	name_lbl.text = name
	name_lbl.custom_minimum_size = Vector2(120, 0)
	hbox.add_child(name_lbl)
	var bar = ProgressBar.new()
	bar.value = value
	bar.max_value = 100
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(200, 16)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fill = StyleBoxFlat.new()
	fill.bg_color = color
	fill.corner_radius_top_left = 4
	fill.corner_radius_top_right = 4
	fill.corner_radius_bottom_left = 4
	fill.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("fill", fill)
	hbox.add_child(bar)
	var val_lbl = Label.new()
	val_lbl.text = str(value)
	val_lbl.custom_minimum_size = Vector2(30, 0)
	hbox.add_child(val_lbl)
	return hbox

func _make_skill_row(s: Dictionary) -> Control:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	var name_lbl = Label.new()
	name_lbl.text = s.get("name", s.get("skill_id", ""))
	name_lbl.custom_minimum_size = Vector2(100, 0)
	hbox.add_child(name_lbl)
	var lvl_lbl = Label.new()
	lvl_lbl.text = "Lv.%d" % s.get("level", 1)
	lvl_lbl.custom_minimum_size = Vector2(40, 0)
	hbox.add_child(lvl_lbl)
	var bar = ProgressBar.new()
	bar.max_value = s.get("xp_for_next", 100)
	bar.value = s.get("xp", 0)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(150, 16)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(bar)
	var xp_lbl = Label.new()
	xp_lbl.text = "%d/%d" % [s.get("xp", 0), s.get("xp_for_next", 100)]
	hbox.add_child(xp_lbl)
	return hbox

func _make_npc_row(npc: Dictionary) -> Control:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	var name_lbl = Label.new()
	name_lbl.text = npc.get("name", npc.get("npc_id", ""))
	name_lbl.custom_minimum_size = Vector2(100, 0)
	hbox.add_child(name_lbl)
	var loc_lbl = Label.new()
	loc_lbl.text = npc.get("location", "")
	hbox.add_child(loc_lbl)
	return hbox

func _make_upgrade_row(u: Dictionary) -> Control:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	var name_lbl = Label.new()
	name_lbl.text = u.get("name", u.get("upgrade_id", ""))
	name_lbl.custom_minimum_size = Vector2(120, 0)
	hbox.add_child(name_lbl)
	var cost_lbl = Label.new()
	cost_lbl.text = "¥%d" % u.get("cost", 0)
	hbox.add_child(cost_lbl)
	var status_lbl = Label.new()
	if u.get("purchased", false):
		status_lbl.text = "已购买"
		status_lbl.add_theme_color_override("font_color", Color("#10b981"))
	else:
		status_lbl.text = "可购买" if u.get("can_afford", false) else "未解锁"
		status_lbl.add_theme_color_override("font_color", Color("#f59e0b"))
	hbox.add_child(status_lbl)
	return hbox

func _clear_container(container: VBoxContainer) -> void:
	for c in container.get_children():
		c.queue_free()
