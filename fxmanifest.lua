fx_version "adamant"
games {"rdr3"}
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
author 'riversafe'
lua54 'yes'

client_scripts {
    "@uiprompt/uiprompt.lua",
    'client.lua',
}

server_scripts {
    'server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css'
}
