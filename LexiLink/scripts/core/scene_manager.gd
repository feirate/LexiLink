# @desc: 负责场景切换、过渡动画、场景状态管理和预加载
# @author: LexiLink
# @date: 2024-07-02
extends Node

# 1. Signals
signal scene_transition_started(scene_path: String)
signal scene_transition_completed(scene_path: String)
signal scene_loaded(scene_name: String)

# 2. Constants
const SCENE_PATHS = {
	"main_menu": {"path": "res://scenes/ui/main_menu.tscn", "preload": true},
	"battle_scene": {"path": "res://scenes/gameplay/battle_scene.tscn", "preload": false},
	"settings": {"path": "res://scenes/ui/settings_panel.tscn", "preload": true},
	"card_collection": {"path": "res://scenes/ui/card_collection.tscn", "preload": false},
	"pause_menu": {"path": "res://scenes/ui/pause_menu.tscn", "preload": true},
	"loading": {"path": "res://scenes/ui/loading_screen.tscn", "preload": false},
	# Roguelike event scenes
	"treasure_scene": {"path": "res://scenes/gameplay/treasure_scene.tscn", "preload": false},
	"shop_scene": {"path": "res://scenes/gameplay/shop_scene.tscn", "preload": false},
	"rest_scene": {"path": "res://scenes/gameplay/rest_scene.tscn", "preload": false},
	"elite_scene": {"path": "res://scenes/gameplay/elite_scene.tscn", "preload": false},
	"boss_scene": {"path": "res://scenes/gameplay/boss_scene.tscn", "preload": false}
}

# 3. Exported Variables
# (None)

# 4. Private Variables
var _current_scene: Node = null
var _current_scene_path: String = ""
var _previous_scene_path: String = ""
var _preloaded_scenes: Dictionary = {}
var _loading_scenes: Dictionary = {}
var _path_to_name_map: Dictionary = {}
var _transition_overlay: Control = null
var _is_transitioning: bool = false


# 5. Lifecycle Methods
func _ready() -> void:
	print("Scene Manager 初始化...")
	_build_path_to_name_map()
	
	var tree = get_tree()
	_current_scene = tree.current_scene
	if _current_scene:
		_current_scene_path = _current_scene.scene_file_path
	
	_create_transition_overlay()
	_preload_common_scenes()
	
	print("Scene Manager 初始化完成")


# 6. Public Methods
# 根据场景路径切换场景
# @param scene_path: String - 目标场景的 .tscn 文件路径
# @param transition_type: String - 过渡动画类型 ("fade", "slide", "zoom")
func change_scene(scene_path: String, transition_type: String = "fade") -> void:
	if _is_transitioning:
		push_warning("场景正在切换中，忽略请求")
		return
	
	if scene_path == _current_scene_path:
		if GameManager and GameManager.debug_mode:
			print("已经在目标场景中")
		return
	
	if GameManager and GameManager.debug_mode:
		print("开始场景切换: %s -> %s" % [_current_scene_path, scene_path])

	_is_transitioning = true
	scene_transition_started.emit(scene_path)
	
	await _play_transition_out(transition_type)
	await _perform_scene_change(scene_path)
	await _play_transition_in(transition_type)
	
	_is_transitioning = false
	scene_transition_completed.emit(scene_path)
	
	if GameManager and GameManager.debug_mode:
		print("场景切换完成: %s" % scene_path)


# 根据场景名称切换场景
# @param scene_name: String - 目标场景的名称 (在 SCENE_PATHS 中定义)
# @param transition_type: String - 过渡动画类型
func change_scene_by_name(scene_name: String, transition_type: String = "fade") -> void:
	if scene_name in SCENE_PATHS:
		await change_scene(SCENE_PATHS[scene_name]["path"], transition_type)
	else:
		push_error("未知的场景名称: %s" % scene_name)


# 7. Private Methods
# 构建路径到名称的反向映射
func _build_path_to_name_map() -> void:
	for scene_name in SCENE_PATHS:
		var scene_data = SCENE_PATHS[scene_name]
		_path_to_name_map[scene_data["path"]] = scene_name


# 创建场景过渡覆盖层
func _create_transition_overlay() -> void:
	_transition_overlay = Control.new()
	_transition_overlay.name = "TransitionOverlay"
	_transition_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_overlay.modulate.a = 0.0
	
	var color_rect = ColorRect.new()
	color_rect.color = Color.BLACK
	color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_transition_overlay.add_child(color_rect)
	
	get_tree().root.add_child(_transition_overlay)
	_transition_overlay.z_index = 1000


# 预加载通用场景
func _preload_common_scenes() -> void:
	for scene_name in SCENE_PATHS:
		var scene_data = SCENE_PATHS[scene_name]
		if scene_data["preload"]:
			_preload_scene_async(scene_name, scene_data["path"])


