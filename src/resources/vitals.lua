-- Compact, profile-owned character gauges. No work until configure/start.
local Vitals = {}
local OWNER = "AardwolfToolbox.vitals"
local STATS = {
  {key="hp", label="HP", short="HP", maximum="maxhp", color="#287a45"},
  {key="mana", label="Mana", short="MP", maximum="maxmana", color="#286aa4"},
  {key="moves", label="Moves", short="MV", maximum="maxmoves", color="#8a651b"},
  {key="target", label="Target", color="#aa4148"},
  {key="tnl", label="TNL", short="TNL", maximum="perlevel", color="#7750a4"},
}
local FIELDS = {vitals={"hp","mana","moves"}, maxstats={"maxhp","maxmana","maxmoves"},
  status={"tnl"}, base={"perlevel"}}
local function number(value)
  if type(value) ~= "number" and type(value) ~= "string" then return nil end
  local n = tonumber(value)
  if not n or n ~= n or n < 0 or n == math.huge then return nil end
  return n
end
local function integer(n) return n and string.format("%.0f", n) or "--" end
local function clamp(n) return math.max(0, math.min(100, n)) end

function Vitals.new(api, borders)
  local self = {enabled=false, last="Waiting for character data"}
  local options={enabled=true,show_tnl=true,show_target=true,bar_height=22,font_size=11}
  local root, gauges, readings, packets = nil, {}, {}, {}
  local borderBefore, borderWritten, adapter, timer, busy
  local handlers = {}
  local generation = 0
  local suspended=false

  local function restoreAdapter()
    if not adapter then return end
    local a=adapter; adapter=nil
    if a.base.sectionFloating == a.floating then a.base.sectionFloating=a.originalFloating end
    if a.base.placeSection == a.place then a.base.placeSection=a.originalPlace end
    if a.section and a.section.save==a.save then a.section.save=a.originalSave end
    if api.BaseUI == a.base and type(a.base.layoutDock)=="function" then
      a.base.layoutDock()
      if a.attached and a.base.sections.vitals==a.section and not a.section.attached then
        a.section:attachToBorder(a.attached)
      end
    end
  end
  local function adapt()
    local base=api.BaseUI
    if adapter and (adapter.base ~= base or base.sectionFloating ~= adapter.floating or base.placeSection ~= adapter.place) then
      restoreAdapter()
    end
    if not base then return end
    if adapter then return end
    if type(base)~="table" or type(base.sectionFloating)~="function" or type(base.placeSection)~="function"
        or type(base.layoutDock)~="function" or type(base.sections)~="table" then
      error("Starter UI Vitals integration unavailable; original pane retained",0)
    end
    local a={base=base,originalFloating=base.sectionFloating,originalPlace=base.placeSection}
    a.floating=function(key)
      if self.enabled and key=="vitals" then return true end
      return a.originalFloating(key)
    end
    a.place=function(key,...)
      if self.enabled and key=="vitals" then
        local pane=base.sections.vitals
        if pane then
          if a.section~=pane then
            if a.section and a.section.save==a.save then a.section.save=a.originalSave end
            if pane.attached and (type(pane.detach)~="function" or type(pane.attachToBorder)~="function") then
              error("Starter Vitals attachment API unavailable; original pane retained",0)
            end
            a.section,a.attached,a.originalSave=pane,pane.attached,pane.save
            -- Keep the temporary suppression out of the starter's saved layout.
            a.save=function() end; pane.save=a.save
            if pane.attached then pane:detach() end
          end
          pane:hide()
        end
        return
      end
      return a.originalPlace(key,...)
    end
    adapter=a; base.sectionFloating=a.floating; base.placeSection=a.place
    base.layoutDock()
  end

  local function render()
    if not root then return end
    local width=root:get_width()
    local count=3+(options.show_tnl and 1 or 0)+(options.show_target and 1 or 0)
    local gap=width < 350 and 3 or 6
    local gaugeWidth=math.max(1,(width-10-gap*(count-1))/count)
    local font=math.min(options.font_size, math.max(6,math.floor(gaugeWidth/16)))
    local short=gaugeWidth < 190
    local index=0
    for _, stat in ipairs(STATS) do
      local gauge=gauges[stat.key]
      local visible=(stat.key~="tnl" or options.show_tnl) and (stat.key~="target" or options.show_target)
      if visible then
        index=index+1
        gauge:show(); gauge:move(5+(index-1)*(gaugeWidth+gap),5)
        gauge:resize(gaugeWidth,options.bar_height); gauge:setFontSize(font)
        local current, maximum=readings[stat.key],readings[stat.maximum]
        local percentage, text=0,nil
        local available=current~=nil and maximum~=nil and maximum>0
        if stat.key=="target" then
          local enemy=readings.enemy
          if enemy==false then text="No target"
          elseif type(enemy)=="string" then
            percentage=readings.enemypct or 0
            local limit=math.max(3,math.floor(gaugeWidth/(font*0.7))-12)
            local chars={}
            for char in enemy:gmatch("[%z\1-\127\194-\244][\128-\191]*") do chars[#chars+1]=char end
            if #chars>limit then enemy=table.concat(chars,"",1,limit).."…" end
            enemy=enemy:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;")
            text="Target "..enemy.." "..integer(readings.enemypct).."%"
          else text="Target --" end
        elseif stat.key=="tnl" then
          if available then percentage=clamp(100*(maximum-current)/maximum) end
          text="TNL "..integer(current)..(available and (" · "..math.floor(percentage).."%") or " · --%")
        else
          if available then percentage=clamp(100*current/maximum) end
          text=(short and stat.short or stat.label).." "..integer(current).."/"..integer(maximum)
        end
        gauge:setValue(percentage,100,text)
      else gauge:hide() end
    end
  end
  local function layout()
    if not self.enabled or not root or busy then return end
    busy=true
    local ok,err=pcall(function()
      if borders then
        borders.refresh()
        borders.reserve(OWNER,"bottom",options.bar_height+10,0,layout)
        local x,y,w,h=borders.box(OWNER)
        root:move(x,y); root:resize(w,h); render(); return
      end
      if borderWritten~=nil and api.getBorderBottom()~=borderWritten then
        error("Bottom border changed outside Toolbox; Vitals stopped to preserve the new layout",0)
      end
      local height=options.bar_height+10
      local wanted=borderBefore+height
      if borderWritten~=wanted then
        borderWritten=wanted -- set before the resize event caused by the write
        api.setBorderBottom(wanted)
        if api.getBorderBottom()~=wanted then error("Cannot reserve bottom Vitals space",0) end
      end
      local w,h=api.getMainWindowSize()
      local left,right=api.getBorderLeft(),api.getBorderRight()
      root:move(left,math.max(0,h-height-borderBefore))
      root:resize(math.max(1,w-left-right),height)
      render()
    end)
    busy=false
    if not ok then error(err,0) end
  end

  function self.stop()
    self.enabled=false; generation=generation+1
    if timer then api.killTimer(timer); timer=nil end
    for _, name in ipairs(handlers) do api.deleteNamedEventHandler(OWNER,name) end
    handlers={}
    if self.subscribed then api.gmod.disableModule(OWNER,"Char"); self.subscribed=false end
    if root then root:delete(); root=nil; gauges={} end
    if borders then borders.release(OWNER) end
    if borderWritten~=nil and api.getBorderBottom()==borderWritten then api.setBorderBottom(borderBefore) end
    borderBefore,borderWritten=nil,nil
    restoreAdapter()
    readings,packets={},{}
    self.last="Disabled"
  end
  self.destroy=self.stop
  local function guarded(fn)
    return function(...)
      if not self.enabled then return end
      local ok,err=pcall(fn,...)
      if not ok then
        self.stop(); self.last=tostring(err)
        api.echo("Aardwolf Vitals: "..self.last.."\n")
      end
    end
  end
  local function leaf(name)
    local gmcp=api.gmcp
    return type(gmcp)=="table" and type(gmcp.char)=="table" and gmcp.char[name] or nil
  end
  function self.reset()
    readings={}; packets={}
    for name in pairs(FIELDS) do packets[name]=leaf(name) end
    self.last="Waiting for fresh character data"; render()
  end
  local function receive(name)
    local data=leaf(name)
    if suspended or type(data)~="table" or packets[name]==data then return end
    packets[name]=data
    for _, key in ipairs(FIELDS[name]) do
      if data[key]~=nil then readings[key]=number(data[key]) end
    end
    if name=="status" then
      local enemy=data.enemy
      if enemy~=nil then
        if type(enemy)=="string" then
          enemy=enemy:gsub("\27%[[0-9;]*m", ""):gsub("[%z\1-\31\127]", ""):match("^%s*(.-)%s*$")
          if readings.enemy~=nil and enemy~=readings.enemy then readings.enemypct=nil end
          readings.enemy=enemy~="" and enemy or false
        else readings.enemy=nil; readings.enemypct=nil end
      end
      if data.enemypct~=nil then
        local pct=number(data.enemypct)
        readings.enemypct=pct and pct<=100 and pct or nil
      end
      local state=number(data.state)
      if (state and state~=8) or readings.enemy==false then readings.enemy=false; readings.enemypct=nil end
    end
    self.last="Receiving character data"; adapt(); layout()
  end
  local function request()
    local _,_,connected=api.getConnectionInfo()
    if connected then api.sendGMCP("request char") end
  end
  local function afterPackageChange()
    if timer then api.killTimer(timer) end
    local current=generation
    timer=api.tempTimer(0,function()
      timer=nil
      if self.enabled and generation==current then guarded(function() adapt(); layout() end)() end
    end)
  end
  function self.start()
    if self.enabled then layout(); return true end
    local ok,err=pcall(function()
      self.enabled=true; suspended=false; self.reset(); adapt()
      borderBefore=api.getBorderBottom()
      root=api.Geyser.Container:new({name=OWNER..".root",x=0,y=0,width=1,height=1})
      for _,stat in ipairs(STATS) do
        local gauge=api.Geyser.Gauge:new({name=OWNER.."."..stat.key,x=0,y=0,width=1,height=1},root)
        gauges[stat.key]=gauge
        gauge:setStyleSheet("background-color: "..stat.color.."; border-radius: 3px;",
          "background-color: #202b39; border: 1px solid #405169; border-radius: 3px;",
          "background-color: transparent; color: white; padding: 0px;")
        gauge.text.fgColor="nocolor"; gauge:setAlignment("center")
      end
      local function on(name,event,fn)
        handlers[#handlers+1]=name
        assert(api.registerNamedEventHandler(OWNER,name,event,guarded(fn)),"Cannot register Vitals handler")
      end
      for name in pairs(FIELDS) do
        local field=name
        on(name,"gmcp.char."..name,function() receive(field) end)
      end
      on("resize","sysWindowResizeEvent",layout)
      on("dock","AdjustableContainerRepositionFinish",layout)
      on("disconnect","sysDisconnectionEvent",function() suspended=true; self.reset() end)
      on("connect","sysConnectionEvent",function() suspended=false; self.reset() end)
      on("protocolOff","sysProtocolDisabled",function(_,protocol) if protocol=="GMCP" then suspended=true; self.reset() end end)
      on("protocolOn","sysProtocolEnabled",function(_,protocol) if protocol=="GMCP" then suspended=false; self.reset(); request() end end)
      on("install","sysInstallPackage",afterPackageChange)
      on("uninstall","sysUninstallPackage",afterPackageChange)
      self.subscribed=true; api.gmod.enableModule(OWNER,"Char")
      layout(); request()
    end)
    if not ok then self.stop(); self.last=tostring(err); return false,self.last end
    return true
  end
  function self.configure(values)
    options={enabled=values.enabled,show_tnl=values.show_tnl,show_target=values.show_target,bar_height=values.bar_height,font_size=values.font_size}
    if not options.enabled then self.stop(); return true end
    local ok,result,message=pcall(self.start)
    if not ok then self.stop(); self.last=tostring(result); return false,self.last end
    return result,message
  end
  return self
end
return Vitals
