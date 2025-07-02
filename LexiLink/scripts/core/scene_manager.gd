## LexiLink 场景管理器
## 负责场景切换、过渡动画、场景状态管理和预加载
extends Node

# 信号定义
signal scene_transition_started(scene_path: String)
signal scene_transition_completed(scene_path: String)
signal scene_loaded(scene_name: String)

# 当前场景信息
var current_scene: Node = null
var current_scene_path: String = ""
var previous_scene_path: String = ""

# 场景预加载缓存
var preloaded_scenes: Dictionary = {}
var loading_scenes: Dictionary = {}

# 过渡效果
var transition_overlay: Control = null
var is_transitioning: bool = false

# 场景路径配置
const SCENE_PATHS = {
    "main_menu": "res://scenes/ui/main_menu.tscn",
    "game_scene": "res://scenes/gameplay/game_scene.tscn", 
    "settings": "res://scenes/ui/settings_panel.tscn",
    "card_collection": "res://scenes/ui/card_collection.tscn",
    "pause_menu": "res://scenes/ui/pause_menu.tscn",
    "loading": "res://scenes/ui/loading_screen.tscn"
}

func _ready() -> void:
    print("Scene Manager 初始化...")
    
    # 获取当前场景
    var tree = get_tree()
    current_scene = tree.current_scene
    
    if current_scene:
        current_scene_path = current_scene.scene_file_path
        print("当前场景: %s" % current_scene_path)
    
    # 创建过渡覆盖层
    create_transition_overlay()
    
    # 预加载常用场景
    preload_common_scenes()
    
    print("Scene Manager 初始化完成")

func create_transition_overlay() -> void:
    """创建场景过渡覆盖层"""
    transition_overlay = Control.new()
    transition_overlay.name = "TransitionOverlay"
    transition_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    transition_overlay.modulate.a = 0.0
    
    # 添加背景
    var color_rect = ColorRect.new()
    color_rect.color = Color.BLACK
    color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    transition_overlay.add_child(color_rect)
    
    # 添加加载提示
    var loading_label = Label.new()
    loading_label.text = "Loading..."
    loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    loading_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    transition_overlay.add_child(loading_label)
    
    # 添加到场景树
    get_tree().root.add_child(transition_overlay)
    transition_overlay.z_index = 1000  # 确保在最上层

func preload_common_scenes() -> void:
    """预加载常用场景"""
    var common_scenes = ["main_menu", "settings", "pause_menu"]
    
    for scene_name in common_scenes:
        if scene_name in SCENE_PATHS:
            preload_scene_async(scene_name, SCENE_PATHS[scene_name])

func preload_scene_async(scene_name: String, scene_path: String) -> void:
    """异步预加载场景"""
    if scene_name in preloaded_scenes or scene_name in loading_scenes:
        return
    
    if not ResourceLoader.exists(scene_path):
        push_warning("场景文件不存在: %s" % scene_path)
        return
    
    loading_scenes[scene_name] = scene_path
    ResourceLoader.load_threaded_request(scene_path)
    
    # 异步等待加载完成
    var scene_resource = await wait_for_scene_load(scene_path)
    loading_scenes.erase(scene_name)
    
    if scene_resource:
        preloaded_scenes[scene_name] = scene_resource
        scene_loaded.emit(scene_name)
        print("场景预加载完成: %s" % scene_name)
    else:
        push_error("场景预加载失败: %s" % scene_path)

func wait_for_scene_load(scene_path: String) -> PackedScene:
    """等待场景加载完成"""
    while true:
        var status = ResourceLoader.load_threaded_get_status(scene_path)
        match status:
            ResourceLoader.THREAD_LOAD_LOADED:
                return ResourceLoader.load_threaded_get(scene_path)
            ResourceLoader.THREAD_LOAD_FAILED:
                return null
            ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
                return null
            _:
                await get_tree().process_frame

# 场景切换API
func change_scene(scene_path: String, transition_type: String = "fade") -> void:
    """切换到指定场景"""
    if is_transitioning:
        push_warning("场景正在切换中，忽略请求")
        return
    
    if scene_path == current_scene_path:
        print("已经在目标场景中")
        return
    
    print("开始场景切换: %s -> %s" % [current_scene_path, scene_path])
    is_transitioning = true
    
    scene_transition_started.emit(scene_path)
    
    # 执行过渡动画
    await play_transition_out(transition_type)
    
    # 切换场景
    await perform_scene_change(scene_path)
    
    # 播放过渡入场动画
    await play_transition_in(transition_type)
    
    is_transitioning = false
    scene_transition_completed.emit(scene_path)
    
    print("场景切换完成: %s" % scene_path)

func change_scene_by_name(scene_name: String, transition_type: String = "fade") -> void:
    """根据场景名称切换场景"""
    if scene_name in SCENE_PATHS:
        await change_scene(SCENE_PATHS[scene_name], transition_type)
    else:
        push_error("未知的场景名称: %s" % scene_name)

