-- Disk-backed character catalog. Only a bounded refresh transaction lives in memory.
local Abilities={}
local OWNER='AardwolfToolbox.abilities'
local function copy(v)
  if type(v)~='table' then return v end
  local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r
end
local function fingerprint(b)
  return table.concat({tostring(b.name),tostring(b.level),tostring(b.classes),tostring(b.class),
    tostring(b.subclass),tostring(b.tier),tostring(b.remorts),tostring(b.redos)},':')
end
-- Verified command syntax, not names converted speculatively into commands.
-- References and unsupported-command behavior are documented in docs/abilities.md.
local SKILLS={assault={command='assault',targeting='single'},scalp={command='scalp',targeting='single'},
  sap={command='sap',targeting='single'},kick={command='kick',targeting='single'},trip={command='trip',targeting='single'},
  stun={command='stun',targeting='single'},hammerswing={command='hammerswing',targeting='area'},bash={command='bash',targeting='single'},uppercut={command='uppercut',targeting='single'},
  headbutt={command='headbutt',targeting='single'},gouge={command='gouge',targeting='single'}}
function Abilities.new(api,config,cache,incoming,tags,store,queries,Capture,Model,spellup)
  local self={enabled=false,last='Disabled'}
  local options={automatic_refresh=true,corrections={}}
  local handlers,request,timeout,pumpTimer,notifyTimer={},nil,nil,nil,nil
  local staged,queue,index,pending,fresh,identity,stamp,session=nil,nil,nil,false,false,nil,nil,0
  local count,updated=0,nil
  local ownSend=false
  local dirty=false
  local drive,fail
  local function connected() return cache.enabled and select(3,api.getConnectionInfo()) end
  local function ready()
    return self.enabled and connected() and cache.get('char.status.state')==3 and cache.get('char.status.pos')=='Standing'
      and not (spellup and spellup.status().inflight)
  end
  local function notify(event)
    if notifyTimer then api.killTimer(notifyTimer) end
    local current=session
    notifyTimer=api.tempTimer(0,function()
      notifyTimer=nil; if self.enabled and current==session then api.raiseEvent(OWNER..'.'..(event or 'updated')) end
    end)
  end
  local function schedule()
    if pumpTimer then return end
    local current=session
    pumpTimer=api.tempTimer(0.15,function()
      pumpTimer=nil
      if self.enabled and current==session then
        local ok,err=pcall(drive); if not ok then fail(tostring(err)) end
      end
    end)
  end
  local function cancel()
    if timeout then api.killTimer(timeout); timeout=nil end
    if pumpTimer then api.killTimer(pumpTimer); pumpTimer=nil end
    if request and request.query.kind=='learned' and tags then tags.abortCapture('spellheaders','Ability collection stopped') end
    request=nil; staged=nil; queue=nil; index=nil; queries.release(OWNER)
  end
  fail=function(reason)
    cancel(); pending=false; fresh=false; self.last='Stale: '..reason..'. Refresh to retry.'
    api.echo('Aardwolf abilities: '..self.last..'\n'); notify()
  end
  local function rows(corrections)
    local result={}
    for _,r in ipairs(store.rows('abilities')) do
      result[#result+1]=Model.correct(r,corrections or options.corrections,store.character())
    end
    return result
  end
  function self.get(id)
    id=tonumber(id); if not id or id%1~=0 or id<1 or id>2147483647 then return nil end
    local r=store.get('abilities',id)
    return r and Model.correct(r,options.corrections,store.character()) or nil
  end
  function self.list(filter,corrections)
    local result={}
    for _,r in ipairs(rows(corrections)) do if r.learned and Model.matches(r,filter) then result[#result+1]=r end end
    table.sort(result,function(a,b) if a.name==b.name then return a.id<b.id end; return a.name<b.name end)
    return result
  end
  function self.types(role,corrections)
    local seen,result={},{}
    for _,r in ipairs(self.list(nil,corrections)) do
      for _,m in ipairs(r.memberships) do
        if (not role or role=='any' or m.role==role) and not seen[m.type] then seen[m.type]=true; result[#result+1]=m.type end
      end
    end
    table.sort(result); return result
  end
  function self.preview(button,corrections)
    local meta=store.get('ability_metadata',0) or {}
    local level=tonumber(cache.get('char.base.level')) or meta.level
    local candidates
    if button.ability_mode=='specific' then
      local r=store.get('abilities',tonumber(button.ability_id) or 0)
      candidates=r and {Model.correct(r,corrections or options.corrections,store.character())} or {}
    else candidates=rows(corrections) end
    return Model.resolve(candidates,button,level)
  end
  function self.resolve(button)
    if not self.enabled then return nil,'Ability catalog disabled' end
    if not connected() or not fresh then return nil,'Catalog is stale; refresh before using this ability' end
    local b=cache.get('char.base') or {}
    if not b.name or b.name:lower()~=identity or fingerprint(b)~=stamp then return nil,'Character catalog needs synchronization' end
    return self.preview(button)
  end
  function self.status()
    return {enabled=self.enabled,fresh=fresh and connected() or false,busy=queue~=nil,pending=pending,
      character=store.character(),count=count,updated=updated,last=self.last,session=session}
  end
  function self.refresh()
    if not self.enabled then return false,'Ability catalog disabled' end
    if queue then return true,'Ability refresh already in progress' end
    pending=true; fresh=false; self.last='Refresh queued; waiting for standing, command-ready character'
    notify(); schedule(); return true,self.last
  end
  local function membership(row,role,kind)
    kind=kind and kind~='' and kind or 'unknown'
    for _,m in ipairs(row.memberships) do if m.role==role and m.type==kind then return end end
    row.memberships[#row.memberships+1]={role=role,type=kind}
  end
  local function findRow(q,r)
    if r.id then
      local found=staged[r.id]
      assert(not found or found.name:lower()==r.name:lower(),'Ability number/name mismatch')
      return found
    end
    local found
    for _,candidate in pairs(staged) do
      if candidate.kind==q.kind and candidate.name:lower()==r.name:lower() then
        assert(not found,'Ambiguous ability name'); found=candidate
      end
    end
    return found
  end
  local function complete(q,capture)
    if q.kind=='learned' then staged=capture.rows
    elseif q.kind=='detail' then
      local r=staged[q.id]
      assert(capture.detail and capture.detail.level,'Incomplete ability details')
      if not r.level then r.level=capture.detail.level end
      if capture.damage then membership(r,'damage',capture.damage) end
    else
      for _,r in pairs(capture.rows) do
        local row=findRow(q,r)
        if row then
          if q.filter=='' then
            row.level=r.level; row.available=true; row.cost=r.cost
            row.cost_known=r.cost~=nil; row.resource=q.kind=='spell' and 'mana' or 'unknown'
          elseif q.filter=='combat' then membership(row,'damage',r.damage)
          elseif q.filter=='resist' then membership(row,'protection','unknown')
          elseif q.filter=='healing' then membership(row,'healing','healing')
          elseif q.filter=='spellup' then membership(row,'buff','general')
          elseif q.filter=='passive' then row.passive=true
          elseif q.filter=='area' then row.targeting='area'
          else membership(row,'stat',q.filter) end
        end
      end
    end
    index=index+1
    if index>#queue then
      local n=0
      for _,r in pairs(staged) do
        if #r.memberships==0 then membership(r,'unknown','unknown') end
        if r.kind=='spell' and r.targeting~='special' and r.targeting~='unknown' then r.command='cast '..r.id
        elseif r.kind=='skill' and SKILLS[r.name:lower()] then
          local known=SKILLS[r.name:lower()]; r.command=known.command
          if r.targeting~='area' then r.targeting=known.targeting end
        end
        if r.learned and r.available then n=n+1 end
      end
      local at=api.getEpoch()
      store.replace({abilities=staged,ability_metadata={[0]={name=identity,level=tonumber(cache.get('char.base.level')),updated=at,count=n,fingerprint=stamp}}})
      cancel(); count=n; updated=at; fresh=true; self.last='Ready · '..n..' available learned abilities'; notify()
      if dirty then dirty=false; self.refresh() end
    else schedule() end
  end
  drive=function()
    if not pending and not queue or request then return end
    if not ready() then self.last='Refresh paused; waiting for standing, command-ready character'; return end
    local b=cache.get('char.base')
    if not b or type(b.name)~='string' or not tonumber(b.level) then return end
    if not queries.acquire(OWNER) then self.last='Waiting for spell tracker synchronization'; return end
    if not queue then
      store.select(b.name); identity=b.name:lower(); stamp=fingerprint(b); staged={}; pending=false; fresh=false
      queue={{kind='learned',command='slist learned noprompt'}}; index=1
      for _,filter in ipairs({'','combat','resist','healing','str','dex','con','int','wis','luck','passive','area','spellup'}) do
        for _,kind in ipairs({'spell','skill'}) do
          queue[#queue+1]={kind=kind,filter=filter,command=kind..'s'..(filter~='' and ' '..filter or '')}
        end
      end
    end
    local q=queue[index]
    request={query=q,capture=Capture.new(q)}; self.last='Collecting '..q.command..' ('..index..'/'..#queue..')'
    local current=session
    timeout=api.tempTimer(10,function()
      timeout=nil; if current==session then fail('Response timed out for '..q.command) end
    end)
    ownSend=true
    local ok,result,err=pcall(api.send,q.command,false)
    ownSend=false
    if not ok or result==false or (result==nil and err) then fail('Request failed: '..tostring(err or result)) end
  end
  local function receive(line)
    if not self.enabled or not connected() then return false end
    if options.automatic_refresh then
      local name=line:match('^Your new skill level in (.-) is %d+%%%.') or line:match('^You are now an expert in (.-)%.')
      if not name then
        local improved=line:match('^You have become better at (.-)! %(%d+%%%)')
        if improved then
          local existing=store.rows('abilities',improved:lower())[1]
          if not existing or not existing.learned then name=improved end
        end
      end
      if name then if queue then dirty=true; fresh=false else self.refresh() end end
      if line:match('^You have forgotten ') or line:match('^You can now use the following skills and spells') then if queue then dirty=true; fresh=false else self.refresh() end end
    end
    if request then
      local current=request
      if current.query.kind~='learned' and tags and tags.isCapturing and tags.isCapturing() then return false end
      local ok,claimed,done=pcall(current.capture.receive,line)
      if not ok then fail(tostring(claimed)); return false end
      if done then
        if timeout then api.killTimer(timeout); timeout=nil end
        request=nil
        local ok,err=pcall(complete,current.query,current.capture); if not ok then fail(tostring(err)) end
      end
      if claimed then return true,true,current.query.kind=='learned' and 'AardwolfToolbox.tags' or nil end
      return false
    end
    return false
  end
  local function reset()
    session=session+1; cancel(); dirty=false; fresh=false; identity=nil; stamp=nil; pending=options.automatic_refresh
    self.last='Saved catalog available offline; waiting for fresh character data'; notify('reset')
  end
  function self.stop()
    self.enabled=false; reset(); pending=false
    if notifyTimer then api.killTimer(notifyTimer); notifyTimer=nil end
    incoming.remove(OWNER)
    for _,event in ipairs(handlers) do api.deleteNamedEventHandler(OWNER,event) end; handlers={}
    if api.gmod then api.gmod.disableModule(OWNER,'Char') end
    store.close(OWNER); self.last='Disabled'; api.raiseEvent(OWNER..'.reset')
  end
  self.destroy=self.stop
  function self.start()
    if self.enabled then return true end
    local ok,err=pcall(function()
      local opened,message=store.open(OWNER); assert(opened,message)
      local meta=store.get('ability_metadata',0) or {}; count=meta.count or 0; updated=meta.updated
      self.enabled=true; reset()
      incoming.add(OWNER,18,receive,function(message) self.stop(); self.last='Stopped: '..tostring(message); api.echo('Aardwolf abilities: '..self.last..'\n') end)
      local function on(event,fn)
        handlers[#handlers+1]=event; assert(api.registerNamedEventHandler(OWNER,event,event,fn),'Cannot register ability handler')
      end
      on('sysDataSendRequest',function(_,command)
        if queue and not ownSend and type(command)=='string' and
            (command:match('^slist[%s$]') or command=='slist' or command:match('^spells?%s') or command=='spells' or command:match('^skills?%s') or command=='skills') then
          fail('Another spell/skill query interrupted collection')
        end
      end)
      on('AardwolfToolbox.queries.available',schedule)
      on('AardwolfToolbox.spellup.updated',schedule)
      on('AardwolfToolbox.gmcp.cleared',reset)
      on('sysDisconnectionEvent',reset)
      on('AardwolfToolbox.gmcp.updated',function(_,path)
        if path=='char.base' then
          local b=cache.get(path)
          if b and b.name then
            local nextStamp=fingerprint(b)
            if stamp and stamp~=nextStamp then reset() end
            if store.character()~=b.name:lower() then
              store.select(b.name)
              local meta=store.get('ability_metadata',0) or {}; count=meta.count or 0; updated=meta.updated
            end
          end
        end
        if path=='char.status' then
          local state=cache.get('char.status.state')
          if request and (state==5 or state==6 or state==7) then fail('Game pager/editor interrupted collection') end
        end
        schedule()
      end)
      api.gmod.enableModule(OWNER,'Char')
      if connected() and type(api.sendGMCP)=='function' then api.sendGMCP('request char') end
      schedule()
    end)
    if not ok then self.stop(); self.last=tostring(err); return false,self.last end
    return true
  end
  function self.configure(values)
    local changed=options.automatic_refresh~=values.automatic_refresh
    options=copy(values)
    if not values.enabled then self.stop(); return true end
    if self.enabled and changed and not options.automatic_refresh then cancel(); pending=false; fresh=false end
    local ok,err=self.start(); if not ok then return ok,err end
    if changed and options.automatic_refresh then self.refresh() end
    notify(); return true
  end
  return self
end
return Abilities
