## LexiLink 音频管理器
## 负责音效播放、背景音乐管理、音节语音播放和音频资源缓存
extends Node

# 信号定义
signal audio_loaded(audio_id: String)
signal playback_finished(audio_id: String)
signal volume_changed(volume_type: String, new_volume: float)

# 音频播放器节点
@onready var music_player: AudioStreamPlayer
@onready var sfx_player: AudioStreamPlayer  
@onready var syllable_player: AudioStreamPlayer
@onready var ui_player: AudioStreamPlayer

# 音频缓存
var audio_cache: Dictionary = {}
var syllable_cache: Dictionary = {}

# 音量配置
var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 0.7
var syllable_volume: float = 0.9

# 音频资源路径
const SYLLABLE_AUDIO_PATH = "res://assets/audio/syllables/"
const SFX_AUDIO_PATH = "res://assets/audio/effects/"
const MUSIC_AUDIO_PATH = "res://assets/audio/music/"
const UI_AUDIO_PATH = "res://assets/audio/ui/"

# 缓存限制
const MAX_CACHE_SIZE = 100
const SYLLABLE_CACHE_SIZE = 200

func _ready() -> void:
    print("Audio Manager 初始化...")
    
    # 创建音频播放器
    create_audio_players()
    
    # 从配置加载音量设置
    load_volume_settings()
    
    # 预加载常用音频
    await preload_common_audio()
    
    print("Audio Manager 初始化完成")

func create_audio_players() -> void:
    """创建音频播放器节点"""
    # 背景音乐播放器
    music_player = AudioStreamPlayer.new()
    music_player.name = "MusicPlayer"
    music_player.bus = "Music"
    add_child(music_player)
    
    # 音效播放器
    sfx_player = AudioStreamPlayer.new()
    sfx_player.name = "SfxPlayer"
    sfx_player.bus = "SFX"
    add_child(sfx_player)
    
    # 音节语音播放器
    syllable_player = AudioStreamPlayer.new()
    syllable_player.name = "SyllablePlayer"
    syllable_player.bus = "Voice"
    add_child(syllable_player)
    
    # UI音效播放器
    ui_player = AudioStreamPlayer.new()
    ui_player.name = "UIPlayer"
    ui_player.bus = "UI"
    add_child(ui_player)
    
    # 连接播放完成信号
    music_player.finished.connect(_on_music_finished)
    sfx_player.finished.connect(_on_sfx_finished)
    syllable_player.finished.connect(_on_syllable_finished)
    ui_player.finished.connect(_on_ui_finished)

func load_volume_settings() -> void:
    """从配置加载音量设置"""
    if DataManager:
        master_volume = DataManager.get_config("master_volume", 1.0)
        music_volume = DataManager.get_config("music_volume", 0.8)
        sfx_volume = DataManager.get_config("sfx_volume", 0.7)
        syllable_volume = DataManager.get_config("syllable_volume", 0.9)
        
        # 应用音量设置
        apply_volume_settings()

func apply_volume_settings() -> void:
    """应用音量设置到音频总线"""
    # 获取音频总线
    var music_bus_idx = AudioServer.get_bus_index("Music")
    var sfx_bus_idx = AudioServer.get_bus_index("SFX")
    var voice_bus_idx = AudioServer.get_bus_index("Voice")
    var ui_bus_idx = AudioServer.get_bus_index("UI")
    
    # 设置音量 (转换为分贝)
    if music_bus_idx != -1:
        AudioServer.set_bus_volume_db(music_bus_idx, linear_to_db(music_volume * master_volume))
    
    if sfx_bus_idx != -1:
        AudioServer.set_bus_volume_db(sfx_bus_idx, linear_to_db(sfx_volume * master_volume))
    
    if voice_bus_idx != -1:
        AudioServer.set_bus_volume_db(voice_bus_idx, linear_to_db(syllable_volume * master_volume))
    
    if ui_bus_idx != -1:
        AudioServer.set_bus_volume_db(ui_bus_idx, linear_to_db(sfx_volume * master_volume))

