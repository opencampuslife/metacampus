extends Node

const TTS_API_URL := "https://api.minimaxi.com/v1/t2a_v2"
const MUSIC_API_URL := "https://api.minimaxi.com/v1/music_generation"
const API_KEY_ENV := "MINIMAX_API_KEY"

var _api_key := ""

signal audio_generated(local_path: String)
signal generation_error(msg: String)

func _ready() -> void:
	_api_key = OS.get_environment(API_KEY_ENV)
	if _api_key.is_empty():
		push_warning("[AudioGenService] MINIMAX_API_KEY not set — audio generation disabled")

func generate_speech(text: String, voice_id: String, output_path: String, emotion: String = "calm") -> void:
	if _api_key.is_empty():
		generation_error.emit("MINIMAX_API_KEY not set")
		return

	var body = JSON.new().stringify({
		"model": "speech-2.8-hd",
		"text": text,
		"stream": false,
		"voice_setting": {
			"voice_id": voice_id,
			"speed": 1.0,
			"vol": 1.0,
			"pitch": 0,
			"emotion": emotion,
		},
		"audio_setting": {
			"sample_rate": 24000,
			"format": "mp3",
			"channel": 1,
		},
	})

	_send_request(TTS_API_URL, body, output_path)

func generate_music(prompt: String, lyrics: String, output_path: String, instrumental: bool = true) -> void:
	if _api_key.is_empty():
		generation_error.emit("MINIMAX_API_KEY not set")
		return

	var body_dict = {
		"model": "music-2.6",
		"prompt": prompt,
		"stream": false,
		"output_format": "hex",
		"audio_setting": {
			"sample_rate": 44100,
			"format": "mp3",
		},
		"is_instrumental": instrumental,
	}
	if not instrumental and not lyrics.is_empty():
		body_dict["lyrics"] = lyrics
		body_dict["lyrics_optimizer"] = false

	var body = JSON.new().stringify(body_dict)

	_send_request(MUSIC_API_URL, body, output_path)

func _send_request(url: String, body: String, output_path: String) -> void:
	var headers = [
		"Authorization: Bearer " + _api_key,
		"Content-Type: application/json",
	]

	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_response.bind(http, output_path))
	http.request(url, headers, HTTPClient.METHOD_POST, body)

func _on_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, output_path: String) -> void:
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

	var audio_hex = resp.get("data", {}).get("audio", "")
	if audio_hex.is_empty():
		generation_error.emit("No audio data in response")
		return

	var audio_bytes = Hex.decode(audio_hex)

	var dir = output_path.get_base_dir()
	var d = DirAccess.open(dir)
	if not d:
		DirAccess.make_dir_recursive(dir)

	var file = FileAccess.open(output_path, FileAccess.WRITE)
	if not file:
		generation_error.emit("Failed to write: " + output_path)
		return
	file.store_buffer(audio_bytes)
	file.close()
	audio_generated.emit(output_path)
