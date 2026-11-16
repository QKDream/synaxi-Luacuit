# 相机测距与命中点

## 1. 方向公式（MC 相机约定）

yaw：0=南(+Z)，90=西(−X)；pitch：正值低头。

```lua
local cp = math.cos(pitch)
local fx = -math.sin(yaw) * cp
local fy = -math.sin(pitch)
local fz =  math.cos(yaw) * cp
```

朝向对照：

| yaw | 朝向 | (fx, fz) |
|---|---|---|
| 0 | 南 | (0, +1) |
| 90 | 西 | (−1, 0) |
| 180 | 北 | (0, −1) |
| 270 | 东 | (+1, 0) |

如果改用世界方位约定 `atan2(x,−z)`，则：

```lua
fx =  math.sin(yaw) * cp
fy =  math.sin(pitch)
fz = -math.cos(yaw) * cp
```

**两套约定差 180° 且旋向相反**，用错了会整体镜像。

## 2. 命中点

```lua
hit = cam_pos + dir * distance
```

`distance` 必须来自射线测距，不能是常数——常数会让命中点沿视线偏移，表现为“近距离准、远距离偏”。

## 3. 测距上限

传感器有最大量程（`aerocali-common.toml` 里的 `Tracker Range`，默认 20）。超出后 `distance` 不再增长，命中点被拉近。

检测方法：

```lua
if d >= cap - 0.5 then saturated = true end
```

`valid = latched and not saturated`，饱和时让下游回落到地图坐标。

## 4. 方块坐标

MC 中方块 `(x,y,z)` 的中心是 `(x+0.5, y+0.5, z+0.5)`。`hit_pos` 与整数坐标差 0.5 格属正常，不要当成误差。

## 5. 脉冲锁存

```lua
if pulse and not prevPulse then
    -- 捕获一次
end
prevPulse = pulse
```

用于“按一下取一次”的头瞄/激光测距，避免视角抖动带入。

## 6. 常见故障

| 现象 | 原因 |
|---|---|
| 偏航大时偏差大 | 角度单位（度/弧度）用错 |
| 整体转 90° 或镜像 | 约定选错 |
| 距离越远偏差越大 | `distance` 是常数或已饱和 |
| 数值不随视角变 | 脉冲未触发 / 端口未绑定 |
