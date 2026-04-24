fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mz_target'
author 'mz-core'
description 'Target interaction layer for mz_core and mz_inventory'
version '0.2.0'

ui_page 'web/index.html'

shared_scripts {
  '@ox_lib/init.lua',
  'shared/config.lua'
}

client_scripts {
  'client/main.lua'
}

server_scripts {
  'server/main.lua'
}

files {
  'web/index.html',
  'web/style.css',
  'web/app.js'
}

dependencies {
  'ox_lib',
  'mz_core',
  'mz_inventory'
}
