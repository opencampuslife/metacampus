extends CanvasLayer
class_name DebugCommandPanel

@onready var input: LineEdit = $DebugPanel/VBox/Input
@onready var output: RichTextLabel = $DebugPanel/VBox/Output
@onready var execute_btn: Button = $DebugPanel/VBox/ButtonRow/ExecuteButton
@onready var close_btn: Button = $DebugPanel/VBox/ButtonRow/CloseButton

var is_visible_state: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	execute_btn.pressed.connect(_execute_command)
	close_btn.pressed.connect(_on_close)
	input.text_submitted.connect(_on_text_submitted)
	$DebugPanel.visible = false

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel") and is_visible_state:
		_on_close()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_QUOTELEFT:
			if is_visible_state:
				_on_close()
			else:
				show_panel()

func show_panel() -> void:
	$DebugPanel.visible = true
	is_visible_state = true
	input.grab_focus()
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_enabled"):
		player.set_enabled(false)

func _on_close() -> void:
	$DebugPanel.visible = false
	is_visible_state = false
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_enabled"):
		player.set_enabled(true)

func _on_text_submitted(_text: String) -> void:
	_execute_command()

func _execute_command() -> void:
	var cmd = input.text.strip_edges()
	if cmd.is_empty():
		return
	_log("> %s" % cmd)
	var parts = cmd.split(" ", false)
	var verb = parts[0].to_lower()
	var args = parts.slice(1)
	match verb:
		"add_ap":
			var amount = int(args[0]) if args.size() > 0 else 1
			var rm = get_node_or_null("/root/ResourceManager")
			if rm:
				rm.modify("ap", amount)
				_log("AP +%d" % amount)
		"add_compute":
			var amount = int(args[0]) if args.size() > 0 else 10
			var rm = get_node_or_null("/root/ResourceManager")
			if rm:
				rm.modify("compute", amount)
				_log("Compute +%d" % amount)
		"add_budget":
			var amount = int(args[0]) if args.size() > 0 else 1000
			var rm = get_node_or_null("/root/ResourceManager")
			if rm:
				rm.modify("budget", amount)
				_log("Budget +%d" % amount)
		"set_time":
			if args.size() >= 2:
				var h = int(args[0])
				var m = int(args[1])
				var tm = get_node_or_null("/root/TimeManager")
				if tm:
					tm.set_time(tm.day, h, m)
					_log("Time set to %02d:%02d" % [h, m])
		"complete":
			if args.size() > 0:
				var qm = get_node_or_null("/root/QuestManager")
				if qm:
					qm.complete_quest(args[0])
					_log("Completed quest: %s" % args[0])
		"fail":
			if args.size() > 0:
				var qm = get_node_or_null("/root/QuestManager")
				if qm:
					qm.fail_quest(args[0])
					_log("Failed quest: %s" % args[0])
		"add_xp":
			if args.size() >= 2:
				var sm = get_node_or_null("/root/SkillManager")
				if sm and sm.has_method("add_xp"):
					sm.add_xp(args[0], int(args[1]))
					_log("Added %d XP to %s" % [int(args[1]), args[0]])
		"help", "?":
			_log("=== 调试命令 ===\nadd_ap N — 增加行动点\nadd_compute N — 增加算力\nadd_budget N — 增加预算\nset_time HH MM — 设置时间\ncomplete QID — 完成任务\nfail QID — 任务失败\nadd_xp SKILL N — 增加技能经验")
		_:
			_log("未知命令: %s. 输入 help 查看命令列表。" % verb, true)
	input.clear()

func _log(msg: String, is_error: bool = false) -> void:
	var prefix = "[color=yellow]" if is_error else "[color=#10b981]"
	output.append_text("%s%s[/color]\n" % [prefix, msg])
