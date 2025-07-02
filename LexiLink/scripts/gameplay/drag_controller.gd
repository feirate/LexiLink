## Drag Controller
# @desc: 统一处理音节卡的拖拽、连接验证、划线渲染及音视频反馈，兼容鼠标和触摸操作。
# @author: LexiLink
# @date: 2024-07-02

class_name DragController
extends Node

# 1. Signals
signal connection_valid(from_card: SyllableCard, to_card: SyllableCard)
signal connection_invalid(from_card: SyllableCard, to_card: SyllableCard)

# 2. Dependencies
var _line_node: Line2D
var _audio_manager: AudioManager

# 3. Private Variables
var _current_card: SyllableCard = null
var _start_pos: Vector2 = Vector2.ZERO

# 4. Lifecycle Methods
func _ready() -> void:
	# 依赖项应在场景中预先设置或通过Autoload获取
	_line_node = get_node_or_null("Line2D") # 假设Line2D是子节点
	_audio_manager = get_node_or_null("/root/AudioManager")
	
	if not _line_node:
		push_error("DragController: Line2D 节点未找到")
	if not _audio_manager:
		push_warning("DragController: AudioManager 未找到")

	_connect_existing_cards()
	get_tree().node_added.connect(_on_node_added)

# 5. Public API
# (None)

# 6. Private Helpers
# 连接场景中已存在的卡片信号
func _connect_existing_cards() -> void:
	for card in get_tree().get_nodes_in_group("syllable_cards"):
		if card is SyllableCard:
			_connect_card_signals(card)

# 连接单个卡片的信号
func _connect_card_signals(card: SyllableCard) -> void:
	if not card.drag_started.is_connected(_on_drag_started):
		card.drag_started.connect(_on_drag_started.bind(card))
	if not card.drag_moved.is_connected(_on_drag_moved):
		card.drag_moved.connect(_on_drag_moved.bind(card))
	if not card.drag_ended.is_connected(_on_drag_ended):
		card.drag_ended.connect(_on_drag_ended.bind(card))

# 在拖拽位置获取卡片节点
func _get_card_at_pos(pos: Vector2, exclude: SyllableCard) -> SyllableCard:
	for node in get_tree().get_nodes_in_group("syllable_cards"):
		if node == exclude:
			continue
		if node is SyllableCard and node.get_global_rect().has_point(pos):
			return node
	return null

# 更新拖拽指示线
func _update_line(end_pos: Vector2) -> void:
	if not _line_node:
		return
	if _line_node.get_point_count() == 0:
		_line_node.add_point(_start_pos)
		_line_node.add_point(end_pos)
	else:
		_line_node.set_point_position(1, end_pos)

# 清除拖拽指示线
func _clear_line() -> void:
	if _line_node:
		_line_node.clear_points()

# 播放连接反馈
func _play_feedback(success: bool) -> void:
	if _audio_manager:
		var sound_id = "connection_success" if success else "connection_fail"
		_audio_manager.play_sfx(sound_id)

# 7. Signal Callbacks
# 拖拽开始时的回调
func _on_drag_started(global_pos: Vector2, card: SyllableCard) -> void:
	_current_card = card
	_start_pos = global_pos
	_update_line(global_pos)

# 拖拽过程中的回调
func _on_drag_moved(global_pos: Vector2, card: SyllableCard) -> void:
	if card != _current_card:
		return
	_update_line(global_pos)

# 拖拽结束时的回调
func _on_drag_ended(global_pos: Vector2, card: SyllableCard) -> void:
	if card != _current_card:
		return

	var target_card: SyllableCard = _get_card_at_pos(global_pos, exclude=_current_card)
	if target_card:
		var is_valid = ConnectionValidator.validate_connection(_current_card, target_card)
		if is_valid:
			connection_valid.emit(_current_card, target_card)
		else:
			connection_invalid.emit(_current_card, target_card)
		_play_feedback(is_valid)
	else:
		_play_feedback(false)

	_current_card = null
	_clear_line()

# 当新节点添加到场景树时的回调，用于连接动态生成的卡片
func _on_node_added(node: Node) -> void:
	if node is SyllableCard:
		_connect_card_signals(node) 