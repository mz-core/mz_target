fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'mz_target'
author 'BerkieB / MZ Framework'
description 'Entity detection and interaction dispatch based on qb-target 5.5.0 (GPL-3.0)'
version '1.0.0'

ui_page 'web/index.html'

shared_scripts {
  '@ox_lib/init.lua',
  'shared/config.lua',
  'shared/locale.lua'
}

client_scripts {
  'client/init.lua',
  'client/main.lua',
  'client/drops.lua'
}

server_scripts {
  'server/main.lua'
}

files {
  'data/*.lua',
  'web/index.html',
  'web/style.css',
  'web/app.js',
  'web/lucide.min.js',
  'locales/*.json',
  'LICENSE',
  'NOTICE.md'
}

dependencies {
  'ox_lib'
}