func preload_common_audio() -> void:
    """预加载常用音频"""
    print("预加载常用音频...")
    
    # 预加载UI音效
    var ui_sounds = [
        "button_click.ogg",
        "button_hover.ogg", 
        "card_select.ogg",
        "card_drop.ogg",
        "success.ogg",
        "error.ogg"
    ]
    
    for sound_file in ui_sounds:
        load_audio_async(UI_AUDIO_PATH + sound_file, "ui_" + sound_file.get_basename())
    
    # 预加载游戏音效
    var game_sounds = [
        "connection_success.ogg",
        "connection_fail.ogg",
        "card_collect.ogg",
        "level_complete.ogg"
    ]
    
    for sound_file in game_sounds:
        load_audio_async(SFX_AUDIO_PATH + sound_file, "game_" + sound_file.get_basename())

func load_audio_async(file_path: String, audio_id: String) -> void:
    """异步加载音频文件"""
    if audio_id in audio_cache:
        return
    
    # 检查文件是否存在
    if not ResourceLoader.exists(file_path):
        push_warning("音频文件不存在: %s" % file_path)
        return
    
    # 使用线程加载请求
    ResourceLoader.load_threaded_request(file_path)
    
    # 等待加载完成
    var resource = await wait_for_resource_load(file_path)
    
    if resource and resource is AudioStream:
        # 检查缓存大小
        if audio_cache.size() >= MAX_CACHE_SIZE:
            remove_oldest_cached_audio()
        
        audio_cache[audio_id] = resource
        audio_loaded.emit(audio_id)
        print("音频已加载: %s" % audio_id)
    else:
        push_error("无法加载音频: %s" % file_path)

func wait_for_resource_load(file_path: String) -> Resource:
    """等待资源加载完成"""
    while true:
        var status = ResourceLoader.load_threaded_get_status(file_path)
        match status:
            ResourceLoader.THREAD_LOAD_LOADED:
                return ResourceLoader.load_threaded_get(file_path)
            ResourceLoader.THREAD_LOAD_FAILED:
                return null
            ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
                return null
            _:
                await get_tree().process_frame

func remove_oldest_cached_audio() -> void:
    """移除最旧的缓存音频"""
    if audio_cache.size() > 0:
        var oldest_key = audio_cache.keys()[0]
        audio_cache.erase(oldest_key)
        print("移除缓存音频: %s" % oldest_key)

# 音节语音播放
func play_syllable(syllable_id: String) -> void:
    """播放音节语音"""
    var audio_stream = get_syllable_audio(syllable_id)
    
    if audio_stream:
        if syllable_player.playing:
            syllable_player.stop()
        
        syllable_player.stream = audio_stream
        syllable_player.play()
        print("播放音节: %s" % syllable_id)
    else:
        push_warning("音节音频不存在: %s" % syllable_id)

func get_syllable_audio(syllable_id: String) -> AudioStream:
    """获取音节音频流"""
    # 先检查缓存
    if syllable_id in syllable_cache:
        return syllable_cache[syllable_id]
    
    # 尝试加载音频文件
    var audio_path = SYLLABLE_AUDIO_PATH + syllable_id + ".ogg"
    
    if ResourceLoader.exists(audio_path):
        var audio_stream = load(audio_path)
        
        if audio_stream:
            # 添加到缓存
            if syllable_cache.size() >= SYLLABLE_CACHE_SIZE:
                remove_oldest_syllable_cache()
            
            syllable_cache[syllable_id] = audio_stream
            return audio_stream
    
    return null

func remove_oldest_syllable_cache() -> void:
    """移除最旧的音节缓存"""
    if syllable_cache.size() > 0:
        var oldest_key = syllable_cache.keys()[0]
        syllable_cache.erase(oldest_key)

# 音效播放
func play_sfx(sfx_id: String) -> void:
    """播放音效"""
    var audio_stream = get_cached_audio(sfx_id)
    
    if not audio_stream:
        # 尝试直接加载
        var sfx_path = SFX_AUDIO_PATH + sfx_id + ".ogg"
        if ResourceLoader.exists(sfx_path):
            audio_stream = load(sfx_path)
    
    if audio_stream:
        sfx_player.stream = audio_stream
        sfx_player.play()
        print("播放音效: %s" % sfx_id)
    else:
        push_warning("音效不存在: %s" % sfx_id)

