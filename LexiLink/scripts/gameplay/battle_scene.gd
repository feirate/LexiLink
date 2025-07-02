## Battle Scene Script
# @desc: 核心战斗场景，负责管理音节卡片的生成、拼接验证和关卡事件交互。
# @author: LexiLink
# @date: 2024-07-02

class_name BattleScene
extends Node2D

# 1. Signals
signal battle_completed(result: Dictionary)

# 2. Exported Variables
@export var hud_scene: PackedScene
@export var syllable_card_scene: PackedScene

# 3. Private Variables
var _hud: GameplayHUD
var _current_word_data: Dictionary
var _active_cards: Array[Node] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


# 4. Lifecycle Methods
func _ready() -> void:
	_spawn_hud()
	
	# EventManager 是 Autoload，可以直接访问
	if EventManager:
		EventManager.event_started.connect(_on_battle_started)
	else:
		push_error("BattleScene: EventManager not found.")


# 5. Public API
# 更新分数显示
# @param score: int - 新的分数
func update_score(score: int) -> void:
	if _hud:
		_hud.set_score(score)


# 更新准确率显示
# @param accuracy: float - 新的准确率
func update_accuracy(accuracy: float) -> void:
	if _hud:
		_hud.set_accuracy(accuracy)


# 6. Private Methods
func _on_battle_started(event_type: String, index: int) -> void:
	if event_type != "battle":
		return

	if not DataManager:
		push_error("BattleScene: DataManager not found.")
		return
	
	var db = DataManager.get_syllable_database()
	if not db.has("common_words") or db["common_words"].is_empty():
		push_error("BattleScene: 'common_words' not found or empty in syllable database.")
		return
		
	var words = db["common_words"].keys()
	var random_word = words[_rng.randi_range(0, words.size() - 1)]
	_current_word_data = db["common_words"][random_word]
	
	print("战斗开始! 目标单词: %s, 音节: %s" % [random_word, _current_word_data["syllables"]])
	
	_spawn_syllable_cards()


# 实例化并添加HUD到场景
func _spawn_hud() -> void:
	if hud_scene:
		_hud = hud_scene.instantiate()
		add_child(_hud)
	else:
		push_error("BattleScene: hud_scene 未设置")


func _clear_cards() -> void:
	for card in _active_cards:
		card.queue_free()
	_active_cards.clear()


func _spawn_syllable_cards() -> void:
	if not syllable_card_scene:
		push_error("BattleScene: syllable_card_scene is not set.")
		return
		
	_clear_cards()
	
	var syllables = _current_word_data["syllables"]
	var viewport_size = get_viewport_rect().size
	
	for s_text in syllables:
		var card_instance = syllable_card_scene.instantiate()
		add_child(card_instance)
		
		# TODO: 获取真实的音节类型，目前默认为VOWEL
		card_instance.set_syllable(s_text, SyllableCard.SyllableType.VOWEL)
		
		# 在屏幕可视区域内随机放置
		var x_pos = _rng.randf_range(50, viewport_size.x - 50)
		var y_pos = _rng.randf_range(100, viewport_size.y - 100)
		card_instance.global_position = Vector2(x_pos, y_pos)
		
		_active_cards.append(card_instance) 