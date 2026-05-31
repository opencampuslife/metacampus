extends CanvasLayer
class_name QuestDetailPanel

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var type_label: Label = $Panel/VBox/TypeLabel
@onready var desc_label: RichTextLabel = $Panel/VBox/DescriptionLabel
@onready var deadline_label: Label = $Panel/VBox/DeadlineLabel
@onready var objectives_label: RichTextLabel = $Panel/VBox/ObjectivesLabel
@onready var rewards_label: RichTextLabel = $Panel/VBox/RewardsLabel
@onready var accept_btn: Button = $Panel/VBox/ButtonRow/AcceptButton
@onready var close_btn: Button = $Panel/VBox/ButtonRow/CloseButton

var _current_qid: String = ""

func _ready() -> void:
	accept_btn.pressed.connect(_on_accept)
	close_btn.pressed.connect(_on_close)
	visible = false

func show_quest(qid: String) -> void:
	_current_qid = qid
	var qm = get_node_or_null("/root/QuestManager")
	if not qm:
		return
	var q = {}
	for quest in qm.get_all_quests():
		var id = quest.get("quest_id", "") or quest.get("id", "")
		if id == qid:
			q = quest
			break
	if q.is_empty():
		return

	title_label.text = q.get("title", q.get("name", "未知任务"))
	type_label.text = "类型: %s" % q.get("type", "日常")
	desc_label.text = q.get("description", "无描述")

	var deadline = q.get("deadline", "")
	deadline_label.text = "截止: %s" % deadline if deadline else "截止: 当日"

	var objectives = q.get("objectives", q.get("conditions", []))
	var obj_text = ""
	if typeof(objectives) == TYPE_ARRAY:
		var parts = []
		for o in objectives:
			if typeof(o) == TYPE_DICTIONARY:
				parts.append(o.get("description", str(o)))
			else:
				parts.append(str(o))
		obj_text = "\n".join(parts)
	elif typeof(objectives) == TYPE_STRING:
		obj_text = objectives
	objectives_label.text = "[b]目标:[/b]\n%s" % obj_text if obj_text else "[b]目标:[/b] 无"

	var reward = q.get("rewards", q.get("reward", {}))
	var reward_text = _format_rewards(reward)
	rewards_label.text = "[b]奖励:[/b]\n%s" % reward_text if reward_text else "奖励: 无"

	var status = qm.get_quest_status(qid)
	accept_btn.visible = (status == "available")
	accept_btn.disabled = (status != "available")

	visible = true

func _format_rewards(reward) -> String:
	if typeof(reward) == TYPE_DICTIONARY:
		var parts = []
		for k in reward.keys():
			var val = reward[k]
			if typeof(val) == TYPE_INT or typeof(val) == TYPE_FLOAT:
				parts.append("%s: %+d" % [k, val])
		return "\n".join(parts)
	return ""

func _on_accept() -> void:
	if _current_qid.is_empty():
		return
	var qm = get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("start_quest"):
		qm.start_quest(_current_qid)
	visible = false

func _on_close() -> void:
	visible = false
