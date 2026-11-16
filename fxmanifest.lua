fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'dw_tapes_lite'
author 'DW'
description 'Free barrier tape system (police, crime scene, caution, fire, EMS tape). Full version: dw_tapes'
version '1.0.0'

shared_scripts {
    'config.lua',
    'locales/*.lua',
    'shared/locale.lua',
    'shared/jobs.lua',
}

client_scripts {
    'client/bridge.lua',
    'client/render.lua',
    'client/main.lua',
}

server_scripts {
    'server/bridge.lua',
    'server/main.lua',
}

files {
    'html/tape.html',
}
