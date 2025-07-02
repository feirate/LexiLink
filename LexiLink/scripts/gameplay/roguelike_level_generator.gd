## Roguelike level generator for LexiLink
# @desc: 为游戏的肉鸽模式生成随机的关卡路径和事件序列。
# @author: LexiLink
# @date: 2024-07-02

class_name RoguelikeLevelGenerator
extends Node

# 1. Signals
signal level_generated(level_data: Array)

# 2. Constants
const DEFAULT_LEVEL_LENGTH: int = 10
const DEFAULT_EVENT_TYPES: Array[String] = [
    "battle",
    "treasure",
    "shop",
    "rest",
    "elite",
    "boss"
]

# Weight presets per difficulty level (0=easy)
const EVENT_WEIGHTS_PRESETS: Array[Dictionary] = [
    { # Easy
        "battle": 40,
        "treasure": 20,
        "shop": 15,
        "rest": 15,
        "elite": 9,
        "boss": 1
    },
    { # Medium
        "battle": 35,
        "treasure": 15,
        "shop": 15,
        "rest": 10,
        "elite": 20,
        "boss": 5
    },
    { # Hard
        "battle": 30,
        "treasure": 10,
        "shop": 10,
        "rest": 5,
        "elite": 30,
        "boss": 15
    }
]

# 3. Exported Variables
@export var level_length: int = DEFAULT_LEVEL_LENGTH
@export var event_type_pool: Array[String] = DEFAULT_EVENT_TYPES
@export var difficulty_level: int = 0

# 4. Private Variables
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _total_weights: Array[int] = []

# 5. Lifecycle Methods
func _ready() -> void:
    _rng.randomize()
    _calculate_total_weights()

# 6. Public Methods
func generate_level(seed: int = -1) -> Array[String]:
    """
    Generates a sequence of events for the current level.
    @param seed: Optional seed for deterministic generation
    @return: An Array of event type strings representing the path
    """
    if seed != -1:
        _rng.seed = seed
    
    # 约束输入值
    var current_difficulty = clamp(difficulty_level, 0, EVENT_WEIGHTS_PRESETS.size() - 1)
    var current_length = max(level_length, 1)

    var level_data: Array[String] = []
    for i in current_length:
        level_data.append(_pick_weighted_event(current_difficulty))
    
    if current_length > 0:
        level_data[current_length - 1] = "boss" # 确保最后一个事件是Boss
    
    level_generated.emit(level_data)
    return level_data

# 7. Private Methods
func _calculate_total_weights() -> void:
    _total_weights.clear()
    for weights in EVENT_WEIGHTS_PRESETS:
        var total = 0
        for key in weights:
            if key in event_type_pool:
                total += weights[key]
        _total_weights.append(total)

func _pick_weighted_event(difficulty: int) -> String:
    var weights = EVENT_WEIGHTS_PRESETS[difficulty]
    var total_weight = _total_weights[difficulty]

    if total_weight <= 0:
        push_warning("总权重为0，无法选择事件，返回默认值 'battle'")
        return "battle"

    var roll = _rng.randi_range(1, total_weight)
    var cumulative = 0
    for event_type in weights:
        if not event_type in event_type_pool:
            continue
        cumulative += weights[event_type]
        if roll <= cumulative:
            return event_type
            
    return "battle" # Fallback 