extends Node


## 通用 JSON 加载器
## 提供 JSON 文件加载、缓存、解析，带错误处理

var _cache: Dictionary = {}

func _ready() -> void:
	add_to_group("json_loader")

## 从文件加载 JSON，结果可选缓存
func load_json(path: String, use_cache: bool = true) -> Dictionary:
	if use_cache and _cache.has(path):
		return _cache[path].duplicate(true)

	if not FileAccess.file_exists(path):
		push_warning("[JsonLoader] File not found: " + path)
		return {}

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("[JsonLoader] Cannot open: " + path)
		return {}

	var json = JSON.new()
	var parse_result = json.parse(file.get_as_text())
	file.close()

	if parse_result != OK:
		push_warning("[JsonLoader] JSON parse error in: " + path)
		return {}

	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("[JsonLoader] Root must be Dictionary: " + path)
		return {}

	if use_cache:
		_cache[path] = data.duplicate(true)

	return data

## 加载 JSON 数组（根为 Array 的文件）
func load_json_array(path: String, use_cache: bool = true) -> Array:
	if use_cache and _cache.has(path):
		return _cache[path].duplicate(true)

	if not FileAccess.file_exists(path):
		push_warning("[JsonLoader] File not found: " + path)
		return []

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return []

	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return []

	file.close()
	var data = json.data
	if typeof(data) != TYPE_ARRAY:
		push_warning("[JsonLoader] Root must be Array: " + path)
		return []

	if use_cache:
		_cache[path] = data.duplicate(true)

	return data

## 清空缓存
func clear_cache() -> void:
	_cache.clear()

## 移除指定缓存
func invalidate(path: String) -> void:
	_cache.erase(path)
