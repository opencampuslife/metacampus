extends CanvasLayer

var _progress: Array = []
var _scene_to_load := ""

func start_load(scene_path: String) -> void:
	_scene_to_load = scene_path
	visible = true
	var err = ResourceLoader.load_threaded_request(scene_path, "", true)
	if err != OK:
		push_error("[LoadingScreen] Failed to request: " + scene_path)
		_finish()
		return
	set_process(true)

func _process(_delta: float) -> void:
	var status: int = ResourceLoader.load_threaded_get_status(_scene_to_load, _progress)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if _progress.size() > 0:
				$CenterContainer/VBox/ProgressBar.value = _progress[0] * 100
		ResourceLoader.THREAD_LOAD_LOADED:
			_finish()
		ResourceLoader.THREAD_LOAD_FAILED:
			push_error("[LoadingScreen] Failed to load: " + _scene_to_load)
			_finish()

func _finish() -> void:
	set_process(false)
	get_tree().change_scene_to_file(_scene_to_load)
