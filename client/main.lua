--[[
    dw_tapes_lite - static barrier tapes.
    The full version (dw_tapes) adds rope physics, lifting, tearing, tape rolls, chain mode,
    cutting, vehicle anchors, NPC traffic blocking, sounds, admin menu and Discord logs.
]]
local L = Locale
local floor, max = math.floor, math.max

local HELP_ENTRY = 'DW_TAPES_LITE_HELP'

Tapes = {}

local streamed, streamedCount = {}, 0
local forceStream = false
local placing = nil
local busy = false
local PickupTape

-- Ground posts are shared: several tapes may hang on the same cone.
local posts = {}
local postByEntity = {}

-- ============================================================
-- Helpers
-- ============================================================

local function LoadModel(model)
    if not IsModelInCdimage(model) then return false end
    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) do
        if GetGameTimer() > timeout then return false end
        Wait(10)
    end
    return true
end

local function PlayAnim(anim)
    if not anim then return end
    if not HasAnimDictLoaded(anim.dict) then
        RequestAnimDict(anim.dict)
        local timeout = GetGameTimer() + 5000
        while not HasAnimDictLoaded(anim.dict) do
            if GetGameTimer() > timeout then return Wait(anim.duration or 1000) end
            Wait(10)
        end
    end
    local ped = PlayerPedId()
    TaskPlayAnim(ped, anim.dict, anim.clip, 3.0, 3.0, -1, anim.flag or 49, 0.0, false, false, false)
    Wait(anim.duration or 1000)
    StopAnimTask(ped, anim.dict, anim.clip, 1.5)
end

local lastHelp
local function Help(text)
    if lastHelp ~= text then
        AddTextEntry(HELP_ENTRY, text)
        lastHelp = text
    end
    BeginTextCommandDisplayHelp(HELP_ENTRY)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

local function Text3D(pos, text)
    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(255, 255, 255, 220)
    SetTextOutline()
    SetTextCentre(true)
    SetDrawOrigin(pos.x, pos.y, pos.z, 0)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

local function RotToDir(rot)
    local z, x = math.rad(rot.z), math.rad(rot.x)
    local c = math.abs(math.cos(x))
    return vector3(-math.sin(z) * c, math.cos(z) * c, math.sin(x))
end

local function IsHit(hit) return hit == true or hit == 1 end

local function CamRaycast(dist)
    local from = GetGameplayCamCoord()
    local to = from + RotToDir(GetGameplayCamRot(2)) * dist
    local handle = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 1 | 16, PlayerPedId(), 7)
    local _, hit, coords, normal, entity = GetShapeTestResult(handle)
    return IsHit(hit), coords, normal, entity
end

local function HasLineOfSight(a, b)
    local handle = StartExpensiveSynchronousShapeTestLosProbe(a.x, a.y, a.z, b.x, b.y, b.z, 1 | 16, PlayerPedId(), 7)
    local _, hit, coords = GetShapeTestResult(handle)
    if not IsHit(hit) then return true end
    return #(coords - b) < 0.25 or #(coords - a) < 0.25
end

local postHeight
local function GetPostHeight()
    local gp = Config.Placement.groundPost
    if not gp or not gp.model then return nil end
    if postHeight then return postHeight end
    local model = GetHashKey(gp.model)
    if not LoadModel(model) then return nil end
    local mn, mx = GetModelDimensions(model)
    postHeight = (mx.z - mn.z) + (gp.attachOffset or 0.0)
    return postHeight
end

local function CanRemove(tape)
    return CB.HasJob(tape.def.removeJobs)
end

-- Static sagging shape (parabola), computed once when the tape comes into range
local function BuildShape(tape)
    local cfg = Config.Render
    local a, b = tape.a, tape.b
    local ab = b - a
    local len = #ab
    local segs = max(2, cfg.segments or 12)
    local sag = math.min(len * (cfg.sag or 0.025), cfg.maxSag or 0.3)
    local pos = {}
    for i = 0, segs do
        local t = i / segs
        pos[i + 1] = a + ab * t - vector3(0.0, 0.0, sag * 4.0 * t * (1.0 - t))
    end
    local h = math.sqrt(ab.x * ab.x + ab.y * ab.y)
    local nx, ny = 0.0, 1.0
    if h > 0.001 then nx, ny = -ab.y / h, ab.x / h end
    tape.sim = { pos = pos, count = segs + 1, segs = segs, nx = nx, ny = ny }
end

-- ============================================================
-- Target
-- ============================================================

