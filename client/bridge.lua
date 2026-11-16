CB = {}

local function started(name) return GetResourceState(name) == 'started' end

local framework = Config.Framework
if framework == 'auto' then
    if started('qbx_core') then framework = 'qbx'
    elseif started('qb-core') then framework = 'qb'
    elseif started('es_extended') then framework = 'esx'
    else framework = 'standalone' end
end

local target = Config.Target
if target == 'auto' then
    if started('ox_target') then target = 'ox_target'
    elseif started('qb-target') then target = 'qb-target'
    elseif started('qtarget') then target = 'qtarget'
    else target = 'none' end
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

CB.Framework = framework
CB.Target = target
CB.Bypass = false -- set by the server on sync (ACE Config.BypassAce)

-- { name, grade, onduty } or nil if unknown
function CB.GetJobInfo()
    local ok, info = pcall(function()
        local job
        if framework == 'qbx' then job = exports.qbx_core:GetPlayerData().job
        elseif framework == 'qb' then job = QBCore.Functions.GetPlayerData().job
        elseif framework == 'esx' then job = ESX.GetPlayerData().job end
        if not job then return nil end
        if framework == 'esx' then
            return { name = job.name, grade = job.grade, onduty = job.onDuty }
        end
        return { name = job.name, grade = job.grade and job.grade.level, onduty = job.onduty }
    end)
    return ok and info or nil
end

-- UI pre-check only, the server has the final say
function CB.HasJob(jobs)
    if not jobs or next(jobs) == nil or framework == 'standalone' or CB.Bypass then return true end
    local info = CB.GetJobInfo()
    if not info then return true end
    return JobAllowed(jobs, info)
end

function CB.Notify(msg, kind)
    kind = kind or 'inform'
    if started('ox_lib') then
        TriggerEvent('ox_lib:notify', { description = msg, type = kind })
    elseif framework == 'qb' and QBCore then
        QBCore.Functions.Notify(msg, kind == 'inform' and 'primary' or kind)
    elseif framework == 'esx' and ESX then
        -- ESX Legacy takes a type, older versions ignore it
        ESX.ShowNotification(msg, kind == 'inform' and 'info' or kind)
    else
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(msg)
        EndTextCommandThefeedPostTicker(false, true)
    end
end
