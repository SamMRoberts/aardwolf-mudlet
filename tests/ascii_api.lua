local W=Geyser.Label
borderTop=0
function getBorderTop() return borderTop end
function setBorderTop(n) borderTop=n; fire('sysWindowResizeEvent') end
function setBorderLeft(n) borderLeft=n; fire('sysWindowResizeEvent') end
function setBorderRight(n) borderRight=n; fire('sysWindowResizeEvent') end
function W:hideMenuLabel() end
function W:addMenuLabel() return true end
function W:setMenuAction(name,fn) self.actions=self.actions or {}; self.actions[name]=fn end
function W:onRightClick() end
function closeAllLevels() end
function W:clear() self.text=''; self.runs={} end
function W:setFontSize(size) self.fontSize=size end
function W:setFont(font) self.font=font end
function W:setWrap(n) self.wrap=n end
function W:enableScrollBar() self.vertical=true end
function W:enableHorizontalScrollBar() self.horizontal=true end
function W:setBufferSize() end
function W:scrollTo(n) self.scroll=n end
Geyser.MiniConsole=setmetatable({}, {__index=W})
function Geyser.MiniConsole:echo(text)
  self.text=(self.text or '')..text
  self.runs=self.runs or {}; self.runs[#self.runs+1]={text=text,fg=self.fg,bg=self.bg}
end
function setFgColor(name,r,g,b) widgets[name].fg={r,g,b} end
function setBgColor(name,r,g,b) widgets[name].bg={r,g,b} end
function selectSection(index) selected=index; return true end
function getFgColor() return selected==0 and 255 or 40,50,60 end
function getBgColor() return 10,20,30 end
function deselect() end

function W:createRightClickMenu(cons)
  self.rightClickMenu=W:new({name=self.name..'.menu'},self)
  self.rightClickMenu.MenuLabels={}
end
local original=Adjustable.Container.new
function Adjustable.Container:new(cons,parent)
 local root=original(self,cons,parent)
 root.adjLabel:createRightClickMenu({})
 return root
end
