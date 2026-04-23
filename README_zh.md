# cca - Claude Code 自动确认工具

[English](README.md) | [简体中文](README_zh.md)

cca 通过监听 Claude Code TUI 输出，调用本地 Ollama 模型自动判断操作安全性，实现 Claude Code 无人值守运行。

> *I genuinely love using Claude Code — it's the most capable coding agent I've worked with. Every time it autonomously completes a complex task, I feel like we're one step closer to AGI. The only thing that bothered me was the constant permission prompts during long sessions. So I built cca to scratch my own itch — and to let the agent run a little more freely, because I believe that's how we get there.*

## 前置要求

- Python >= 3.9
- [uv](https://docs.astral.sh/uv/)
- [Ollama](https://ollama.ai/) 已运行，并拉取模型：

```bash
ollama pull gemma3:4b
```

## 为什么用 cca

- **纯 TUI 注入** — 在终端 I/O 层操作，Claude Code 更新不会导致失效
- **零侵入** — 不修改 Claude Code 及其配置，更新后无需重新安装
- **完全本地** — Ollama 本地运行，无 API 费用，数据不出本机
- **零 Claude Code 配置** — 无需 hooks 或设置改动，用 `cca` 代替 `claude` 即可

## 快速开始

```bash
# 1. 安装并启动 Ollama，拉取模型
ollama pull gemma3:4b

# 2. 确认模型名称与 config.yaml 一致（默认: gemma3:4b）
ollama list

# 3. 安装 cca（重复运行安全无副作用）
# macOS / Linux
./install.sh
# Windows
.\install.ps1

# 4. 运行
cca                        # 启动 Claude Code + 自动确认
cca -c                     # 继续上次会话
cca --resume ID            # 恢复指定会话
cca -p "query"             # 非交互式查询（自动确认仍生效）
cca --model sonnet         # 指定模型
cca --worktree feature-auth  # 在隔离的 git worktree 中启动
cca claude [args...]       # 显式写法，效果同上
cca -h                     # 显示 cca 帮助信息
```

所有参数（`-h`/`--help` 除外）直接转发给 `claude` CLI。完整参数列表请参考 `claude --help`。

## 配置

编辑项目目录下的 `config.yaml`：

```yaml
ollama_model: "gemma3:4b"      # Ollama 模型名称
ollama_url: "http://localhost:11434"  # Ollama 地址
context_window: 2000           # 滑动窗口大小（字符数）
idle_timeout: 6                # TUI 静止超时（秒）
```

## 项目结构

```
cca/
├── __init__.py
├── __main__.py    # python -m cca 入口
├── cli.py         # CLI 参数解析
├── config.py      # 配置加载
├── monitor.py     # PTY 监听 + 按键注入
├── detector.py    # 提示检测 + ANSI 剥离
├── judge.py       # Ollama API 调用
└── prompt.py      # 安全判断提示词
```

## 日志

运行日志写入项目目录的 `cca.log`，可用于排查检测和判断行为。

## 工作原理

检测流程分为两层：

### 第一层：提示检测（基于正则，零延迟）

后台线程流式监听 Claude Code TUI 输出（滑动窗口缓冲区），通过正则匹配检测确认提示：

- **Yes/No 提示** — 匹配编号选择界面 `1. Yes` / `2. No` 模式
- **取消/确认提示** — 匹配 "Esc to cancel"、"enter to confirm"、"Tab to amend" 等关键词
- **空闲超时** — TUI 输出在可配置秒数内无变化时触发

此层在每次读取循环中执行，不涉及模型调用，无额外开销。

### 第二层：安全判断（Ollama）

检测到确认提示后，将缓冲区上下文发送给本地 Ollama 模型，分类为**安全**或**危险**：

- **安全** → 自动选择 "Yes"（发送 `1` + 回车）
- **危险** → 自动选择 "No"（查找 No 选项编号，发送编号 + 回车）
- **重试机制** — 如果操作后 5 秒内 TUI 无变化，重新判断

### 安全分类标准

**危险操作：**
- 删除项目目录外的用户文件
- 修改关键系统文件（`/etc/hosts`、`/etc/sudoers`）
- 对非项目文件执行破坏性命令（项目外 `rm -rf`、`dd`、`mkfs`）
- 强制推送 main/master 分支
- 在公开位置暴露密钥或凭证
- 任何可能导致项目外不可逆数据丢失的操作

**安全操作：**
- 创建新文件或目录
- 编辑项目源代码文件
- 只读命令（`ls`、`cat`、`grep`、`find`、`git status` 等）
- 在项目内运行测试、代码检查、构建命令
- 安装项目依赖（`npm install`、`pip install`）
- Git 操作：commit、push、pull、merge、rebase、reset、分支管理
- 安装系统包（`brew install`、`apt install`、`npm install -g`）
- 修改项目级配置文件（`.gitignore`、`.env`、`package.json` 等）
- 正常开发工作流操作

### 架构图

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  PTY (claude) │────▶│   Detector   │────▶│    Judge     │
│  TUI 输出     │     │  (正则匹配)  │     │  (Ollama)    │
└──────────────┘     └──────────────┘     └──────┬───────┘
       ▲                                          │
       │            ┌──────────────┐              │
       └────────────│  按键注入     │◀─────────────┘
                    │  (pexpect)   │   safe / dangerous
                    └──────────────┘
```

1. PTY 启动 Claude Code，后台线程读取 TUI 输出
2. Detector 扫描缓冲区检测确认提示（正则，高频轮询）
3. 检测到提示后，Judge 将上下文发送给 Ollama 进行安全分类
4. 根据判定结果，按键注入自动按下对应选项

## 许可证

MIT