local function AddTarget(tape)
    if CB.Target == 'none' then return end
    local s = tape.sim
    local points = { tape.a, tape.b, s.pos[floor(s.count / 2) + 1] }
    tape.zones = {}

    for k, p in ipairs(points) do
        if CB.Target == 'ox_target' then
            tape.zones[k] = exports.ox_target:addSphereZone({
                coords = p,
                radius = 0.5,
                debug = Config.Debug,
                options = { {
                    name = 'dw_tapes_lite_remove',
                    icon = 'fa-solid fa-hand',
                    label = L.target_remove,
                    distance = 2.5,
                    canInteract = function() return CanRemove(tape) end,
                    onSelect = function() CreateThread(function() PickupTape(tape.id) end) end,
                } },
            })
        else -- qb-target and qtarget share the same zone API
            local name = ('dw_tapes_lite_%s_%s'):format(tape.id, k)
            exports[CB.Target]:AddCircleZone(name, p, 0.5, { name = name, debugPoly = Config.Debug, useZ = true }, {
                options = { {
                    icon = 'fas fa-hand-paper',
                    label = L.target_remove,
                    canInteract = function() return CanRemove(tape) end,
                    action = function() CreateThread(function() PickupTape(tape.id) end) end,
                } },
                distance = 2.5,
            })
            tape.zones[k] = name
        end
    end
end

local function RemoveTarget(tape)
    if not tape.zones then return end
    for _, z in pairs(tape.zones) do
        if CB.Target == 'ox_target' then
            exports.ox_target:removeZone(z)
        else
            exports[CB.Target]:RemoveZone(z)
        end
    end
    tape.zones = nil
end

-- ============================================================
-- Ground posts (reference counted)
-- ============================================================

local function PostKey(ground)
    return ('%.1f:%.1f:%.1f'):format(ground.x, ground.y, ground.z)
end

local function AcquirePost(ground, anchor, heading, model)
    local key = PostKey(ground)
    local post = posts[key]
    if post then
        post.refs = post.refs + 1
        return key
    end
    local obj = CreateObjectNoOffset(model, ground.x, ground.y, ground.z, false, false, false)
    SetEntityHeading(obj, heading)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    post = { obj = obj, refs = 1, anchor = anchor, ground = ground }
    posts[key] = post
    postByEntity[obj] = post
    return key
end

local function ReleasePost(key)
    local post = posts[key]
    if not post then return end
    post.refs = post.refs - 1
    if post.refs > 0 then return end
    postByEntity[post.obj] = nil
    if DoesEntityExist(post.obj) then DeleteEntity(post.obj) end
    posts[key] = nil
end

