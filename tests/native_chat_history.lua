-- Approved disconnected acceptance only, after profile/map/database backup and foundation interception.
assert(getProfileName()=='AardwolfToolboxSettingsTest' and not select(3,getConnectionInfo()))
assert(AardwolfToolboxAcceptance and not AardwolfToolboxChatHistoryAcceptance)
local t=AardwolfToolbox
local character='ChatHistoryFixture'..math.floor(getEpoch())
assert(t.history.list(character,1,'chat').total==0)
local saved={history={},shell={}}
for _,key in ipairs({'progression','quests','kills','chat','placement'}) do saved.history[key]=t.config.get('history',key) end
for _,key in ipairs({'chat_colors','hidden_channels'}) do saved.shell[key]=t.config.get('shell',key) end
local oldChar,oldComm=gmcp and gmcp.char,gmcp and gmcp.comm
local originalChat=t.shell.getBase();local oldUnread,oldMentions={},{}
for key,value in pairs(originalChat.unread) do oldUnread[key]=value end
for key,value in pairs(originalChat.mentions) do oldMentions[key]=value end
AardwolfToolboxChatHistoryAcceptance={character=character}
function AardwolfToolboxChatHistoryAcceptance.restore()
  t.historyPane.close();assert(t.history.clear(character,t.history.revision,'chat'))
  local draft,revision=t.config.draft()
  for key,value in pairs(saved.history) do draft.history[key]=value end
  for key,value in pairs(saved.shell) do draft.shell[key]=value end
  assert(t.config.apply(draft,revision))
  gmcp.char=oldChar;gmcp.comm=oldComm;t.gmcp.stop();assert(t.gmcp.start())
  local chat=t.shell.getBase()
  for key in pairs(chat.unread) do chat.unread[key]=oldUnread[key] or 0 end
  for key in pairs(chat.mentions) do chat.mentions[key]=oldMentions[key] or 0 end
  chat.refreshChatTabs()
  t.historyPane.close();AardwolfToolboxChatHistoryAcceptance=nil
  echo('CHAT_HISTORY_NATIVE: fixture records removed, preferences restored; synthetic chat remains in test scrollback.\n')
end
local draft,revision=t.config.draft()
draft.history.progression=false;draft.history.quests=false;draft.history.kills=false;draft.history.chat=true
draft.chat.chat_colors='ansi';draft.chat.hidden_channels='gossip'
assert(t.config.apply(draft,revision))
gmcp=gmcp or {};gmcp.char={base={name=character}};raiseEvent('gmcp.char','gmcp.char.base')
local function chat(channel,player,message)
  gmcp.comm={channel={chan=channel,player=player,msg=message}}
  raiseEvent('gmcp.comm','gmcp.comm.channel')
end
chat('clantalk','Friend','\27[32mFriend: Chat history fixture <Éowyn> & hello\27[0m')
chat('newbie','Newcomer','Newcomer: Chat history fixture welcome!')
chat('tell','Friend','Friend tells you: Private fixture message')
local b=t.shell.getBase();local unread={}
for key,value in pairs(b.unread) do unread[key]=value end
chat('tell','Friend','You tell Friend: Outgoing fixture message')
for key,value in pairs(b.unread) do assert(value==(unread[key] or 0),'Outgoing unread changed: '..key) end
chat('gossip','Friend','Hidden fixture message')
local result=t.history.list(character,1,'chat')
assert(result.total==4 and result.rows[1].outgoing)
assert(result.rows[4].text=='Friend: Chat history fixture <Éowyn> & hello')
assert(t.historyPane.open('chat'))
echo('CHAT_HISTORY_NATIVE: four records, hidden channel excluded, own message did not increment unread. Verify export/clear, literal text, settings and lifecycle.\n')
