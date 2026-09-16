-- Disk-backed character catalog. Only a bounded refresh transaction lives in memory.
local Abilities={}
local OWNER='AardwolfToolbox.abilities'
local function copy(v)
  if type(v)~='table' then return v end
  local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r
end
local function validLevel(value)
  value=tonumber(value)
  if value and value==value and value>0 and value<math.huge and value%1==0 then return value end
end
local function fingerprint(b)
  return table.concat({tostring(b.name),tostring(b.level),tostring(b.classes),tostring(b.class),
    tostring(b.subclass),tostring(b.tier),tostring(b.remorts),tostring(b.redos)},':')
end
-- Spell invocation is defined by the protocol. Skill invocation is saved data
-- captured from help; there is no built-in ability-name or number registry.
local function withCommand(row)
  if not row then return nil end
  row=copy(row)
  if row.kind=='spell' and row.targeting~='special' and row.targeting~='unknown' then
    row.command='cast '..row.id; row.command_source='slist'
  elseif row.kind=='skill' and row.command_source=='help' then
    if row.command_name~=row.name or row.command_id~=row.id then row.command=nil end
  end
  return row
end
function Abilities.new(api,config,cache,incoming,tags,store,queries,Capture,Model,spellup)
  local function diagnosticEcho(message)
    if incoming and incoming.defer then incoming.defer(function() api.echo(message) end)
    else api.echo(message) end
  end

  local self={enabled=false,last='Disabled'}
  local options={automatic_refresh=true,corrections={}}
  local handlers,request,wire,pumpTimer,notifyTimer={},nil,nil,nil,nil
  local staged,queue,index,pending,fresh,identity,stamp,session=nil,nil,nil,false,false,nil,nil,0
  local count,updated=0,nil
  local ownSend=false
  local forceSyntax,pendingForce,nextForce=false,false,false
  local sequence=0
  local dirty=false
  local coreCommitted=false
  local priority=40
  local observedStamp,currentLevel,baseLevel,statusLevel
  local drive,fail
  local function connected() return cache.enabled and select(3,api.getConnectionInfo()) end
  local function ready()
    if cache.checkReadiness then return self.enabled and cache.checkReadiness("spellup") and not (spellup and spellup.status().inflight) end
    return self.enabled and connected() and cache.get('char.status.state')==3 and cache.get('char.status.pos')=='Standing'
      and not (spellup and spellup.status().inflight)
  end
  local function characterData()
    local b=copy(cache.get('char.base') or {})
    local base=validLevel(cache.get('char.base.level')) or validLevel(b.level)
    local status=validLevel(cache.get('char.status.level'))
    -- Each producer can lag behind the other. An unchanged old level must not
    -- undo a newer observation from the other GMCP packet.
    if base and base~=baseLevel then baseLevel=base; currentLevel=base end
    if status and status~=statusLevel then statusLevel=status; currentLevel=status end
    b.level=currentLevel
    return b
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
    if pumpTimer then api.killTimer(pumpTimer); pumpTimer=nil end
    if request and request.query.kind=='learned' and tags then tags.abortCapture('spellheaders','Ability collection stopped') end
    local old=wire; wire=nil
    request=nil; staged=nil; queue=nil; index=nil
    if old then old.detach('Ability collection stopped') else queries.release(OWNER) end
  end
  fail=function(reason,boundary)
    if wire and request and not boundary then
      request.discard=reason; wire.cancel(reason); pending=false; fresh=false
      self.last='Draining interrupted ability response: '..reason; notify(); return
    end
    local enrichment=coreCommitted and not dirty
    cancel(); pending=false; fresh=enrichment; self.last=(enrichment and 'Catalog ready; command verification incomplete: ' or 'Stale: ')..reason..'. Refresh to retry.'
    diagnosticEcho('Aardwolf abilities: '..self.last..'\n'); notify()
  end
  local function rows(corrections)
    local result={}
    for _,r in ipairs(store.rows('abilities')) do
      result[#result+1]=Model.correct(withCommand(r),corrections or options.corrections,store.character())
    end
    return result
  end
  function self.get(id)
    id=tonumber(id); if not id or id%1~=0 or id<1 or id>2147483647 then return nil end
    local r=store.get('abilities',id)
    return r and Model.correct(withCommand(r),options.corrections,store.character()) or nil
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
    local level=characterData().level or meta.level
    local candidates
    if button.ability_mode=='specific' then
      local r=store.get('abilities',tonumber(button.ability_id) or 0)
      candidates=r and {Model.correct(withCommand(r),corrections or options.corrections,store.character())} or {}
    else candidates=rows(corrections) end
    return Model.resolve(candidates,button,level)
  end
  function self.resolve(button)
    if not self.enabled then return nil,'Ability catalog disabled' end
    if not connected() then return nil,'Disconnected; waiting for fresh character data' end
    local b=characterData()
    if type(b.name)~='string' or b.name:lower()~=store.character() or not b.level then
      return nil,'Waiting for fresh character identity and level'
    end
    -- Staleness is advisory. Keep the last committed same-character catalog
    -- usable while collecting its replacement, without relaxing eligibility.
    return self.preview(button)
  end
  function self.status()
    return {enabled=self.enabled,fresh=fresh and not dirty and connected() and stamp==fingerprint(characterData()) or false,busy=queue~=nil,pending=pending,
      character=store.character(),count=count,updated=updated,last=self.last,session=session}
  end
  function self.refresh(recheckSyntax)
    if not self.enabled then return false,'Ability catalog disabled' end
    if queue then
      if wire and recheckSyntax~=false then wire.setPriority(10) end
      if recheckSyntax~=false then dirty=true; nextForce=true end
      return true,'Ability refresh already in progress'
    end
    priority=recheckSyntax==false and 40 or 10
    pendingForce=pendingForce or recheckSyntax~=false
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
  local function persistCatalog()
    local n=0
    for _,r in pairs(staged) do
      if #r.memberships==0 then membership(r,'unknown','unknown') end
      staged[r.id]=withCommand(r)
      if r.learned and r.available then n=n+1 end
    end
    local at=api.getEpoch()
    store.replace({abilities=staged,ability_metadata={[0]={name=identity,level=characterData().level,updated=at,count=n,fingerprint=stamp}}})
    count=n; updated=at; fresh=true; coreCommitted=true; notify()
  end
  local function complete(q,capture)
    if q.kind=='learned' then staged=capture.rows
    elseif q.kind=='syntax' then
      local r=staged[q.id]
      r.command=capture.command; r.command_source='help'; r.command_name=r.name; r.command_id=r.id
      r.command_version=Capture.syntaxVersion; r.command_checked=api.getEpoch()
      r.command_syntax=copy(capture.syntax); r.command_reason=capture.reason
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
    if index>#queue and q.kind~='syntax' then
      local ids={}
      for id,r in pairs(staged) do
        if r.kind=='skill' and r.learned and r.available and not r.passive then ids[#ids+1]=id end
      end
      table.sort(ids)
      for _,id in ipairs(ids) do
        local r=staged[id]; local saved=store.get('abilities',id)
        if saved and saved.kind==r.kind and saved.name==r.name
            and saved.command_source=='help' and saved.command_id==id and saved.command_name==r.name
            and saved.command_version==Capture.syntaxVersion then
          for _,key in ipairs({'command','command_source','command_name','command_id','command_version',
              'command_checked','command_syntax','command_reason'}) do r[key]=copy(saved[key]) end
        end
        if forceSyntax or r.command_version~=Capture.syntaxVersion then
          if Model.single(r.name,256) and r.name:match('%S') then
            queue[#queue+1]={kind='syntax',id=id,name=r.name,command='help '..r.name}
          else r.command_reason='Ability name cannot be used in a help query' end
        end
      end
      persistCatalog()
    elseif q.kind=='syntax' then
      -- Commit each verified command independently of the remaining help queries.
      store.put('abilities',q.id,withCommand(staged[q.id])); notify()
    end
    if index>#queue then
      if not coreCommitted then persistCatalog() end
      cancel(); fresh=true; self.last='Ready · '..count..' available learned abilities'; notify()
      if dirty then
        local recheck=nextForce; dirty=false; nextForce=false; self.refresh(recheck)
      end
    else queries.release(OWNER); schedule() end
  end
  drive=function()
    if not pending and not queue or request or wire then return end
    if not queries.accepting(OWNER) then return end
    if not ready() then self.last='Refresh paused; waiting for standing, command-ready character'; return end
    local b=characterData()
    if type(b.name)~='string' or not b.level then return end
    if not queue then
      store.select(b.name); identity=b.name:lower(); stamp=fingerprint(b); observedStamp=stamp; staged={}; pending=false; fresh=false
      forceSyntax=pendingForce; pendingForce=false; coreCommitted=false
      queue={{kind='learned',command='slist learned noprompt'}}; index=1
      for _,filter in ipairs({'','combat','resist','healing','str','dex','con','int','wis','luck','passive','area','spellup'}) do
        for _,kind in ipairs({'spell','skill'}) do
          queue[#queue+1]={kind=kind,filter=filter,command=kind..'s'..(filter~='' and ' '..filter or '')}
        end
      end
    end
    local q=queue[index]
    if q.kind=='syntax' then
      sequence=sequence+1
      q.marker='AWTB_ABILITY_'..tostring(self):gsub('[^%w]','')..'_'..session..'_'..sequence
    end
    local current=session
    local expected=stamp
    self.last='Queued: '..q.command
    wire=queries.request(OWNER,{priority=priority,timeout=10,ready=ready,
      current=function() return self.enabled and current==session and expected==fingerprint(characterData()) end,
      boundary=function(line)
        local text=line:match('^%s*(.-)%s*$')
        if q.kind=='syntax' then return text==q.marker end
        if q.kind=='learned' then return text=='{/spellheaders}','AardwolfToolbox.tags' end
        return text=="To see all skills/spells for your class, use 'allspells <class>'"
          or text=='No spells found.' or text=='No skills found.'
      end,
      start=function(handle)
        request={query=q,capture=Capture.new(q)}
        self.last='Collecting '..q.command..' ('..index..'/'..#queue..')'; notify()
        ownSend=true
        local function send(command)
          if cache.sendChecked then return cache.sendChecked('command',command) end
          local ok,result,err=pcall(api.send,command,false)
          return ok and result~=false and not (result==nil and err),tostring(err or result)
        end
        local ok,result,reason=pcall(function()
          local good,message=send(q.command)
          if good and q.marker then good,message=send('echo '..q.marker) end
          return good,message
        end)
        ownSend=false
        if not ok then return false,tostring(result) end
        return result,reason
      end,
      finish=function(ok,reason,handle)
        if wire~=handle then return end
        wire=nil
        if current~=session or not self.enabled then return end
        if not ok then
          reason=request and request.discard or reason
          request=nil
          if expected~=fingerprint(characterData()) then
            cancel(); coreCommitted=false; dirty=false; fresh=false
            pending=options.automatic_refresh; pendingForce=pendingForce or nextForce; nextForce=false
            self.last='Character progression changed; fresh catalog queued'; notify(); schedule()
          else
            if reason=='Query deadline exceeded' then reason='Response timed out for '..q.command end
            fail(reason or 'Request failed',true)
          end
        end
      end,
    })
  end

  local function captureLine(line)
    if request then
      local current=request
      if current.query.kind~='learned' and current.query.kind~='syntax' and tags and tags.isCapturing and tags.isCapturing() then return false end
      local ok,claimed,done=pcall(current.capture.receive,line)
      if not ok then fail(tostring(claimed)); return false end
      if done then
        request=nil
        local handle=wire
        if current.discard or not handle or not handle.current() then
          if handle then handle.finish(false,current.discard or 'Obsolete response') end
        else
          handle.finish(true)
          local good,err=pcall(complete,current.query,current.capture); if not good then fail(tostring(err),true) end
        end
      end
      if claimed then return true,true,current.query.kind=='learned' and 'AardwolfToolbox.tags' or nil end
      return false
    end
    return false
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
      if name then if queue then dirty=true; fresh=false else self.refresh(false) end end
      if line:match('^You have forgotten ') or line:match('^You can now use the following skills and spells') then if queue then dirty=true; fresh=false else self.refresh(false) end end
    end
    if request and request.query.kind~='syntax' then return captureLine(line) end
    return false
  end
  local function reset()
    session=session+1; cancel(); priority=40; coreCommitted=false; dirty=false; fresh=false; identity=nil; stamp=nil; pending=options.automatic_refresh
    observedStamp=nil; currentLevel=nil; baseLevel=nil; statusLevel=nil
    forceSyntax=false; pendingForce=false; nextForce=false
    self.last='Saved catalog available offline; waiting for fresh character data'; notify('reset')
  end
  function self.stop()
    self.enabled=false; reset(); pending=false
    if notifyTimer then api.killTimer(notifyTimer); notifyTimer=nil end
    incoming.remove(OWNER); incoming.remove(OWNER..'.syntax')
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
      incoming.add(OWNER,18,receive,function(message) self.stop(); self.last='Stopped: '..tostring(message); diagnosticEcho('Aardwolf abilities: '..self.last..'\n') end,nil,true)
      incoming.add(OWNER..'.syntax',14,function(line)
        if self.enabled and connected() and request and request.query.kind=='syntax' then return captureLine(line) end
        return false
      end,function(message) self.stop(); self.last='Stopped: '..tostring(message); diagnosticEcho('Aardwolf abilities: '..self.last..'\n') end,nil,true)
      local function on(event,fn)
        handlers[#handlers+1]=event; assert(api.registerNamedEventHandler(OWNER,event,event,fn),'Cannot register ability handler')
      end
      on('sysDataSendRequest',function(_,command)
        -- Other coordinated consumers may query between our complete responses.
        -- Only an uncoordinated query (or one during our active response) can
        -- contaminate this collection. Yielding must not discard staged rows.
        local owner=queries.owner()
        local yielded=not request and owner and owner~=OWNER
        if queue and not ownSend and not yielded and type(command)=='string' and
            (request and request.query.kind=='syntax' and command:match('^help%s') or command:match('^slist[%s$]') or command=='slist' or command:match('^spells?%s') or command=='spells' or command:match('^skills?%s') or command=='skills') then
          fail('Another spell/skill query interrupted collection')
        end
      end)
      on('AardwolfToolbox.queries.available',schedule)
      on('AardwolfToolbox.spellup.updated',schedule)
      on('AardwolfToolbox.gmcp.cleared',reset)
      on('sysDisconnectionEvent',reset)
      on('AardwolfToolbox.gmcp.updated',function(_,path)
        if path=='char' or path=='char.base' or path=='char.status'
            or (type(path)=='string' and (path:match('^char%.base%.') or path=='char.status.level')) then
          local raw=cache.get('char.base') or {}
          if type(raw.name)=='string' and raw.name~='' then
            if store.character()~=raw.name:lower() then
              reset(); store.select(raw.name)
              local meta=store.get('ability_metadata',0) or {}; count=meta.count or 0; updated=meta.updated
            end
            local b=characterData(); local nextStamp=fingerprint(b)
            if observedStamp and observedStamp~=nextStamp then
              fresh=false
              if queue then
                -- Drain only the active response. Unsent work from the previous
                -- progression is cancelled by the broker's current-state check.
                dirty=dirty or options.automatic_refresh
                self.last='Character progression changed; catalog refresh pending'; notify()
              elseif options.automatic_refresh then self.refresh(false)
              else self.last='Stale: character progression changed; automatic refresh disabled'; notify() end
            end
            observedStamp=nextStamp
          end
        end
        if path=='char.status' then
          local state=cache.get('char.status.state')
          if request and (state==5 or state==6 or state==7) then fail('Game pager/editor interrupted collection') end
        end
        queries.poke(); schedule()
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
    if changed and options.automatic_refresh then self.refresh(false) end
    notify(); return true
  end
  return self
end
return Abilities
