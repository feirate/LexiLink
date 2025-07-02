# @desc: 负责音效播放、背景音乐管理、音节语音播放和音频资源缓存
# @author: LexiLink
# @date: 2024-07-02
extends Node

# 1. Signals
signal audio_loaded(audio_id: String)
signal playback_finished(audio_id: String)
signal volume_changed(volume_type: String, new_volume: float)

# 2. Constants
const SYLLABLE_AUDIO_PATH = "res://assets/audio/syllables/"
const SFX_AUDIO_PATH = "res://assets/audio/effects/"
const MUSIC_AUDIO_PATH = "res://assets/audio/music/"
const UI_AUDIO_PATH = "res://assets/audio/ui/"

const MAX_CACHE_SIZE = 100
const SYLLABLE_CACHE_SIZE = 200

# 3. Private Variables
var _music_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _syllable_player: AudioStreamPlayer
var _ui_player: AudioStreamPlayer

var _audio_cache: Dictionary = {}
var _syllable_cache: Dictionary = {}

var _master_volume: float = 1.0
var _music_volume: float = 0.8
var _sfx_volume: float = 0.7
var _syllable_volume: float = 0.9


# 4. Lifecycle Methods
func _ready() -> void:
	print("Audio Manager 初始化...")
	
	_create_audio_players()
	_load_volume_settings()
	
	await _preload_common_audio()
	
	print("Audio Manager 初始化完成")


# 5. Public Methods
# 播放背景音乐
# @param music_id: String - 音乐文件的ID (不含扩展名)
# @param loop: bool - 是否循环播放
func play_music(music_id: String, loop: bool = true) -> void:
	var stream = await _get_or_load_audio_stream(music_id, MUSIC_AUDIO_PATH)
	if stream:
		_music_player.stream = stream
		_music_player.play()
		# Godot's loop is a property on the stream itself
		if stream is AudioStreamOggVorbis:
			stream.loop = loop


# 停止背景音乐
func stop_music() -> void:
	_music_player.stop()


# 播放音效
# @param sfx_id: String - 音效文件的ID (不含扩展名)
func play_sfx(sfx_id: String) -> void:
	_play_sound(_sfx_player, sfx_id, SFX_AUDIO_PATH)


# 播放UI音效
# @param ui_sound_id: String - UI音效文件的ID (不含扩展名)
func play_ui_sound(ui_sound_id: String) -> void:
	_play_sound(_ui_player, ui_sound_id, UI_AUDIO_PATH)


# 播放音节语音
# @param syllable_id: String - 音节的ID
func play_syllable(syllable_id: String) -> void:
	var audio_stream = await _get_or_load_syllable_audio(syllable_id)
	if audio_stream:
		if _syllable_player.playing:
			_syllable_player.stop()
		_syllable_player.stream = audio_stream
		_syllable_player.play()
	else:
		push_warning("音节音频不存在: %s" % syllable_id)


# 设置主音量
# @param volume: float - 音量值 (0.0 to 1.0)
func set_master_volume(volume: float) -> void:
	_master_volume = clampf(volume, 0.0, 1.0)
	_apply_volume_settings()
	volume_changed.emit("master", _master_volume)


# 设置音乐音量
# @param volume: float - 音量值 (0.0 to 1.0)
func set_music_volume(volume: float) -> void:
	_music_volume = clampf(volume, 0.0, 1.0)
	_apply_volume_settings()
	volume_changed.emit("music", _music_volume)


# 6. Private Methods
# 创建音频播放器节点
func _create_audio_players() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = "Music"
	add_child(_music_player)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "SfxPlayer"
	_sfx_player.bus = "SFX"
	add_child(_sfx_player)

	_syllable_player = AudioStreamPlayer.new()
	_syllable_player.name = "SyllablePlayer"
	_syllable_player.bus = "Voice"
	add_child(_syllable_player)

	_ui_player = AudioStreamPlayer.new()
	_ui_player.name = "UIPlayer"
	_ui_player.bus = "UI"
	add_child(_ui_player)

	_music_player.finished.connect(func(): playback_finished.emit("music"))


