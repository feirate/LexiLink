# @desc: 负责本地数据存储、音节数据管理、用户配置和静态数据加载
# @author: LexiLink
# @date: 2024-07-02
extends Node

# 1. Signals
signal save_completed(success: bool)
signal data_loaded(data_type: String, data: Dictionary)
signal syllable_data_updated()

# 2. Constants
const USER_DATA_PATH = "user://save_data.json"
const CONFIG_PATH = "user://config.json"
const SYLLABLE_DATA_PATH = "res://data/syllables/"
const CARD_DATA_PATH = "res://data/cards/"

# 3. Private Variables
var _syllable_database: Dictionary = {}
var _card_database: Dictionary = {}
var _user_config: Dictionary = {}
var _cached_user_data: Dictionary = {}

var _default_config: Dictionary = {
	"audio_volume": 0.8,
	"sfx_volume": 0.7,
	"language": "zh_CN",
	"difficulty": "medium",
	"tutorial_completed": false,
	"first_launch": true
}


# 4. Lifecycle Methods
func _ready() -> void:
	print("Data Manager 初始化...")
	
	_ensure_user_directory()
	_load_config()
	_load_all_user_data_from_disk()
	
	await _preload_static_data()
	
	print("Data Manager 初始化完成")


# 5. Public Methods
# 保存单个键值对到用户数据缓存
# @param key: String - 数据的键
# @param data: Variant - 要保存的数据
func save_user_data(key: String, data: Variant) -> void:
	_cached_user_data[key] = data


# 从用户数据缓存中加载数据
# @param key: String - 数据的键
# @param default_value: Variant - 如果键不存在时返回的默认值
# @return: Variant - 加载的数据或默认值
func load_user_data(key: String, default_value: Variant = null) -> Variant:
	return _cached_user_data.get(key, default_value)


# 获取配置值
# @param key: String - 配置项的键
# @param default_value: Variant - 默认值
# @return: Variant - 配置值
func get_config_value(key: String, default_value: Variant = null) -> Variant:
	return _user_config.get(key, default_value)


# 设置配置值并立即保存
# @param key: String - 配置项的键
# @param value: Variant - 新的配置值
func set_config_value(key: String, value: Variant) -> void:
	_user_config[key] = value
	_save_config()


# 获取完整的音节数据库
# @return: Dictionary - 音节数据库的副本
func get_syllable_database() -> Dictionary:
	return _syllable_database.duplicate()


# 获取完整的卡片数据库
# @return: Dictionary - 卡片数据库的副本
func get_card_database() -> Dictionary:
	return _card_database.duplicate()


# 将所有缓存的数据写入磁盘
# @return: bool - 是否保存成功
func save_all_data_to_disk() -> bool:
	var user_data_success = _write_user_data_to_disk()
	var config_success = _save_config()
	
	var success = user_data_success and config_success
	save_completed.emit(success)
	return success


# 6. Private Methods
# 确保用户数据目录存在
func _ensure_user_directory() -> void:
	var dir = DirAccess.open("user://")
	if not dir:
		push_error("无法访问用户数据目录 'user://'")


# 加载用户配置
func _load_config() -> void:
	var config_data = _load_json_file(CONFIG_PATH)
	if not config_data.is_empty():
		_user_config = config_data
		if GameManager and GameManager.debug_mode:
			print("用户配置已加载")
	else:
		_user_config = _default_config.duplicate()
		if GameManager and GameManager.debug_mode:
			print("未找到用户配置, 使用默认配置")
		_save_config()


# 保存用户配置
# @return: bool - 是否保存成功
func _save_config() -> bool:
	var success = _save_json_file(CONFIG_PATH, _user_config)
	if success and GameManager and GameManager.debug_mode:
		print("用户配置已保存")
	elif not success:
		push_error("无法保存用户配置文件")
	return success


# 加载所有用户数据到缓存
func _load_all_user_data_from_disk() -> void:
	_cached_user_data = _load_json_file(USER_DATA_PATH, {})


# 将缓存的用户数据写入磁盘
# @return: bool - 是否保存成功
func _write_user_data_to_disk() -> bool:
	var success = _save_json_file(USER_DATA_PATH, _cached_user_data)
	if success and GameManager and GameManager.debug_mode:
		print("用户数据已保存到磁盘")
	elif not success:
		push_error("无法保存用户数据到磁盘")
	return success


# 预加载静态数据
func _preload_static_data() -> void:
	if GameManager and GameManager.debug_mode:
		print("正在加载静态数据...")
	
	await _load_syllable_database()
	await _load_card_database()
	
	if GameManager and GameManager.debug_mode:
		print("静态数据加载完成")


# 加载音节数据库
func _load_syllable_database() -> void:
	var dir = DirAccess.open(SYLLABLE_DATA_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				var file_path = SYLLABLE_DATA_PATH.path_join(file_name)
				var file_data = _load_json_file(file_path)
				if file_data:
					_syllable_database.merge(file_data, true)
			file_name = dir.get_next()
	else:
		push_error("无法打开音节数据目录: " + SYLLABLE_DATA_PATH)
		_create_sample_syllable_data()

	syllable_data_updated.emit()


# 创建示例音节数据 (仅当目录读取失败时作为后备)
func _create_sample_syllable_data() -> void:
	push_warning("创建示例音节数据作为后备。")
	var sample_data = {
		"vowels": {"a": {"type": "vowel", "difficulty": 1}},
		"consonants": {"b": {"type": "consonant", "difficulty": 1}},
		"common_words": {"cat": {"syllables": ["c", "a", "t"], "difficulty": 2, "meaning": "猫"}},
	}
	_syllable_database = sample_data
	_save_json_file(SYLLABLE_DATA_PATH.path_join("basic_syllables.json"), sample_data)


# 加载卡片数据库
func _load_card_database() -> void:
	var dir = DirAccess.open(CARD_DATA_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				var file_path = CARD_DATA_PATH.path_join(file_name)
				var file_data = _load_json_file(file_path)
				if file_data:
					# 使用 merge 来合并多个卡片文件的数据
					_card_database.merge(file_data, true)
			file_name = dir.get_next()
	else:
		push_error("无法打开卡片数据目录: " + CARD_DATA_PATH)

	# 可以在此处发射一个信号，通知其他部分卡片数据已更新
	# data_loaded.emit("cards", _card_database)


# 通用JSON文件加载工具
# @param file_path: String - 文件路径
# @param default_value: Dictionary - 加载失败时返回的默认值
# @return: Dictionary - JSON数据或默认值
func _load_json_file(file_path: String, default_value: Dictionary = {}) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return default_value

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("无法打开文件: %s" % file_path)
		return default_value
	
	var json_string = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error == OK:
		return json.get_data()
	else:
		push_error("JSON 解析失败: %s (错误: %s, 行: %s)" % [file_path, json.get_error_message(), json.get_error_line()])
		return default_value


# 通用JSON文件保存工具
# @param file_path: String - 文件路径
# @param data: Dictionary - 要保存的数据
# @return: bool - 是否保存成功
func _save_json_file(file_path: String, data: Dictionary) -> bool:
	var dir_path = file_path.get_base_dir()
	var dir = DirAccess.open(dir_path)
	if not dir:
		var err = DirAccess.make_dir_recursive_absolute(dir_path)
		if err != OK:
			push_error("创建目录失败: %s, 错误码: %s" % [dir_path, err])
			return false

	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_error("无法创建文件: %s" % file_path)
		return false
	
	var json_string = JSON.stringify(data, "\t")
	file.store_string(json_string)
	return true 