#!/bin/bash
# LexiLink 自动提交脚本
# 实现每完成一次编码开发后自动提交本地仓库
# 如果当天commit太多，自动整合

set -e  # 遇到错误立即退出

# 颜色输出定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置参数
MAX_DAILY_COMMITS=5  # 每日最大提交数，超过则整合
COMMIT_MESSAGE_PREFIX="chore(daily):"
INTEGRATION_PREFIX="chore(integration):"

# 获取当前时间信息
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
TODAY=$(date "+%Y-%m-%d")
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "main")

echo -e "${BLUE}=== LexiLink 自动提交脚本 ===${NC}"
echo -e "${BLUE}时间: $TIMESTAMP${NC}"
echo -e "${BLUE}分支: $CURRENT_BRANCH${NC}"

# 函数：检查Git仓库状态
check_git_status() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo -e "${RED}错误: 当前目录不是Git仓库${NC}"
        exit 1
    fi
    
    if [[ -z $(git status --porcelain) ]]; then
        echo -e "${GREEN}没有检测到更改，跳过提交${NC}"
        exit 0
    fi
}

# 函数：检查是否有冲突文件
check_conflicts() {
    if git diff --check > /dev/null 2>&1; then
        echo -e "${GREEN}✓ 没有冲突文件${NC}"
    else
        echo -e "${RED}✗ 检测到冲突文件，请手动解决${NC}"
        git diff --check
        exit 1
    fi
}

# 函数：获取今日提交数量
get_today_commit_count() {
    local count=$(git log --since="$TODAY 00:00:00" --oneline 2>/dev/null | wc -l | tr -d ' ')
    echo $count
}

# 函数：生成提交信息
generate_commit_message() {
    local commit_count=$1
    local changed_files=$(git diff --cached --name-only | head -10)
    local file_count=$(echo "$changed_files" | wc -l | tr -d ' ')
    
    local message="$COMMIT_MESSAGE_PREFIX 开发进度提交 #$((commit_count + 1)) - $TIMESTAMP

自动提交包含:
- 修改文件数: $file_count
- 代码优化和重构
- 功能开发和调试
- 文档和配置更新

分支: $CURRENT_BRANCH
提交序号: $((commit_count + 1))"

    # 添加主要修改文件信息
    if [ ! -z "$changed_files" ]; then
        message="$message

主要修改文件:"
        echo "$changed_files" | head -5 | while read file; do
            if [ ! -z "$file" ]; then
                message="$message
- $file"
            fi
        done
    fi
    
    echo "$message"
}

# 函数：生成整合提交信息
generate_integration_message() {
    local commit_count=$1
    local message="$INTEGRATION_PREFIX 整合 $TODAY 的开发进度

今日开发成果:
- 总提交数: $commit_count
- 开发时间: $TODAY
- 主要工作: 音节拼接游戏开发

整合内容:
- 核心系统开发和优化
- UI界面实现和调整
- 数据结构设计和完善
- 代码重构和性能优化
- Bug修复和功能增强
- 文档更新和配置调整

分支: $CURRENT_BRANCH
整合时间: $TIMESTAMP"

    echo "$message"
}

# 函数：执行整合提交
perform_integration() {
    local commit_count=$1
    
    echo -e "${YELLOW}今日提交数量过多($commit_count)，执行commit整合...${NC}"
    
    # 查找今日第一个提交
    local first_commit=$(git log --since="$TODAY 00:00:00" --format="%H" --reverse | head -1)
    
    if [ -z "$first_commit" ]; then
        echo -e "${RED}错误: 无法找到今日第一个提交${NC}"
        exit 1
    fi
    
    # 软重置到昨天最后一个提交
    local parent_commit="${first_commit}^"
    
    echo -e "${YELLOW}重置到: $parent_commit${NC}"
    git reset --soft "$parent_commit"
    
    # 重新提交整合后的更改
    local integration_message=$(generate_integration_message $commit_count)
    git commit -m "$integration_message"
    
    echo -e "${GREEN}✓ 已整合今日的 $commit_count 个commit${NC}"
}

# 函数：执行普通提交
perform_normal_commit() {
    local commit_count=$1
    
    # 添加所有更改到暂存区
    git add .
    
    # 检查暂存区是否有内容
    if [[ -z $(git diff --cached --name-only) ]]; then
        echo -e "${YELLOW}暂存区为空，可能只有已跟踪文件的修改${NC}"
        git add -u  # 添加已跟踪文件的修改
    fi
    
    # 生成提交信息
    local commit_message=$(generate_commit_message $commit_count)
    
    # 执行提交
    git commit -m "$commit_message"
    
    echo -e "${GREEN}✓ 自动提交完成 (#$((commit_count + 1)))${NC}"
}

# 函数：显示提交统计
show_commit_stats() {
    local commit_count=$1
    
    echo -e "${BLUE}=== 提交统计 ===${NC}"
    echo -e "${BLUE}今日提交数: $commit_count${NC}"
    echo -e "${BLUE}当前分支: $CURRENT_BRANCH${NC}"
    
    # 显示最近几次提交
    echo -e "${BLUE}最近提交:${NC}"
    git log --oneline -3 --color=always
}

# 函数：检查编码规范
check_coding_standards() {
    echo -e "${BLUE}检查编码规范...${NC}"
    
    # 检查GDScript文件格式
    local gd_files=$(find . -name "*.gd" -not -path "./.godot/*" 2>/dev/null | head -10)
    
    if [ ! -z "$gd_files" ]; then
        echo -e "${GREEN}✓ 发现 GDScript 文件，建议运行格式检查${NC}"
    fi
    
    # 检查是否有大文件
    local large_files=$(git diff --cached --name-only | xargs -I {} sh -c 'if [ -f "{}" ] && [ $(stat -f%z "{}" 2>/dev/null || stat -c%s "{}" 2>/dev/null || echo 0) -gt 1048576 ]; then echo "{}"; fi')
    
    if [ ! -z "$large_files" ]; then
        echo -e "${YELLOW}警告: 检测到大文件 (>1MB):${NC}"
        echo "$large_files"
        echo -e "${YELLOW}建议检查是否应该忽略这些文件${NC}"
    fi
}

# 主执行流程
main() {
    echo -e "${BLUE}开始自动提交流程...${NC}"
    
    # 检查Git状态
    check_git_status
    
    # 检查冲突
    check_conflicts
    
    # 检查编码规范
    check_coding_standards
    
    # 获取今日提交数量
    local today_commits=$(get_today_commit_count)
    echo -e "${BLUE}今日已有提交数: $today_commits${NC}"
    
    # 判断是否需要整合
    if [ $today_commits -ge $MAX_DAILY_COMMITS ]; then
        perform_integration $today_commits
    else
        perform_normal_commit $today_commits
    fi
    
    # 显示统计信息
    show_commit_stats $(get_today_commit_count)
    
    echo -e "${GREEN}=== 自动提交完成 ===${NC}"
}

# 错误处理
handle_error() {
    echo -e "${RED}错误: 自动提交失败${NC}"
    echo -e "${RED}错误发生在第 $1 行${NC}"
    echo -e "${YELLOW}请检查Git状态并手动处理${NC}"
    exit 1
}

# 设置错误处理
trap 'handle_error $LINENO' ERR

# 执行主流程
main "$@" 