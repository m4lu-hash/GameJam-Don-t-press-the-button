# Game Design Document — "别按那个键" (Don't Press That Key)

> **版本**: 0.2 — 工程现状  
> **引擎**: Godot 4.7  
> **类型**: 2D 俯视角塔防 + 按钮点击机制  
> **主题**: 桌面隐喻 — 别按那个键  

> **文档说明**: 本文档反映工程的**实际实现状态**，只描述已经存在于代码/场景中的类设计、系统设计和运行时行为。  
> 设计愿景和未实现的创意存储在 `docs/IDEA.md` 中。工程配置和目录结构见 `CLAUDE.md`。

---

## 1. 游戏概述

### 1.1 一段话简介

"别按那个键"是一款桌面隐喻风格的塔防游戏。敌人化身为鼠标光标，试图点击地图上的"按钮"——你必须部署钓鱼弹窗、炮塔和区域打击等各式各样的手段，在它们触发"失败按钮"前将其消灭。同时地图上还散落着其他类型的按钮，他们会带来各种各样的效果：负面效果、增益效果和随机效果，以及还有一些短期收益长期减益甚至负面的按钮，玩家需要在这些按钮的诱惑和威胁之间做出权衡，合理分配资源，才能成功抵御敌人的进攻，守护"失败按钮"。（这些按钮全都可以被玩家触发，部分可以被敌人触发）

### 1.2 平台与规格

| 项 | 值 |
|---|---|
| 平台 | PC (Windows) 后期考虑手机移植 |
| 输入 | 纯鼠标操作（+ 空格键技能） |
| 分辨率 | 1280×720 |
| 视角 | 2D 俯视 |
| 渲染风格 | 像素风格（纹理过滤 = Nearest） |

---

## 2. 核心游戏循环（设计目标）

### 2.1 游玩流程

准备阶段（观察地图的布局和各个按钮的文本提示等，同时部署防御） → 第x波来袭-战斗阶段（游戏开始生成敌人，玩家在这个阶段可以部署防御和撤回防御） → 第x波结束-调整阶段（如果有随机按钮或者一些延迟效果将会触发，玩家在这个阶段可以部署防御和撤回防御） → 继续战斗然后调整直到游戏结束（胜利或失败） → 结算阶段（显示统计数据和奖励，让玩家能够带到下一关）

#### A. 准备阶段
- 持续 30 秒（可配置）
- 商店面板滑入，然后玩家可以购买/升级防御，也可以折叠起来
- 部署的时候商店面板折叠，玩家可以直接点击地图放置防御（如果有足够碎片），放置完成后商店面板再次滑入
- 玩家使用**代码碎片**购买/升级防御
- 新的Debuff按钮可能在此时出现在地图上
- 点击"Ready"可提前开始下一波（奖励额外碎片）

#### B. 战斗阶段（波次进行中）
- 敌人从地图边缘的生成点出现
- 敌人寻路走向随机按钮
- 玩家可在战斗中放置防御设施
- 炮塔自动射击（如果有）
- 所有敌人被消灭后波次结束

#### C. 调整阶段（波次之间）
- 玩家可以在此阶段调整防御布局
- 如果有随机按钮或者一些延迟效果将会触发

#### D. 结算阶段（游戏结束）
- 显示统计数据和奖励，让玩家能够带到下一关

### 2.2 胜负条件

| 结果 | 条件 |
|---|---|
| **胜利** | 存活 20 波 |
| **失败** | 失败按钮被点击满 **3 次**（"系统稳定性"= 3条命） |

---

## 3. 已实现的游戏对象

### 3.1 按钮系统

按钮通过继承 `BaseClickedButton` 区分类型，而非枚举。所有按钮场景注册在全局组 `"ClickedButtons"` 中，供敌人寻路查询。

---

#### `BaseClickedButton` — 按钮基类

**文件**: `scripts/buttons/base_button.gd` | **场景**: `scenes/buttons/base_button.tscn`  
**继承**: `Node2D` | **全局组**: `"ClickedButtons"`

内部包含一个 Godot `Button` 子节点（toggle_mode），通过 `press()` / `release()` 控制按下状态。敌人寻路到达后调用这两个方法模拟点击。按钮的显示文本通过 `@export var text` 在编辑器中配置，`_ready()` 时赋值到子 Button。

- **`_ready()`** — 把 `text` 显示到子 Button 上
- **`press()` / `release()`** — 供 `BaseEnemy.click()` 调用，切换按钮视觉按下/弹起
- **`_on_button_pressed()`** — 响应 `Button.pressed` 信号，当前占位 `print("pressed")`

场景结构：`Node2D (scale=2)` → `Button (8×8px, toggle_mode)`

---

#### `FailureButton` — 失败按钮（占位）

**文件**: `scripts/buttons/failure_button.gd` | **继承**: `BaseClickedButton`

被敌人点击会导致游戏结束。当前为空占位，行为完全继承基类。

---

#### `DebuffButton` — 负面效果按钮（占位）

**文件**: `scripts/buttons/debuff_button.gd` | **继承**: `BaseClickedButton`

被点击触发负面效果。当前为空占位，行为完全继承基类。

---

### 3.2 敌人系统 — `BaseEnemy`

