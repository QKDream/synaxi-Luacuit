# synaxi-Luacuit · CBC 火炮火控库

Synaxis / Luacuit（Minecraft 1.21.1 NeoForge，Create Big Cannons）火炮火控的实践笔记与可复用代码。

## 目录

| 文档 | 内容 |
|---|---|
| [docs/01-ballistics.md](docs/01-ballistics.md) | 弹道模型、初速标定、高低角求解 |
| [docs/02-azimuth.md](docs/02-azimuth.md) | 方位闭环、传动比、开环与防震荡 |
| [docs/03-imu.md](docs/03-imu.md) | 四元数、偏航提取、双/三 IMU 架构 |
| [docs/04-camera.md](docs/04-camera.md) | 相机测距、命中点解算、坐标系约定 |
| [docs/05-pitfalls.md](docs/05-pitfalls.md) | 踩坑清单与修复对照表 |
| [docs/06-api.md](docs/06-api.md) | Luacuit API 速查与预算限制 |
| [docs/07-lesson-outline.md](docs/07-lesson-outline.md) | 《控制学进阶与闭环控制论》对话大纲 |

## 快速开始

1. 主板脚本：`src/fire_control_main.lua`
2. 链接板（目标源选择）：`src/link_board.lua`
3. 相机板（可选）：`src/camera_board.lua`

## 核心结论（先看这个）

- CBC 大炮初速：`V0 = 2 × 装药`（格/tick），重力 `0.05`，阻力每 tick `×0.99`
- 弹道解析式：`y = ((5·secθ)/n + tanθ)·x + 500·ln(1−inner) − (5k)/n + 2`，`inner = (x·secθ − k)/(100n)`
- 炮塔传动比：**实测值**，不要假设；方法是 manual 模式给两次已知角，读 `turret_deg`
- 方位必须用**相对角**（炮塔 − 车体），否则车体一转动就偏
- 输出端口在 Apply 后可能丢失绑定，**每次改脚本都要重新验证 yaw_target 是否还在写电机**