# 异步预加载场景
# @param scene_name: String - 场景名称
# @param scene_path: String - 场景路径
func _preload_scene_async(scene_name: String, scene_path: String) -> void:
	if scene_name in _preloaded_scenes or scene_name in _loading_scenes:
		return
	
	if not ResourceLoader.exists(scene_path):
		push_warning("场景文件不存在: %s" % scene_path)
		return
	
	_loading_scenes[scene_name] = scene_path
	ResourceLoader.load_threaded_request(scene_path)
	
	var scene_resource = await _wait_for_scene_load(scene_path)
	_loading_scenes.erase(scene_name)
	
	if scene_resource:
		_preloaded_scenes[scene_name] = scene_resource
		scene_loaded.emit(scene_name)
		if GameManager and GameManager.debug_mode:
			print("场景预加载完成: %s" % scene_name)
	else:
		push_error("场景预加载失败: %s" % scene_path)


# 等待场景加载完成
# @param scene_path: String - 场景路径
# @return: PackedScene - 加载的场景资源，失败则返回 null
func _wait_for_scene_load(scene_path: String) -> PackedScene:
	while true:
		var status = ResourceLoader.load_threaded_get_status(scene_path)
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				return ResourceLoader.load_threaded_get(scene_path)
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				return null
			_:
				await get_tree().process_frame


# 执行实际的场景切换
# @param scene_path: String - 目标场景路径
func _perform_scene_change(scene_path: String) -> void:
	var new_scene: Node = null
	
	var scene_name = _get_scene_name_from_path(scene_path)
	if scene_name in _preloaded_scenes:
		var scene_resource = _preloaded_scenes[scene_name]
		new_scene = scene_resource.instantiate()
	else:
		if ResourceLoader.exists(scene_path):
			var scene_resource = load(scene_path)
			if scene_resource:
				new_scene = scene_resource.instantiate()
			else:
				push_error("场景加载失败: %s" % scene_path)
				return
		else:
			push_error("场景文件不存在: %s" % scene_path)
			return
	
	_previous_scene_path = _current_scene_path
	
	if _current_scene:
		_current_scene.queue_free()
		await _current_scene.tree_exited
	
	_current_scene = new_scene
	_current_scene_path = scene_path
	get_tree().root.add_child(_current_scene)
	get_tree().current_scene = _current_scene
	
	await get_tree().process_frame


# 从场景路径获取场景名称
# @param scene_path: String - 场景路径
# @return: String - 场景名称或基本文件名
func _get_scene_name_from_path(scene_path: String) -> String:
	if _path_to_name_map.has(scene_path):
		return _path_to_name_map[scene_path]
	return scene_path.get_file().get_basename()


# --- 过渡动画 ---
func _play_transition_out(transition_type: String) -> void:
	if not _transition_overlay:
		return
	
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	match transition_type:
		"fade":
			await _fade_transition(1.0, 0.5)
		_: # 默认淡入淡出
			await _fade_transition(1.0, 0.5)


func _play_transition_in(transition_type: String) -> void:
	if not _transition_overlay:
		return
	
	match transition_type:
		"fade":
			await _fade_transition(0.0, 0.5)
		_: # 默认淡入淡出
			await _fade_transition(0.0, 0.5)
	
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


# 淡入淡出动画
# @param target_alpha: float - 目标透明度 (0.0 到 1.0)
# @param duration: float - 动画时长（秒）
func _fade_transition(target_alpha: float, duration: float) -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(_transition_overlay, "modulate:a", target_alpha, duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	await tween.finished

# 场景历史管理
func go_back() -> void:
	"""返回上一个场景"""
	if _previous_scene_path.is_empty():
		push_warning("没有上一个场景记录")
		return
	
	await change_scene(_previous_scene_path)

func reload_current_scene() -> void:
	"""重新加载当前场景"""
	if _current_scene_path.is_empty():
		push_warning("没有当前场景路径")
		return
	
	await change_scene(_current_scene_path)

# 工具方法
func get_current_scene_name() -> String:
	"""获取当前场景名称"""
	return _get_scene_name_from_path(_current_scene_path)

func is_scene_preloaded(scene_name: String) -> bool:
	"""检查场景是否已预加载"""
	return scene_name in _preloaded_scenes

func clear_preloaded_scenes() -> void:
	"""清空预加载的场景缓存"""
	_preloaded_scenes.clear()
	_loading_scenes.clear()
	print("场景缓存已清空")

func get_scene_info() -> Dictionary:
	"""获取场景管理器信息"""
	return {
		"current_scene": get_current_scene_name(),
		"previous_scene": _get_scene_name_from_path(_previous_scene_path),
		"is_transitioning": _is_transitioning,
		"preloaded_count": _preloaded_scenes.size(),
		"loading_count": _loading_scenes.size()
	}

# 暂停相关
func show_pause_menu() -> void:
	"""显示暂停菜单"""
	if get_current_scene_name() == "game_scene":
		await change_scene_by_name("pause_menu", "slide")

func hide_pause_menu() -> void:
	"""隐藏暂停菜单"""
	if get_current_scene_name() == "pause_menu":
		await change_scene_by_name("game_scene", "slide") 