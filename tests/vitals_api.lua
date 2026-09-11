-- Additional native contracts used by the Vitals component.
Geyser.Container=Geyser.Label
Geyser.Gauge=setmetatable({}, {__index=Geyser.Label})
function Geyser.Gauge:new(cons,parent)
  local gauge=Geyser.Label.new(self,cons,parent)
  gauge.text=Geyser.Label:new({name=cons.name.."_text"},gauge)
  return gauge
end
function Geyser.Gauge:setValue(value,maximum,label)
  assert(maximum>0); self.value,self.maximum,self.label=value,maximum,label
end
function Geyser.Gauge:setFontSize(size) self.fontSize=size end
function Geyser.Gauge:setAlignment(alignment) self.alignment=alignment end
borderBottom,borderLeft,borderRight=0,0,300
windowWidth,windowHeight=1200,800
connected,gmcpRequests=false,{}
function getMainWindowSize() return windowWidth,windowHeight end
function getBorderBottom() return borderBottom end
function getBorderLeft() return borderLeft end
function getBorderRight() return borderRight end
function setBorderBottom(n) borderBottom=n; fire('sysWindowResizeEvent') end
function getConnectionInfo() return 'offline',4000,connected end
function sendGMCP(text) gmcpRequests[#gmcpRequests+1]=text end
function character(name,data)
  gmcp=gmcp or {}; gmcp.char=gmcp.char or {}; gmcp.char[name]=data
  fire('gmcp.char.'..name)
end
function gauge(key) return widgets['AardwolfToolbox.vitals.'..key] end
function starter()
  BaseUI={sections={vitals=Geyser.Container:new({name='starter-vitals'})}}
  function BaseUI.sectionFloating() return false end
  function BaseUI.placeSection(key) BaseUI.sections[key]:show() end
  function BaseUI.layoutDock()
    BaseUI.vitalsAllocated=not BaseUI.sectionFloating('vitals')
    BaseUI.placeSection('vitals')
  end
  BaseUI.layoutDock()
end
