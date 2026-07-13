# cc-pet

**把一张照片变成常驻 macOS 的桌宠，让它实时反映 Claude Code 正在做什么。**

一只悬浮的像素精灵住在你的屏幕上，随 Claude Code 的活动切换动作：Claude 干活时它一起工作，需要你批准时它期待等待，一轮结束时它欢呼（长任务则唱歌），工具报错时它垂头丧气，你打字时它敲键盘，你拖它时它扇翅膀飞。

[English](README.md) · 中文 · **[LESSONS.md](LESSONS.md)**（多轮调试的宝贵经验，强烈建议读）

---

## 仓库内容

| 部分 | 说明 |
|------|------|
| `app/` | 原生 Swift app（SwiftPM）。`ClawPetCore` 是纯逻辑、带单测；`ClawPet` 是透明、置顶、常驻的悬浮窗，负责渲染精灵图集。 |
| `hooks/` | `pet-state`：一个极小脚本，从 stdin 读 Claude Code 的 hook JSON，把桌宠当前状态原子写入一个文件，app 轮询它。 |
| `scripts/` | 照片到图集的生成管线，外加安装、打包、质检工具。 |
| `pets/placeholder/` | 一张生成好的占位图集（彩色块），让机制在你做出真形象之前就能跑起来。 |

## 快速开始（用占位素材跑通机制）

```bash
cd app
swift run ClawPet          # 悬浮桌宠出现，菜单栏 🧚 退出
swift run ClawPetTests     # 核心断言测试（无需 Xcode / XCTest）
```

持久安装并接入 Claude Code：

```bash
scripts/install.sh                 # 编译 release，安装二进制 + hook + 占位宠
# 把 hooks/settings-hooks-snippet.json 合并进 ~/.claude/settings.json
# 首次弹窗时授予输入监控权限（typing 状态需要）
```

## 13 个状态与触发规则

**跟随 Claude Code**（hook 到 `pet-state`，写入 `~/.claude/pet/state.json`，app 轮询读取）：

| 状态 | 触发 |
|------|------|
| greet | `SessionStart`（同时自动拉起 app） |
| working | `UserPromptSubmit` / `PreToolUse` / `PostToolUse` |
| waiting | `Notification`（需要你批准时） |
| droop | `PostToolUse` 且 `isError: true` |
| cheer | 普通一轮结束的 `Stop` |
| singing | 长任务（工具调用不少于 8 次或耗时不少于 120 秒）结束的 `Stop`，彩蛋 |
| hover | 默认待机（Claude 空闲、idle 通知、或一次性动作播完回落） |

**鼠标 / 键盘 / 定时器**：fly-left/right（拖动）、twirl（双击）、hearts（单击）、typing（你打字，需输入监控权限）、wave（每 30 秒有一半概率随机触发，仅在待机时）。

优先级：拖动大于一次性手势，一次性手势大于 typing，typing 大于 Claude Code 状态，最后才是 hover。

## 用你自己的照片做一只桌宠

```bash
export FAL_KEY=...            # 见 .env.example，provider 可插拔（scripts/providers.py）
python3 scripts/gen_base_sprite.py my-photo.png            # 照片到基准立绘
python3 scripts/gen_row_strip.py hover 6                   # 生成一条动画行（网格 + 绿幕）
python3 scripts/reslice.py out/rows pets/mypet/pet.json    # 分割 + 重新锚定到干净格子
python3 scripts/compose_atlas.py out/rows pets/mypet       # 拼成 spritesheet.png
python3 scripts/check_clipping.py pets/mypet pets/mypet/pet.json   # 质检：0 帧触碰格边
```

**provider 可插拔**：`scripts/providers.py` 定义了一个只有一个方法的适配器（`edit_image`）。参考实现是 fal.ai 的 `gpt-image-2/edit`；想换 OpenAI、OpenRouter、Gemini 或本地模型，只需实现这一个函数。

## 图集契约

一张 `1536 × (行数·208)` 的 PNG，8 列、每格 `192×208`，每行一个状态，透明背景。帧数和时长写在 `pet.json` 里（单一真源）。契约改编自 OpenAI 的 `hatch-pet`，署名见 [NOTICE](NOTICE)。

## 为什么这件事没那么简单

管线看着直白，做到稳健并不容易。精灵分割、fal 的 3:1 画布上限、FSEvents 与原子替换的冲突、把 Claude Code 卡死的 hook、定位漂移、裁切、解剖缺陷，每一个都记录在 **[LESSONS.md](LESSONS.md)** 里。改管线前先读它，大多数看似显然的做法都已经试过并因明确的原因失败了。

## 环境要求

macOS 14 以上，Swift 工具链（Command Line Tools 即可，无需 Xcode）。生图管线需要 Python 3 加 Pillow 和 numpy。Apache-2.0 许可。
