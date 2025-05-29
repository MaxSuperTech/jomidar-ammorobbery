fx_version 'cerulean'
lua54 'yes'
game 'gta5'

name         'jomidar-ammorobbery'
version      '2.0.0'
description  'ESX + OxLib based Ammunation Robbery (converted from QBCore)'
author       'Hasib (converted by MaxSuperTech)'

-- Shared scripts
shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua',
    'config.lua',
}

-- Client scripts
client_scripts {
    'cl.lua',
}

-- Server scripts
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'sv.lua',
}

-- Required resources
dependencies {
    'es_extended',
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'jomidar-ui'
}
