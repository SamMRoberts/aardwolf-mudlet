-- A retained, extensible top row. Preferences and session data have separate owners.
local Bar={}
local OWNER="AardwolfToolbox.utilityBar"
local function escape(value)
  return (tostring(value):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"):gsub('"',"&quot;"))
end
local function numeric(n)
  return type(n)=="number" and n==n and math.abs(n)<math.huge and n>=0 and n%1==0 and n<=9007199254740991
end
local function exact(n)
  if not numeric(n) then return "--" end
  local value=string.format("%.0f",n)
  return (value:reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,",""))
end
local function short(n)
  if not numeric(n) then return "--" end
  for _,unit in ipairs({{1e9,"B"},{1e6,"M"},{1e3,"K"}}) do
    if n>=unit[1] then return (string.format("%.1f",n/unit[1]):gsub("%.0$",""))..unit[2] end
  end
  return exact(n)
end
function Bar.new(api,cache,inventory,borders,openSettings,ui)
  local self={enabled=false,last="Disabled"}
  local items,handlers={},{}
  local root,overflow,menu,adapter,refreshTimer
  local options={enabled=true,font_size=10,inventory_tracking=true}
  local busy=false
  local spells,spellup
  local function rowHeight() return ui and ui.metrics().height or 28 end
  local render
  local function hideMenu()
    if menu then menu:hide() end
  end
  local function activate(id)
    hideMenu()
    local item=items[id]
    if not self.enabled or not item or not item.definition.callback then return end
    local ok,err=pcall(item.definition.callback)
    if not ok then self.last="Action failed: "..tostring(err) end
  end
  local function widgets(id,item)
    if not root or item.widget then return end
    item.widget=api.Geyser.Label:new({name=OWNER..".item."..id,x=0,y=0,width=1,height=rowHeight()},root)
    item.menuWidget=api.Geyser.Label:new({name=OWNER..".menu."..id,x=0,y=0,width="100%",height=rowHeight()},menu)
    item.widget:setClickCallback(function() activate(id) end)
    item.menuWidget:setClickCallback(function() activate(id) end)
  end
  function self.registerItem(def)
    assert(type(def)=="table" and type(def.id)=="string" and def.id:match("^[a-z][a-z0-9_]*$"),"Invalid utility item ID")
    assert(not items[def.id],"Duplicate utility item ID: "..def.id)
    assert(type(def.label)=="string" and #def.label<=120,"Invalid utility label")
    assert(type(def.order)=="number" and def.order==def.order and math.abs(def.order)<math.huge,"Invalid utility order")
    assert(type(def.overflowPriority)=="number" and def.overflowPriority==def.overflowPriority and math.abs(def.overflowPriority)<math.huge,"Invalid overflow priority")
    assert(def.tooltip==nil or type(def.tooltip)=="string","Invalid utility tooltip")
    assert(def.callback==nil or type(def.callback)=="function","Invalid utility callback")
    local copied={}; for k,v in pairs(def) do copied[k]=v end
    local item={definition=copied,state={text="--",visible=true}}
    items[def.id]=item
    widgets(def.id,item)
    if render then render() end
  end
  function self.updateItem(id,state)
    local item=assert(items[id],"Unknown utility item: "..tostring(id))
    assert(type(state)=="table","Invalid utility state")
    for key,value in pairs(state) do
      assert((key=="visible" and type(value)=="boolean") or
        ((key=="color" or key=="badgeColor") and type(value)=="string" and value:match("^#%x%x%x%x%x%x$")) or
        ((key=="text" or key=="compactText" or key=="tooltip" or key=="badge") and type(value)=="string" and #value<=4096),"Invalid utility state field")
    end
    for k,v in pairs(state) do item.state[k]=v end
    if render then render() end
  end
  function self.unregisterItem(id)
    local item=items[id]; if not item then return false end
    if item.widget then item.widget:delete(); item.menuWidget:delete() end
    items[id]=nil; if render then render() end; return true
  end
  local function restoreSidebar()
    local a=adapter; adapter=nil
    if not a then return end
    if a.root.reposition==a.wrapper then a.root.reposition=a.original end
    if a.root.get_y==a.y then a.root.get_y=a.rawY end
    if a.root.get_height==a.height then a.root.get_height=a.rawHeight end
    if api.BaseUI==a.base and a.base.container==a.root then a.root:set_constraints(a.root) end
  end
  local function sidebar()
    local base=api.BaseUI
    if adapter and (not base or base~=adapter.base or base.container~=adapter.root or adapter.root.reposition~=adapter.wrapper) then restoreSidebar() end
    if not base then return end
    if base.AardwolfToolboxDashboard then restoreSidebar(); return end
    if not base.container then self.last="Waiting for starter sidebar construction"; return end
    if not adapter then
      local r=base.container
      assert(type(r.reposition)=="function" and type(r.set_constraints)=="function","Unsupported starter sidebar geometry")
      local a={base=base,root=r,original=r.reposition}
      a.wrapper=function(widget,...)
        -- Keep the starter's constraints unchanged, so its persistence and later
        -- resizing retain their original meaning. Only alter computed geometry.
        if widget.get_y~=a.y then a.rawY=widget.get_y end
        if widget.get_height~=a.height then a.rawHeight=widget.get_height end
        widget.get_y=a.rawY; widget.get_height=a.rawHeight
        local y,h=widget:get_y(),widget:get_height()
        local _,barY,_,barH=borders.box(OWNER)
        local offset=math.max(0,barY+barH-y)
        a.y=function() return y+offset end
        a.height=function() return math.max(1,h-offset) end
        widget.get_y=a.y; widget.get_height=a.height
        return a.original(widget,...)
      end
      adapter=a; r.reposition=a.wrapper
    end
    adapter.root:set_constraints(adapter.root)
  end
  local function style(label,clickable,separator)
    if ui then ui.apply(label) else label:setFontSize(options.font_size) end
    label:setStyleSheet("QLabel { background-color: #14191e; color: #b6c0c9; padding-left: 7px; font-weight: normal; font-size: "..
      (ui and ui.metrics().size or options.font_size).."pt; border: none;"..(separator and " border-right: 1px solid #30373e;" or "")..
      " }"..(clickable and " QLabel:hover { color: #eef2f5; background-color: #252e36; }" or ""))
  end
  render=function()
    if not root or busy then return end
    busy=true
    local ok,err=pcall(function()
      local h=rowHeight()
      borders.reserve(OWNER,"top",h,0,function() if root then render() end end,true)
      local x,y,w= borders.box(OWNER)
      root:move(x,y); root:resize(w,h)
      local ordered={}
      for id,item in pairs(items) do
        widgets(id,item); item.widget:hide(); item.menuWidget:hide()
        if item.state.visible then ordered[#ordered+1]={id=id,item=item} end
      end
      table.sort(ordered,function(a,b)
        if a.item.definition.order==b.item.definition.order then return a.id<b.id end
        return a.item.definition.order<b.item.definition.order
      end)
      local compact=false
      local function prepare()
        local total=0
        for _,entry in ipairs(ordered) do
          local d,s=entry.item.definition,entry.item.state
          entry.text=d.label..(s.text~="" and " "..(compact and s.compactText or s.text) or "")
          if compact and entry.id=="remorts" then entry.text="R "..s.text end
          if compact and entry.id=="total" then entry.text="Tot "..s.text end
          if s.badge and s.badge~="" then entry.text=entry.text.." "..s.badge end
          entry.pinned=entry.id=="settings" or d.pinned==true
          entry.width=entry.id=="settings" and h or math.max(h,(ui and ui.measure(entry.text) or #entry.text*options.font_size*0.78)+20)
          total=total+entry.width
        end
        return total
      end
      local needed=prepare()
      if needed>w then compact=true; needed=prepare() end
      local candidates={}
      for _,entry in ipairs(ordered) do if not entry.pinned then candidates[#candidates+1]=entry end end
      table.sort(candidates,function(a,b)
        if a.item.definition.overflowPriority==b.item.definition.overflowPriority then return a.item.definition.order>b.item.definition.order end
        return a.item.definition.overflowPriority<b.item.definition.overflowPriority
      end)
      local hidden=0
      for _,entry in ipairs(candidates) do
        if needed+(hidden>0 and h or 0)<=w then break end
        entry.hidden=true; hidden=hidden+1; needed=needed-entry.width
      end
      local left,row=0,0
      local pinnedWidth=0; for _,entry in ipairs(ordered) do if entry.pinned then pinnedWidth=pinnedWidth+entry.width end end
      local right=math.max(0,w-pinnedWidth)
      for _,entry in ipairs(ordered) do
        local item=entry.item
        local tooltip=item.state.tooltip or item.definition.tooltip or entry.text
        style(item.widget,item.definition.callback~=nil,entry.id~="settings")
        style(item.menuWidget,item.definition.callback~=nil,false)
        local function content(text)
          local state=item.state
          if state.badge and state.badge~="" then text=text:sub(1,#text-#state.badge-1) end
          local result=escape(text)
          if state.color then result='<span style="color:'..state.color..'">'..result..'</span>' end
          if state.badge and state.badge~="" then
            result=result..' <span style="color:'..(state.badgeColor or '#b6c0c9')..'">'..escape(state.badge)..'</span>'
          end
          return result
        end
        item.widget:echo(content(entry.text)); item.widget:setToolTip(escape(tooltip))
        item.menuWidget:echo(content(item.definition.label.." "..item.state.text..(item.state.badge and " "..item.state.badge or ""))); item.menuWidget:setToolTip(escape(tooltip))
        if entry.hidden then
          item.menuWidget:move(0,row*h); item.menuWidget:resize("100%",h); item.menuWidget:show(); row=row+1
        else
          item.widget:move(entry.pinned and right or left,0)
          item.widget:resize(entry.width,h); item.widget:show()
          if entry.pinned then right=right+entry.width else left=left+entry.width end
        end
      end
      overflow:move(math.max(0,w-pinnedWidth-h),0); overflow:resize(h,h)
      if hidden>0 then overflow:show() else overflow:hide(); hideMenu() end
      local menuWidth=math.min(350,w)
      menu:move(x+math.max(0,w-menuWidth),y+h); menu:resize(menuWidth,math.max(1,row*h))
      sidebar()
    end)
    busy=false
    if not ok then error(err,0) end
  end
  -- The controller owns the confirmed buff set and server batch state.
  function self.bindSpellups(tracker,controller,openBuffs)
    spells,spellup=tracker,controller
    if items.spellups then self.unregisterItem("spellups") end
    self.registerItem({id="spellups",label="",order=900000,overflowPriority=1000,callback=openBuffs})
  end
  local function spellReading()
    if not spells or not spellup or not items.spellups then return end
    local snapshot,status=spells.snapshot(),spellup.status()
    local glyph,color,coverage="?","#B0B0B0","Buff coverage unknown"
    if not spells.enabled then coverage="Spell tracking disabled"
    elseif spells.isFresh() then
      local coverageState=status.coverage
      if coverageState and coverageState.known then
        local count,total=coverageState.active,coverageState.total
        if total==0 or count==0 then glyph,color,coverage="○","#B0B0B0","No expected buffs applied"
        elseif count<total then glyph,color,coverage="◐","#FFCC66","Partially buffed"
        else glyph,color,coverage="●","#66DD88","Fully buffed (confirmed buff set)" end
        coverage=coverage.." — "..count.."/"..total.." expected buffs active"
      else coverage=coverageState and coverageState.reason or "Waiting for a confirmed spellup" end
    end
    local badge,badgeColor,automation="×","#B0B0B0","Auto refresh disabled"
    if status.automatic then badge,badgeColor,automation="✓","#66DD88","Auto refresh enabled" end
    if status.paused then badge,badgeColor="!","#FF7777"
    elseif status.inflight then badge,badgeColor="↻","#77CCFF"
    elseif status.pending then badge,badgeColor="…","#FFCC66"
    elseif status.automatic and (not spells.isFresh() or status.last~="Ready") then badge,badgeColor="…","#FFCC66" end
    items.spellups.state={text=glyph,color=color,badge=badge,badgeColor=badgeColor,visible=options.show_spellups~=false,
      tooltip="Spellups: "..coverage.."\n"..automation.." — "..status.last..
        "\n○ none · ◐ partial · ● full · ? unknown\n× auto off · ✓ auto on · … pending/waiting · ↻ running · ! paused"..
        "\nCoverage uses buffs observed in the confirmed spellup, not all spells in your catalog. Click to open Buffs; no casting."}
  end
  local function readings()
    local base=cache.get("char.base"); if type(base)~="table" then base={} end
    local status=cache.get("char.status"); if type(status)~="table" then status={} end
    local worth=cache.get("char.worth"); if type(worth)~="table" then worth={} end
    local level=numeric(status.level) and status.level or base.level
    local total
    if numeric(level) and numeric(base.tier) and numeric(base.redos) and numeric(base.remorts) and base.remorts>=1 then
      total=201*(7*(base.tier+base.redos)+base.remorts-1)+math.min(level,201)
    end
    local wealth=numeric(worth.gold) and numeric(worth.bank) and worth.gold+worth.bank or nil
    local values={level=level,total=total,tier=base.tier,remorts=base.remorts,worth=wealth,gold=worth.gold,items=inventory.count}
    for id in pairs({level=true,total=true,tier=true,remorts=true,worth=true,gold=true,items=true}) do
      local item=items[id]
      if item then
        item.state={text=exact(values[id]),compactText=short(values[id]),visible=options["show_"..id]~=false,
          tooltip=id=="items" and ("Loose carried items: "..exact(values[id])..". Click to refresh. "..inventory.last) or item.definition.label..": "..exact(values[id])}
      end
    end
    spellReading()
    render()
  end
  local function refresh()
    if not self.enabled or refreshTimer then return end
    refreshTimer=api.tempTimer(0,function()
      refreshTimer=nil
      if not self.enabled then return end
      local ok,err=pcall(function() borders.refresh(); readings() end)
      if not ok then self.stop(); self.last="Stopped: "..tostring(err) end
    end)
  end
  function self.stop()
    self.enabled=false
    if refreshTimer then api.killTimer(refreshTimer); refreshTimer=nil end
    for _,name in ipairs(handlers) do api.deleteNamedEventHandler(OWNER,name) end
    handlers={}; inventory.stop(); restoreSidebar()
    -- Release after removing the layout callback's widgets.
    if root then root:delete(); root=nil end
    if menu then menu:delete(); menu=nil end
    overflow=nil
    for _,item in pairs(items) do item.widget=nil; item.menuWidget=nil end
    borders.release(OWNER); self.last="Disabled"
  end
  self.destroy=self.stop
  function self.start()
    if self.enabled then return true end
    local inventoryError
    local ok,err=pcall(function()
      self.enabled=true
      borders.reserve(OWNER,"top",rowHeight(),0,function() if root then render() end end,true)
      root=api.Geyser.Container:new({name=OWNER..".root",x=0,y=0,width="100%",height=rowHeight()})
      local background=api.Geyser.Label:new({name=OWNER..".background",x=0,y=0,width="100%",height="100%"},root)
      background:setStyleSheet("background-color: #14191e; border: none; border-bottom: 1px solid #30373e;")
      menu=api.Geyser.Container:new({name=OWNER..".menu",x=0,y=28,width=350,height=1})
      menu:hide()
      overflow=api.Geyser.Label:new({name=OWNER..".overflow",x=0,y=0,width=32,height=rowHeight()},root)
      style(overflow,true,false); overflow:echo("⋯"); overflow:setToolTip("More utility readings")
      overflow:setClickCallback(function() if menu.hidden then menu:show(); menu:raiseAll() else hideMenu() end end)
      local function on(name,event,callback)
        handlers[#handlers+1]=name
        assert(api.registerNamedEventHandler(OWNER,name,event,callback),"Cannot register utility handler")
      end
      for _,event in ipairs({"AardwolfToolbox.spells.updated","AardwolfToolbox.spells.reset","AardwolfToolbox.spells.synced","AardwolfToolbox.spellup.updated","AardwolfToolbox.gmcp.updated","AardwolfToolbox.gmcp.cleared","AardwolfToolbox.inventory.updated","AardwolfToolbox.ui.changed","sysWindowResizeEvent","sysInstallPackage","sysUninstallPackage","AdjustableContainerRepositionFinish"}) do on(event,event,refresh) end
      readings(); self.last="Running"
      local good,message=inventory.configure({enabled=options.inventory_tracking})
      if not good then self.last="Inventory: "..message; inventoryError=self.last end
    end)
    if not ok then self.stop(); self.last="Stopped: "..tostring(err); return false,self.last end
    if inventoryError then return false,inventoryError end
    return true
  end
  function self.configure(values)
    options={}; for k,v in pairs(values) do options[k]=v end
    if not options.enabled then self.stop(); return true end
    if not self.enabled then return self.start() end
    local ok,message=inventory.configure({enabled=options.inventory_tracking})
    self.last=ok and "Running" or "Inventory: "..tostring(message)
    refresh(); return ok,message
  end
  for index,entry in ipairs({{"level","Lv",100},{"total","Total",50},{"tier","Tier",40},{"remorts","Remorts",30},{"worth","Worth",60},{"gold","Gold",70},{"items","Items",80}}) do
    self.registerItem({id=entry[1],label=entry[2],order=index,overflowPriority=entry[3],
      callback=entry[1]=="items" and function() inventory.request(true) end or nil})
  end
  self.registerItem({id="settings",label="⚙",order=1000000,overflowPriority=1000000,tooltip="Toolbox settings",callback=openSettings})
  self.updateItem("settings",{text=""})
  return self
end
return Bar
