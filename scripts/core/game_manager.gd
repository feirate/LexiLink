# @desc: 负责整个游戏的状态管理、流程控制和核心系统协调
# @author: LexiLink
# @date: 2024-07-02
extends Node

# 1. Signals
signal game_state_changed(old_state: GameState, new_state: GameState)
signal game_session_started(session_data: Dictionary)
signal game_session_completed(results: Dictionary)

# 2. Constants
# 游戏状态枚举
enum GameState {
	LOADING,        # 加载中
	MAIN_MENU,      # 主菜单
	GAME_PLAYING,   # 游戏进行中
	GAME_PAUSED,    # 游戏暂停
	GAME_COMPLETED, # 游戏完成
	SETTINGS        # 设置界面
}

# 3. Exported Variables
@export var debug_mode: bool = false
@export var auto_save_interval: float = 30.0  # 自动保存间隔(秒)

# 4. Private Variables
var _current_state: GameState = GameState.LOADING
var _previous_state: GameState = GameState.LOADING
var _current_session_data: Dictionary = {}
var _player_progress: Dictionary = {}


# 5. Lifecycle Methods
func _ready() -> void:
	print("LexiLink Game Manager 初始化...")
	
	# 设置单例引用
	set_process(true)
	set_process_unhandled_input(true)
	
	# 初始化核心系统
	await _initialize_core_systems()
	
	# 加载用户数据
	await _load_player_progress()
	
	# 切换到主菜单状态
	change_game_state(GameState.MAIN_MENU)
	
	print("Game Manager 初始化完成")


func _input(event: InputEvent) -> void:
	# ESC键处理
	if event.is_action_pressed("ui_cancel"):
		match _current_state:
			GameState.GAME_PLAYING:
				change_game_state(GameState.GAME_PAUSED)
			GameState.GAME_PAUSED:
				resume_game()
			GameState.SETTINGS:
				change_game_state(_previous_state)


# 6. Public Methods
# 改变游戏状态
# @param new_state: GameState - 要切换到的新状态
func change_game_state(new_state: GameState) -> void:
	if new_state == _current_state:
		return
	
	var old_state = _current_state
	_previous_state = _current_state
	_current_state = new_state
	
	if debug_mode:
		print("游戏状态改变: %s -> %s" % [GameState.keys()[old_state], GameState.keys()[new_state]])
	
	# 处理状态转换逻辑
	_handle_state_transition(old_state, new_state)
	
	# 发出状态改变信号
	game_state_changed.emit(old_state, new_state)


# 恢复游戏
func resume_game() -> void:
	get_tree().paused = false
	change_game_state(GameState.GAME_PLAYING)


# 获取玩家进度数据
# @return: Dictionary - 玩家进度的副本
func get_player_progress() -> Dictionary:
	return _player_progress.duplicate()


# 7. Private Methods
# 初始化核心系统
func _initialize_core_systems() -> void:
	if debug_mode:
		print("正在初始化核心系统...")
	
	# 等待其他自动加载完成
	await get_tree().process_frame
	
	# 验证管理器是否正确加载
	if not DataManager:
		push_error("DataManager 未正确加载")
		return
		
	if not AudioManager:
		push_error("AudioManager 未正确加载")
		return
		
	if not SceneManager:
		push_error("SceneManager 未正确加载")
		return
	
	# 连接信号
	_connect_manager_signals()
	
	# 启动自动保存定时器
	var auto_save_timer = Timer.new()
	auto_save_timer.wait_time = auto_save_interval
	auto_save_timer.timeout.connect(_auto_save_progress)
	auto_save_timer.autostart = true
	add_child(auto_save_timer)


# 连接管理器信号
func _connect_manager_signals() -> void:
	# 连接数据管理器信号
	if DataManager.has_signal("save_completed"):
		DataManager.save_completed.connect(_on_save_completed)
	
	# 连接场景管理器信号
	if SceneManager.has_signal("scene_transition_started"):
		SceneManager.scene_transition_started.connect(_on_scene_transition_started)


