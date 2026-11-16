-- Paste into ox_inventory/data/items.lua
-- Copy the images from install/images/ to ox_inventory/web/images/
-- Upgrading to the full version: replace 'dw_tapes_lite.useTape' with 'dw_tapes.useTape'

['police_tape'] = {
    label = 'Police Tape', weight = 250, stack = true, close = true,
    description = 'Barrier tape for police scenes',
    client = { export = 'dw_tapes_lite.useTape' },
},

['crimescene_tape'] = {
    label = 'Crime Scene Tape', weight = 250, stack = true, close = true,
    description = 'Barrier tape for crime scenes',
    client = { export = 'dw_tapes_lite.useTape' },
},

['caution_tape'] = {
    label = 'Caution Tape', weight = 250, stack = true, close = true,
    description = 'Yellow caution tape',
    client = { export = 'dw_tapes_lite.useTape' },
},

['fire_tape'] = {
    label = 'Fire Line Tape', weight = 250, stack = true, close = true,
    description = 'Barrier tape of the fire department',
    client = { export = 'dw_tapes_lite.useTape' },
},

['ems_tape'] = {
    label = 'EMS Tape', weight = 250, stack = true, close = true,
    description = 'Barrier tape of the emergency medical services',
    client = { export = 'dw_tapes_lite.useTape' },
},

['barrier_tape'] = {
    label = 'Barrier Tape (red/white)', weight = 250, stack = true, close = true,
    description = 'Red and white barrier tape',
    client = { export = 'dw_tapes_lite.useTape' },
},

['hazard_tape'] = {
    label = 'Hazard Tape (yellow/black)', weight = 250, stack = true, close = true,
    description = 'Yellow and black hazard tape',
    client = { export = 'dw_tapes_lite.useTape' },
},
