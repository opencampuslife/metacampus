extends CanvasLayer

var _mode := "save"
var _slot_buttons: Array = []

func _ready() -> void:
	visible = false
	for i in range(6):
		var btn = $Panel/VBox/SlotGrid.get_node("Slot%d" % i)
		_slot_buttons.append(btn)
		btn.pressed.connect(_on_slot_pressed.bind(i))
	$Panel/VBox/ButtonRow/CloseBtn.pressed.connect(_on_close)

func show_panel(mode: String) -> void:
	_mode = mode
	if mode == "save":
		$Panel/VBox/TitleLabel.text = "保存游戏"
	else:
		$Panel/VBox/TitleLabel.text = "读取存档"
	_refresh_slots()
	visible = true

func _refresh_slots() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	for i in range(6):
		var btn = _slot_buttons[i]
		if sm:
			var meta = sm.get_save_meta(i)
			if meta.exists:
				btn.text = "存档位 %d: %s" % [i + 1, meta.label]
			else:
				btn.text = "存档位 %d: (空)" % (i + 1)
				btn.disabled = (_mode == "load")

func _on_slot_pressed(slot: int) -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if not sm:
		return
	if _mode == "save":
		sm.save_game(slot)
	elif _mode == "load":
		sm.load_game(slot)
	visible = false

func _on_close() -> void:
	visible = false
