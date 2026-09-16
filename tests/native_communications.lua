-- Run only after native_foundation.lua in the disconnected disposable profile.
assert(getProfileName()=='AardwolfToolboxSettingsTest' and not select(3,getConnectionInfo()))
assert(AardwolfToolboxAcceptance and not AardwolfToolboxChatQA)
local t=AardwolfToolbox
local saved=t.config.draft()
local oldGMCP=gmcp
local commands=AardwolfToolboxAcceptance.commands
local startCount=#commands
local function record(key,values)
  local r={id=values.id}
  for _,s in ipairs(t.config.features.chat.settings) do if s.key==key then for _,f in ipairs(s.fields) do r[f.key]=f.default end end end
  for k,v in pairs(values) do r[k]=v end;return r
end
AardwolfToolboxChatQA={}
function AardwolfToolboxChatQA.restore()
  t.chatWorkspace.close();t.chat.stop()
  local current,revision=t.config.draft()
  for k,v in pairs(saved) do current[k]=v end
  assert(t.config.apply(current,revision));assert(t.chat.configure(saved.chat))
  gmcp=oldGMCP;t.gmcp.stop();assert(t.gmcp.start())
  AardwolfToolboxChatQA=nil
  echo('COMMUNICATIONS_RESTORED: preferences and protocol state restored; one intercepted send only.\n')
end
local draft,rev=t.config.draft()
draft.chat.enabled=true;draft.chat.timestamps=true;draft.chat.chat_colors='ansi';draft.chat.hidden_channels='';draft.chat.ignored_players=''
draft.chat.desktop=false;draft.chat.sound=false;draft.chat.dnd=false;draft.chat.rules={record('rules',{id='native_regex',label='Native bounded regex',match='regex',pattern='\\bfixture\\b',color='cyan'})}
assert(t.config.apply(draft,rev))
assert(rex.new('(*LIMIT_MATCH=10000)(*LIMIT_RECURSION=1000)(?i)\\bfixture\\b'):find('Fixture'))
local expensive=record('rules',{id='costly',label='Limited regex',match='regex',pattern='^(a+)+$'})
local preview=t.chat.options();preview.rules={expensive}
local result=assert(t.chat.preview({chan='gossip',player='Friend',msg=string.rep('a',500)..'!'},preview))
assert(result.error,'Native PCRE match limit was not enforced')
gmcp={char={base={name='ChatFixture'},status={state=3}}}
raiseEvent('gmcp.char','gmcp.char.base');raiseEvent('gmcp.char','gmcp.char.status')
local function message(channel,sender,text)
  gmcp.comm={channel={chan=channel,player=sender,msg=text}}
  raiseEvent('gmcp.comm','gmcp.comm.channel')
end
message('tell','Éowyn',"Éowyn tells you 'Hello ChatFixture — <literal> fixture'")
message('gtell','Leader','Group fixture: rendezvous')
message('clantalk','Friend','Clan fixture: welcome')
message('newbie','Newcomer','Newbie fixture: question?')
message('question','Newcomer','Question fixture')
message('answer','Helper','Answer fixture')
message('market','Merchant','Trade fixture')
message('say','Guide','Room fixture')
message('mobsay','a guard','Mob fixture')
message('gossip','Friend','Public fixture')
message('future_channel','Friend','Unknown channel fixture')
message('tell','ChatFixture',"You tell Friend 'outgoing fixture'")
message('tell','Friend','Identical fixture');message('tell','Friend','Identical fixture')
assert(#commands==startCount,'Reception sent a command in the offline profile')
assert(#t.chat.list()==14 and #t.chat.conversations()==2)
-- Explicit composer dispatch is intercepted; use a temporary readiness adapter only.
local original=t.readiness.check
t.readiness.check=function(policy) assert(policy=='manual');return true end
assert(t.chat.send('tell','Friend','intercepted composer fixture'))
assert(not t.chat.send('tell','Friend','bad\nquit'))
t.readiness.check=original
assert(commands[#commands]=='tell Friend intercepted composer fixture' and #commands==startCount+1)
if t.settingsWindow then t.settingsWindow.destroy() end
assert(t.views.open('all'))
echo('COMMUNICATIONS_NATIVE_OK: 14 messages; bounded native regex; grouped routes; one intercepted composer send.\n')
echo('Check Write/drafts, People/reply, filter preview, settings records, float/return and sounds. Then restore ChatQA before foundation.\n')
