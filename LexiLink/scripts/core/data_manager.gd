## LexiLink 数据管理器
## 负责本地数据存储、音节数据管理、用户配置和静态数据加载
extends Node

# 信号定义
signal save_completed(success: bool)
signal data_loaded(data_type: String, data: Dictionary)
signal syllable_data_updated()

# 数据路径配置
const USER_DATA_PATH = "user://save_data.json"
const CONFIG_PATH = "user://config.json"
const SYLLABLE_DATA_PATH = "res://data/syllables/"
const CARD_DATA_PATH = "res://data/cards/"

# 缓存数据
var syllable_database: Dictionary = {}
var card_database: Dictionary = {}
var user_config: Dictionary = {}
var cached_user_data: Dictionary = {}

# 默认配置
var default_config: Dictionary = {
    "audio_volume": 0.8,
    "sfx_volume": 0.7,
    "language": "zh_CN",
    "difficulty": "medium",
    "tutorial_completed": false,
    "first_launch": true
}

func _ready() -> void:
    print("Data Manager 初始化...")
    
    # 确保用户数据目录存在
    ensure_user_directory()
    
    # 加载配置文件
    load_config()
    
    # 预加载静态数据
    await preload_static_data()
    
    print("Data Manager 初始化完成")

func ensure_user_directory() -> void:
    """确保用户数据目录存在"""
    var dir = DirAccess.open("user://")
    if not dir:
        push_error("无法访问用户数据目录")

func load_config() -> void:
    """加载用户配置"""
    if FileAccess.file_exists(CONFIG_PATH):
        var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
        if file:
            var json_string = file.get_as_text()
            file.close()
            
            var json = JSON.new()
            var parse_result = json.parse(json_string)
            
            if parse_result == OK:
                user_config = json.data
                print("用户配置已加载")
            else:
                print("配置文件解析失败，使用默认配置")
                user_config = default_config.duplicate()
        else:
            print("无法打开配置文件，使用默认配置")
            user_config = default_config.duplicate()
    else:
        print("配置文件不存在，创建默认配置")
        user_config = default_config.duplicate()
        save_config()

func save_config() -> void:
    """保存用户配置"""
    var file = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
    if file:
        var json_string = JSON.stringify(user_config)
        file.store_string(json_string)
        file.close()
        print("用户配置已保存")
    else:
        push_error("无法保存配置文件")

func preload_static_data() -> void:
    """预加载静态数据"""
    print("正在加载静态数据...")
    
    # 加载音节数据
    await load_syllable_database()
    
    # 加载卡片数据  
    await load_card_database()
    
    print("静态数据加载完成")

func load_syllable_database() -> void:
    """加载音节数据库"""
    var syllable_files = [
        "basic_syllables.json",
        "advanced_syllables.json",
        "special_syllables.json"
    ]
    
    for file_name in syllable_files:
        var file_path = SYLLABLE_DATA_PATH + file_name
        if ResourceLoader.exists(file_path):
            var resource = load(file_path)
            if resource is Resource:
                # 如果是Godot资源文件
                print("加载音节资源: %s" % file_name)
            else:
                # 如果是JSON文件
                var file_data = load_json_file(file_path)
                if file_data:
                    syllable_database.merge(file_data)
                    print("加载音节数据: %s" % file_name)
        else:
            # 创建示例数据
            if file_name == "basic_syllables.json":
                create_sample_syllable_data()

func create_sample_syllable_data() -> void:
    """创建示例音节数据"""
    var sample_data = {
        "vowels": {
            "a": {"type": "vowel", "difficulty": 1, "audio_file": "a.ogg"},
            "e": {"type": "vowel", "difficulty": 1, "audio_file": "e.ogg"},
            "i": {"type": "vowel", "difficulty": 1, "audio_file": "i.ogg"},
            "o": {"type": "vowel", "difficulty": 1, "audio_file": "o.ogg"},
            "u": {"type": "vowel", "difficulty": 1, "audio_file": "u.ogg"}
        },
        "consonants": {
            "b": {"type": "consonant", "difficulty": 1, "audio_file": "b.ogg"},
            "c": {"type": "consonant", "difficulty": 1, "audio_file": "c.ogg"},
            "d": {"type": "consonant", "difficulty": 1, "audio_file": "d.ogg"},
            "f": {"type": "consonant", "difficulty": 1, "audio_file": "f.ogg"},
            "g": {"type": "consonant", "difficulty": 1, "audio_file": "g.ogg"}
        },
        "common_words": {
            "cat": {"syllables": ["c", "a", "t"], "difficulty": 2, "meaning": "猫"},
            "dog": {"syllables": ["d", "o", "g"], "difficulty": 2, "meaning": "狗"},
            "sun": {"syllables": ["s", "u", "n"], "difficulty": 2, "meaning": "太阳"},
            "run": {"syllables": ["r", "u", "n"], "difficulty": 2, "meaning": "跑"}
        }
    }
    
    syllable_database.merge(sample_data)
    save_json_file(SYLLABLE_DATA_PATH + "basic_syllables.json", sample_data)

func load_card_database() -> void:
    """加载卡片数据库"""
    # 基于音节数据生成卡片数据
    card_database = {
        "rarities": {
            "common": {"color": "#FFFFFF", "probability": 0.6},
            "uncommon": {"color": "#00FF00", "probability": 0.25},
            "rare": {"color": "#0080FF", "probability": 0.1},
            "epic": {"color": "#8000FF", "probability": 0.04},
            "legendary": {"color": "#FF8000", "probability": 0.01}
        },
        "card_types": {
            "syllable": {"base_score": 10},
            "word": {"base_score": 50},
            "special": {"base_score": 100}
        }
    }

