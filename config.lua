Config = {}

Config.Debug    = false  -- target zone debug drawing
Config.Language = 'en'   -- 'en' | 'de'  (see locales/)

-- 'auto' detects everything from the running resources
Config.Framework = 'auto'   -- 'auto' | 'qbx' | 'qb' | 'esx' | 'standalone'
Config.Inventory = 'auto'   -- 'auto' | 'ox' | 'qb' | 'esx' | 'none'
Config.Target    = 'auto'   -- 'auto' | 'ox_target' | 'qb-target' | 'qtarget' | 'none' (none = press G near an end)

-- Job restricted tapes need the player to be on duty (QB/QBX duty, ESX job.onDuty if your ESX has it)
Config.RequireOnDuty = true

-- qb-inventory item popup. Older qb-inventory versions use 'inventory:client:ItemBox', false = off
Config.QBItemBoxEvent = 'qb-inventory:client:ItemBox'

Config.ConsumeItem = true   -- remove the item when a tape is placed
Config.ReturnItem  = true   -- give the item back when a tape is picked up

Config.MaxTapesPerPlayer = 10
Config.MaxTapesTotal     = 150
Config.Persist           = true  -- keep tapes across restarts (tapes.json in the resource folder)

-- ACE permissions
Config.Command      = { enabled = true, name = 'tape', ace = 'dw_tapes.command' } -- /tape <type> without item
Config.AdminCommand = { name = 'cleartapes', ace = 'dw_tapes.admin' }             -- /cleartapes [radius]
Config.BypassAce    = 'dw_tapes.bypass'                                           -- ignore jobs and player limit

-- Whoever placed a tape may always pick it up again, whatever removeJobs says.
-- Needed for /tape: it places any type without item and without job check.
Config.OwnerCanRemove = true

Config.Placement = {
    reach              = 6.0,   -- max. distance player -> point
    minLength          = 1.0,
    requireLineOfSight = true,  -- nothing may block the line between A and B
    groundNormal       = 0.65,  -- hits with normal.z above this count as ground
    groundHeight       = 1.0,   -- height above ground when no post prop is used
    -- Aiming at the ground spawns this prop as a post and attaches the tape on top.
    -- false = no prop, the tape floats at groundHeight
    groundPost         = { model = 'prop_roadcone02a', attachOffset = -0.03 },
}

Config.Render = {
    distance        = 60.0,  -- view distance of tapes
    textureRatio    = 16.0,  -- texture aspect ratio (1024x64) -> repeat length = width * 16
    nightBrightness = 0.45,  -- tapes are unlit -> darken them at night
    segments        = 12,    -- points per tape (static shape)
    sag             = 0.025, -- sag as fraction of the length
    maxSag          = 0.30,
}

Config.Anims = {
    place  = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer', flag = 49, duration = 1200 },
    pickup = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer', flag = 49, duration = 1500 },
}

--[[
    Key = item name (same item names as the full version, so upgrading keeps your items).
    jobs       = who may place it  (nil = everyone)
    removeJobs = who may remove it (nil = everyone)
                 list:  { 'police', 'sheriff' }       -> any grade
                 map:   { police = 2, sheriff = 0 }   -> minimum grade per job
    texture.style = 'text'    -> bg, fg, border, text
    texture.style = 'stripes' -> colors = { stripe, background }
]]
Config.Tapes = {
    police_tape = {
        label = 'Police Tape', maxLength = 15.0, width = 0.075,
        jobs = { 'police', 'sheriff' }, removeJobs = { 'police', 'sheriff' },
        texture = { style = 'text', text = 'POLICE LINE  •  DO NOT CROSS', bg = '#1d3f9e', fg = '#ffffff', border = '#ffffff' },
    },
    crimescene_tape = {
        label = 'Crime Scene Tape', maxLength = 15.0, width = 0.075,
        jobs = { 'police', 'sheriff' }, removeJobs = { 'police', 'sheriff' },
        texture = { style = 'text', text = 'CRIME SCENE  •  DO NOT CROSS', bg = '#f5c400', fg = '#111111', border = '#111111' },
    },
    caution_tape = {
        label = 'Caution Tape', maxLength = 15.0, width = 0.075,
        jobs = nil, removeJobs = nil,
        texture = { style = 'text', text = 'CAUTION  •  DO NOT ENTER', bg = '#f5c400', fg = '#111111' },
    },
    fire_tape = {
        label = 'Fire Line Tape', maxLength = 15.0, width = 0.075,
        jobs = { 'fire', 'ambulance' }, removeJobs = { 'fire', 'ambulance', 'police' },
        texture = { style = 'text', text = 'FIRE LINE  •  DO NOT CROSS', bg = '#c81e1e', fg = '#ffffff', border = '#ffffff' },
    },
    ems_tape = {
        label = 'EMS Tape', maxLength = 15.0, width = 0.075,
        jobs = { 'ambulance' }, removeJobs = { 'ambulance', 'fire', 'police' },
        texture = { style = 'text', text = 'EMERGENCY SCENE  •  EMS', bg = '#ffffff', fg = '#c81e1e', border = '#c81e1e' },
    },
    barrier_tape = {
        label = 'Barrier Tape (red/white)', maxLength = 20.0, width = 0.08,
        jobs = nil, removeJobs = nil,
        texture = { style = 'stripes', colors = { '#d41f1f', '#ffffff' } },
    },
    hazard_tape = {
        label = 'Hazard Tape (yellow/black)', maxLength = 20.0, width = 0.08,
        jobs = nil, removeJobs = nil,
        texture = { style = 'stripes', colors = { '#111111', '#f5c400' } },
    },
}