# 从配置加载音量设置
func _load_volume_settings() -> void:
	if DataManager:
		_master_volume = DataManager.get_config_value("master_volume", 1.0)
		_music_volume = DataManager.get_config_value("music_volume", 0.8)
		_sfx_volume = DataManager.get_config_value("sfx_volume", 0.7)
		_syllable_volume = DataManager.get_config_value("syllable_volume", 0.9)
	_apply_volume_settings()


# 应用音量设置到音频总线
func _apply_volume_settings() -> void:
	_set_bus_volume("Music", _music_volume * _master_volume)
	_set_bus_volume("SFX", _sfx_volume * _master_volume)
	_set_bus_volume("UI", _sfx_volume * _master_volume) # UI sound uses SFX volume
	_set_bus_volume("Voice", _syllable_volume * _master_volume)


# 设置总线音量的辅助函数
# @param bus_name: String - 音频总线名称
# @param linear_volume: float - 线性音量 (0.0 to 1.0)
func _set_bus_volume(bus_name: String, linear_volume: float) -> void:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear_volume))


# 预加载常用音频
func _preload_common_audio() -> void:
	if GameManager and GameManager.debug_mode:
		print("预加载常用音频...")

	# 定义需要预加载的音频
	var sounds_to_preload = {
		UI_AUDIO_PATH: ["button_click", "button_hover", "card_select", "success", "error"],
		SFX_AUDIO_PATH: ["connection_success", "connection_fail", "card_collect"]
	}

	for path in sounds_to_preload:
		for sound_id in sounds_to_preload[path]:
			_get_or_load_audio_stream(sound_id, path)


# 通用音频播放函数
# @param player: AudioStreamPlayer - 用于播放的节点
# @param sound_id: String - 音频ID (不含扩展名)
# @param path_prefix: String - 音频文件所在目录
func _play_sound(player: AudioStreamPlayer, sound_id: String, path_prefix: String) -> void:
	var stream = await _get_or_load_audio_stream(sound_id, path_prefix)
	if stream:
		player.stream = stream
		player.play()


# 获取或加载音频流（通用）
# @param audio_id: String - 音频ID
# @param path_prefix: String - 路径
# @return: AudioStream - 音频流
func _get_or_load_audio_stream(audio_id: String, path_prefix: String) -> AudioStream:
	if audio_id in _audio_cache:
		return _audio_cache[audio_id]
	
	var file_path = path_prefix.path_join(audio_id) + ".ogg"
	if not ResourceLoader.exists(file_path):
		push_warning("音频文件不存在: %s" % file_path)
		return null

	# 使用线程加载以避免卡顿
	ResourceLoader.load_threaded_request(file_path)
	var resource = await ResourceLoader.load_threaded_get(file_path)

	if resource is AudioStream:
		if _audio_cache.size() >= MAX_CACHE_SIZE:
			_remove_oldest_from_cache(_audio_cache)
		_audio_cache[audio_id] = resource
		audio_loaded.emit(audio_id)
		return resource
	else:
		push_error("无法加载或资源类型错误: %s" % file_path)
		return null


# 获取或加载音节音频
# @param syllable_id: String - 音节ID
# @return: AudioStream - 音频流
func _get_or_load_syllable_audio(syllable_id: String) -> AudioStream:
	if syllable_id in _syllable_cache:
		return _syllable_cache[syllable_id]
	
	var audio_path = SYLLABLE_AUDIO_PATH + syllable_id + ".ogg"
	if ResourceLoader.exists(audio_path):
		var audio_stream = load(audio_path)
		if audio_stream is AudioStream:
			if _syllable_cache.size() >= SYLLABLE_CACHE_SIZE:
				_remove_oldest_from_cache(_syllable_cache)
			_syllable_cache[syllable_id] = audio_stream
			return audio_stream
	return null


# 从指定缓存中移除最旧的条目
# @param cache: Dictionary - 目标缓存字典
func _remove_oldest_from_cache(cache: Dictionary) -> void:
	if not cache.is_empty():
		var oldest_key = cache.keys()[0]
		cache.erase(oldest_key)
		if GameManager and GameManager.debug_mode:
			print("从缓存中移除: %s" % oldest_key) 