func load_json_file(file_path: String) -> Dictionary:
    """加载JSON文件"""
    if not FileAccess.file_exists(file_path):
        return {}
    
    var file = FileAccess.open(file_path, FileAccess.READ)
    if not file:
        push_error("无法打开文件: %s" % file_path)
        return {}
    
    var json_string = file.get_as_text()
    file.close()
    
    var json = JSON.new()
    var parse_result = json.parse(json_string)
    
    if parse_result == OK:
        return json.data
    else:
        push_error("JSON解析失败: %s" % file_path)
        return {}

func save_json_file(file_path: String, data: Dictionary) -> bool:
    """保存JSON文件"""
    # 确保目录存在
    var dir_path = file_path.get_base_dir()
    var dir = DirAccess.open("res://")
    if not dir.dir_exists(dir_path):
        dir.make_dir_recursive(dir_path)
    
    var file = FileAccess.open(file_path, FileAccess.WRITE)
    if not file:
        push_error("无法创建文件: %s" % file_path)
        return false
    
    var json_string = JSON.stringify(data, "\t")
    file.store_string(json_string)
    file.close()
    
    return true

# 用户数据管理
func save_user_data(key: String, data: Variant) -> void:
    """保存用户数据"""
    # 加载现有数据
    var all_data = load_all_user_data()
    
    # 更新指定键的数据
    all_data[key] = data
    
    # 保存到文件
    var file = FileAccess.open(USER_DATA_PATH, FileAccess.WRITE)
    if file:
        var json_string = JSON.stringify(all_data)
        file.store_string(json_string)
        file.close()
        
        # 更新缓存
        cached_user_data[key] = data
        
        save_completed.emit(true)
        print("用户数据已保存: %s" % key)
    else:
        push_error("无法保存用户数据")
        save_completed.emit(false)

func load_user_data(key: String, default_value: Variant = null) -> Variant:
    """加载用户数据"""
    # 先检查缓存
    if key in cached_user_data:
        return cached_user_data[key]
    
    # 从文件加载
    var all_data = load_all_user_data()
    
    if key in all_data:
        cached_user_data[key] = all_data[key]
        return all_data[key]
    else:
        return default_value

func load_all_user_data() -> Dictionary:
    """加载所有用户数据"""
    if not FileAccess.file_exists(USER_DATA_PATH):
        return {}
    
    var file = FileAccess.open(USER_DATA_PATH, FileAccess.READ)
    if not file:
        push_error("无法打开用户数据文件")
        return {}
    
    var json_string = file.get_as_text()
    file.close()
    
    var json = JSON.new()
    var parse_result = json.parse(json_string)
    
    if parse_result == OK:
        return json.data
    else:
        push_error("用户数据解析失败")
        return {}

# 音节数据API
func get_syllable_data(syllable_id: String) -> Dictionary:
    """获取音节数据"""
    for category in syllable_database.values():
        if syllable_id in category:
            return category[syllable_id]
    return {}

func get_syllables_by_type(syllable_type: String) -> Array:
    """根据类型获取音节列表"""
    var result = []
    
    for category_name in syllable_database:
        var category = syllable_database[category_name]
        for syllable_id in category:
            var syllable_data = category[syllable_id]
            if syllable_data.get("type", "") == syllable_type:
                result.append({
                    "id": syllable_id,
                    "data": syllable_data
                })
    
    return result

func get_syllables_by_difficulty(difficulty: int) -> Array:
    """根据难度获取音节列表"""
    var result = []
    
    for category_name in syllable_database:
        var category = syllable_database[category_name]
        for syllable_id in category:
            var syllable_data = category[syllable_id]
            if syllable_data.get("difficulty", 1) == difficulty:
                result.append({
                    "id": syllable_id,
                    "data": syllable_data
                })
    
    return result

func get_word_data(word: String) -> Dictionary:
    """获取单词数据"""
    if "common_words" in syllable_database:
        return syllable_database["common_words"].get(word, {})
    return {}

func validate_syllable_connection(from_syllable: String, to_syllable: String) -> bool:
    """验证音节连接规则"""
    var from_data = get_syllable_data(from_syllable)
    var to_data = get_syllable_data(to_syllable)
    
    if from_data.is_empty() or to_data.is_empty():
        return false
    
    var from_type = from_data.get("type", "")
    var to_type = to_data.get("type", "")
    
    # 基础连接规则
    match from_type:
        "vowel":
            return to_type == "consonant"
        "consonant":
            return to_type in ["vowel", "liquid"]
        _:
            return false

# 配置管理API
func get_config(key: String, default_value: Variant = null) -> Variant:
    """获取配置值"""
    return user_config.get(key, default_value)

func set_config(key: String, value: Variant) -> void:
    """设置配置值"""
    user_config[key] = value
    save_config()

func reset_config() -> void:
    """重置配置到默认值"""
    user_config = default_config.duplicate()
    save_config()

# 缓存管理
func clear_cache() -> void:
    """清除缓存数据"""
    cached_user_data.clear()

func get_cache_size() -> int:
    """获取缓存大小"""
    return cached_user_data.size() 