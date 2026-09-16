-- Minimal geometry contracts; native UI acceptance verifies actual Geyser layout.
Geyser.children={}
function Geyser:get_width() return windowWidth end
function Geyser:get_height() return windowHeight end
local W=Geyser.Label
local function dimension(value,total)
  if type(value)=='number' then return value end
  value=tostring(value or 0)
  local percent,offset=value:match('^(%-?[%d.]+)%%%-?(%d*)$')
  if percent then return total*tonumber(percent)/100-(tonumber(offset) or 0) end
  return tonumber(value:match('^(%-?[%d.]+)')) or 0
end
function W:get_width() return dimension(self.width,self.parent and self.parent:get_width() or windowWidth) end
function W:get_height() return dimension(self.height,self.parent and self.parent:get_height() or windowHeight) end
function W:get_x() return dimension(self.x,self.parent and self.parent:get_width() or windowWidth) end
function W:get_y() return dimension(self.y,self.parent and self.parent:get_height() or windowHeight) end
function W:reposition() end
function W:set_constraints() end
function W:detach() self.attached=nil; setBorderRight(0) end
function W:attachToBorder(edge) self.attached=edge; setBorderRight(self:get_width()) end
function closeMapWidget() mapClosed=true end
function dashboardStarter()
  BaseUI={sections={},chats={},chatTabLabels={},unread={tells=2},activeChatTab='all'}
  local b=BaseUI
  b.container=Adjustable.Container:new({name='BaseUI',x='75%',y=0,width='25%',height='100%'})
  b.container.attached='right'
  for _,key in ipairs({'map','chat','vitals'}) do
    b.sections[key]=Adjustable.Container:new({name='BaseUI.'..key,x=0,y=0,width='100%',height='30%'},b.container.Inside)
  end
  b.map=W:new({name='BaseUI.mapper',x=0,y=0,width='100%',height='100%'},b.sections.map.Inside)
  function b.map:move(x,y) if not self.hidden then W.move(self,x,y) end end
  function b.map:resize(w,h) if not self.hidden then W.resize(self,w,h) end end
  for _,key in ipairs({'all','tells','channels'}) do
    b.chats[key]=Geyser.MiniConsole:new({name='BaseUI.chat.'..key,x=0,y=24,width='100%',height='100%-24'},b.sections.chat.Inside)
    b.chatTabLabels[key]=W:new({name='BaseUI.tab.'..key,x=0,y=0,width='33%',height=24},b.sections.chat.Inside)
  end
  function b.sectionFloating() return false end
  function b.placeSection(key,frame)
    local section=b.sections[key]
    if not frame then section:hide(); return end
    section:move(0,b.container.Inside:get_height()*frame.y)
    section:resize('100%',b.container.Inside:get_height()*frame.height); section:show()
  end
  function b.layoutDock()
    b.placeSection('map',{y=0,height=0.5}); b.placeSection('chat',{y=0.5,height=0.35})
    b.placeSection('vitals',{y=0.85,height=0.15})
  end
  function b.refreshChatTabs() end
  b.layoutDock()
end