# 处理状态转换逻辑
func _handle_state_transition(old_state: GameState, new_state: GameState) -> void:
	match new_state:
		GameState.LOADING:
			# 显示加载界面
			pass
			
		GameState.MAIN_MENU:
			# 确保回到主菜单
			get_tree().paused = false
			SceneManager.change_scene_by_name("main_menu")
			
		GameState.GAME_PLAYING:
			# 直接开始游戏会话，由EventManager负责加载第一个场景
			_start_game_session()
			
		GameState.GAME_PAUSED:
			# 暂停游戏
			_pause_game()
			
		GameState.GAME_COMPLETED:
			# 游戏完成处理
			_complete_game_session()
			
		GameState.SETTINGS:
			# 显示设置界面
			pass


# 开始游戏会话
func _start_game_session() -> void:
	_current_session_data = {
		"start_time": Time.get_unix_time_from_system(),
		"score": 0,
		"correct_connections": 0,
		"total_attempts": 0,
		"current_level": 1,
		"cards_collected": []
	}
	
	if debug_mode:
		print("游戏会话开始")
	game_session_started.emit(_current_session_data)
	
	# 生成新的肉鸽关卡
	if EventManager:
		var difficulty = clamp(_current_session_data["current_level"] - 1, 0, 2)
		EventManager.start_new_level(-1, difficulty)
	else:
		push_warning("EventManager 未在Autoload中注册")


# 暂停游戏
func _pause_game() -> void:
	get_tree().paused = true


# 完成游戏会话
func _complete_game_session() -> void:
	_current_session_data["end_time"] = Time.get_unix_time_from_system()
	_current_session_data["duration"] = _current_session_data["end_time"] - _current_session_data["start_time"]
	
	# 计算准确率
	if _current_session_data["total_attempts"] > 0:
		_current_session_data["accuracy"] = float(_current_session_data["correct_connections"]) / _current_session_data["total_attempts"]
	else:
		_current_session_data["accuracy"] = 0.0
	
	if debug_mode:
		print("游戏会话完成，准确率: %.2f%%" % (_current_session_data["accuracy"] * 100))
	
	# 更新玩家进度
	_update_player_progress(_current_session_data)
	
	game_session_completed.emit(_current_session_data)


# 更新玩家进度
func _update_player_progress(session_data: Dictionary) -> void:
	if not _player_progress.has("total_sessions"):
		_player_progress["total_sessions"] = 0
		_player_progress["total_score"] = 0
		_player_progress["best_accuracy"] = 0.0
		_player_progress["cards_collected"] = []
		_player_progress["achievements"] = []
	
	# 更新统计数据
	_player_progress["total_sessions"] += 1
	_player_progress["total_score"] += session_data["score"]
	
	if session_data["accuracy"] > _player_progress["best_accuracy"]:
		_player_progress["best_accuracy"] = session_data["accuracy"]
	
	# 添加新收集的卡片
	for card in session_data["cards_collected"]:
		if card not in _player_progress["cards_collected"]:
			_player_progress["cards_collected"].append(card)
	
	# 保存进度
	_save_player_progress()


# 加载玩家进度
func _load_player_progress() -> void:
	if DataManager:
		_player_progress = await DataManager.load_user_data("player_progress", {})
		if debug_mode:
			print("玩家进度已加载，总会话数: %d" % _player_progress.get("total_sessions", 0))


# 保存玩家进度
func _save_player_progress() -> void:
	if DataManager:
		DataManager.save_user_data("player_progress", _player_progress)


# 自动保存进度
func _auto_save_progress() -> void:
	if _current_state == GameState.GAME_PLAYING:
		_save_player_progress()
		if debug_mode:
			print("自动保存完成")


# 保存完成回调
func _on_save_completed() -> void:
	if debug_mode:
		print("自动保存完成")


# 场景转换开始回调
func _on_scene_transition_started(scene_path: String) -> void:
	# 可以在此显示加载动画
	pass

func get_current_session_data() -> Dictionary:
	"""获取当前会话数据"""
	return _current_session_data.duplicate()

func is_game_playing() -> bool:
	"""检查游戏是否正在进行"""
	return _current_state == GameState.GAME_PLAYING

func add_score(points: int) -> void:
	"""添加分数"""
	if _current_state == GameState.GAME_PLAYING:
		_current_session_data["score"] += points 