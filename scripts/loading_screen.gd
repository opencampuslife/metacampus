extends CanvasLayer

var _progress: Array = []
var _total := 1
var _loaded := 0

func start_load(scene_path: String) -> void:
	visible = true
	var err = ResourceLoader.load_threaded_request(scene_path, "", true)
	if err != OK:
		push_error("[LoadingScreen] Failed to request: " + scene_path)
		_finish(scene_path)
		return
	set_process(true)

func _process(_delta: float) -> void:
	var status: int = ResourceLoader.load_threaded_get_status("res://scenes/Main.tscn", _progress)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if _progress.size() > 0:
				$CenterContainer/VBox/ProgressBar.value = _progress[0] * 100
		ResourceLoader.THREAD_LOAD_LOADED:
			_finish("res://scenes/Main.tscn")
		ResourceLoader.THREAD_LOAD_FAILED:
			push_error("[LoadingScreen] Failed to load scene")
			_finish("res://scenes/Main.tscn")

func _finish(scene_path: String) -> void:
	set_process(false)
	get_tree().change_scene_to_file(scene_path)
