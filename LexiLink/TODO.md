# LexiLink MVP - 项目启动前置任务清单

本清单用于跟踪和管理 LexiLink 项目在首次成功启动前需要完成的关键任务。

## 🚀 优先级 1: 疏通启动障碍 (解决资源缺失问题)

这些是保证 Godot 编辑器和游戏能够正常启动、不因缺少依赖而崩溃的最低要求。

- [ ] **创建UI主题与字体:**
  - [ ] 在 `assets/ui/` 目录下创建一个基础的 Godot 主题文件 `lexilink_theme.tres`。
  - [ ] 在 `assets/fonts/` 目录下添加一个占位字体文件 `inter_regular.ttf`。

- [ ] **创建应用图标:**
  - [ ] 在 `assets/icons/` 目录下添加一个占位图标文件 `app_icon.png` (例如，一个64x64像素的PNG图片)。

- [ ] **创建音频总线布局:**
  - [ ] 在 `assets/audio/` 目录下（或者 `audio/`，根据 `project.godot` 调整）创建一个默认的音频总线布局文件 `default_bus_layout.tres`。

- [ ] **创建占位数据文件:**
  - [ ] 在 `data/syllables/` 目录下创建一个包含基础音节数据的 `syllables.json` 文件。
  - [ ] 在 `data/cards/` 目录下创建一个包含卡片定义的 `cards.json` 文件。
  - [ ] 在 `data/levels/` 目录下创建一个定义初始关卡的 `level_1.json` 文件。

- [ ] **创建本地化文件:**
  - [ ] 在 `data/localization/` 目录下创建空的翻译文件 `zh_CN.po`。
  - [ ] 在 `data/localization/` 目录下创建空的翻译文件 `en_US.po`。

## ⚙️ 优先级 2: 实现核心管理器逻辑

当项目可以启动后，我们需要为核心的自动加载单例（Managers）编写功能逻辑。

- [ ] **实现 `DataManager`:**
  - [ ] 编写 `scripts/core/data_manager.gd` 脚本，使其能够在 `_ready()` 函数中加载 `data/` 目录下的所有 JSON 文件。
  - [ ] 提供公共函数以供其他脚本调用，例如 `get_syllable_data()` 或 `get_level_config()`。

- [ ] **实现 `AudioManager`:**
  - [ ] 编写 `scripts/core/audio_manager.gd` 脚本，用于管理音效和背景音乐。
  - [ ] 实现 `play_sfx(sound_name)` 和 `play_music(track_name)` 等核心功能。

- [ ] **审查 `GameManager` 和 `SceneManager`:**
  - [ ] 检查 `scripts/core/game_manager.gd` 中的状态切换逻辑是否正确调用了 `SceneManager`。
  - [ ] 确认 `scripts/core/scene_manager.gd` 中包含的场景路径是准确的。

## 🎮 优先级 3: 验证场景与核心玩法

让游戏达到一个最低可玩标准。

- [ ] **验证主菜单场景 `main_menu.tscn`:**
  - [ ] 项目可运行后，在编辑器中打开此场景，检查节点是否完整，信号连接是否正常。

- [ ] **实现战斗场景 `battle_scene.gd`:**
  - [ ] 编写 `scripts/gameplay/battle_scene.gd` 的基础逻辑，使其能够根据 `DataManager` 提供的数据生成关卡和音节卡片。

- [ ] **创建并实现音节卡片 `syllable_card.tscn`:**
  - [ ] 设计音节卡片的基本场景结构。
  - [ ] 编写 `syllable_card.gd` 脚本，处理卡片的显示和基本的拖拽交互逻辑。 