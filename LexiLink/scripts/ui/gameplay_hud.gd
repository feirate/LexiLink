## Gameplay HUD
# @desc: 游戏内 HUD，展示分数、准确率等信息，支持响应式布局。
# @author: Lexi
# @date: 2025-07-02

class_name GameplayHUD
extends Control

# 1. OnReady Variables
@onready var score_label: Label = $TopBar/ScoreLabel
@onready var accuracy_label: Label = $TopBar/AccuracyLabel

# 2. Private Variables
var _score: int = 0
var _accuracy: float = 0.0

# 3. Lifecycle Methods
func _ready() -> void:
	# 初始化显示
	_update_score_label()
	_update_accuracy_label()

# 4. Public API
# 设置分数
# @param new_score: int - 新的分数值
func set_score(new_score: int) -> void:
	_score = new_score
	_update_score_label()

# 设置准确率
# @param new_accuracy: float - 新的准确率 (0.0 to 1.0)
func set_accuracy(new_accuracy: float) -> void:
	_accuracy = clampf(new_accuracy, 0.0, 1.0)
	_update_accuracy_label()

# 5. Private Methods
# 更新分数标签的文本
func _update_score_label() -> void:
	if score_label:
		score_label.text = "分数: %d" % _score

# 更新准确率标签的文本
func _update_accuracy_label() -> void:
	if accuracy_label:
		accuracy_label.text = "准确率: %.0f%%" % (_accuracy * 100) 