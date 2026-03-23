fx_version 'cerulean'
game 'gta5'

name        'SDR AntiCheat'
description 'Advanced FiveM AntiCheat - by SDR'
version     '3.0.0'
author      'SDR'

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/script.js',
}

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/detections.lua',
    'client/screenshot.lua',
    'client/menu_detection.lua',
    'client/entity_monitor.lua',
    'client/damage_monitor.lua',
    'client/native_protection.lua',
    'client/aimbot_detection.lua',
    'client/admin_panel.lua',
}

server_scripts {
    'server/main.lua',
    'server/bans.lua',
    'server/logs.lua',
    'server/entity_server.lua',
    'server/hwid.lua',
    'server/aimbot_server.lua',
    'server/admin_panel.lua',
}

lua54 'yes'
