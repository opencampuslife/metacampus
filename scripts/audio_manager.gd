extends Node

## ─────────────────────────────────────────────────────────────────
## MetaCampus 2D — AudioManager (GDScript)
## Phase 2.8A: 基础音效系统
## Autoload: /root/AudioManager
## ─────────────────────────────────────────────────────────────────

const DEBUG_AUDIO := true  # Phase 2.8A-Verify: 日志开关，验证通过后改为 false

const AUDIO_EVENTS_PATH := "res://data/audio/audio_events.json"
const NPC_VOICE_PROFILES_PATH := "res://data/audio/npc_voice_profiles.json"

# Audio Bus 名称（需在 Godot Editor → Project → Audio 中配置）
enum Bus { MASTER, MUSIC, SFX, VOICE, AMBIENCE, UI }

# ── 数据 ──────────────────────────────────────────────────────────
var _events: Dictionary = {}
var _npc_voice_profiles: Dictionary = {}

# ── 播放器节点 ────────────────────────────────────────────────────
var _ui_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _voice_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _ambience_player: AudioStreamPlayer

# ── 限流 ──────────────────────────────────────────────────────────
var _last_sfx_time: Dictionary = {}
var _sfx_cooldowns: Dictionary = {
	"risk_warning": 2.0,
	"critical_alert": 2.0,
	"metric_up": 0.3,
	"metric_down": 0.3,
}

var _rng := RandomNumberGenerator.new()

# ══════════════════════════════════════════════════════════════════
# Life Cycle
# ══════════════════════════════════════════════════════════════════

func _ready() -> void:
	_rng.randomize()
	_create_players()
	_load_audio_events()
	_load_npc_voice_profiles()
	print("[AudioManager] Ready — events=%d, voice_profiles=%d" % [_events.size(), _npc_voice_profiles.size()])
	validate_audio_events()


# ══════════════════════════════════════════════════════════════════
# Public API
# ══════════════════════════════════════════════════════════════════

## 播放一个 audio event（通过 audio_events.json 驱动）
func play_event(event_id: String) -> void:
	if DEBUG_AUDIO:
		print("[Audio] play_event: ", event_id)

	if not _events.has(event_id):
		push_warning("[AudioManager] Unknown event: " + event_id)
		return

	var def: Dictionary = _events[event_id]
	var path: String = def.get("path", "")

	if not _check_resource(path, event_id):
		return

	# 限流检查
	var cooldown = _sfx_cooldowns.get(event_id, 0.0)
	if cooldown > 0.0:
		var last = _last_sfx_time.get(event_id, -INF)
		if Time.get_unix_time_from_system() - last < cooldown:
			return
		_last_sfx_time[event_id] = Time.get_unix_time_from_system()

	var bus: String = def.get("bus", "SFX")
	var player = _get_player_for_bus(bus)
	if player == null:
		return

	var stream: AudioStream = load(path)
	if stream == null:
		push_warning("[AudioManager] Failed to load: " + path)
		return

	player.stream = stream
	player.volume_db = def.get("volume_db", 0.0)

	var pitch_min: float = def.get("pitch_min", 1.0)
	var pitch_max: float = def.get("pitch_max", 1.0)
	player.pitch_scale = _rng.randf_range(pitch_min, pitch_max) if pitch_max > pitch_min else 1.0

	player.play()


## 播放 NPC 短语音
func play_npc_voice(npc_id: String, clip_key: String) -> void:
	if DEBUG_AUDIO:
		print("[Audio] play_npc_voice: ", npc_id, ".", clip_key)
	if not _npc_voice_profiles.has(npc_id):
		push_warning("[AudioManager] Unknown NPC voice profile: " + npc_id)
		return

	var profile: Dictionary = _npc_voice_profiles[npc_id]
	var clips: Dictionary = profile.get("clips", {})
	if not clips.has(clip_key):
		push_warning("[AudioManager] Unknown clip: " + npc_id + "." + clip_key)
		return

	var base_path: String = profile.get("base_path", "")
	var filename: String = clips[clip_key]
	var full_path: String = base_path + filename

	if not _check_resource(full_path, npc_id + "/" + clip_key):
		return

	var stream: AudioStream = load(full_path)
	if stream == null:
		return

	# Voice Player 打断上一条语音
	_voice_player.stop()
	_voice_player.stream = stream
	_voice_player.volume_db = profile.get("default_volume_db", -2.0)
	_voice_player.pitch_scale = profile.get("default_pitch", 1.0)
	_voice_player.play()


