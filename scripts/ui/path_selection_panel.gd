## Path Selection Panel for Roguelike progression
# @desc: 为肉鸽玩法的路径选择提供UI，显示可用事件并发出选择信号。
# @author: LexiLink
# @date: 2024-07-02

class_name PathSelectionPanel
extends Control

# 1. Signals
signal choice_selected(event_type: String)

# 2. OnReady Variables
@onready var choices_container: VBoxContainer = $ChoicesContainer
@onready var choice_button_scene: PackedScene = preload("res://scenes/ui/components/choice_button.tscn") # 假设有一个按钮场景模板

# 3. Private Variables
var _available_choices: Array[String] = []


# 4. Lifecycle Methods
func _ready() -> void:
	visible = false # 默认隐藏


# 5. Public API
# 显示路径选项
# @param choices: Array[String] - 事件类型的数组
func show_choices(choices: Array[String]) -> void:
	_available_choices = choices
	_populate_ui()
	visible = true


# 6. Private Methods
# 根据选项数据填充UI
func _populate_ui() -> void:
	# 清空现有选项
	for child in choices_container.get_children():
		child.queue_free()

	if not choice_button_scene:
		push_error("PathSelectionPanel: choice_button_scene 未设置")
		return

	for event_type in _available_choices:
		var button_instance = choice_button_scene.instantiate()
		button_instance.text = _translate_event_to_chinese(event_type)
		button_instance.pressed.connect(_on_choice_button_pressed.bind(event_type))
		choices_container.add_child(button_instance)


# 将事件类型翻译为中文
# @param event_type: String - 事件类型
# @return: String - 中文名称
func _translate_event_to_chinese(event_type: String) -> String:
	match event_type:
		"battle": return "战斗"
		"treasure": return "宝藏"
		"shop": return "商店"
		"rest": return "休息"
		"elite": return "精英"
		"boss": return "首领"
		_: return event_type.capitalize()


# 7. Signal Callbacks
# 当选择按钮被按下时
# @param event_type: String - 绑定的事件类型
func _on_choice_button_pressed(event_type: String) -> void:
	choice_selected.emit(event_type)
	visible = false 