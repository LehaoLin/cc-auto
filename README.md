# cca - Claude Code Auto-Confirmation Tool

cca 通过监听 Claude Code TUI 输出，调用本地 Ollama 模型自动判断操作安全性，实现 Claude Code 无人值守运行。

## 工作原理

1. 通过 PTY 启动 Claude Code，后台线程流式监听 TUI 输出（滑动窗口缓冲区）
2. 检测到用户确认提示时（Yes/No 选择、TUI 静止超时、"Esc to cancel" 提示符）
3. 将上下文发送给本地 Ollama 模型判断操作是否安全
4. 安全 → 自动按 Enter 确认；危险 → 自动选择 No，并输入"继续"并回车

## 前置要求

- Python >= 3.9
- [uv](https://docs.astral.sh/uv/)
- [Ollama](https://ollama.ai/) 已运行，并拉取模型：

```bash
ollama pull gemma3:4b
```

## 快速开始

```bash
# 测试运行（项目目录内）
./test.sh          # macOS / Linux
.\test.ps1         # Windows
```

## 全局安装与更新

安装后在任意目录使用 `cca claude`。安装和更新使用同一命令，重复运行安全无副作用：

```bash
# macOS / Linux
./install.sh

# Windows
.\install.ps1
```

安装完成后：

```bash
cca claude              # 启动 Claude Code + 自动确认
cca claude -c           # 继续上次会话
cca claude --resume ID  # 恢复指定会话
```

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
