# cc-auto — Claude Code 安全钩子

[English](README.md) | [简体中文](README_zh.md)

cc-auto 通过 bash 钩子和 Ollama 为 Claude Code 添加本地安全门控。它拦截 Bash 工具调用，在执行前判断操作是否安全。

> `cca` 和 `claude` 用法完全一样，但自动启用 Ollama 安全钩子。

## 工作原理

```
cca [参数...]
 │
 ▼
claude --settings hook-settings.json [参数...]
 │
 ▼ (每次 Bash 工具调用)
safe-hook.sh
 ├── 第一层：硬拦截（rm -rf、sudo 等）→ 拒绝
 ├── 第二层：Ollama（qwen3.5:9b）判断 → 允许 / 拒绝
 └── Ollama 不确定 → 询问用户
```

- **只拦截 Bash 工具调用** — Edit、Write、Read 等自动放行
- **不干扰用户选择** — 计划审批、模式选择等不受影响
- **失败时放行** — Ollama 不可达时回退到询问用户

## 前置要求

- macOS（使用系统自带的 `python3`）
- [Ollama](https://ollama.ai/) 本地运行

```bash
ollama pull qwen3.5:9b
```

## 快速开始

```bash
# 1. 克隆仓库
git clone https://github.com/LehaoLin/cc-auto.git
cd cc-auto

# 2. 拉取 Ollama 模型
ollama pull qwen3.5:9b

# 3. 安装 cca 命令（一次性设置）
#    会在 ~/.local/bin/cca 创建软链接
mkdir -p ~/.local/bin
ln -sf "$(pwd)/cca" ~/.local/bin/cca

# 确保 ~/.local/bin 在 PATH 中
# （如果已配置可跳过）
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# 4. 像 claude 一样使用 cca
cca                        # 交互模式
cca -c                     # 继续上次会话
cca --resume ID            # 恢复指定会话
cca -p "修复这个 bug"       # 单次模式
cca --model sonnet         # 指定模型
cca --worktree feature-auth  # 隔离的 git worktree
```

## 项目结构

```
├── cca                 # 包装脚本（claude 的替代品）
├── safe-hook.sh        # PreToolUse 钩子脚本（两层安全判断）
├── hook-settings.json  # 钩子配置（通过 --settings 加载）
├── LICENSE
└── README.md
```

## 自定义

### 更换 Ollama 模型

编辑 `safe-hook.sh` 中 `"model": "qwen3.5:9b"` 那行，替换为你已拉取的模型。

### 添加更多危险模式

编辑 `safe-hook.sh` 第一层的 `grep -qEi` 行。

### 拦截更多工具

修改 `safe-hook.sh` 中 `if [ "$TOOL_NAME" != "Bash" ]` 判断，加入其他工具名。

## 参与贡献

欢迎提 Issue 和 PR！

## 许可证

MIT
