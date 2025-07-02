## Roguelike Event Manager for LexiLink
# @desc: 负责管理肉鸽关卡中的事件序列，包括路径选择和事件执行。
# @author: LexiLink
# @date: 2024-07-02

class_name EventManager
extends Node

# 1. Signals
signal level_started(level_data: Array)
signal event_started(event_type: String, index: int)
signal event_completed(event_type: String, index: int, result: Dictionary)
signal level_completed(level_data: Array)

# 2. Dependencies
var _level_generator: RoguelikeLevelGenerator
var _path_selection_panel: PathSelectionPanel

# 3. Private Variables
var _level_data: Array[String] = []
var _current_index: int = -1
var _event_rng: RandomNumberGenerator = RandomNumberGenerator.new()


# 4. Lifecycle Methods
func _ready() -> void:
	# 依赖项通常通过 Autoload 获取，这里使用 get_node 作为示例
	_level_generator = get_node_or_null("/root/RoguelikeLevelGenerator")
	_path_selection_panel = get_node_or_null("/root/PathSelectionPanel")


# 5. Public API
# 开始一个新关卡
# @param seed: int - 关卡生成的种子，-1表示随机
# @param difficulty: int - 关卡难度
func start_new_level(seed: int = -1, difficulty: int = 0) -> void:
	if not _level_generator:
		push_error("EventManager: level_generator 引用缺失")
		return
	
	_level_generator.difficulty_level = difficulty
	_level_data = _level_generator.generate_level(seed)
	_current_index = -1
	
	level_started.emit(_level_data)
	_advance_to_next_event()


# 在当前事件完成后进入下一个事件
# @param result: Dictionary - 当前事件的结果
func proceed_to_next_event(result: Dictionary = {}) -> void:
	if _current_index < 0:
		return  # 关卡未开始
	
	var event_type = _level_data[_current_index]
	event_completed.emit(event_type, _current_index, result)
	_advance_to_next_event()


# 获取当前事件类型
# @return: String - 当前事件的类型字符串
func get_current_event() -> String:
	if _current_index >= 0 and _current_index < _level_data.size():
		return _level_data[_current_index]
	return ""


# 获取关卡进度
# @return: float - 进度百分比 (0.0 to 1.0)
func get_level_progress() -> float:
	if _level_data.is_empty():
		return 0.0
	return float(_current_index + 1) / _level_data.size()


# 6. Private Helpers
# 前进到下一个事件
func _advance_to_next_event() -> void:
	_current_index += 1
	
	if _current_index >= _level_data.size():
		level_completed.emit(_level_data)
		return
	
	var event_type = _level_data[_current_index]

	if _current_index > 0:
		_offer_path_choices(event_type)
	else:
		event_started.emit(event_type, _current_index)
		_handle_event(event_type)


# 提供路径选择
func _offer_path_choices(default_event: String) -> void:
	var alternative_event = _pick_alternative_event(default_event)
	var choices = [default_event, alternative_event]

	if not _path_selection_panel:
		push_error("EventManager: PathSelectionPanel 未找到")
		_handle_event(default_event) # 如果UI不存在，则自动选择默认路径
		return

	_path_selection_panel.choice_selected.connect(_on_path_choice_made, CONNECT_ONESHOT)
	_path_selection_panel.show_choices(choices)


# 随机选择一个备用事件
func _pick_alternative_event(exclude_event: String) -> String:
	var pool = _level_generator.event_type_pool.duplicate()
	pool.erase(exclude_event)
	if pool.is_empty():
		return exclude_event
	return pool[_event_rng.randi_range(0, pool.size() - 1)]


# 处理事件逻辑
func _handle_event(event_type: String) -> void:
	if not SceneManager:
		push_error("EventManager: SceneManager 未找到")
		return
	
	var scene_name = event_type + "_scene"
	if SceneManager.SCENE_PATHS.has(scene_name):
		SceneManager.change_scene_by_name(scene_name)
	else:
		push_warning("未处理的事件类型或场景未在SceneManager中定义: %s" % event_type)


# 7. Signal Callbacks
# 当玩家做出路径选择时的回调
# @param event_type: String - 玩家选择的事件类型
func _on_path_choice_made(event_type: String) -> void:
	event_started.emit(event_type, _current_index)
	_handle_event(event_type) 