**文件**: `scripts/enemies/base_enemy.gd` | **场景**: `scenes/enemies/base_enemy.tscn`  
**继承**: `Node2D`

鼠标光标外观的敌人，通过 `NavigationAgent2D` 寻路到 `"ClickedButtons"` 组中的随机按钮，到达后点击，点击次数耗尽后死亡。

- **`_ready()`** — 调用 `navigation()` 初始化首个寻路目标
- **`navigation()`** — 从 `"ClickedButtons"` 全局组中纯随机抽取一个按钮作为 `current_button`
- **`click()`** — 播放 "clicked" 动画 → 调用目标按钮的 `press()` → 等动画结束 → `release()` → `click_times -= 1`
- **`free_self()`** — 播放 "free" 淡出动画 → 等动画结束 → `queue_free` 释放节点
- **`_physics_process(delta)`** — 每帧向 `NavigationAgent2D` 的下一个路径点以 `speed` 速度移动
- **`_on_navigation_agent_2d_navigation_finished()`** — 导航到达目标后触发 → 调用 `click()`

导出属性：`health : int = 1`（当前逻辑中未使用）、`click_times : int = 2`、`speed := 200`。

`click_times` 自定义 setter：≤0 时自动调用 `free_self()` 触发死亡，>0 时调用 `navigation()` 重新随机寻路。

`current_button : BaseClickedButton` 自定义 setter：赋值时自动同步 `navigation_agent_2d.target_position`。

场景结构：
```
BaseEnemy (Node2D, scale=0.5)
├── Sprite2D (mouse.png, rotation≈28.5°)
├── AnimationPlayer
│   ├── "RESET"     — 默认空状态 0.2s
│   ├── "clicked"   — 倾斜抖动 0.5s
│   └── "free"      — modulate 淡出 0.2s
├── Area2D → CollisionShape2D (CircleShape2D, r≈24px)
└── NavigationAgent2D
```

---

### 3.3 主场景 — `main.tscn`

**文件**: `scenes/main/main.tscn` | **脚本**: `scenes/main/main.gd`

根场景。`main.gd` 预加载 `base_enemy.tscn`，监听 `left_mouse` 输入，左键点击时在鼠标位置实例化一个 `BaseEnemy`——当前为调试用途的敌人手动生成器。

当前场景内容：
```
Main (Node2D)
├── BaseEnemy  — 预置敌人, position=(420, 219)
└── NavigationRegion2D — 导航区域 (~1280×720, 隐藏)
```

---

## 4. 全局组与 Autoloads

### 4.1 全局组 (Global Groups)

| 组名 | 说明 |
|---|---|
| `ClickedButtons` | 所有可被点击的按钮节点注册到此组，供 `BaseEnemy.navigation()` 查询寻路目标 |

### 4.2 全局类注册 (class_name)

| 类名 | 继承 | 脚本路径 |
|---|---|---|
| `BaseClickedButton` | `Node2D` | `res://scripts/buttons/base_button.gd` |
| `FailureButton` | `BaseClickedButton` | `res://scripts/buttons/failure_button.gd` |
| `DebuffButton` | `BaseClickedButton` | `res://scripts/buttons/debuff_button.gd` |
| `BaseEnemy` | `Node2D` | `res://scripts/enemies/base_enemy.gd` |

### 4.3 Autoloads（全局单例）

**当前无任何 Autoload**。

---

## 5. 运行时行为（当前状态）

当前在 Godot 编辑器中按 F5 运行后，实际行为如下：

1. **场景加载**: 显示 1 个预置的鼠标光标敌人（无按钮，按钮需自行创建后放入场景）
2. **调试生成**: 玩家点击鼠标左键 → `main.gd` 在鼠标位置实例化新的 `BaseEnemy`
3. **敌人自动寻路**: 敌人调用 `navigation()`，从 `"ClickedButtons"` 组中纯随机选一个按钮作为目标
4. **敌人点击**: 到达目标按钮后，播放 "clicked" 动画（0.5s 倾斜抖动）→ `press()` → 等动画结束 → `release()` → `click_times -= 1`
5. **继续寻路**: `click_times > 0` 时 setter 重新调用 `navigation()`，随机选下一个按钮
6. **敌人死亡**: `click_times <= 0` 时 setter 触发 `free_self()` → 播放 "free" 淡出动画（0.2s） → `queue_free`
7. **控制台输出**: 每次按钮被点击时输出 `"pressed"`

### 尚未实现的系统

- ❌ 波次生成系统
- ❌ 代码碎片经济系统
- ❌ 防御设施（钓鱼窗口、射击炮塔、盾牌猛击）
- ❌ 敌人子类型（老实人、连点器、飙车党、坦克）
- ❌ 按钮点击的实际效果（debuff 触发、失败判定）
- ❌ HUD / UI / 商店面板
- ❌ 音效
- ❌ 主菜单 / 暂停菜单

---

> **变更记录**  
> v0.1 (2026-06-20) — 初稿，游戏概述与核心循环  
> v0.2 (2026-06-21) — 基于工程实际代码重写；按钮系统改为继承模式；寻路简化为纯随机；新增 FailureButton/DebuffButton 占位类
