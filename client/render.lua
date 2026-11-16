--[[
    Draws tapes as textured polygons (DrawTexturedPoly).
    Textures are generated at runtime via DUI from html/tape.html,
    so no streamed .ytd files are needed.
]]
Render = {}

local RES = GetCurrentResourceName()
local TXD_NAME = 'dw_tapes_lite_txd'
local TEX_W, TEX_H = 1024, 64
local RATIO = Config.Render.textureRatio

local sqrt, floor = math.sqrt, math.floor
local DrawTexturedPoly = DrawTexturedPoly

local txd
local textures = {}

local function UrlEncode(s)
    return (tostring(s):gsub('[^%w%-_%.~]', function(ch) return ('%%%02X'):format(ch:byte()) end))
end

local function BuildUrl(def)
    local tex = def.texture or {}
    local params = {}
    local values = {
        style = tex.style or 'text',
        text = tex.text, bg = tex.bg, fg = tex.fg, border = tex.border,
        c1 = tex.colors and tex.colors[1], c2 = tex.colors and tex.colors[2],
    }
    for k, v in pairs(values) do
        if v then params[#params + 1] = k .. '=' .. UrlEncode(v) end
    end
    return ('nui://%s/html/tape.html?%s'):format(RES, table.concat(params, '&'))
end

-- Returns the texture once it is ready (otherwise nil and starts creating it)
function Render.GetTexture(tapeType)
    local t = textures[tapeType]
    if t then return t.ready and t or nil end

    local def = Config.Tapes[tapeType]
    if not def then return nil end

    t = { ready = false, dict = TXD_NAME, name = 'tape_' .. tapeType }
    textures[tapeType] = t

    CreateThread(function()
        if not txd then txd = CreateRuntimeTxd(TXD_NAME) end
        local dui = CreateDui(BuildUrl(def), TEX_W, TEX_H)
        t.dui = dui
        local timeout = GetGameTimer() + 10000
        while not IsDuiAvailable(dui) and GetGameTimer() < timeout do Wait(50) end
        CreateRuntimeTextureFromDuiHandle(txd, t.name, GetDuiHandle(dui))
        t.ready = true
    end)
    return nil
end

function Render.Destroy()
    for _, t in pairs(textures) do
        if t.dui then DestroyDui(t.dui) end
    end
    textures = {}
end

function Render.Brightness()
    local h = GetClockHours() + GetClockMinutes() / 60.0
    local night = Config.Render.nightBrightness
    local f
    if h >= 7.0 and h <= 19.0 then f = 1.0
    elseif h > 19.0 and h < 21.0 then f = 1.0 - (h - 19.0) / 2.0 * (1.0 - night)
    elseif h > 5.0 and h < 7.0 then f = night + (h - 5.0) / 2.0 * (1.0 - night)
    else f = night end
    return floor(255 * f)
end

-- current draw parameters (upvalues instead of many function arguments)
local cr, cg, cb, ca, cdict, cname = 255, 255, 255, 255, '', ''

-- One tape piece from (a) to (b), w = half width as vector, visible from both sides
local function Quad(ax, ay, az, bx, by, bz, wx, wy, wz, ua, ub)
    local a1x, a1y, a1z = ax - wx, ay - wy, az - wz
    local a2x, a2y, a2z = ax + wx, ay + wy, az + wz
    local b1x, b1y, b1z = bx - wx, by - wy, bz - wz
    local b2x, b2y, b2z = bx + wx, by + wy, bz + wz

    DrawTexturedPoly(a1x, a1y, a1z, b1x, b1y, b1z, b2x, b2y, b2z, cr, cg, cb, ca, cdict, cname,
        ua, 1.0, 1.0, ub, 1.0, 1.0, ub, 0.0, 1.0)
    DrawTexturedPoly(a1x, a1y, a1z, b2x, b2y, b2z, a2x, a2y, a2z, cr, cg, cb, ca, cdict, cname,
        ua, 1.0, 1.0, ub, 0.0, 1.0, ua, 0.0, 1.0)
    -- back side
    DrawTexturedPoly(a1x, a1y, a1z, b2x, b2y, b2z, b1x, b1y, b1z, cr, cg, cb, ca, cdict, cname,
        ua, 1.0, 1.0, ub, 0.0, 1.0, ub, 1.0, 1.0)
    DrawTexturedPoly(a1x, a1y, a1z, a2x, a2y, a2z, b2x, b2y, b2z, cr, cg, cb, ca, cdict, cname,
        ua, 1.0, 1.0, ua, 0.0, 1.0, ub, 0.0, 1.0)
end

--[[
    pos   = point list, count = number of points
    nx,ny = horizontal tape normal (so hanging parts don't collapse into a line)
    skip  = segment index that is not drawn (torn tape)
]]
function Render.DrawRibbon(pos, count, nx, ny, width, tex, skip, r, g, b, a)
    cr, cg, cb, ca, cdict, cname = r, g, b, a, tex.dict, tex.name
    local half = width * 0.5
    local rep = width * RATIO
    local s = 0.0

    for i = 1, count - 1 do
        local p1, p2 = pos[i], pos[i + 1]
        local dx, dy, dz = p2.x - p1.x, p2.y - p1.y, p2.z - p1.z
        local len = sqrt(dx * dx + dy * dy + dz * dz)

        if len > 0.0005 and i ~= skip then
            local ix, iy, iz = dx / len, dy / len, dz / len
            -- width direction = normal x segment direction
            local wx, wy, wz = ny * iz, -nx * iz, nx * iy - ny * ix
            local wl = sqrt(wx * wx + wy * wy + wz * wz)
            if wl < 0.25 then
                wx, wy, wz = 0.0, 0.0, half
            else
                if wz < 0.0 then wl = -wl end
                local k = half / wl
                wx, wy, wz = wx * k, wy * k, wz * k
            end

            -- split at tile boundaries so u always stays within [0,1]
            local u0 = s / rep
            local u1 = (s + len) / rep
            local du = u1 - u0
            local cu = u0
            local cx, cy, cz = p1.x, p1.y, p1.z
            while true do
                local fl = floor(cu)
                local nextU = fl + 1.0
                if u1 <= nextU + 1e-5 then
                    Quad(cx, cy, cz, p2.x, p2.y, p2.z, wx, wy, wz, cu - fl, u1 - fl)
                    break
                end
                local t = (nextU - u0) / du
                local ex, ey, ez = p1.x + dx * t, p1.y + dy * t, p1.z + dz * t
                Quad(cx, cy, cz, ex, ey, ez, wx, wy, wz, cu - fl, 1.0)
                cx, cy, cz, cu = ex, ey, ez, nextU
            end
        end
        s = s + len
    end
end

function Render.DrawTape(tape, bright)
    local tex = Render.GetTexture(tape.type)
    local s = tape.sim
    if not tex or not s then return end
    Render.DrawRibbon(s.pos, s.count, s.nx, s.ny, tape.def.width or 0.075, tex, tape.brokenSeg, bright, bright, bright, 255)
end

local previewPts = {}
function Render.DrawPreview(tapeType, a, b, ok, bright)
    local tex = Render.GetTexture(tapeType)
    if not tex then return end
    local def = Config.Tapes[tapeType]
    local ab = b - a
    local h = sqrt(ab.x * ab.x + ab.y * ab.y)
    local nx, ny = 0.0, 1.0
    if h > 0.001 then nx, ny = -ab.y / h, ab.x / h end
    previewPts[1], previewPts[2] = a, b
    if ok then
        Render.DrawRibbon(previewPts, 2, nx, ny, def.width or 0.075, tex, nil, bright, bright, bright, 190)
    else
        Render.DrawRibbon(previewPts, 2, nx, ny, def.width or 0.075, tex, nil, 255, 60, 60, 160)
    end
end
