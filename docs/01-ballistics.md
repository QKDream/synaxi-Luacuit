# 弹道模型与仰角求解

## 1. CBC 大炮的离散运动

每 tick：

```
vy -= 0.05           -- 重力
v  *= 0.99           -- 阻力
pos += v
```

初速换算：源码中 `v = 40n`（m/s），1 m/s = 0.05 格/tick，故

```
V0（格/tick） = 2 × n        n = 装药数
```

旧版本为 `20n`，即 `V0 = n`。**版本不同要重新确认**。

## 2. 解析式（推荐）

线性阻力的连续解：

```
inner = (x·secθ − k) / (100·n)
y = ((5·secθ)/n + tanθ)·x + 500·ln(1 − inner) − (5k)/n + 2
```

- `x` 水平距离，`y` 相对炮口高度
- `k` 炮管方块数（不含底座）
- `n = 2 × 装药`

成立条件：`inner < 1`，否则该距离超出射程。

## 3. 求仰角

`y(θ)` 不单调：先升后降，因此最多两个解（低角/高角）。

做法：以 0.5° 步长扫 −30°~60°，找相邻两点异号区间，再二分 40 次。

```lua
local function solvePitch(n, k, x, dy, preferHigh)
    local sols, prevA, prevD = {}, nil, nil
    local a = -30.0
    while a <= 60.0 + 1e-9 do
        local y = heightAt(a, n, k, x)
        local d = y and (y - dy) or nil
        if d and prevD and prevD * d < 0 then
            local bl, bh = prevA, a
            for _ = 1, 40 do
                local bm = (bl + bh) * 0.5
                local ym = heightAt(bm, n, k, x)
                if ym == nil then bl = bm
                elseif (ym - dy) * prevD > 0 then bl = bm
                else bh = bm end
            end
            sols[#sols + 1] = (bl + bh) * 0.5
        end
        prevA, prevD = a, d
        a = a + 0.5
    end
    if #sols == 0 then return nil end
    table.sort(sols)
    return preferHigh and sols[#sols] or sols[1]
end
```

## 4. 实测标定法（模型不确定时）

已知仰角 `θ`、水平距离 `R`、高度差 `dh`，二分反解 `V0`：

```lua
local lo, hi = 1.0, 40.0
for _ = 1, 30 do
    local mid = (lo + hi) * 0.5
    if rangeAt(mid, theta, dh) > R then hi = mid else lo = mid end
end
local V0 = (lo + hi) * 0.5
```

一般 45° 打一发、600 格以上，精度最好。

## 5. 常见错误

| 现象 | 原因 |
|---|---|
| 仰角恒为 60°（上端） | 求解区间端点被当成解，`solvePitch` 返回的其实是边界 |
| 仰角为 0 | 所有角度都 `inner ≥ 1`（超程） |
| 仰角算小、打近 | `V0` 偏小 |
| 高抛不生效 | 目标超出高角可达范围；或 `traj_high` 端口名不一致 |

## 6. 单位陷阱

- `solvePitch` 返回**度**，脚本其他地方用**弧度** —— 必须 `* D2R`
- 这个错误会让 `pitch_target` 变成 −6 rad，炮管直接怼地
