-- Load after native_foundation.lua, then exercise the tab row with real scrolling.
assert(getProfileName()=='AardwolfToolboxSettingsTest' and not select(3,getConnectionInfo()))
assert(AardwolfToolboxAcceptance and not AardwolfToolboxScrollQA)
local t=AardwolfToolbox
local saved=t.config.draft()
local qa={}
AardwolfToolboxScrollQA=qa
local draft,revision=t.config.draft()
draft.dashboard.enabled=true;draft.dashboard.collapsed=false;draft.dashboard.width=360
draft.chat.enabled=true
for _,tab in ipairs(draft.chat.tabs) do tab.enabled=true;tab.placement='tabbed' end
assert(t.config.apply(draft,revision))
t.settingsWindow.close()
function qa.status()
  local base=t.shell.getBase()
  local visible={}
  for _,tab in ipairs(t.chat.tabs()) do
    local label=base.chatTabLabels[tab.id]
    if label and not label.hidden then visible[#visible+1]=tab.id end
  end
  echo('SCROLL_QA active='..tostring(base.activeChatTab)..' visible='..table.concat(visible,',')..' input='..getCmdLine()..'\n')
end
function qa.restore()
  if qa.timer then killTimer(qa.timer);qa.timer=nil end
  local current,rev=t.config.draft()
  for key,value in pairs(saved) do current[key]=value end
  assert(t.config.apply(current,rev))
  AardwolfToolboxScrollQA=nil
  echo('SCROLL_QA_RESTORED\n')
end
qa.timer=tempTimer(0.5,function()
  qa.timer=nil
  local base=t.shell.getBase();base.selectChatTab('all')
  for i=1,100 do base.chats.all:echo('Offline scroll fixture line '..i..'\n') end
  qa.status()
end)
echo('Scroll both ways and check the directional indicator; clicking it must not open a menu. Check console scrolling and unsent input.\n')
