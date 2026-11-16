--[[
    Job check shared by client and server.

    jobs = { 'police', 'sheriff' }        -> any grade
    jobs = { police = 2, sheriff = 0 }    -> minimum grade per job
    info = { name = 'police', grade = 3, onduty = true }  (onduty nil = framework has no duty system)
]]
function JobAllowed(jobs, info)
    if not jobs or next(jobs) == nil then return true end
    if not info or not info.name then return false end
    if Config.RequireOnDuty and info.onduty == false then return false end

    for k, v in pairs(jobs) do
        if type(k) == 'number' then
            if v == info.name then return true end
        elseif k == info.name then
            return (info.grade or 0) >= v
        end
    end
    return false
end
