# IMU 与四元数

## 1. 四元数端口

```lua
defineInput.quaternion("rot", 0, 0, 0, 1)
local q = input.quaternion("rot")
local qx, qy, qz, qw = q:unpack()
local f = q:transform(Vector3d:new(0, 0, 1))   -- 注意是单冒号
```

`qw == 1.00` 且持续不变 ⇒ **端口未绑定**（单位四元数）。每次 Apply 后都要检查。

## 2. 偏航提取

### 2.1 四元数法（推荐）

```lua
local function yawOf(q)
    local qx, qy, qz, qw = q:unpack()
    return math.atan2(2 * (qw * qy + qx * qz), 1 - 2 * (qy * qy + qz * qz))
end
```

优点：俯仰/横滚不影响，不会在轴接近竖直时跳变。

### 2.2 前向量法（会退化）

```lua
local fx, fy, fz = q:transform(Vector3d:new(0, 0, 1)):unpack()
local az = math.atan2(fx, -fz)
```

当 `fx`、`fz` 同时接近 0（前向接近竖直）时方位失去意义，会出现 180° 跳变。**炮管仰角大时尤其明显**。

## 3. 偏航约定

`yawOf` 与 `atan2(x, -z)` 的零点相差 180°，直接相减会镜像/反相。用常数吸收：

```lua
local YAW_OFS = math.pi
relNeed = wrapPi(azTgt - bBody + YAW_OFS)
```

## 4. 多 IMU 架构

| 方案 | 端口 | 适用 |
|---|---|---|
| 单 IMU（炮塔） | 1 个 QUATERNION | 车体不动 |
| 双 IMU（车体 + 炮塔） | 2 个 | 车体移动 |
| 三 IMU（+炮管） | 3 个 | 需要实测仰角 |

端口数量够用（实测 3 个 QUATERNION 可同时工作）。

## 5. 角色分配

```
方位  ← 炮塔 IMU（水平，不受俯仰污染）
仰角  ← 炮管 IMU（asin(-fy)）
车体  ← 车体 IMU
```

不要用炮管 IMU 求方位：炮管一抬，其前向水平分量变化，方位会被污染。

## 6. `phys` 的坑

- `phys.quaternionToWorld()` 返回**车体**姿态，其 yaw 与 MC 方位不一致（实测朝向西方时读 0.01）
- 不要用它做航向基准

## 7. 座椅在炮塔上的特殊情况

炮塔转 → 玩家视角角跟着转 → 任何“视角角 − 车体角”都会形成正反馈。

解法：**锁存差值**

```lua
if not init then
    zero = wrapPi(seatYaw - azBar)
    init = true
end
relNeed = wrapPi(seatYaw - azBar) - zero
```

启用瞬间记下差值，之后只看变化量，闭环被打断。
