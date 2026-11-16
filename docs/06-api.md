# Luacuit API 速查

## 结构

```lua
function define()
    defineInput.real("x", 0)
    defineInput.bool("b", false)
    defineInput.vec3("v", 0, 0, 0)
    defineInput.quaternion("q", 0, 0, 0, 1)

    defineOutput.real("y")
    defineOutput.bool("ok")
    defineOutput.vec3("w")
end

function loop()
    local x = input.real("x")
    local b = input.bool("b")
    local v = input.vec3("v")
    local q = input.quaternion("q")

    local vx, vy, vz = v:unpack()
    local qx, qy, qz, qw = q:unpack()
    local f = q:transform(Vector3d:new(0, 0, 1))

    output.real("y", x)
    output.bool("ok", b)
    output.vec3("w", Vector3d:new(vx, vy, vz))
end
```

## 预算（每次 `loop()`）

| 限制 | 数值 |
|---|---|
| 指令数 | 2,500,000 |
| 墙钟 | 250 ms |
| 分配 | 4 MB |
| 输出写 | 128 |
| 总线写 | 128 |

超限的帧直接作废，连续失败会把脚本置为 `DISABLED`。

## 性能经验

- 逐 tick 弹道模拟：迭代上限 600 足够（炮弹飞行通常 < 200 tick）
- 求仰角：扫描 121 点 + 二分 40 次，单帧约 2 万次迭代，安全
- 加滞环：`if (elevR == nil) or math.abs(R - elevR) > 5 then` 重算

## 跨板通信

```lua
bus.write("deviceName", "port", value)
local v = bus.read("deviceName", "port", fallback)
```

VEC3 的 `bus.write` 支持度视版本而定；不稳定时拆成三个 REAL 直连。

## 常用常量

```lua
local R2D = 180 / math.pi
local D2R = math.pi / 180
local PI2 = math.pi * 2

local function wrapPi(a) return ((a + math.pi) % PI2) - math.pi end
local function azimuth(x, z) return math.atan2(x, -z) end
```
