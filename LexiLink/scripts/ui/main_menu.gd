## Main Menu Script
# @desc: 主菜单界面逻辑脚本，负责UI节点的事件响应。
# @author: LexiLink
# @date: 2024-07-02

class_name MainMenu
extends Control

# 1. Signals
signal start_game_pressed
signal settings_pressed
signal quit_pressed

# 2. OnReady Variables
@onready var start_button: Button = $VBoxContainer/StartButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

# 3. Lifecycle Methods
func _ready() -> void:
	# 推荐在编辑器中连接信号，此处为代码连接示例
	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_button_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_button_pressed)

# 4. Public API
# (None)

# 5. Private Methods
# (None)

# 6. Signal Callbacks
func _on_start_button_pressed() -> void:
	if GameManager:
		GameManager.change_game_state(GameManager.GameState.GAME_PLAYING)
	else:
		push_error("MainMenu: GameManager 未找到")
	start_game_pressed.emit()

func _on_settings_button_pressed() -> void:
	if GameManager:
		GameManager.change_game_state(GameManager.GameState.SETTINGS)
	else:
		push_error("MainMenu: GameManager 未找到")
	settings_pressed.emit()

func _on_quit_button_pressed() -> void:
	get_tree().quit()
	quit_pressed.emit() 