func perform_scene_change(scene_path: String) -> void:
    """执行实际的场景切换"""
    var new_scene: Node = null
    
    # 检查是否有预加载的场景
    var scene_name = get_scene_name_from_path(scene_path)
    if scene_name in preloaded_scenes:
        var scene_resource = preloaded_scenes[scene_name]
        new_scene = scene_resource.instantiate()
        print("使用预加载场景: %s" % scene_name)
    else:
        # 直接加载场景
        if ResourceLoader.exists(scene_path):
            var scene_resource = load(scene_path)
            if scene_resource:
                new_scene = scene_resource.instantiate()
                print("直接加载场景: %s" % scene_path)
            else:
                push_error("场景加载失败: %s" % scene_path)
                return
        else:
            push_error("场景文件不存在: %s" % scene_path)
            return
    
    # 保存前一个场景路径
    previous_scene_path = current_scene_path
    
    # 移除当前场景
    if current_scene:
        current_scene.queue_free()
        await current_scene.tree_exited
    
    # 设置新场景
    current_scene = new_scene
    current_scene_path = scene_path
    get_tree().root.add_child(current_scene)
    get_tree().current_scene = current_scene
    
    # 等待场景初始化
    await get_tree().process_frame

func get_scene_name_from_path(scene_path: String) -> String:
    """从场景路径获取场景名称"""
    for scene_name in SCENE_PATHS:
        if SCENE_PATHS[scene_name] == scene_path:
            return scene_name
    return scene_path.get_file().get_basename()

# 过渡动画
func play_transition_out(transition_type: String) -> void:
    """播放退场过渡动画"""
    if not transition_overlay:
        return
    
    transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    
    match transition_type:
        "fade":
            await fade_transition_out()
        "slide":
            await slide_transition_out()
        "zoom":
            await zoom_transition_out()
        _:
            await fade_transition_out()

func play_transition_in(transition_type: String) -> void:
    """播放入场过渡动画"""
    if not transition_overlay:
        return
    
    match transition_type:
        "fade":
            await fade_transition_in()
        "slide":
            await slide_transition_in()
        "zoom":
            await zoom_transition_in()
        _:
            await fade_transition_in()
    
    transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

func fade_transition_out() -> void:
    """淡出过渡"""
    var tween = create_tween()
    tween.set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(transition_overlay, "modulate:a", 1.0, 0.3)
    await tween.finished

func fade_transition_in() -> void:
    """淡入过渡"""
    var tween = create_tween()
    tween.set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(transition_overlay, "modulate:a", 0.0, 0.3)
    await tween.finished

func slide_transition_out() -> void:
    """滑动退出过渡"""
    transition_overlay.modulate.a = 1.0
    transition_overlay.position.x = -get_viewport().get_visible_rect().size.x
    
    var tween = create_tween()
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(transition_overlay, "position:x", 0.0, 0.4)
    await tween.finished

func slide_transition_in() -> void:
    """滑动进入过渡"""
    var tween = create_tween()
    tween.set_ease(Tween.EASE_IN)
    tween.tween_property(transition_overlay, "position:x", get_viewport().get_visible_rect().size.x, 0.4)
    await tween.finished
    
    transition_overlay.position.x = 0
    transition_overlay.modulate.a = 0.0

func zoom_transition_out() -> void:
    """缩放退出过渡"""
    transition_overlay.modulate.a = 1.0
    transition_overlay.scale = Vector2.ZERO
    
    var tween = create_tween()
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(transition_overlay, "scale", Vector2.ONE, 0.5)
    await tween.finished

func zoom_transition_in() -> void:
    """缩放进入过渡"""
    var tween = create_tween()
    tween.set_ease(Tween.EASE_IN)
    tween.tween_property(transition_overlay, "scale", Vector2(2.0, 2.0), 0.3)
    tween.parallel().tween_property(transition_overlay, "modulate:a", 0.0, 0.3)
    await tween.finished
    
    transition_overlay.scale = Vector2.ONE

# 场景历史管理
func go_back() -> void:
    """返回上一个场景"""
    if previous_scene_path.is_empty():
        push_warning("没有上一个场景记录")
        return
    
    await change_scene(previous_scene_path)

func reload_current_scene() -> void:
    """重新加载当前场景"""
    if current_scene_path.is_empty():
        push_warning("没有当前场景路径")
        return
    
    await change_scene(current_scene_path)

# 工具方法
func get_current_scene_name() -> String:
    """获取当前场景名称"""
    return get_scene_name_from_path(current_scene_path)

func is_scene_preloaded(scene_name: String) -> bool:
    """检查场景是否已预加载"""
    return scene_name in preloaded_scenes

func clear_preloaded_scenes() -> void:
    """清空预加载的场景缓存"""
    preloaded_scenes.clear()
    loading_scenes.clear()
    print("场景缓存已清空")

func get_scene_info() -> Dictionary:
    """获取场景管理器信息"""
    return {
        "current_scene": get_current_scene_name(),
        "previous_scene": get_scene_name_from_path(previous_scene_path),
        "is_transitioning": is_transitioning,
        "preloaded_count": preloaded_scenes.size(),
        "loading_count": loading_scenes.size()
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