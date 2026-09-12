-- Session-only room activity with bounded, readiness-gated informational refreshes.
local Mobs={}
local OWNER='AardwolfToolbox.mobs'
function Mobs.definition(apply)
  return {id='mobs',label='Room mobs',description='Always-visible room list. Refresh includes nearby scan results while command-ready. Every mob has its own row. Double-click attacks with kill <ordinal>.<full mob name>; unseen mobs are not presumed dead. Attacker markers mean recently observed incoming attacks.',settings={
    {key='enabled',label='Enable room mob pane',type='boolean',default=true},
    {key='automatic_setup',label='Automatically enable scan tags',type='boolean',default=true},
    {key='nearby',label='Include nearby scan results',type='boolean',default=true},
    {key='on_entry',label='Refresh when entering a room',type='boolean',default=true},
    {key='after_combat',label='Refresh after combat ends',type='boolean',default=true},
    {key='interval',label='Periodic refresh (seconds; 0 disables)',type='number',default=0,min=0,max=300,integer=true},
    {key='width',label='Pane width (pixels)',type='number',default=260,min=180,max=480,integer=true},
    {key='target',label='Show current target',type='boolean',default=true},
    {key='attackers',label='Show observed attackers',type='boolean',default=true},
    {key='attack_window',label='Attacker evidence lifetime (seconds)',type='number',default=12,min=3,max=60,integer=true},
    {key='show_killed',label='Retain confirmed kills until leaving',type='boolean',default=true},
    {key='show_missing',label='Show mobs no longer seen',type='boolean',default=false},
    {key='flags',label='Show mob flags and auras',type='boolean',default=true},
    {key='symbols',label='Show indicator symbols',type='boolean',default=true},
    {key='colors',label='Use status colors',type='boolean',default=true},
    {key='blink',label='Pulse observed attacker backgrounds',type='boolean',default=false},
    {key='target_color',label='Target color (#RRGGBB)',type='text',default='#80cfff',maxLength=7},
    {key='attacker_color',label='Attacker color (#RRGGBB)',type='text',default='#ff997f',maxLength=7},
    {key='killed_color',label='Killed color (#RRGGBB)',type='text',default='#aebbc8',maxLength=7},
  },validate=function(values)
    if values.interval>0 and values.interval<10 then return false,'Periodic refresh must be off or at least 10 seconds.' end
    for _,key in ipairs({'target_color','attacker_color','killed_color'}) do
      if not values[key]:match('^#%x%x%x%x%x%x$') then return false,'Colors must use #RRGGBB.' end
    end
    return true
  end,apply=apply}
