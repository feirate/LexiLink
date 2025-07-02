# LexiLink - 音节拼接英语学习游戏

![LexiLink Logo](assets/icons/app_icon.png)

## 📋 项目概述

LexiLink是一款创新的音节拼接英语学习游戏，融合了肉鸽机制和卡片收集系统。玩家扮演语言探险家Lexi，在被"语言诅咒"封印的世界中冒险，通过拖拽音节卡片组成完整单词来解除封印。

### 🎯 核心特性

- **音节拼接玩法**: 拖拽音节卡片组成完整单词
- **肉鸽机制**: 随机路线、音节池、特殊事件、Boss挑战  
- **卡片收藏**: 五个稀有度等级，100%正确获得卡片
- **社交竞技**: 好友系统、排行榜、挑战对决
- **语言探险**: 四个主题世界，渐进式难度设计
- **极简美学**: 参考《迷你地铁》视觉风格

## 🛠 技术栈

| 技术 | 用途 | 版本 |
|------|------|------|
| Godot | 游戏引擎 | 4.4 |
| GDScript | 主要编程语言 | - |
| Firebase | 云端数据同步 | 最新版 |
| Vercel | Web部署 | - |
| JSON | 数据存储格式 | - |

## 📁 项目结构

```
LexiLink/
├── project.godot              # Godot项目配置
├── scenes/                    # 场景文件
│   ├── ui/                   # UI相关场景
│   ├── gameplay/             # 游戏玩法场景
│   └── managers/             # 管理器场景
├── scripts/                   # 脚本文件
│   ├── core/                 # 核心系统
│   ├── gameplay/             # 游戏逻辑
│   ├── ui/                   # UI控制器
│   └── utils/                # 工具类
├── data/                      # 数据文件
│   ├── syllables/            # 音节数据
│   ├── cards/                # 卡片数据
│   └── levels/               # 关卡配置
├── assets/                    # 资源文件
│   ├── audio/                # 音频资源
│   ├── textures/             # 纹理图片
│   └── fonts/                # 字体文件
├── docs/                      # 文档
├── tests/                     # 测试文件
└── scripts/ci_cd/            # CI/CD脚本
```

## 🚀 快速开始

### 环境准备

1. **安装Godot 4.4**
   ```bash
   # 下载并安装Godot 4.4稳定版
   # https://godotengine.org/download
   ```

2. **克隆项目**
   ```bash
   git clone https://github.com/feirate/LexiLink.git
   cd LexiLink
   ```

3. **打开项目**
   - 启动Godot编辑器
   - 点击"Import"导入项目
   - 选择`project.godot`文件

### 开发设置

1. **配置开发环境**
   ```bash
   # 安装依赖工具
   npm install -g firebase-tools  # Firebase CLI (可选)
   ```

2. **环境变量配置**
   ```bash
   # 复制环境变量模板
   cp .env.example .env
   
   # 编辑.env文件，填入你的API密钥
   # 注意：.env文件不会提交到git
   ```

### 运行项目

1. **在Godot编辑器中运行**
   - 按F5或点击播放按钮
   - 选择主场景`scenes/ui/main_menu.tscn`

2. **导出Web版本**
   - Project → Export
   - 选择Web平台
   - 配置导出设置
   - 点击Export导出

## 🔧 开发规范

### 代码规范

项目遵循严格的编码规范，详见 [`coding_standards.mdc`](coding_standards.mdc)

**核心原则:**
- **YAGNI**: 只实现真正需要的功能
- **KISS**: 保持设计和实现简单性
- **防御式编程**: 完善的错误处理
- **可读性优先**: 清晰的命名和注释

**命名规则:**
```gdscript
# 变量和函数: snake_case
var player_health: int = 100
func validate_syllable_connection() -> bool:

# 类名: PascalCase
class_name SyllableCard extends Control

# 常量: SCREAMING_SNAKE_CASE
const MAX_SYLLABLE_COUNT: int = 50

# 信号: snake_case (过去时态)
signal syllable_connected(card: SyllableCard)
```

### Git工作流

```bash
# 分支策略
main          # 生产分支
develop       # 开发主分支
feature/*     # 功能分支
hotfix/*      # 紧急修复分支

# 提交规范
feat(scope): 新功能描述
fix(scope): bug修复描述
docs(scope): 文档更新
style(scope): 代码格式调整
refactor(scope): 代码重构
test(scope): 测试相关
chore(scope): 构建工具、依赖更新
```

### 自动化提交

项目配置了自动提交脚本，每次开发完成后自动commit：

```bash
# 手动运行自动提交
./scripts/ci_cd/auto_commit.sh

# 当天commit过多时自动整合
# 最大提交数: 5次/天，超过自动整合
```

## 📅 开发计划

### MVP开发 (21天)

**第一周 (Day 1-7): 核心框架 + 肉鸽机制**
- [x] 项目搭建和环境配置
- [x] 核心管理器(Game/Data/Audio/Scene)
- [x] 基础数据结构设计
- [ ] 肉鸽核心机制实现
- [ ] 音节拖拽系统
- [ ] UI基础界面

**第二周 (Day 8-14): 卡片系统 + 学习体验**
- [ ] 卡片收藏系统
- [ ] 学习进度追踪  
- [ ] 音频系统优化
- [ ] 性能与安全
- [ ] 多平台适配

**第三周 (Day 15-21): 抛光 + 测试 + 发布**
- [ ] UI/UX抛光
- [ ] 内容完善
- [ ] 用户测试
- [ ] Bug修复
- [ ] 正式发布

## 🧪 测试

### 运行测试

```bash
# 单元测试 (使用GUT框架)
# 在Godot编辑器中运行GUT插件

# 集成测试
# 测试完整游戏流程

# 性能测试
# 监控内存使用和帧率
```

### 测试覆盖率目标

- 核心逻辑: 100%
- UI组件: >80%
- 整体覆盖率: >80%

## 🚢 部署

### Web部署 (Vercel)

```bash
# 导出Web版本
# 在Godot中: Project → Export → Web

# 部署到Vercel
vercel --prod
```

### 移动端部署

```bash
# Android
# 配置Android SDK和签名
# 在Godot中导出APK

# iOS  
# 需要macOS和Xcode
# 在Godot中导出iOS项目
```

## 📊 成功指标

### 技术指标
- [ ] 页面加载时间 < 3秒
- [ ] 崩溃率 < 0.1%
- [ ] 跨设备兼容性 > 95%
- [ ] 代码测试覆盖率 > 80%

### 用户体验指标  
- [ ] 平均游戏时长 > 15分钟
- [ ] 用户重玩率 > 70%
- [ ] 满意度 > 7分(10分制)
- [ ] 学习效果感知 > 70%

## 🤝 贡献指南

### 贡献流程

1. Fork项目到你的GitHub
2. 创建功能分支: `git checkout -b feature/amazing-feature`
3. 提交更改: `git commit -m 'feat: add amazing feature'`
4. 推送分支: `git push origin feature/amazing-feature`
5. 创建Pull Request

### 代码审查

- 所有PR需要经过代码审查
- 确保测试通过
- 遵循编码规范
- 添加必要的文档

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 📞 联系方式

- **项目主页**: https://github.com/feirate/LexiLink
- **问题反馈**: https://github.com/feirate/LexiLink/issues
- **开发者**: [@feirate](https://github.com/feirate)

## 🙏 致谢

- Godot引擎团队提供优秀的开源游戏引擎
- 音节拼接教学法的研究者和实践者
- 所有为项目贡献代码和建议的开发者

---

**LexiLink** - 让英语学习变成一场有趣的冒险 🎮📚✨ 