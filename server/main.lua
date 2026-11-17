local RES = GetCurrentResourceName()
local L = Locale
local SAVE_FILE = 'tapes.json'   -- same format as the full version: copy it over when upgrading

local tapes = {}
local nextId = 1
local dirty = false
local cooldown = {}
local freeUse = {}   -- players placing via command (without item)

local function Notify(src, msg, kind)
    TriggerClientEvent('dw_tapes_lite:client:notify', src, msg, kind)
end

-- clients only get a salted hash of the owner, never the identifier itself
local ownerSalt = ('%d:%d'):format(math.random(1, 0x3FFFFFFF), os.time())
local function OwnerTag(owner)
    return owner and GetHashKey(ownerSalt .. owner) or nil
end

local function OwnsTape(src, tape)
    if Config.OwnerCanRemove == false or not tape.owner then return false end
    return tape.owner == SB.Identifier(src)
end

local function ToClient(t)
    return { id = t.id, type = t.type, a = t.a, b = t.b, postA = t.postA, postB = t.postB, own = OwnerTag(t.owner) }
end

local function VecToTbl(v) return v and { x = v.x, y = v.y, z = v.z } or nil end
local function TblToVec(t) return t and vector3(t.x + 0.0, t.y + 0.0, t.z + 0.0) or nil end

local function DistToSegment(p, a, b)
    local ab = b - a
    local l2 = ab.x * ab.x + ab.y * ab.y + ab.z * ab.z
    if l2 < 1e-6 then return #(p - a) end
    local ap = p - a
    local t = (ap.x * ab.x + ap.y * ab.y + ap.z * ab.z) / l2
    t = math.max(0.0, math.min(1.0, t))
    return #(p - (a + ab * t))
end

-- ============================================================
-- Persistence
-- ============================================================

local function Save()
    if not Config.Persist then return end
    local out = {}
    for _, t in pairs(tapes) do
        out[#out + 1] = {
            id = t.id, type = t.type, owner = t.owner, ownerName = t.ownerName, free = t.free, created = t.created,
            a = VecToTbl(t.a), b = VecToTbl(t.b), postA = VecToTbl(t.postA), postB = VecToTbl(t.postB),
        }
    end
    SaveResourceFile(RES, SAVE_FILE, json.encode(out), -1)
end

local function Load()
    if not Config.Persist then return end
    local raw = LoadResourceFile(RES, SAVE_FILE)
    if not raw or raw == '' then return end
    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= 'table' then return end
    local count = 0
    for _, t in ipairs(data) do
        if Config.Tapes[t.type] and t.a and t.b and not t.broken then
            tapes[t.id] = {
                id = t.id, type = t.type, owner = t.owner, ownerName = t.ownerName, free = t.free, created = t.created or os.time(),
                a = TblToVec(t.a), b = TblToVec(t.b), postA = TblToVec(t.postA), postB = TblToVec(t.postB),
            }
            nextId = math.max(nextId, t.id + 1)
            count = count + 1
        end
    end
    print(('[dw_tapes_lite] ' .. L.loaded):format(count))
end

local function RemoveTape(id)
    if not tapes[id] then return end
    tapes[id] = nil
    dirty = true
    TriggerClientEvent('dw_tapes_lite:client:remove', -1, id)
end

CreateThread(function()
    Load()
    while true do
        Wait(10000)
        if dirty then
            dirty = false
            Save()
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == RES then Save() end
end)

-- Bypass ACE as the client knows it. Frameworks often grant group.admin only when the character
-- loads, after the first sync -> changes are pushed, otherwise the client hides "remove" for admins.
local bypassSent = {}
local function SendPerms(src)
    local bypass = IsPlayerAceAllowed(src, Config.BypassAce)
    if bypassSent[src] ~= bypass then
        bypassSent[src] = bypass
        TriggerClientEvent('dw_tapes_lite:client:perms', src, bypass)
    end
end

CreateThread(function()
    while true do
        Wait(5000)
        for src in pairs(bypassSent) do
            if GetPlayerName(src) then SendPerms(src) else bypassSent[src] = nil end
        end
    end
end)

AddEventHandler('playerDropped', function()
    cooldown[source] = nil
    freeUse[source] = nil
    bypassSent[source] = nil
end)

-- ============================================================
-- Items / commands
-- ============================================================

CreateThread(function()
    Wait(500)
    for tapeType in pairs(Config.Tapes) do
        SB.RegisterUsable(tapeType, function(src)
            SendPerms(src)
            TriggerClientEvent('dw_tapes_lite:client:use', src, tapeType)
        end)
    end
end)