local function SpawnPosts(tape)
    local gp = Config.Placement.groundPost
    if not gp or not gp.model or (not tape.postA and not tape.postB) then return end
    local model = GetHashKey(gp.model)
    if not LoadModel(model) or not tape.streamed then return end

    tape.postKeys = {}
    local heading = GetHeadingFromVector_2d(tape.b.x - tape.a.x, tape.b.y - tape.a.y)
    if tape.postA then tape.postKeys[#tape.postKeys + 1] = AcquirePost(tape.postA, tape.a, heading, model) end
    if tape.postB then tape.postKeys[#tape.postKeys + 1] = AcquirePost(tape.postB, tape.b, heading, model) end
    SetModelAsNoLongerNeeded(model)
end

-- ============================================================
-- Streaming + drawing
-- ============================================================

local function StreamIn(tape)
    if tape.streamed then return end
    BuildShape(tape)
    tape.streamed = true
    streamed[tape.id] = tape
    streamedCount = streamedCount + 1
    Render.GetTexture(tape.type)
    AddTarget(tape)
    SpawnPosts(tape)
end

local function StreamOut(tape)
    if not tape.streamed then return end
    tape.streamed = false
    streamed[tape.id] = nil
    streamedCount = streamedCount - 1
    RemoveTarget(tape)
    if tape.postKeys then
        for _, key in ipairs(tape.postKeys) do ReleasePost(key) end
    end
    tape.postKeys = nil
    tape.sim = nil
end

local function PrepareTape(data)
    local def = Config.Tapes[data.type]
    if not def then return nil end
    data.def = def
    data.center = (data.a + data.b) * 0.5
    data.length = #(data.a - data.b)
    data.dist = math.huge
    return data
end

CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        local renderDist = Config.Render.distance

        local ids = {}
        for id in pairs(Tapes) do ids[#ids + 1] = id end

        for _, id in ipairs(ids) do
            local tape = Tapes[id]
            if tape then
                local d = #(pos - tape.center) - tape.length * 0.5
                tape.dist = d
                if not tape.streamed then
                    if d < renderDist then StreamIn(tape) end
                elseif d > renderDist + 10.0 then
                    StreamOut(tape)
                end
            end
        end

        local waited = 0
        while waited < 500 and not forceStream do
            Wait(100)
            waited = waited + 100
        end
        forceStream = false
    end
end)

CreateThread(function()
    while true do
        if streamedCount == 0 then
            Wait(300)
        else
            local bright = Render.Brightness()
            for _, tape in pairs(streamed) do
                local c = tape.center
                if IsSphereVisible(c.x, c.y, c.z, tape.length * 0.5 + 1.5) then
                    Render.DrawTape(tape, bright)
                end
            end
            Wait(0)
        end
    end
end)

-- ============================================================
-- Placement
-- ============================================================

-- returns anchor (where the tape attaches) and post (ground position of a cone, or nil)
local function ResolveAnchor(coords, normal, entity)
    if entity and entity ~= 0 and postByEntity[entity] then
        local post = postByEntity[entity]
        return post.anchor, post.ground
    end
    for _, t in pairs(streamed) do
        if #(coords - t.a) < 0.3 then return t.a, t.postA end
        if #(coords - t.b) < 0.3 then return t.b, t.postB end
    end

    if normal.z >= Config.Placement.groundNormal then
        local h = GetPostHeight()
        if h then return coords + vector3(0.0, 0.0, h), coords end
        return coords + vector3(0.0, 0.0, Config.Placement.groundHeight), nil
    end

    return coords + normal * 0.03, nil
end

local DISABLED = { 24, 25, 37, 44, 140, 141, 142, 143, 257, 263, 264, 14, 15, 16, 17 }

local function StartPlacement(tapeType, skipJobCheck)
    if placing then
        placing = nil
        return CB.Notify(L.cancelled, 'inform')
    end
    if busy then return end

    local def = Config.Tapes[tapeType]
    if not def then return end
    if not skipJobCheck and not CB.HasJob(def.jobs) then return CB.Notify(L.no_permission, 'error') end
    if IsPedInAnyVehicle(PlayerPedId(), false) then return CB.Notify(L.in_vehicle, 'error') end

    local state = { type = tapeType }
    placing = state
    Render.GetTexture(tapeType)

    CreateThread(function()
        local cfg = Config.Placement
        local maxLen = def.maxLength or 15.0

        while placing == state do
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then
                placing = nil
                break
            end

            for i = 1, #DISABLED do DisableControlAction(0, DISABLED[i], true) end

            local bright = Render.Brightness()
            local hit, coords, normal, entity = CamRaycast(cfg.reach + 8.0)
            local anchor, post, valid
            if hit then
                anchor, post = ResolveAnchor(coords, normal, entity)
                valid = #(GetEntityCoords(ped) - coords) <= cfg.reach
            end

            if not state.a then
                Help(L.help_point_a)
                if anchor then
                    local r, g = valid and 70 or 220, valid and 200 or 60
                    DrawMarker(28, anchor.x, anchor.y, anchor.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.06, 0.06, 0.06, r, g, 70, 200, false, false, 2, false, nil, nil, false)
                    if post then DrawLine(post.x, post.y, post.z, anchor.x, anchor.y, anchor.z, r, g, 70, 200) end
                    if not valid then Text3D(anchor + vector3(0.0, 0.0, 0.15), L.too_far) end
                end

                if IsControlJustPressed(0, 38) then
                    if anchor and valid then
                        state.a, state.postA = anchor, post
                        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
                    else
                        PlaySoundFrontend(-1, 'ERROR', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
                    end
                elseif IsDisabledControlJustPressed(0, 25) then
                    placing = nil
                    CB.Notify(L.cancelled, 'inform')
                end
            else
                Help(L.help_point_b)
                local a = state.a
                DrawMarker(28, a.x, a.y, a.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.06, 0.06, 0.06, 70, 200, 70, 220, false, false, 2, false, nil, nil, false)
                if state.postA then DrawLine(state.postA.x, state.postA.y, state.postA.z, a.x, a.y, a.z, 70, 200, 70, 200) end

                if anchor then
                    local len = #(anchor - a)
                    local reason
                    if not valid then reason = L.too_far
                    elseif len > maxLen then reason = L.too_long
                    elseif len < cfg.minLength then reason = L.too_short
                    elseif cfg.requireLineOfSight and not HasLineOfSight(a, anchor) then reason = L.no_los end
                    local ok = reason == nil

                    if post then DrawLine(post.x, post.y, post.z, anchor.x, anchor.y, anchor.z, ok and 70 or 220, ok and 200 or 60, 70, 200) end
                    Render.DrawPreview(tapeType, a, anchor, ok, bright)

                    local label = ('%s%.1f m / %.1f m'):format(ok and '~g~' or '~r~', len, maxLen)
                    if reason then label = label .. '~n~' .. reason end
                    Text3D((a + anchor) * 0.5 + vector3(0.0, 0.0, 0.25), label)

                    if IsControlJustPressed(0, 38) then
                        if ok then
                            local b, postA = anchor, state.postA
                            placing = nil
                            busy = true
                            PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
                            TaskTurnPedToFaceCoord(ped, b.x, b.y, b.z, 500)
                            Wait(500)
                            PlayAnim(Config.Anims.place)
                            TriggerServerEvent('dw_tapes_lite:server:place', tapeType, a, b, postA, post)
                            busy = false
                            break
                        else
                            PlaySoundFrontend(-1, 'ERROR', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
                        end
                    end
                end

                if IsDisabledControlJustPressed(0, 25) then
                    state.a, state.postA = nil, nil
                end
            end

            if IsControlJustPressed(0, 194) then
                placing = nil
                CB.Notify(L.cancelled, 'inform')
            end

            Wait(0)
        end
    end)
end

-- ============================================================
-- Pick up
-- ============================================================

PickupTape = function(id)
    if busy or placing then return end
    local tape = Tapes[id]
    if not tape then return end
    if not CanRemove(tape) then return CB.Notify(L.no_permission, 'error') end

    busy = true
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local target = #(pos - tape.b) < #(pos - tape.a) and tape.b or tape.a
    TaskTurnPedToFaceCoord(ped, target.x, target.y, target.z, 500)
    Wait(500)
    PlayAnim(Config.Anims.pickup)
    if Tapes[id] then TriggerServerEvent('dw_tapes_lite:server:remove', id) end
    busy = false
end

-- Fallback without a target script: press G near an end point
if CB.Target == 'none' then
    CreateThread(function()
        while true do
            local sleep = 500
            if streamedCount > 0 and not placing and not busy then
                local pos = GetEntityCoords(PlayerPedId())
                local best, bestD = nil, 1.6
                for _, t in pairs(streamed) do
                    if t.dist < 5.0 then
                        sleep = 200
                        local da, db = #(pos - t.a), #(pos - t.b)
                        if da < bestD then best, bestD = t, da end
                        if db < bestD then best, bestD = t, db end
                    end
                end
                if best and CanRemove(best) then
                    sleep = 0
                    Help(L.help_remove)
                    if IsControlJustPressed(0, 47) then
                        local id = best.id
                        CreateThread(function() PickupTape(id) end)
                    end
                end
            end
            Wait(sleep)
        end
    end)
end

-- ============================================================
-- Events / exports
-- ============================================================

RegisterNetEvent('dw_tapes_lite:client:use', function(tapeType, skipJobCheck)
    StartPlacement(tapeType, skipJobCheck == true)
end)

-- ox_inventory: client = { export = 'dw_tapes_lite.useTape' }
exports('useTape', function(data)
    StartPlacement(type(data) == 'table' and data.name or data)
end)
exports('startPlacement', function(tapeType) StartPlacement(tapeType) end)

RegisterNetEvent('dw_tapes_lite:client:sync', function(list, bypass)
    CB.Bypass = bypass == true
    for _, tape in pairs(Tapes) do StreamOut(tape) end
    Tapes = {}
    for _, data in ipairs(list) do
        local tape = PrepareTape(data)
        if tape then Tapes[tape.id] = tape end
    end
    forceStream = true
end)

RegisterNetEvent('dw_tapes_lite:client:add', function(data)
    local tape = PrepareTape(data)
    if tape then
        Tapes[tape.id] = tape
        forceStream = true
    end
end)

RegisterNetEvent('dw_tapes_lite:client:remove', function(id)
    local tape = Tapes[id]
    if not tape then return end
    StreamOut(tape)
    Tapes[id] = nil
end)

RegisterNetEvent('dw_tapes_lite:client:notify', function(msg, kind)
    CB.Notify(msg, kind)
end)

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(250) end
    TriggerServerEvent('dw_tapes_lite:server:requestSync')
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, tape in pairs(Tapes) do StreamOut(tape) end
    Render.Destroy()
end)