end
function Mobs.new(api,cache,incoming,tags,queries,spellup,State,Protocol,Pane,ui,borders,settings)
  local self={enabled=false,last='Disabled'}
  local options,handlers={},{}
  local nearby={fresh=false,sections={}}; local requestFull=false
  local function copy(value)
    if type(value)~='table' then return value end
    local result={}; for k,v in pairs(value) do result[k]=copy(v) end; return result
  end
  local model=State.new(api.getEpoch)
  local timer,timeout,notifyTimer,frame,pending,owned,setup,lastRequest,lastRoom=nil,nil,nil,nil,false,false,false,-math.huge,nil
  local generation=0; local ownSend=false; local failedRefresh=false; local status={}
  local view=Pane.new(api,ui,borders,function() self.refresh() end,settings,function(id,revision) return self.attack(id,revision) end,function() self.clearSelection() end)
  local function connected() return cache.enabled and select(3,api.getConnectionInfo())==true end
  local function ready() return connected() and cache.get('char.status.state')==3 and cache.get('char.status.pos')=='Standing' and not spellup.status().inflight end
  local function update()
    view.update(self.snapshot(),self.last)
    if notifyTimer then return end
    local current=generation
    notifyTimer=api.tempTimer(0,function()
      notifyTimer=nil; if self.enabled and current==generation then api.raiseEvent(OWNER..'.updated') end
    end)
  end
  local function cancel()
    if timeout then api.killTimer(timeout); timeout=nil end
    if frame and tags.abortCapture then tags.abortCapture('scan','Room capture stopped') end
    frame=nil; owned=false; queries.release(OWNER)
  end
  local function fail(reason)
    cancel(); pending=false; failedRefresh=true; model.fresh=false; model.selected=nil
    nearby.fresh=false
    self.last=reason..'; Refresh to retry'; update()
  end
  local function reset()
    generation=generation+1; cancel(); pending=false; setup=false; lastRoom=nil; failedRefresh=false
    status={}; nearby={fresh=false,sections={}}; model.clear(nil); self.last='Waiting for fresh room data'; update()
  end
  function self.snapshot()
    local result=model.snapshot(options.attack_window or 12); result.nearby=copy(nearby); return result
  end
  function self.select(id,revision)
    if not self.enabled or not connected() or not model.room then return false,'Room targeting unavailable' end
    local state=cache.get('char.status.state')
    if state~=3 and state~=8 then self.last='Selection unavailable until character is command-ready'; update(); return false,self.last end
    local ok,reason=model.select(id,revision)
    if not ok then self.last=reason end
    update(); return ok,reason
  end
  function self.attack(id,revision)
    local ok,reason=self.select(id,revision)
    if not ok then return false,reason end
    local row=self.selected()
    if not row then return false,'Room target unavailable' end
    local command='kill '..row.ordinal..'.'..row.name
    local sent,result,err=pcall(api.send,command,true)
    if not sent or result==false or err then
      self.last='Attack command could not be sent'; update(); return false,self.last
    end
    model.command(command)
    self.last='Attack requested: '..row.ordinal..'.'..row.name; update(); return true
  end
  function self.clearSelection()
    if not self.enabled then return false end
    model.selected=nil; update(); return true
  end
  function self.selected()
    if not self.enabled or not connected() or not model.fresh then return end
    for _,r in ipairs(self.snapshot().rows) do if r.selected then return r end end
  end
  function self.refresh()
    if not self.enabled then return false,'Room tracker disabled' end
    if not model.room or not ready() then self.last='Refresh requires a fresh room and standing, command-ready character'; update(); return false,self.last end
    if owned then return true,'Room refresh already in progress' end
    pending=true; failedRefresh=false; self.last='Refresh queued'; update(); return true
  end
  local function drive()
    if not pending or owned or not model.room or not ready() or api.getEpoch()-lastRequest<3 then return end
    if not queries.acquire(OWNER) then return end
    if options.automatic_setup and not setup then
      ownSend=true; local ok,result,err=pcall(api.send,'tags scan on',false); ownSend=false
      if not ok or result==false or err then fail('Could not enable scan tags'); return end
      setup=true
    end
    requestFull=options.nearby==true
    owned=true; pending=false; lastRequest=api.getEpoch(); self.last='Refreshing room mobs'
    local current=generation
    timeout=api.tempTimer(10,function() timeout=nil; if current==generation then fail('Room scan timed out') end end)
    ownSend=true; local ok,result,err=pcall(api.send,requestFull and 'scan' or 'scan here',false); ownSend=false
    if not ok or result==false or err then fail('Room scan request failed') end
    update()
  end
  local function receive(text)
    if not self.enabled or not connected() or type(text)~='string' then return false end
    if not frame and tags.isCapturing and tags.isCapturing() then return false end
    if text:match('^%s*{scan}%s*$') then
      if frame then fail('Interrupted room scan'); return false end
      if not owned then return false end
      frame={capture=Protocol.scan(),room=model.room,events={},full=requestFull}
      return true,true,'AardwolfToolbox.tags'
    end
    if frame then
      if text:match('^%s*{/scan}%s*$') then
        local saved=frame
        if not saved.capture.valid or not saved.full and not saved.capture.seen then
          fail('No recognized scan section'); return true,true,'AardwolfToolbox.tags'
        end
        if saved.room~=model.room then cancel(); return true,true,'AardwolfToolbox.tags' end
        if saved.capture.seen then
          local ok,err=pcall(model.observe,saved.capture.entries)
          if not ok then fail(tostring(err)); return true,true,'AardwolfToolbox.tags' end
        else
          -- A directional-only scan cannot establish current-room membership.
          model.fresh=false; model.selected=nil
        end
        nearby=saved.full and {fresh=true,updated=api.getEpoch(),sections=copy(saved.capture.sections)} or {fresh=false,sections={}}
        frame=nil; cancel()
        for _,event in ipairs(saved.events) do model[event[1]](event[2]) end
        failedRefresh=false
        self.last=saved.capture.seen and 'Visible mobs · current visit' or 'Nearby scan updated; current room not reported'
        update()
        return true,true,'AardwolfToolbox.tags'
      end
      local ok,claimed=pcall(frame.capture.line,text)
      if not ok then fail(tostring(claimed)); return false end
      if claimed then return true,true,'AardwolfToolbox.tags' end
    end
    if tags.isCapturing and tags.isCapturing() and not frame then return false end
    local event,name=Protocol.combat(text,model.snapshot(options.attack_window).rows)
    if event then
      model[event](name)
      if frame then frame.events[#frame.events+1]={event,name}; if #frame.events>512 then fail('Too many interleaved combat events') end end
      update()
    end
    return false
  end
  local function tick()
    timer=nil; if not self.enabled then return end
    local ok,err=pcall(function()
      if options.interval>0 and not failedRefresh and not owned and model.updated and api.getEpoch()-math.max(lastRequest,model.updated)>=options.interval then pending=true end
      drive(); view.update(self.snapshot(),self.last,true)
    end)
    if not ok then fail(tostring(err)) end
    timer=api.tempTimer(1,tick)
  end
  local function gmcp(_,path)
    if path=='room.info' then
      local room=cache.get(path)
      local key=type(room)=='table' and type(room.num)=='number' and room.num>0 and room.num<2147483648 and room.num%1==0 and tostring(room.num) or nil
      if key~=lastRoom or key==nil then
        cancel(); lastRoom=key; nearby={fresh=false,sections={}}; model.clear(key); status={}; failedRefresh=false
        self.last=key and 'Waiting for room scan' or 'Room identity unavailable'
        pending=key~=nil and options.on_entry
      end
    elseif path=='char.status' then
      local s=cache.get(path) or {}
      local wasFighting=status.state==8
      for _,key in ipairs({'state','enemy','enemypct'}) do if s[key]~=nil then status[key]=s[key] end end
      model.enemy(status.enemy,status.state==8,status.enemypct)
      if wasFighting and status.state==3 and options.after_combat then pending=true; failedRefresh=false end
      if owned and (s.state==5 or s.state==6 or s.state==7) then fail('Room scan interrupted by editor/pager') end
    end
    update()
  end
  function self.stop()
    self.enabled=false; generation=generation+1; cancel()
    if timer then api.killTimer(timer) end
    if notifyTimer then api.killTimer(notifyTimer) end
    timer,notifyTimer=nil,nil
    for _,event in ipairs(handlers) do api.deleteNamedEventHandler(OWNER,event) end; handlers={}
    incoming.remove(OWNER)
    if api.gmod then for _,m in ipairs({'Char','Room'}) do api.gmod.disableModule(OWNER,m) end end
    model.clear(nil); nearby={fresh=false,sections={}}; pending=false; setup=false; lastRoom=nil; view.destroy(); self.last='Disabled'
  end
  self.destroy=self.stop
  function self.start()
    if self.enabled then return true end
    local ok,err=pcall(function()
      self.enabled=true; view.configure(options); reset()
      incoming.add(OWNER,17,receive,function(message) self.stop(); self.last='Stopped: '..tostring(message); api.echo('Aardwolf mobs: '..self.last..'\n') end)
      local function on(event,fn) handlers[#handlers+1]=event; assert(api.registerNamedEventHandler(OWNER,event,event,fn)) end
      on('AardwolfToolbox.gmcp.updated',gmcp)
      on('AardwolfToolbox.gmcp.cleared',reset)
      on('sysDisconnectionEvent',reset)
      on('sysWindowResizeEvent',view.layout)
      on('AardwolfToolbox.ui.changed',view.layout)
      on('sysDataSendRequest',function(_,command)
        local state=cache.get('char.status.state')
        if connected() and (state==3 or state==8) then model.command(command) end
        if owned and not ownSend and type(command)=='string' and (command=='scan' or command:match('^scan%s')) then fail('Another scan interrupted refresh') end
      end)
      api.gmod.enableModule(OWNER,'Char'); api.gmod.enableModule(OWNER,'Room')
      if connected() then api.sendGMCP('request room'); api.sendGMCP('request char') end
      timer=api.tempTimer(1,tick)
    end)
    if not ok then self.stop(); self.last='Stopped: '..tostring(err); return false,self.last end
    return true
  end
  function self.configure(values)
    if values.nearby~=options.nearby then nearby={fresh=false,sections={}} end
    options={}; for k,v in pairs(values) do options[k]=v end
    if not options.enabled then self.stop(); return true end
    if self.enabled then
      cancel(); pending=false
      local ok,err=pcall(view.configure,options); if not ok then self.stop(); self.last=tostring(err); return false,self.last end
      update(); return true
    end
    return self.start()
  end
  return self
end
return Mobs