local function TypeList()
    local names = {}
    for k in pairs(Config.Tapes) do names[#names + 1] = k end
    table.sort(names)
    return table.concat(names, ', ')
end

if Config.Command and Config.Command.enabled then
    RegisterCommand(Config.Command.name, function(src, args)
        if src == 0 then return end
        if not IsPlayerAceAllowed(src, Config.Command.ace) then return Notify(src, L.no_permission, 'error') end
        local tapeType = args[1] or 'police_tape'
        if not Config.Tapes[tapeType] then return Notify(src, L.unknown_type:format(TypeList()), 'error') end
        freeUse[src] = tapeType
        TriggerClientEvent('dw_tapes_lite:client:use', src, tapeType, true)
    end, false)
end

RegisterCommand(Config.AdminCommand.name, function(src, args)
    if src ~= 0 and not IsPlayerAceAllowed(src, Config.AdminCommand.ace) then
        return Notify(src, L.no_permission, 'error')
    end
    local radius = tonumber(args[1])
    local origin = src ~= 0 and GetEntityCoords(GetPlayerPed(src)) or nil
    local count = 0
    for id, t in pairs(tapes) do
        if not radius or not origin or DistToSegment(origin, t.a, t.b) <= radius then
            RemoveTape(id)
            count = count + 1
        end
    end
    if src == 0 then print('[dw_tapes_lite] ' .. L.cleared:format(count)) else Notify(src, L.cleared:format(count), 'success') end
end, false)

-- ============================================================
-- Network events
-- ============================================================

RegisterNetEvent('dw_tapes_lite:server:requestSync', function()
    local list = {}
    for _, t in pairs(tapes) do list[#list + 1] = ToClient(t) end
    local bypass = IsPlayerAceAllowed(source, Config.BypassAce)
    bypassSent[source] = bypass
    TriggerClientEvent('dw_tapes_lite:client:sync', source, list, bypass, OwnerTag(SB.Identifier(source)))
end)

local function ValidPost(post, anchor)
    if post == nil then return true end
    if type(post) ~= 'vector3' then return false end
    return post.z < anchor.z and #(anchor - post) < 3.0
end

RegisterNetEvent('dw_tapes_lite:server:place', function(tapeType, a, b, postA, postB)
    local src = source
    local def = Config.Tapes[tapeType]
    if not def or type(a) ~= 'vector3' or type(b) ~= 'vector3' then return end
    if not ValidPost(postA, a) or not ValidPost(postB, b) then return end

    local now = GetGameTimer()
    if cooldown[src] and now - cooldown[src] < 1500 then return end
    cooldown[src] = now

    local cfg = Config.Placement
    local maxLen = def.maxLength or 15.0
    local len = #(a - b)
    local pp = GetEntityCoords(GetPlayerPed(src))
    if len > maxLen + 0.05 or len < cfg.minLength - 0.05
        or #(pp - b) > cfg.reach + 4.0 or #(pp - a) > cfg.reach + maxLen + 6.0 then
        return Notify(src, L.invalid, 'error')
    end

    local free = freeUse[src] == tapeType
    if not free and not SB.HasJob(src, def.jobs) then return Notify(src, L.no_permission, 'error') end

    local owner = SB.Identifier(src)
    local total, mine = 0, 0
    for _, t in pairs(tapes) do
        total = total + 1
        if t.owner == owner then mine = mine + 1 end
    end
    if total >= Config.MaxTapesTotal then return Notify(src, L.limit_total, 'error') end
    if mine >= Config.MaxTapesPerPlayer and not IsPlayerAceAllowed(src, Config.BypassAce) then
        return Notify(src, L.limit_player, 'error')
    end

    if free then
        freeUse[src] = nil
    else
        if not SB.HasItem(src, tapeType) then return Notify(src, L.no_item, 'error') end
        if Config.ConsumeItem and not SB.RemoveItem(src, tapeType) then return Notify(src, L.no_item, 'error') end
    end

    local tape = {
        id = nextId, type = tapeType, owner = owner, ownerName = GetPlayerName(src),
        free = free or not Config.ConsumeItem, created = os.time(),
        a = a, b = b, postA = postA, postB = postB,
    }
    nextId = nextId + 1
    tapes[tape.id] = tape
    dirty = true

    TriggerClientEvent('dw_tapes_lite:client:add', -1, ToClient(tape))
    Notify(src, L.placed, 'success')
end)

RegisterNetEvent('dw_tapes_lite:server:remove', function(id)
    local src = source
    local tape = tapes[id]
    if not tape then return end

    local pp = GetEntityCoords(GetPlayerPed(src))
    if DistToSegment(pp, tape.a, tape.b) > 4.0 then return end

    local def = Config.Tapes[tape.type]
    -- whoever placed it may always pick it up again (also tapes placed with /tape)
    if def and not SB.HasJob(src, def.removeJobs) and not OwnsTape(src, tape) then
        return Notify(src, L.no_permission, 'error')
    end

    RemoveTape(id)

    if Config.ReturnItem and not tape.free then
        if not SB.AddItem(src, tape.type) then
            return Notify(src, L.inventory_full, 'error')
        end
    end
    Notify(src, L.removed, 'success')
end)