## 停止 NPC 语音
func stop_voice() -> void:
	_voice_player.stop()


## 播放背景音乐（loop）
func play_music(path: String, fade_in: float = 0.5) -> void:
	if not _check_resource(path, "music"):
		return

	var stream: AudioStream = load(path)
	if stream == null:
		return

	_music_player.stream = stream
	_music_player.volume_db = -80  # 从零开始
	_music_player.play()

	# 淡入
	var tween = create_tween()
	tween.tween_property(_music_player, "volume_db", 0.0, fade_in)


## 停止背景音乐（fade out）
func stop_music(fade_out: float = 0.5) -> void:
	var tween = create_tween()
	tween.tween_property(_music_player, "volume_db", -80.0, fade_out)
	await tween.finished
	_music_player.stop()


## 设置总音量（0.0 ~ 1.0）
func set_master_volume(v: float) -> void:
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Master"),
		linear_to_db(clamp(v, 0.0, 1.0))
	)


## 设置某个 Bus 的音量
func set_bus_volume(bus_name: String, v: float) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clamp(v, 0.0, 1.0)))


## 兼容性：保留旧的调用名称（某些脚本仍用这些方法名）
func play_interact_prompt() -> void:
	play_event("interact_prompt")

func play_dialog_open() -> void:
	play_event("ui_open_dialog")

func play_dialog_close() -> void:
	play_event("ui_close_dialog")

func play_ui_click() -> void:
	play_event("ui_click")

func play_quest_start() -> void:
	play_event("quest_start")

func play_quest_complete() -> void:
	play_event("quest_complete")

func play_quest_fail() -> void:
	play_event("quest_fail")

func play_npc_footstep() -> void:
	play_event("npc_footstep")


# ══════════════════════════════════════════════════════════════════
# Private
# ══════════════════════════════════════════════════════════════════

func _create_players() -> void:
	_ui_player = _make_player("UI", -2.0)
	_sfx_player = _make_player("SFX", 0.0)
	_voice_player = _make_player("SFX", -2.0)  # Voice 走 SFX bus until bus is configured
	_music_player = _make_player("Master", 0.0)
	_ambience_player = _make_player("Master", -3.0)


func _make_player(bus: String, vol: float) -> AudioStreamPlayer:
	var p = AudioStreamPlayer.new()
	p.bus = bus
	p.volume_db = vol
	add_child(p)
	return p


func _get_player_for_bus(bus: String) -> AudioStreamPlayer:
	match bus:
		"UI": return _ui_player
		"Voice": return _voice_player
		"Music": return _music_player
		"Ambience": return _ambience_player
		_: return _sfx_player


func _check_resource(path: String, label: String) -> bool:
	if path.is_empty():
		return false
	if not ResourceLoader.exists(path):
		# 不输出 warning — placeholder 文件首次导入时会有短暂不存在的情况
		return false
	return true


func _load_audio_events() -> void:
	if not FileAccess.file_exists(AUDIO_EVENTS_PATH):
		push_warning("[AudioManager] audio_events.json not found — audio events disabled")
		return

	var file = FileAccess.open(AUDIO_EVENTS_PATH, FileAccess.READ)
	if not file:
		push_warning("[AudioManager] Cannot open " + AUDIO_EVENTS_PATH)
		return

	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("[AudioManager] JSON parse error in audio_events.json")
		return

	var data: Dictionary = json.data
	if data.has("events"):
		_events = data["events"]


func _load_npc_voice_profiles() -> void:
	if not FileAccess.file_exists(NPC_VOICE_PROFILES_PATH):
		# 不是 error — Phase 2.8A 只需要 audio_events.json
		return

	var file = FileAccess.open(NPC_VOICE_PROFILES_PATH, FileAccess.READ)
	if not file:
		return

	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return

	var data: Dictionary = json.data
	if data.has("voices"):
		_npc_voice_profiles = data["voices"]


## ── Phase 2.8A-Verify ─────────────────────────────────────────────

func validate_audio_events() -> void:
	var missing: Array = []
	for event_id in _events.keys():
		var def: Dictionary = _events[event_id]
		var path: String = def.get("path", "")
		if path.is_empty():
			missing.append("%s → (empty path)" % event_id)
		elif not ResourceLoader.exists(path):
			missing.append("%s → %s" % [event_id, path])

	if missing.is_empty():
		print("[AudioManager] All %d audio event paths valid ✅" % _events.size())
	else:
		print("[AudioManager] Missing audio files (%d):" % missing.size())
		for m in missing:
			print("  MISSING: " + m)