func play_ui_sound(sound_id: String) -> void:
    """播放UI音效"""
    var audio_stream = get_cached_audio("ui_" + sound_id)
    
    if audio_stream:
        ui_player.stream = audio_stream
        ui_player.play()
    else:
        push_warning("UI音效不存在: %s" % sound_id)

func get_cached_audio(audio_id: String) -> AudioStream:
    """获取缓存的音频"""
    return audio_cache.get(audio_id, null)

# 背景音乐
func play_music(music_id: String, loop: bool = true) -> void:
    """播放背景音乐"""
    var music_path = MUSIC_AUDIO_PATH + music_id + ".ogg"
    
    if ResourceLoader.exists(music_path):
        var music_stream = load(music_path)
        
        if music_stream:
            if music_player.playing:
                fade_out_music()
                await music_player.finished
            
            music_player.stream = music_stream
            
            # 设置循环
            if music_stream is AudioStreamOggVorbis:
                music_stream.loop = loop
            
            music_player.play()
            print("播放背景音乐: %s" % music_id)
        else:
            push_error("无法加载背景音乐: %s" % music_id)
    else:
        push_warning("背景音乐文件不存在: %s" % music_id)

func stop_music() -> void:
    """停止背景音乐"""
    if music_player.playing:
        music_player.stop()

func fade_out_music(duration: float = 1.0) -> void:
    """淡出背景音乐"""
    if music_player.playing:
        var tween = create_tween()
        tween.tween_property(music_player, "volume_db", -80, duration)
        tween.tween_callback(music_player.stop)
        tween.tween_callback(func(): music_player.volume_db = 0)

# 音量控制
func set_master_volume(volume: float) -> void:
    """设置主音量"""
    master_volume = clamp(volume, 0.0, 1.0)
    apply_volume_settings()
    save_volume_setting("master_volume", master_volume)
    volume_changed.emit("master", master_volume)

func set_music_volume(volume: float) -> void:
    """设置音乐音量"""
    music_volume = clamp(volume, 0.0, 1.0)
    apply_volume_settings()
    save_volume_setting("music_volume", music_volume)
    volume_changed.emit("music", music_volume)

func set_sfx_volume(volume: float) -> void:
    """设置音效音量"""
    sfx_volume = clamp(volume, 0.0, 1.0)
    apply_volume_settings()
    save_volume_setting("sfx_volume", sfx_volume)
    volume_changed.emit("sfx", sfx_volume)

func set_syllable_volume(volume: float) -> void:
    """设置音节音量"""
    syllable_volume = clamp(volume, 0.0, 1.0)
    apply_volume_settings()
    save_volume_setting("syllable_volume", syllable_volume)
    volume_changed.emit("syllable", syllable_volume)

func save_volume_setting(key: String, value: float) -> void:
    """保存音量设置"""
    if DataManager:
        DataManager.set_config(key, value)

# 工具方法
func is_playing(player_type: String) -> bool:
    """检查是否正在播放"""
    match player_type:
        "music":
            return music_player.playing
        "sfx":
            return sfx_player.playing
        "syllable":
            return syllable_player.playing
        "ui":
            return ui_player.playing
        _:
            return false

func stop_all() -> void:
    """停止所有音频播放"""
    music_player.stop()
    sfx_player.stop()
    syllable_player.stop()
    ui_player.stop()

func get_volume(volume_type: String) -> float:
    """获取音量值"""
    match volume_type:
        "master":
            return master_volume
        "music":
            return music_volume
        "sfx":
            return sfx_volume
        "syllable":
            return syllable_volume
        _:
            return 0.0

# 信号回调
func _on_music_finished() -> void:
    playback_finished.emit("music")

func _on_sfx_finished() -> void:
    playback_finished.emit("sfx")

func _on_syllable_finished() -> void:
    playback_finished.emit("syllable")

func _on_ui_finished() -> void:
    playback_finished.emit("ui")

# 缓存管理
func clear_audio_cache() -> void:
    """清空音频缓存"""
    audio_cache.clear()
    syllable_cache.clear()
    print("音频缓存已清空")

func get_cache_info() -> Dictionary:
    """获取缓存信息"""
    return {
        "audio_cache_size": audio_cache.size(),
        "syllable_cache_size": syllable_cache.size(),
        "total_cached_items": audio_cache.size() + syllable_cache.size()
    } 