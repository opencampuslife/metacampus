extends CanvasLayer
class_name QuestBoardController

@onready var panel: PanelContainer = $Root/Panel
@onready var category_tabs: TabContainer = $Root/Panel/VBox/CategoryTabs
@onready var daily_list: VBoxContainer = $Root/Panel/VBox/CategoryTabs/DailyTab/DailyQuestList
@onready var risk_list: VBoxContainer = $Root/Panel/VBox/CategoryTabs/RiskTab/RiskQuestList
@onready var active_list: VBoxContainer = $Root/Panel/VBox/CategoryTabs/ActiveTab/ActiveQuestList
@onready var close_btn: Button = $Root/Panel/VBox/HeaderRow/CloseButton

var is_visible_state: bool = false

const COLOR_NORMAL := Color("#64748b")
const COLOR_ACTIVE := Color("#2563eb")
const COLOR_COMPLETED := Color("#10b981")
const COLOR_FAILED := Color("#ef4444")
const COLOR_AVAILABLE := Color("#f59e0b")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	close_btn.pressed.connect(_hide)
	category_tabs.tab_changed.connect(_refresh)
	panel.visible = false

	var qm = get_node_or_null("/root/QuestManager")
	if qm:
		qm.quest_started.connect(_refresh)
		qm.quest_completed.connect(_refresh)
		qm.quest_failed.connect(_refresh)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_questboard"):
		if is_visible_state:
			_hide()
		else:
			_show()
	elif Input.is_action_just_pressed("ui_cancel") and is_visible_state:
		_hide()

func show_board() -> void:
	_show()

func _show() -> void:
	is_visible_state = true
	panel.visible = true
	_refresh()
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_enabled"):
		player.set_enabled(false)

func _hide() -> void:
	is_visible_state = false
	panel.visible = false
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_enabled"):
		player.set_enabled(true)

func _refresh(_index: int = 0) -> void:
	_clear_list(daily_list)
	_clear_list(risk_list)
	_clear_list(active_list)

	var qm = get_node_or_null("/root/QuestManager")
	if not qm:
		return

	for q in qm.get_all_quests():
		var qid = q.get("quest_id", "") or q.get("id", "")
		if qid.is_empty():
			continue
		var status = qm.get_quest_status(qid)
		var quest_type = q.get("type", "daily")
		if typeof(quest_type) == TYPE_STRING:
			quest_type = quest_type.to_lower()

		var card = _make_quest_card(q, status)

		if quest_type == "daily":
			daily_list.add_child(card)
		elif quest_type in ["risk", "high_risk", "high"]:
			risk_list.add_child(card)

		if status == "active" or status == "active":
			active_list.add_child(card.duplicate())

func _make_quest_card(q: Dictionary, status: String) -> Control:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.18, 0.8)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var title_hbox = HBoxContainer.new()
	title_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(title_hbox)

	var title = Label.new()
	title.text = q.get("title", q.get("name", "未知任务"))
	title.add_theme_font_size_override("font_size", 16)
	title_hbox.add_child(title)

	var status_label = Label.new()
	match status:
		"active":
			status_label.text = "进行中"
			status_label.add_theme_color_override("font_color", COLOR_ACTIVE)
		"completed":
			status_label.text = "已完成"
			status_label.add_theme_color_override("font_color", COLOR_COMPLETED)
		"failed":
			status_label.text = "已失败"
			status_label.add_theme_color_override("font_color", COLOR_FAILED)
		"available":
			status_label.text = "可领取"
			status_label.add_theme_color_override("font_color", COLOR_AVAILABLE)
		_:
			status_label.text = status
			status_label.add_theme_color_override("font_color", COLOR_NORMAL)
	status_label.add_theme_font_size_override("font_size", 11)
	title_hbox.add_child(status_label)

	var desc = Label.new()
	desc.text = q.get("description", "")
	desc.add_theme_color_override("font_color", COLOR_NORMAL)
	desc.add_theme_font_size_override("font_size", 12)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(desc)

	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var qid_ref = q.get("quest_id", "") or q.get("id", "")
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var detail = get_node_or_null("/root/Main/QuestDetailPanel")
			if detail and detail.has_method("show_quest"):
				detail.show_quest(qid_ref)
	)

	return card

func _clear_list(list: VBoxContainer) -> void:
	for c in list.get_children():
		c.queue_free()
