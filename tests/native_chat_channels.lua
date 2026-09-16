-- Synthetic chat only in the disconnected disposable profile. No server commands.
assert(getProfileName()=='AardwolfToolboxSettingsTest' and not select(3,getConnectionInfo()))
assert(AardwolfToolboxAcceptance,'Run native_foundation.lua first')
assert(not AardwolfToolboxChatAcceptance,'Restore the previous fixture')
local t=AardwolfToolbox;local b=t.shell.getBase()
assert(t.views.available('clan') and t.views.available('newbie'))
local oldComm,oldChar=(gmcp or {}).comm,(gmcp or {}).char
local selected=b.activeChatTab
local function message(channel,player,text)
  gmcp.comm={channel={chan=channel,player=player,msg=text}}
  raiseEvent('gmcp.comm','gmcp.comm.channel')
end
gmcp=gmcp or {};gmcp.char={base={name='ChatFixture'}}
raiseEvent('gmcp.char','gmcp.char.base')
assert(t.views.open('all'))
local beforeClan,beforeNewbie=b.unread.clan or 0,b.unread.newbie or 0
local color=t.config.get('chat','chat_colors')=='raw' and '@G' or '\27[32m'
message('clantalk','Friend',color..'Friend: Clan fixture — Éowyn <literal>')
message('newbie','Newcomer','Newcomer: Newbie fixture — welcome!')
message('clantalk','ChatFixture','You clantalk: own reply (no unread increment)')
message('newbie','ChatFixture','You newbie: own reply (no unread increment)')
message('tell','Friend','You tell Friend: own tell (no unread increment)')
assert((b.unread.clan or 0)==beforeClan+1 and (b.unread.newbie or 0)==beforeNewbie+1)
assert(#AardwolfToolboxAcceptance.commands==0,'Chat fixture dispatched unexpectedly')
AardwolfToolboxChatAcceptance={}
function AardwolfToolboxChatAcceptance.restore()
  gmcp.comm=oldComm;gmcp.char=oldChar
  t.gmcp.stop();assert(t.gmcp.start())
  for _,id in ipairs({'all','channels','tells','clan','newbie'}) do b.unread[id]=0;b.mentions[id]=0 end
  b.selectChatTab(selected or 'all')
  AardwolfToolboxChatAcceptance=nil
  echo('CHAT_CHANNELS: fixture restored; no gameplay dispatch.\n')
end
assert(t.views.open('clan'))
echo('CHAT_CHANNELS: Clan/Newbie fixtures captured; own replies did not increment unread.\n')
echo('Check Clan/Newbie in Views, overflow tabs, float/return, literal colors and Settings placement. Restore ChatAcceptance before foundation.\n')
