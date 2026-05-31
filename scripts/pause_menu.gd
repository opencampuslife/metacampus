extends CanvasLayer

var _settings_panel = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	$CenterContainer/VBox/ContinueBtn.pressed.connect(_on_continue)
	$CenterContainer/VBox/SaveBtn.pressed.connect(_on_save)
	$CenterContainer/VBox/SettingsBtn.pressed.connect(_on_settings)
	$CenterContainer/VBox/QuitBtn.pressed.connect(_on_quit)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if visible:
				_resume()
			else:
				_pause()

func _pause() -> void:
	visible = true
	get_tree().paused = true

func _resume() -> void:
	visible = false
	get_tree().paused = false

func _on_continue() -> void:
	_resume()

func _on_save() -> void:
	var sl = get_node_or_null("/root/Main/SaveLoadPanel")
	if sl and sl.has_method("show_panel"):
		sl.show_panel("save")
	else:
		print("[PauseMenu] SaveLoadPanel not found")

func _on_settings() -> void:
	if _settings_panel == null:
		var scene = load("res://scenes/SettingsPanel.tscn")
		if scene:
			_settings_panel = scene.instantiate()
			add_child(_settings_panel)
	if _settings_panel:
		_settings_panel.show_panel()

func _on_quit() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
