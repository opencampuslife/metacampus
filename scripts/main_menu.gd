extends CanvasLayer

@onready var new_game_btn: Button = $CenterContainer/VBox/NewGameBtn
@onready var continue_btn: Button = $CenterContainer/VBox/ContinueBtn
@onready var settings_btn: Button = $CenterContainer/VBox/SettingsBtn
@onready var quit_btn: Button = $CenterContainer/VBox/QuitBtn

var _settings_panel = null

func _ready() -> void:
	new_game_btn.pressed.connect(_on_new_game)
	continue_btn.pressed.connect(_on_continue)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit)
	_update_continue_button()

func _update_continue_button() -> void:
	var has_save = false
	var dir = DirAccess.open("user://saves")
	if dir:
		for f in dir.get_files():
			if f.ends_with(".json") and f.begins_with("save_"):
				has_save = true
				break
	continue_btn.disabled = not has_save
	if not has_save:
		continue_btn.text = "继续游戏（无存档）"

func _on_new_game() -> void:
	_reset_all_managers()
	_show_loading_screen("res://scenes/Main.tscn")

func _on_continue() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if not sm:
		return
	var saves = sm.list_saves()
	if saves.is_empty():
		return
	var latest = saves.back()
	sm.load_game(latest.slot)
	_show_loading_screen("res://scenes/Main.tscn")

func _on_settings() -> void:
	if _settings_panel == null:
		var scene = load("res://scenes/SettingsPanel.tscn")
		if scene:
			_settings_panel = scene.instantiate()
			add_child(_settings_panel)
	if _settings_panel:
		_settings_panel.show_panel()

func _on_quit() -> void:
	get_tree().quit()

func _reset_all_managers() -> void:
	var tm = get_node_or_null("/root/TimeManager")
	if tm and tm.has_method("set_time"):
		tm.set_time(1, 8, 0)
		tm.running = false

	var rm = get_node_or_null("/root/ResourceManager")
	if rm and rm.has_method("reset_all"):
		rm.reset_all()

	var mm = get_node_or_null("/root/MetricManager")
	if mm and mm.has_method("reset_all"):
		mm.reset_all()

	var qm = get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("_load_all_quests"):
		qm._load_all_quests()
		qm._init_states()
		qm._check_available()

func _list_saves() -> Array:
	var saves = []
	var dir = DirAccess.open("user://saves")
	if not dir:
		return saves
	dir.list_dir_begin()
	var f = dir.get_next()
	while f != "":
		if f.ends_with(".json") and f.begins_with("save_"):
			saves.append(f.trim_suffix(".json"))
		f = dir.get_next()
	saves.sort()
	return saves

func _show_loading_screen(scene_path: String) -> void:
	var ls_path = "res://scenes/LoadingScreen.tscn"
	var ls_scene = load(ls_path)
	if ls_scene:
		var ls = ls_scene.instantiate()
		add_child(ls)
		if ls.has_method("start_load"):
			ls.start_load(scene_path)

func _unused_load_save(save_name: String) -> void:
	var path = "user://saves/%s.json" % save_name
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data = json.data

	var tm = get_node_or_null("/root/TimeManager")
	if tm and data.has("day"):
		tm.set_time(data.get("day", 1), data.get("hour", 8), data.get("minute", 0))

	var rm = get_node_or_null("/root/ResourceManager")
	if rm and data.has("resources"):
		for rid in ["ap", "compute", "budget"]:
			if data["resources"].has(rid):
				rm.modify(rid, data["resources"][rid] - rm.get_value(rid))
