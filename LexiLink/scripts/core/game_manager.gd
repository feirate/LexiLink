## LexiLink 游戏主管理器
## 负责整个游戏的状态管理、流程控制和核心系统协调
extends Node

# 游戏状态枚举
enum GameState {
    LOADING,        # 加载中
    MAIN_MENU,      # 主菜单
    GAME_PLAYING,   # 游戏进行中
    GAME_PAUSED,    # 游戏暂停
    GAME_COMPLETED, # 游戏完成
    SETTINGS        # 设置界面
}

# 信号定义
signal game_state_changed(old_state: GameState, new_state: GameState)
signal game_session_started(session_data: Dictionary)
signal game_session_completed(results: Dictionary)

# 当前游戏状态
var current_state: GameState = GameState.LOADING
var previous_state: GameState = GameState.LOADING

# 游戏数据
var current_session_data: Dictionary = {}
var player_progress: Dictionary = {}

# 配置参数
@export var debug_mode: bool = false
@export var auto_save_interval: float = 30.0  # 自动保存间隔(秒)

func _ready() -> void:
    print("LexiLink Game Manager 初始化...")
    
    # 设置单例引用
    set_process(true)
    set_process_unhandled_input(true)
    
    # 初始化核心系统
    await initialize_core_systems()
    
    # 加载用户数据
    await load_player_progress()
    
    # 切换到主菜单状态
    change_game_state(GameState.MAIN_MENU)
    
    print("Game Manager 初始化完成")

func initialize_core_systems() -> void:
    """初始化核心系统"""
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
    connect_manager_signals()
    
    # 启动自动保存定时器
    var auto_save_timer = Timer.new()
    auto_save_timer.wait_time = auto_save_interval
    auto_save_timer.timeout.connect(_auto_save_progress)
    auto_save_timer.autostart = true
    add_child(auto_save_timer)

func connect_manager_signals() -> void:
    """连接管理器信号"""
    # 连接数据管理器信号
    if DataManager.has_signal("save_completed"):
        DataManager.save_completed.connect(_on_save_completed)
    
    # 连接场景管理器信号
    if SceneManager.has_signal("scene_transition_started"):
        SceneManager.scene_transition_started.connect(_on_scene_transition_started)

func change_game_state(new_state: GameState) -> void:
    """改变游戏状态"""
    if new_state == current_state:
        return
    
    var old_state = current_state
    previous_state = current_state
    current_state = new_state
    
    print("游戏状态改变: %s -> %s" % [GameState.keys()[old_state], GameState.keys()[new_state]])
    
    # 处理状态转换逻辑
    handle_state_transition(old_state, new_state)
    
    # 发出状态改变信号
    game_state_changed.emit(old_state, new_state)

func handle_state_transition(old_state: GameState, new_state: GameState) -> void:
    """处理状态转换逻辑"""
    match new_state:
        GameState.LOADING:
            # 显示加载界面
            pass
            
        GameState.MAIN_MENU:
            # 确保回到主菜单
            SceneManager.change_scene("res://scenes/ui/main_menu.tscn")
            
        GameState.GAME_PLAYING:
            # 开始游戏会话
            start_game_session()
            
        GameState.GAME_PAUSED:
            # 暂停游戏
            pause_game()
            
        GameState.GAME_COMPLETED:
            # 游戏完成处理
            complete_game_session()
            
        GameState.SETTINGS:
            # 显示设置界面
            pass

func start_game_session() -> void:
    """开始游戏会话"""
    current_session_data = {
        "start_time": Time.get_unix_time_from_system(),
        "score": 0,
        "correct_connections": 0,
        "total_attempts": 0,
        "current_level": 1,
        "cards_collected": []
    }
    
    print("游戏会话开始")
    game_session_started.emit(current_session_data)

func pause_game() -> void:
    """暂停游戏"""
    get_tree().paused = true

func resume_game() -> void:
    """恢复游戏"""
    get_tree().paused = false
    change_game_state(GameState.GAME_PLAYING)

func complete_game_session() -> void:
    """完成游戏会话"""
    current_session_data["end_time"] = Time.get_unix_time_from_system()
    current_session_data["duration"] = current_session_data["end_time"] - current_session_data["start_time"]
    
    # 计算准确率
    if current_session_data["total_attempts"] > 0:
        current_session_data["accuracy"] = float(current_session_data["correct_connections"]) / current_session_data["total_attempts"]
    else:
        current_session_data["accuracy"] = 0.0
    
    print("游戏会话完成，准确率: %.2f%%" % (current_session_data["accuracy"] * 100))
    
    # 更新玩家进度
    update_player_progress(current_session_data)
    
    game_session_completed.emit(current_session_data)

func update_player_progress(session_data: Dictionary) -> void:
    """更新玩家进度"""
    if not player_progress.has("total_sessions"):
        player_progress["total_sessions"] = 0
        player_progress["total_score"] = 0
        player_progress["best_accuracy"] = 0.0
        player_progress["cards_collected"] = []
        player_progress["achievements"] = []
    
    # 更新统计数据
    player_progress["total_sessions"] += 1
    player_progress["total_score"] += session_data["score"]
    
    if session_data["accuracy"] > player_progress["best_accuracy"]:
        player_progress["best_accuracy"] = session_data["accuracy"]
    
    # 添加新收集的卡片
    for card in session_data["cards_collected"]:
        if card not in player_progress["cards_collected"]:
            player_progress["cards_collected"].append(card)
    
    # 保存进度
    save_player_progress()

func load_player_progress() -> void:
    """加载玩家进度"""
    if DataManager:
        player_progress = await DataManager.load_user_data("player_progress", {})
        print("玩家进度已加载，总会话数: %d" % player_progress.get("total_sessions", 0))

func save_player_progress() -> void:
    """保存玩家进度"""
    if DataManager:
        DataManager.save_user_data("player_progress", player_progress)

func _auto_save_progress() -> void:
    """自动保存进度"""
    if current_state == GameState.GAME_PLAYING:
        save_player_progress()
        if debug_mode:
            print("自动保存完成")

func _on_save_completed(success: bool) -> void:
    """保存完成回调"""
    if debug_mode:
        print("数据保存%s" % ("成功" if success else "失败"))

func _on_scene_transition_started(scene_path: String) -> void:
    """场景转换开始回调"""
    if debug_mode:
        print("场景转换开始: %s" % scene_path)

func _input(event: InputEvent) -> void:
    """处理全局输入"""
    # ESC键处理
    if event.is_action_pressed("ui_cancel"):
        match current_state:
            GameState.GAME_PLAYING:
                change_game_state(GameState.GAME_PAUSED)
            GameState.GAME_PAUSED:
                resume_game()
            GameState.SETTINGS:
                change_game_state(previous_state)

# 公共API方法
func get_player_progress() -> Dictionary:
    """获取玩家进度数据"""
    return player_progress.duplicate()

func get_current_session_data() -> Dictionary:
    """获取当前会话数据"""
    return current_session_data.duplicate()

func is_game_playing() -> bool:
    """检查游戏是否正在进行"""
    return current_state == GameState.GAME_PLAYING

func add_score(points: int) -> void:
    """添加分数"""
    if current_state == GameState.GAME_PLAYING:
        current_session_data["score"] += points

func record_connection_attempt(is_correct: bool) -> void:
    """记录连接尝试"""
    if current_state == GameState.GAME_PLAYING:
        current_session_data["total_attempts"] += 1
        if is_correct:
            current_session_data["correct_connections"] += 1 