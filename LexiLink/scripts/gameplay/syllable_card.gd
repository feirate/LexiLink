## Syllable Card
# @desc: 代表一个可拖拽的音节卡片，是构成单词的基本视觉单元。
# @author: LexiLink
# @date: 2024-07-02

class_name SyllableCard
extends Control

# 1. Signals
signal drag_started(global_position: Vector2)
signal drag_moved(global_position: Vector2)
signal drag_ended(global_position: Vector2)

# 2. Constants & Enums
enum SyllableType { VOWEL, CONSONANT, LIQUID, OTHER }

# 3. Exported Variables
@export var syllable_text: String = "" : set = _set_syllable_text
@export var syllable_type: SyllableType = SyllableType.VOWEL
@export var rarity: int = 0

# 4. OnReady Variables
@onready var syllable_label: Label = $SyllableLabel

# 5. Private Variables
var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

# 6. Lifecycle Methods
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_to_group("syllable_cards")

# 7. Public Methods
# 设置卡片音节
# @param text: String - 音节文本
# @param s_type: SyllableType - 音节类型
func set_syllable(text: String, s_type: SyllableType) -> void:
	self.syllable_text = text
	self.syllable_type = s_type

func is_vowel() -> bool:
	return syllable_type == SyllableType.VOWEL

# 8. Private Methods
func _set_syllable_text(new_text: String) -> void:
	syllable_text = new_text
	if syllable_label:
		syllable_label.text = new_text
	else:
		if is_inside_tree():
			await ready
			syllable_label.text = new_text

# 8. Input Handling Logic (Private)
# 开始拖拽
func _on_drag_start(pos: Vector2) -> void:
	_is_dragging = true
	_drag_offset = get_global_mouse_position() - global_position
	drag_started.emit(get_global_mouse_position())
	raise() # Bring to front for better visibility

# 拖拽中
func _on_drag_move(pos: Vector2) -> void:
	global_position = pos - _drag_offset
	drag_moved.emit(pos)

# 结束拖拽
func _on_drag_end(pos: Vector2) -> void:
	_is_dragging = false
	drag_ended.emit(pos)

func _unhandled_input(event: InputEvent) -> void:
	if _is_dragging:
		if event is InputEventMouseMotion:
			_on_drag_move(event.position)
		elif event is InputEventScreenDrag:
			_on_drag_move(event.position)
		elif event.is_action_released("ui_accept"): # Corresponds to mouse up or touch release
			_on_drag_end(get_global_mouse_position())
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and get_rect().has_point(to_local(event.position)):
			_on_drag_start(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		if get_rect().has_point(to_local(event.position)):
			_on_drag_start(event.position) 