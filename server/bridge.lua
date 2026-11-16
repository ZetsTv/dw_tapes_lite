SB = {}

local function started(name) return GetResourceState(name) == 'started' end

local framework = Config.Framework
if framework == 'auto' then
    if started('qbx_core') then framework = 'qbx'
    elseif started('qb-core') then framework = 'qb'
    elseif started('es_extended') then framework = 'esx'
    else framework = 'standalone' end
end

local inventory = Config.Inventory
if inventory == 'auto' then
    if started('ox_inventory') then inventory = 'ox'
    elseif framework == 'qb' or framework == 'qbx' then inventory = 'qb'
    elseif framework == 'esx' then inventory = 'esx'
    else inventory = 'none' end
end

-- Core objects: export on current versions, shared-object event on older ones
local QBCore, ESX
if framework == 'qb' then
    local ok, obj = pcall(function() return exports['qb-core']:GetCoreObject() end)
    if ok and obj then QBCore = obj else TriggerEvent('QBCore:GetObject', function(o) QBCore = o end) end
elseif framework == 'esx' then
    local ok, obj = pcall(function() return exports['es_extended']:getSharedObject() end)
    if ok and obj then ESX = obj else TriggerEvent('esx:getSharedObject', function(o) ESX = o end) end
end

SB.Framework = framework
SB.Inventory = inventory

local function GetPlayer(src)
    if framework == 'qbx' then return exports.qbx_core:GetPlayer(src) end
    if framework == 'qb' then return QBCore.Functions.GetPlayer(src) end
    if framework == 'esx' then return ESX.GetPlayerFromId(src) end
end

-- newer qb-inventory versions moved the item functions into exports
local function QBInv() return started('qb-inventory') and exports['qb-inventory'] or nil end

local function QBItemBox(src, item, action)
    if not Config.QBItemBoxEvent or not QBCore then return end
    local data = QBCore.Shared.Items[item]
    if data then TriggerClientEvent(Config.QBItemBoxEvent, src, data, action, 1) end
end

function SB.Identifier(src)
    return GetPlayerIdentifierByType(src, 'license') or ('src:' .. src)
end

-- { name, grade, onduty } or nil
function SB.GetJobInfo(src)
    local ok, info = pcall(function()
        local p = GetPlayer(src)
        if not p then return nil end
        if framework == 'esx' then
            local job = p.job or (p.getJob and p.getJob())
            return job and { name = job.name, grade = job.grade, onduty = job.onDuty }
        end
        local job = p.PlayerData and p.PlayerData.job
        return job and { name = job.name, grade = job.grade and job.grade.level, onduty = job.onduty }
    end)
    return ok and info or nil
end

function SB.HasJob(src, jobs)
    if not jobs or next(jobs) == nil then return true end
    if IsPlayerAceAllowed(src, Config.BypassAce) then return true end
    if framework == 'standalone' then return true end
    return JobAllowed(jobs, SB.GetJobInfo(src))
end

function SB.HasItem(src, item)
    if inventory == 'none' then return true end
    local ok, res = pcall(function()
        if inventory == 'ox' then
            return (exports.ox_inventory:Search(src, 'count', item) or 0) > 0
        end
        if inventory == 'qb' then
            local inv = QBInv()
            if inv then
                local okInv, has = pcall(function() return inv:HasItem(src, item, 1) end)
                if okInv and has ~= nil then return has end
            end
            local p = GetPlayer(src)
            if not p or not p.Functions.GetItemByName then return false end
            local it = p.Functions.GetItemByName(item)
            return it ~= nil and (it.amount or it.count or 0) > 0
        end
        if inventory == 'esx' then
            local p = GetPlayer(src)
            local it = p and p.getInventoryItem(item)
            return it ~= nil and (it.count or 0) > 0
        end
        return false
    end)
    return ok and res or false
end

function SB.RemoveItem(src, item)
    if inventory == 'none' then return true end
    local ok, res = pcall(function()
        if inventory == 'ox' then return exports.ox_inventory:RemoveItem(src, item, 1) end
        local p = GetPlayer(src)
        if not p then return false end
        if inventory == 'qb' then
            local done
            if p.Functions.RemoveItem then
                done = p.Functions.RemoveItem(item, 1)
            elseif QBInv() then
                done = QBInv():RemoveItem(src, item, 1, false, 'dw_tapes')
            end
            if done then QBItemBox(src, item, 'remove') end
            return done
        end
        if inventory == 'esx' then
            p.removeInventoryItem(item, 1)
            return true
        end
        return false
    end)
    return ok and res and true or false
end

function SB.AddItem(src, item)
    if inventory == 'none' then return true end
    local ok, res = pcall(function()
        if inventory == 'ox' then
            if not exports.ox_inventory:CanCarryItem(src, item, 1) then return false end
            return exports.ox_inventory:AddItem(src, item, 1)
        end
        local p = GetPlayer(src)
        if not p then return false end
        if inventory == 'qb' then
            local done
            if p.Functions.AddItem then
                done = p.Functions.AddItem(item, 1)
            elseif QBInv() then
                done = QBInv():AddItem(src, item, 1, false, false, 'dw_tapes')
            end
            if done then QBItemBox(src, item, 'add') end
            return done
        end
        if inventory == 'esx' then
            if p.canCarryItem and not p.canCarryItem(item, 1) then return false end
            p.addInventoryItem(item, 1)
            return true
        end
        return false
    end)
    return ok and res and true or false
end

-- With ox_inventory, usage runs through the client export (see install/ox_inventory.lua)
function SB.RegisterUsable(item, cb)
    if inventory == 'ox' then return end
    if framework == 'qb' then
        QBCore.Functions.CreateUseableItem(item, function(source) cb(source) end)
    elseif framework == 'qbx' then
        exports.qbx_core:CreateUseableItem(item, function(source) cb(source) end)
    elseif framework == 'esx' then
        ESX.RegisterUsableItem(item, function(source) cb(source) end)
    end
end
