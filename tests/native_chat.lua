-- Manual native fixture, never a player-profile acceptance or live-data test.
assert(getProfileName()=='AardwolfToolboxSettingsTest','Use the disposable test profile')
assert(not select(3,getConnectionInfo()),'Disconnect the disposable profile first')
assert(AardwolfToolboxAcceptance,'Run native_foundation.lua to intercept dispatch first')
local t=AardwolfToolbox
assert(t.shell.enabled,'Use the disposable standalone sidebar or explicitly migrate its starter')
assert(t.gmcp.enabled,'Enable the shared GMCP cache in this disposable profile')
local old=gmcp and gmcp.comm
gmcp=gmcp or {}
local raw=t.config.get('chat','chat_colors')=='raw'
local text=raw and '@GÉowyn: @x196red @@ literal <red> @Wwhite' or '\27[32mÉowyn: \27[38;5;196mred @ literal <red> \27[97mwhite\27[0m'
local ok,err=pcall(function()
  for _,message in ipairs({text,'LOCAL CHAT FIXTURE: search literal [brackets] and 100%.','LOCAL CHAT FIXTURE: second Éowyn message.'}) do
    gmcp.comm={channel={chan='gossip',player='Fixture',msg=message}}
    raiseEvent('gmcp.comm','gmcp.comm.channel')
  end
end)
gmcp.comm=old
assert(ok,err)
assert(t.views.open('all'))
echo('CHAT FIXTURE: colors and literal symbols should appear in All and Channels.\n')
echo('Use chat view menu > Search chat. Search Éowyn, [brackets], or %. Click a result; Close/Escape must retain chat and command input.\n')
echo('Repeat in a floating chat view. Resize, read older scrollback while appending another fixture, and inspect mention badges with configured words.\n')
