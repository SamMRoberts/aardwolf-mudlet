-- Retained, compact dashboard content independent of its tab/window host.
local Panels={}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function num(n) return finite(n) and string.format("%.0f",n) or "--" end
local function duration(n) return string.format("%d:%02d",math.floor(n/60),n%60) end
function Panels.new(api,config,cache,data,ui,spells,spellup,views,objectives)
  local self={}; local panes={}
  local function notify(message) if message then api.echo("Aardwolf dashboard: "..tostring(message).."\n") end end
  local function widget(p,id,parent,button,fn)
    local b=p.widgets[id]
    if not b then
      b=api.Geyser.Label:new({name="AardwolfToolbox.dashboard."..p.id.."."..id,x=0,y=0,width=1,height=1},parent)
      p.widgets[id]=b
      b.selectable=(p.id=="quest" or p.id=="campaign" or p.id=="globalQuest") and not button
      if fn then b:setClickCallback(function() if panes[p.id]==p and b.action then b.action() end end) end
    end
    b.action=fn
    return b
  end
  local function paint(b,text,x,y,w,h,color,button,rich,alignment)
    local metrics=ui.metrics()
    local key=table.concat({text,x,y,w,h,color or "",metrics.font,metrics.size,tostring(button),alignment or "l"},"|")
    if b.paintKey~=key then
      ui.apply(b)
      b:setStyleSheet("QLabel { background:"..(button and "#253747" or "#101820").."; color:"..(color or "#e6edf3")..
        "; border:0; padding:2px 6px; qproperty-wordWrap:true; "..(b.selectable and "qproperty-textInteractionFlags: TextSelectableByMouse; " or "").."}"..(button and " QLabel:hover {background:#35536a;} QLabel:focus {border:1px solid #8fcaf0;}" or ""))
      b:move(x,y); b:resize(w,h); b:echo(rich and text or ui.escape(text),color or "#e6edf3",alignment or (button and "c" or "l")); b.paintKey=key
    end
    if b.hidden then b:show() end
  end
  function self.mount(id,parent)
    local p={id=id,widgets={}}
    panes[id]=p
    p.root=api.Geyser.Container:new({name="AardwolfToolbox.dashboard."..id..".content",x=0,y=0,width="100%",height="100%"},parent)
    p.actions=api.Geyser.ScrollBox:new({name="AardwolfToolbox.dashboard."..id..".actions",x=0,y=0,width="100%",height=1},p.root)
    p.body=api.Geyser.ScrollBox:new({name="AardwolfToolbox.dashboard."..id..".scroll",x=0,y=0,width="100%",height="100%"},p.root)
    return p.root
  end
  function self.render(id)
    local p=panes[id]; if not p or not views.visible(id) then return end
    local width=math.max(80,p.root:get_width()); local m=ui.metrics(); local row=math.max(20,m.line-2); local used={}
    local y=0
    local function line(key,left,right,color)
      used[key]=true
      local b=widget(p,key,p.body)
      local rightWidth=right and math.min(width*0.45,ui.measure(right)+16) or 0
      local available=math.max(30,width-rightWidth-12)
      local h=math.max(row,math.ceil(ui.measure(left)/available)*row)
      paint(b,left,0,y,width-rightWidth,h,color)
      if right then
        used[key.."_value"]=true; local value=widget(p,key.."_value",p.body)
        paint(value,right,width-rightWidth,y,rightWidth,h,color,false,false,"r"); value:setToolTip(left..": "..right)
      end
      y=y+h
    end
    local status=""; local statusColor="#8fcaf0"; local actions={}
    local function action(id,text,fn,tip) actions[#actions+1]={id,text,fn,tip} end
    if id=="buffs" then
      local s=spells.snapshot(false); local state=spellup.status(); local coverage=state.coverage or {}
      status=(state.inflight and "Spellup running" or state.paused and "Paused" or state.pending and "Refresh pending" or state.automatic and "Auto on" or "Auto off")..
        " · "..(coverage.known and (coverage.active.."/"..coverage.total.." buffed") or "Coverage unknown")
      p.statusTip=state.last.."\n"..tostring(s.last or "")
      action("buffSync","Sync",function() local ok,err=spellup.sync(); if not ok then notify(err) end end,"Request spell data; does not cast")
      action("buffCast","Spellup now",function() local ok,err=spellup.runOnce(); if not ok then notify(err) end end,"Uses the existing spellup readiness guards")
      action("buffAuto",state.paused and "Resume" or state.automatic and "Pause" or "Enable",function()
        local st=spellup.status(); local enable=st.paused~=nil or not config.get("spellups","auto_refresh")
        local ok,err=config.set("spellups","auto_refresh",enable)
        if ok and enable then spellup.resume() elseif not ok then notify(err) end
      end,"Controls future batches; already queued server casts can continue")
      local effects=s.active or {}
      table.sort(effects,function(a,b)
        local at=finite(a.remaining) and a.remaining or math.huge; local bt=finite(b.remaining) and b.remaining or math.huge
        return at==bt and tostring(a.name)<tostring(b.name) or at<bt
      end)
      if #effects==0 then line("empty",s.fresh and "No active effects" or "Waiting for spell data") end
      for _,effect in ipairs(effects) do
        local awaiting=effect.awaiting or not finite(effect.remaining)
        line("effect_"..effect.id,effect.name or "Spell #"..effect.id,awaiting and (effect.awaiting and "Confirming" or "Unknown") or duration(effect.remaining),
          awaiting and "#abbcca" or effect.remaining<=config.get("views","expiry_warning") and "#ffcb70" or "#e6edf3")
      end
      local recoveries={}; for _,r in pairs(s.recoveries or {}) do recoveries[#recoveries+1]=r end
      table.sort(recoveries,function(a,b) return tostring(a.name)<tostring(b.name) end)
      used.recoveries=true
      local b=widget(p,"recoveries",p.body,true,function() config.set("views","recoveries",not config.get("views","recoveries")) end)
      paint(b,(config.get("views","recoveries") and "▾" or "▸").." Recoveries · "..#recoveries,0,y,width,m.height,"#b7c9d8",true); y=y+m.height
      if config.get("views","recoveries") then
        for _,r in ipairs(recoveries) do
          local n=finite(r.expires) and math.max(0,math.ceil(r.expires-api.getEpoch())) or nil
          line("recovery_"..r.id,r.name or "Recovery #"..r.id,n and (n>0 and duration(n) or "Confirming") or "Unknown","#b7c9d8")
        end
      end
    elseif id=="quest" then
      local q=data.quest; status="Quest · "..q.state
      statusColor=({Ready="#8eddaf",["Target defeated"]="#8eddaf",Waiting="#ffcb70",Unknown="#abbcca"})[q.state] or "#8fcaf0"
      local remaining=finite(q.remaining) and math.max(0,math.ceil(q.remaining*60-(api.getEpoch()-(q.reported or api.getEpoch())))) or nil
      if remaining then status=status.." · "..(remaining>0 and "~"..duration(remaining) or "Awaiting update") end
      local nextStep={Ready="Ready to request a quest",Active="Find the target",["Target defeated"]="Return to the quest giver",Waiting="Waiting for the next quest",Unknown="Refresh when connected to retrieve quest status"}
      line("next",nextStep[q.state] or "Waiting for quest data",nil,"#8fcaf0")
      for _,field in ipairs({"target","room","area"}) do
        if q[field] then line(field,field:sub(1,1):upper()..field:sub(2)..": "..q[field]) end
      end
      action("refresh","Refresh",function() if not data.requestQuest() then notify("Quest refresh requires a command-ready character") end end,"Request current quest status")
      action("copy","Copy",function()
        local text="Quest: "..data.quest.state
        for _,field in ipairs({"target","room","area"}) do if data.quest[field] then text=text.."\n"..field..": "..data.quest[field] end end
        if api.setClipboardText then api.setClipboardText(text) else notify("Clipboard unavailable") end
      end,"Copy quest details")
      action("find","Find on map",function()
        p.matches={}
        local preferred={}
        local q=data.quest
        if q.room and api.searchRoom then
          for roomId,name in pairs(api.searchRoom(q.room,false,true) or {}) do
            local area=api.getRoomArea(roomId); local areaName=(api.getAreaTableSwap() or {})[area]
            local match={id=roomId,name=name,area=areaName}
            p.matches[#p.matches+1]=match
            if q.area and tostring(areaName):lower()==q.area:lower() then preferred[#preferred+1]=match end
          end
        end
        if #preferred>0 then p.matches=preferred end
        table.sort(p.matches,function(a,b) return a.id<b.id end)
        p.questIdentity=(q.target or "").."|"..(q.room or "").."|"..(q.area or "")
        self.render(id)
      end,"Search existing rooms in the reported area; never walks")
      local identity=(q.target or "").."|"..(q.room or "").."|"..(q.area or "")
      if p.questIdentity~=identity then p.matches=nil end
      if p.matches then
        if #p.matches==0 then line("noMatches","No matching room in the saved map",nil,"#abbcca") end
        for index,match in ipairs(p.matches) do
          if index>200 then line("matchLimit","First 200 matches shown"); break end
          local key="match_"..match.id; used[key]=true
          local b=widget(p,key,p.body,true,function() if p.questIdentity==identity then api.centerview(match.id) end end)
          paint(b,match.name.." · "..tostring(match.area or "Unknown area").." #"..match.id,0,y,width,m.height,"#8fcaf0",true); y=y+m.height
        end
      end
    elseif objectives and objectives[id] then
      local service=objectives[id];local q=service.snapshot();local report=service.status()
      status=(id=="campaign" and "Campaign" or "Global Quest").." · "..q.state..(q.fresh and "" or " · Stale")
      p.statusTip=report.last
      statusColor=q.fresh and "#8fcaf0" or "#abbcca"
      if finite(q.remainingSeconds) then
        local remaining=math.max(0,math.ceil(q.remainingSeconds-(api.getEpoch()-(q.reported or api.getEpoch()))))
        status=status.." · "..(remaining>0 and "~"..duration(remaining) or "Awaiting update")
      end
      line("source",report.last,nil,"#abbcca")
      if q.today~=nil then line("today","Campaigns today",num(q.today)) end
      if id=="globalQuest" then
        line("participation",q.fresh and q.participating and ("Participating · #"..tostring(q.eventId or "?")) or "Participation unconfirmed",nil,"#abbcca")
      end
      local function choose(key,text,fn,tip)
        used[key]=true;local b=widget(p,key,p.body,true,fn)
        local h=math.max(m.height,math.ceil(ui.measure(text)/math.max(30,width-12))*row)
        paint(b,text,0,y,width,h,"#8fcaf0",true);b:setToolTip(ui.escape(tip or text));y=y+h
      end
      for _,e in ipairs(q.events or {}) do
        local number=e.id
        choose("event_"..number,"#"..number.." · "..(e.state or "Unknown")..(e.minLevel and " · Lv "..e.minLevel.."–"..tostring(e.maxLevel or "?") or ""),function()
          p.details=true;local ok,why=service.inspect(number);if not ok then notify(why) end
        end,"Request informational event details; never joins")
      end
      if id=="globalQuest" and q.availabilityKnown and #(q.events or {})==0 then line("none","No events in last availability response",nil,"#abbcca") end
      local visibleObjectives=id=="campaign" or q.fresh and q.participating
      local function displayed(current)
        if id=="globalQuest" and current.selected and p.details~=false then return current.selected end
        return current
      end
      local shown=displayed(q)
      if id=="globalQuest" and q.selected and p.details~=false then
        visibleObjectives=true
        line("selectedEvent","Event details · #"..q.selected.eventId.." · "..q.selected.state..(q.selected.fresh and "" or " · Stale"),nil,"#8fcaf0")
        line("selectedScope","Public event objectives; not personal progress",nil,"#abbcca")
      end
      local identity=api.yajl.to_string({shown.eventId or false,shown.objectives or {},shown.fresh})
      if identity~=p.objectiveIdentity then p.matches=nil;p.selected=nil;p.objectiveIdentity=identity end
      if visibleObjectives then
        for index,o in ipairs(shown.objectives or {}) do
          choose("objective_"..index,(p.selected==index and "› " or "")..o.name..
            (o.remaining~=nil and " · "..o.remaining.." remaining" or o.quantity and " · "..o.quantity.." required" or "")..
            (o.unavailable and " · Unavailable (not credited)" or ""),function()
              p.selected=index;p.matches=nil;self.render(id)
            end,"Select for local map lookup; identity is unverified")
          line("location_"..index,o.room and "Room: "..o.room or o.area and "Area: "..o.area or o.location and "Location (type unknown): "..o.location or "Location unknown",nil,"#abbcca")
        end
      end
      for _,key in ipairs({"rewards","awards"}) do
        local rewards=shown[key] or {}
        for _,field in ipairs({"qp","gold","tp","trains","pracs"}) do
          if rewards[field]~=nil then line(key..field,(key=="rewards" and "Advertised " or "Observed award ")..field,num(rewards[field])) end
        end
      end
      if id=="globalQuest" and q.selected then
        action("scope",p.details==false and "Event details" or "My progress",function() p.details=p.details==false;self.render(id) end,"Switch between inspected public details and personal progress")
      end
      action("refresh","Refresh",function() local ok,why=service.refresh();if not ok then notify(why) end end,"Informational refresh; unsupported formats stay visible")
      action("copy","Copy",function()
        local current=displayed(service.snapshot());local lines={status}
        for _,o in ipairs(current.objectives or {}) do lines[#lines+1]=o.name.." · "..(o.room or o.area or o.location or "Unknown location") end
        if api.setClipboardText then api.setClipboardText(table.concat(lines,"\n")) else notify("Clipboard unavailable") end
      end,"Copy last observed details")
      action("find","Find on map",function()
        local current=displayed(service.snapshot());local o=current.objectives and current.objectives[p.selected or 0]
        if not o then notify("Select an objective first");return end
        p.matches={};local areas=api.getAreaTableSwap and api.getAreaTableSwap() or {}
        local query=o.room or o.location
        if query and api.searchRoom then
          for roomId,name in pairs(api.searchRoom(query,false,true) or {}) do
            local areaName=areas[api.getRoomArea(roomId)]
            if not o.area or areaName and areaName:lower()==o.area:lower() then p.matches[#p.matches+1]={id=roomId,name=name,area=areaName} end
          end
        end
        if o.area and api.getAreaRooms then
          for areaId,name in pairs(areas) do if name:lower()==o.area:lower() then
            local roomIds=api.getAreaRooms(areaId) or {};local first
            for _,roomId in pairs(roomIds) do if not first or roomId<first then first=roomId end end
            if first and not o.room then p.matches[#p.matches+1]={id=first,name="Area: "..name,area=name} end
          end end
        end
        table.sort(p.matches,function(a,b) return a.id<b.id end);self.render(id)
      end,"Find the selected reported location in the saved map; never walks")
      if p.matches then
        if #p.matches==0 then line("noMatches","No matching location in the saved map",nil,"#abbcca") end
        for index,match in ipairs(p.matches) do
          if index>200 then line("matchLimit","First 200 matches shown");break end
          choose("match_"..match.id,match.name.." · "..tostring(match.area or "Unknown area").." #"..match.id,function()
            local latest=displayed(service.snapshot())
            if api.yajl.to_string({latest.eventId or false,latest.objectives or {},latest.fresh})==identity then api.centerview(match.id) end
          end,"Center the saved map here; no movement")
        end
      end
    elseif id=="group" then
      local g=cache.get("group") or {}; local members=type(g.members)=="table" and g.members or {}
      status=g.reason=="no group" and "Not grouped" or (g.groupname and g.groupname~="" and g.groupname or "Group").." · "..#members.." members"
      if g.leader then line("leader","Leader: "..g.leader,nil,"#8fcaf0") end
      if #members==0 and g.reason~="no group" then line("empty","Waiting for group data") end
      for i,member in ipairs(members) do
        if i>100 then break end
        local info=member.info or {}; local key="member_"..i
        line(key,member.name or "Unknown","Lv "..num(info.lvl)..(info.here==1 and " · Here" or info.here==0 and " · Away" or ""),info.here==1 and "#8eddaf" or "#b7c9d8")
        local resourceHeight=row
        for j,v in ipairs({{"HP","hp","mhp","#8eddaf"},{"MP","mn","mmn","#8fcaf0"},{"MV","mv","mmv","#e5ca82"}}) do
          local current,maximum=info[v[2]],info[v[3]]
          local percent=finite(current) and finite(maximum) and maximum>0 and math.max(0,math.min(100,math.floor(current/maximum*100))) or nil
          local text=v[1].." "..(percent and percent.."%" or num(current).."/"..num(maximum))
          local cellKey=key.."_"..v[2]; used[cellKey]=true
          local b=widget(p,cellKey,p.body)
          local h=math.max(row,math.ceil(ui.measure(text)/math.max(20,width/3-12))*row); resourceHeight=math.max(resourceHeight,h)
          paint(b,text,(j-1)*width/3,y,width/3,h,j==1 and percent and percent<25 and "#ff927e" or v[4])
          b:setToolTip(v[1].." "..num(current).."/"..num(maximum))
        end
        y=y+resourceHeight

      end
    end
    used.status=true; local header=widget(p,"status",p.root)
    local statusHeight=math.max(row,math.ceil(ui.measure(status)/math.max(1,width-12))*row)
    paint(header,status,0,0,width,statusHeight,statusColor); header:setToolTip(p.statusTip or status)
    local top=statusHeight
    if #actions>0 then
      local total=0; for _,a in ipairs(actions) do total=total+ui.measure(a[2])+16 end
      local h=m.height; local x=0
      p.actions:move(0,top); p.actions:resize("100%",h+2); p.actions:show()
      for _,a in ipairs(actions) do
        used[a[1]]=true; local b=widget(p,a[1],p.actions,true,a[3]); local bw=math.max(width,total)*(ui.measure(a[2])+16)/total
        -- Keep the action row horizontally scrollable at unusually large font sizes.
        paint(b,a[2],x,0,bw,h,nil,true); b:setToolTip(a[4]); x=x+bw
      end
      top=top+h+2
    else p.actions:hide() end
    p.body:move(0,top); p.body:resize("100%","100%-"..top)
    for key,b in pairs(p.widgets) do if not used[key] and not b.hidden then b:hide() end end
  end
  function self.stop() panes={} end
  return self
end
return Panels
