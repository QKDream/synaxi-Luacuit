-- CBC fire control main board
-- YAW_REVERSE = true for a reversed turret drive
local R2D, D2R, PI2 = 180 / math.pi, math.pi / 180, math.pi * 2

local function wrapPi(a) return ((a + math.pi) % PI2) - math.pi end
local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi else return v end end
local function azimuth(x, z) return math.atan2(x, -z) end
local function nan(v) return v ~= v end
local function yawOf(q)
    local qx, qy, qz, qw = q:unpack()
    return math.atan2(2 * (qw * qy + qx * qz), 1 - 2 * (qy * qy + qz * qz))
end

local CHARGE = 4
local KV, NV = 3.0, CHARGE * 2.0

local function heightAt(a, n, k, x)
    local t = a * D2R
    local ct = math.cos(t)
    if math.abs(ct) < 1e-6 then return nil end
    local s, tan = 1 / ct, math.tan(t)
    local inner = (x * s - k) / (100 * n)
    if inner >= 1 then return nil end
    return ((5 * s) / n + tan) * x + 500 * math.log(1 - inner) - (5 * k) / n + 2
end

local function solvePitch(n, k, x, dy, hi)
    local sols, pA, pD = {}, nil, nil
    local a = -30.0
    while a <= 60.0 + 1e-9 do
        local y = heightAt(a, n, k, x)
        local d = y and (y - dy) or nil
        if d and pD and pD * d < 0 then
            local bl, bh = pA, a
            for _ = 1, 40 do
                local bm = (bl + bh) * 0.5
                local ym = heightAt(bm, n, k, x)
                if ym == nil then bl = bm
                elseif (ym - dy) * pD > 0 then bl = bm
                else bh = bm end
            end
            sols[#sols + 1] = (bl + bh) * 0.5
        end
        pA, pD = a, d
        a = a + 0.5
    end
    if #sols == 0 then return nil end
    table.sort(sols)
    return hi and sols[#sols] or sols[1]
end

local AX_BARREL = 3
local MOFF = { 0.0, 1.5, 0.0 }
local PITCH0, PITCH_SGN = -0.17 * D2R, -1.0

local YAW_REVERSE = false       -- true: 方向机反向版本
local YAW_MIR = YAW_REVERSE and 1.0 or -1.0
local YAW_OFS = math.pi
local K_REL = 1.0
local YAW_RATE = 0.03

function define()
    defineInput.quaternion("rot_body", 0, 0, 0, 1)
    defineInput.quaternion("rot_turret", 0, 0, 0, 1)
    defineInput.quaternion("rot_barrel", 0, 0, 0, 1)
    defineInput.vec3("body_pos", 0, 0, 0)
    defineInput.real("yaw_angle", 0)
    defineInput.real("pitch_angle", 0)
    defineInput.bool("use_seat", false)
    defineInput.real("seat_yaw", 0)
    defineInput.real("seat_pitch", 0)
    defineInput.real("seat_off_deg", 90)
    defineInput.bool("use_map", false)
    defineInput.vec3("aim_target", 0, 64, 0)
    defineInput.real("tx", 0); defineInput.real("ty", 64); defineInput.real("tz", 0)
    defineInput.bool("traj_high", false)
    defineInput.bool("manual", false)
    defineInput.real("cmd", 0); defineInput.real("pitch_cmd", 0)

    defineOutput.real("yaw_target"); defineOutput.real("pitch_target")
    defineOutput.bool("seat_mode"); defineOutput.bool("tgt_ok")
    defineOutput.real("range"); defineOutput.real("elev_need_deg")
    defineOutput.real("elev_bar_deg"); defineOutput.real("rel_need_deg")
    defineOutput.real("err_deg"); defineOutput.real("flight_s")
end

local function axisVec(a)
    if a == 1 then return 1, 0, 0 elseif a == 2 then return -1, 0, 0
    elseif a == 4 then return 0, 0, -1 elseif a == 5 then return 0, 1, 0
    elseif a == 6 then return 0, -1, 0 else return 0, 0, 1 end
end

local elevDeg, elevR, R = 0.0, nil, 0.0
local cmdHold, relPrev = nil, nil

function loop()
    local qb = input.quaternion("rot_body")
    local qt = input.quaternion("rot_turret")
    local qr = input.quaternion("rot_barrel")

    local bx, by, bz = input.vec3("body_pos"):unpack()
    if nan(bx) or nan(by) or nan(bz) then bx, by, bz = 0, 0, 0 end

    local o = qb:transform(Vector3d:new(MOFF[1], MOFF[2], MOFF[3]))
    local ox, oy, oz = o:unpack()
    local px, py, pz = bx + ox, by + oy, bz + oz

    local bBody = wrapPi(yawOf(qb))
    local azBar = wrapPi(yawOf(qt))
    local axx, ayy, azz = axisVec(AX_BARREL)
    local _, fy, _ = qr:transform(Vector3d:new(axx, ayy, azz)):unpack()
    output.real("elev_bar_deg", math.asin(clamp(-fy, -1, 1)) * R2D)

    if input.bool("manual") then
        output.real("yaw_target", input.real("cmd"))
        output.real("pitch_target", input.real("pitch_cmd"))
        return
    end

    -- head aim: same math as map mode, target bearing = player view
    if input.bool("use_seat") then
        local seatAz = (input.real("seat_yaw") + input.real("seat_off_deg")) * D2R + math.pi
        local relNeed = wrapPi(YAW_MIR * seatAz - bBody + YAW_OFS)
        output.real("yaw_target", relNeed / K_REL)
        output.real("rel_need_deg", relNeed * R2D)
        output.real("err_deg", relNeed * R2D)
        output.bool("seat_mode", true)
        output.bool("tgt_ok", true)
        output.real("range", 0)

        local sp = -input.real("seat_pitch") * D2R
        output.real("pitch_target", (sp - PITCH0) / PITCH_SGN)
        output.real("elev_need_deg", -input.real("seat_pitch"))
        return
    end
    output.bool("seat_mode", false)

    local tx, ty, tz = input.real("tx"), input.real("ty"), input.real("tz")
    if nan(tx) or nan(ty) or nan(tz) then tx, ty, tz = 0, 64, 0 end

    local tOk = false
    if input.bool("use_map") then
        local a3, b3, c3 = input.vec3("aim_target"):unpack()
        if not (nan(a3) or nan(b3) or nan(c3)) then tx, ty, tz = a3, b3, c3; tOk = true end
    end
    output.bool("tgt_ok", tOk)

    local relNeed = wrapPi(YAW_MIR * azimuth(tx - px, tz - pz) - bBody + YAW_OFS)
    output.real("rel_need_deg", relNeed * R2D)
    output.real("err_deg", wrapPi(relNeed - wrapPi(azBar - bBody)) * R2D)

    if cmdHold == nil or relPrev == nil then
        cmdHold = relNeed / K_REL
    else
        cmdHold = cmdHold + clamp(wrapPi(relNeed - relPrev) / K_REL, -YAW_RATE, YAW_RATE)
    end
    relPrev = relNeed
    output.real("yaw_target", cmdHold)

    local dx, dz = tx - px, tz - pz
    local dy = ty - py
    R = math.max(1.0, math.sqrt(dx * dx + dz * dz))

    if (elevR == nil) or (math.abs(R - elevR) > 5.0) then
        elevR = R
        elevDeg = solvePitch(NV, KV, R, dy, input.bool("traj_high")) or 0.0
    end

    output.real("pitch_target", (elevDeg * D2R - PITCH0) / PITCH_SGN)
    output.real("elev_need_deg", elevDeg)
    output.real("range", R)

    local ft = 0.0
    local ct = math.cos(elevDeg * D2R)
    if math.abs(ct) > 1e-6 then
        local inner = (R / ct - KV) / (100 * NV)
        if inner < 1 and inner > 0 then ft = (math.log(1 - inner) / math.log(0.99)) / 20.0 end
    end
    output.real("flight_s", ft)
end
