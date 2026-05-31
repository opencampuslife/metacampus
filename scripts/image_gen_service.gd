extends Node

const API_URL_DEFAULT := "https://api.minimax.chat/v1/image_generation"
const API_KEY_ENV := "MINIMAX_API_KEY"

var _api_key := ""
var _api_url := API_URL_DEFAULT

signal image_generated(url: String, local_path: String)
signal generation_error(msg: String)

func _ready() -> void:
	_api_key = OS.get_environment(API_KEY_ENV)
	if _api_key.is_empty():
		push_warning("[ImageGenService] MINIMAX_API_KEY not set — image generation disabled")
	var config = _load_config()
	if config.has("api_url"):
		_api_url = config.api_url

func _load_config() -> Dictionary:
	var path = "res://data/api_config.json"
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	var data = json.data
	return data.get("image_gen", {})

func generate_image(prompt: String, output_dir: String, filename: String = "") -> void:
	var output_path = output_dir
	if not output_path.ends_with("/"):
		output_path += "/"
	if filename.is_empty():
		filename = "gen_%d.png" % Time.get_unix_time_from_system()
	output_path += filename

	var dir = DirAccess.open(output_dir)
	if not dir:
		DirAccess.make_dir_recursive_absolute(output_dir)

	if _api_key.is_empty():
		generation_error.emit("MINIMAX_API_KEY not set")
		return

	var headers = [
		"Authorization: Bearer " + _api_key,
		"Content-Type: application/json",
	]

	var model = "image-01"
	var config = _load_config()
	if config.has("model"):
		model = config.model

	var body = JSON.new().stringify({
		"model": model,
		"prompt": prompt,
		"n": 1,
	})

	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_image_response.bind(http, output_path, filename))
	http.request(_api_url, headers, HTTPClient.METHOD_POST, body)

func _on_image_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, output_path: String, filename: String) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS:
		generation_error.emit("HTTP request failed: %d" % result)
		return
	if code != 200:
		generation_error.emit("API error (HTTP %d): %s" % [code, body.get_string_from_utf8()])
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		generation_error.emit("Failed to parse API response")
		return

	var resp = json.data
	if resp.get("base_resp", {}).get("status_code", -1) != 0:
		generation_error.emit("MiniMax error: %s" % resp.get("base_resp", {}).get("status_msg", "unknown"))
		return

	var urls = resp.get("data", {}).get("image_urls", [])
	if urls.is_empty():
		generation_error.emit("No image URLs in response")
		return

	var image_url = urls[0]
	_download_image(image_url, output_path, filename)

func _download_image(url: String, output_path: String, filename: String) -> void:
	var dl = HTTPRequest.new()
	add_child(dl)
	dl.request_completed.connect(_on_download_complete.bind(dl, output_path, filename, url))
	dl.request(url)

func _on_download_complete(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, dl: HTTPRequest, output_path: String, _filename: String, url: String) -> void:
	dl.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		generation_error.emit("Failed to download image: %d/%s" % [code, url])
		return

	var file = FileAccess.open(output_path, FileAccess.WRITE)
	if not file:
		generation_error.emit("Failed to write: " + output_path)
		return
	file.store_buffer(body)
	file.close()
	image_generated.emit(url, output_path)

func regenerate_player_sprite() -> void:
	var prompt = "2D pixel art game character, top-down view, male student, blue school uniform, 64x64 pixels per frame, 4 direction idle animation (front, back, left, right), transparent background, pixel art style, 16-bit color palette, game sprite sheet"
	generate_image(prompt, "res://assets/sprites/player/", "player_spritesheet.png")

func regenerate_tilemap_textures() -> void:
	var prompts = {
		"grass.png": "2D top-down pixel art grass tile, 32x32 pixels, green grass texture, seamless tileable, RPG game style, 16-bit color palette",
		"path.png": "2D top-down pixel art stone path tile, 32x32 pixels, gray cobblestone, seamless tileable, RPG game style",
		"wall.png": "2D top-down pixel art brick wall tile, 32x32 pixels, red-brown bricks, seamless tileable, RPG game style",
		"water.png": "2D top-down pixel art water tile, 32x32 pixels, blue water with wave animation frames, seamless tileable, RPG game style",
		"building.png": "2D top-down pixel art school building roof tile, 64x64 pixels, gray roof, RPG game style",
	}

	for filename in prompts.keys():
		generate_image(prompts[filename], "res://assets/tiles/", filename)

func regenerate_tiles() -> void:
	var prompts = {
		"grass.png": "2D top-down pixel art grass tile, 32x32 pixels, green grass texture, seamless tileable, RPG game style, 16-bit color palette",
		"path.png": "2D top-down pixel art stone path tile, 32x32 pixels, gray cobblestone, seamless tileable, RPG game style",
		"wall.png": "2D top-down pixel art brick wall tile, 32x32 pixels, red-brown bricks, seamless tileable, RPG game style",
		"water.png": "2D top-down pixel art water tile, 32x32 pixels, blue water with wave animation frames, seamless tileable, RPG game style",
		"building.png": "2D top-down pixel art school building roof tile, 64x64 pixels, gray roof, RPG game style",
	}

	for filename in prompts.keys():
		generate_image(prompts[filename], "res://assets/tiles/", filename)
