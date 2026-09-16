-- Session-only room activity with bounded, readiness-gated informational refreshes.
local Mobs={}
local OWNER='AardwolfToolbox.mobs'
function Mobs.definition(apply,Actions)
  local definition={id='mobs',label='Room mobs',description='Always-visible room list. Current-room and nearby refreshes are independent. Every mob has its own row. Configure double-click and right-click actions using {target}; unseen mobs are not presumed dead. Attacker markers mean recently observed incoming attacks.',settings={
    {key='enabled',label='Enable room mob pane',type='boolean',default=true},
    {key='automatic_setup',label='Automatically enable scan tags',type='boolean',default=true},
    {key='nearby',label='Include nearby scan results',type='boolean',default=true},
    {key='nearby_mode',label='Nearby refresh',type='choice',default='manual',options={{value='manual',label='On demand'},{value='entry',label='After room entry'}}},
    {key='automatic_consider',label='Rate room once per visit',type='boolean',default=true,description='First use Rate room to verify the server completion marker this session. Automatic ratings never delay attacks.'},
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
    {key='consider',label='Show observed consider ratings',type='boolean',default=true,
      description='Relative level ranges from consider output. Threat colors follow Use status colors; automatic rating requests are controlled separately.'},
    {key='quest_hints',label='Show quest target candidates',type='boolean',default=true,
      description='Exact name matches to the observed active quest get a Quest? label. These are candidates, not verified identities; no queries or actions are sent.'},
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
    return Actions.validate(values)
  end,apply=apply}
  for _,setting in ipairs(Actions.settings()) do definition.settings[#definition.settings+1]=setting end
  return definition
end
function Mobs.new(api,cache,incoming,tags,queries,spellup,State,Protocol,Pane,ui,borders,settings,consider,Actions,config,questSource,objectiveSource)
  local self={enabled=false,last='Disabled'}
  local options,handlers={},{}
  local configuration=0; local actions; local view
  local model=State.new(api.getEpoch)
  local nearby={fresh=false,sections={}}
  local ratings={fresh=false,verified=false,last='Use Rate room to verify completion this session'}
  local diagnostics={requests=0,renders=0,stale=0,lines=0,bytes=0}
  local pending={}; local active,frame,wire,queuedKind
  local wake,timeout,paintTimer,evidenceTimer,periodicTimer
  local session,visit,sequence=0,0,0
  local setup,ownSend,autoRated=false,false,false
  local setupConfirmed=false
  local lastSpellupBlocking
  local lastRequest=-math.huge; local settle=0; local status={}
  local encounter
  local schedule,drive,update,armEvidence,armPeriodic,fail,recordDefeat
  local function copy(v)
    if type(v)~='table' then return v end
    local t={};for k,x in pairs(v) do t[k]=copy(x) end;return t
  end
  local function connected() return cache.enabled and select(3,api.getConnectionInfo())==true end
  local function sharedExperience()
    local group=cache.get('group')
    return type(group)=='table' and ((tonumber(group.count) or 0)>1 or type(group.members)=='table' and #group.members>1)
  end
  local function spellupBlocking()
    local batch=spellup and spellup.status()
    -- Unconfirmed completion still blocks another casting batch, but must not
    -- indefinitely block informational scans after its completion timeout.
    return batch and batch.inflight==true and not batch.uncertain or false
  end
  local function ready(kind)
    if not self.enabled then return false,'Room mobs disabled' end
    if spellupBlocking() then return false,'Spellup in progress' end
    local policy=kind=='rate' and 'spellup' or 'information'
    if cache.checkReadiness then return cache.checkReadiness(policy) end
    if not connected() or cache.get('char.status.state')~=3 then return false,'Waiting for command-ready character' end
    if policy=='spellup' and cache.get('char.status.pos')~='Standing' then return false,'Not standing' end
    return true
  end
  view=Pane.new(api,ui,borders,function() self.refresh() end,settings,
    function(id,revision) return self.doubleClick(id,revision) end,function() self.clearSelection() end,
    function() self.refreshNearby() end,function() self.rateRoom() end,{
      capture=function(id,revision) return actions.capture(id,revision) end,
      doubleClick=function(token) return actions.doubleClick(token) end,
      resolve=function(token) return actions.resolve(token) end,
      menu=function(token) return actions.menu(token) end,
      activate=function(id,token) return actions.activate(id,token) end,
      describe=function() return actions.describe() end,
      visibility=function(open) self.menuOpen=open;api.raiseEvent(OWNER..'.menu',open) end,
      feedback=function(message) self.last=message;update(true) end,
    })
  local function kill(id) if id then api.killTimer(id) end end
  local function release(ok,reason,detach)
    local old=wire;wire=nil;queuedKind=nil
    if old and detach then old.detach(reason)
    else
      if old then old.finish(ok~=false,reason) end
      queries.release(OWNER)
    end
  end
  local questHint,questKey
  local objectiveHints,objectiveKey={},""
  local function clean(value)
    if type(value)~='string' or #value>512 or value:find('[%z\1-\31\127]') then return nil end
    value=value:gsub('^%s+',''):gsub('%s+$',''):gsub('%s+',' ')
    if value~='' then return value end
  end
  local function readQuest()
    local q=questSource and questSource()
    local target=type(q)=='table' and q.state=='Active' and q.targetKnown~=false and clean(q.target)
    local hint=target and {source='quest',candidate=true,target=target,room=clean(q.room),area=clean(q.area)} or nil
    local key=hint and table.concat({hint.target,hint.room or '',hint.area or ''},'\0') or ''
    local changed=key~=questKey;questKey=key;questHint=hint
    return changed
  end
  local function readObjectives()
    local hints=objectiveSource and objectiveSource() or {}
    local kept,keys={},{}
    for _,h in ipairs(hints) do
      if (h.source=='campaign' or h.source=='globalQuest') and clean(h.target) then
        kept[#kept+1]={source=h.source,target=clean(h.target),room=clean(h.room),area=clean(h.area),candidate=true}
        keys[#keys+1]=table.concat({h.source,h.target,h.room or '',h.area or ''},'\0')
      end
    end
    local key=table.concat(keys,'|');local changed=key~=objectiveKey
    objectiveHints=kept;objectiveKey=key;return changed
  end
  function self.snapshot()
    local result=model.snapshot(options.attack_window or 12)
    result.nearby=copy(nearby); result.ratings=copy(ratings)
    if options.quest_hints and result.fresh and questHint then
      local matches={};local wanted=questHint.target:lower()
      for _,r in ipairs(result.rows) do
        local name=clean(r.name)
        if r.alive>0 and r.killed==0 and r.missing==0 and not r.unclassified and name and name:lower()==wanted then matches[#matches+1]=r end
      end
      for _,r in ipairs(matches) do r.objective=copy(questHint);r.objective.matches=#matches end
    end
    if result.fresh then
      local room=cache.get('room.info') or {}
      for _,hint in ipairs(objectiveHints) do
        local matches={}
        if (not hint.room or not room.name or hint.room:lower()==room.name:lower())
            and (not hint.area or not room.zone or hint.area:lower()==room.zone:lower()) then
          for _,r in ipairs(result.rows) do
            if r.alive>0 and r.killed==0 and r.missing==0 and not r.unclassified and clean(r.name) and clean(r.name):lower()==hint.target:lower() then matches[#matches+1]=r end
          end
        end
        for _,r in ipairs(matches) do
          r.objectives=r.objectives or {};local h=copy(hint);h.matches=#matches;r.objectives[#r.objectives+1]=h
        end
      end
    end
    for _,r in ipairs(result.rows) do
      if r.objective then r.objectives=r.objectives or {};table.insert(r.objectives,1,copy(r.objective)) end
    end
    return result
  end
  function self.status()
    local result=copy(diagnostics);result.enabled=self.enabled;result.last=self.last
    result.ratingStatus=ratings.last;result.markerVerified=ratings.verified
    result.scanMonitoring=setupConfirmed and 'confirmed' or setup and 'requested' or 'unavailable';return result
  end
  local lastRows={}
  local function flush()
    kill(paintTimer); paintTimer=nil
    if not self.enabled then return end
    local snapshot=self.snapshot(); local changed={}; local nextRows={}
    -- Row versions are presentation signatures; roster revision is independent.
    for _,r in ipairs(snapshot.rows) do
      local key=table.concat({r.name,r.flags,tostring(r.ordinal),tostring(r.selected),tostring(r.target),
        tostring(r.health),tostring(r.requested),tostring(r.attacking),r.alive,r.killed,r.missing,
        r.consider and r.consider.id or '',r.objective and questKey or '',r.objective and r.objective.matches or '',r.objectives and objectiveKey or ''},'|')
      nextRows[r.id]=key
      if lastRows[r.id]~=key then changed[#changed+1]=r.id end
    end
    for id in pairs(lastRows) do if not nextRows[id] then changed[#changed+1]=id end end
    lastRows=nextRows; diagnostics.renders=diagnostics.renders+1
    view.update(snapshot,diagnostics.queued or self.last)
    api.raiseEvent(OWNER..'.updated',changed)
    armEvidence(snapshot)
  end
  update=function(immediate)
    if view.validateMenu then view.validateMenu() end
    if immediate then flush(); return end
    if not paintTimer and self.enabled then paintTimer=api.tempTimer(0.05,flush) end
  end
  local function queued(reason)
    if diagnostics.queued==reason then return end
    diagnostics.queued=reason;update()
  end
  armEvidence=function(snapshot)
    kill(evidenceTimer); evidenceTimer=nil
    local at=model.expiry(options.attack_window or 12)
    local blink=false
    if options.blink and options.attackers then
      for _,r in ipairs(snapshot.rows) do if r.attacking then blink=true; break end end
    end
    if blink then at=math.min(at or math.huge,api.getEpoch()+1) end
    if at then evidenceTimer=api.tempTimer(math.max(0.01,at-api.getEpoch()),function()
      evidenceTimer=nil
      if self.enabled then
        if blink then view.update(self.snapshot(),diagnostics.queued or self.last,true) end
        update()
      end
    end) end
  end
  local function finish(ok,reason)
    kill(timeout); timeout=nil
    diagnostics.queued=nil
    if active then diagnostics.duration=api.getEpoch()-active.started end
    active=nil; frame=nil; release(ok,reason); schedule(); armPeriodic()
  end
  fail=function(reason,boundary)
    if wire and active and not boundary then
      active.error=reason;active.discard=true;wire.cancel(reason)
      self.last=reason..'; draining response';update();return
    end
    local kind=active and active.kind or 'room'
    if kind=='nearby' then nearby.fresh=false
    elseif kind=='rate' then ratings.fresh=false; ratings.last=reason
    else diagnostics.rosterError=reason end
    self.last=reason..'; Refresh to retry'; pending[kind]=nil
    if frame and tags.abortCapture then tags.abortCapture('scan',reason) end
    finish(false,reason); update()
  end
  local function queue(kind,manual)
    if not self.enabled or not model.room or manual and not connected() then return false,'Room data unavailable' end
    if manual then local ok,reason=ready(kind);if not ok then return false,reason end end
    if kind=='rate' and not model.fresh then return false,'Acquire the current-room list first' end
    if kind=='nearby' and not options.nearby then return false,'Nearby is disabled' end
    if active and active.kind==kind and active.visit==visit then return true,'Already in progress' end
    pending[kind]={kind=kind,priority=manual and 10 or kind=='room' and 20 or kind=='rate' and 30 or 40,manual=manual}
    if wire and not active then
      -- A manual click promotes already queued work without duplicating its send.
      if manual and queuedKind==kind then wire.setPriority(10)
      elseif manual then release(false,'Manual request reprioritized queued work') end
    end
    self.last=manual and 'Refresh queued' or self.last
    schedule(); update(); return true
  end
  function self.refresh() return queue('room',true) end
  function self.refreshNearby() return queue('nearby',true) end
  function self.rateRoom() return queue('rate',true) end
  local function autoRate()
    if options.automatic_consider and ratings.verified and not autoRated and model.fresh then queue('rate',false) end
  end
  armPeriodic=function()
    kill(periodicTimer); periodicTimer=nil
    if self.enabled and options.interval>0 and model.room and not diagnostics.rosterError then
      periodicTimer=api.tempTimer(options.interval,function() periodicTimer=nil; queue('room',false) end)
    end
  end
  local function send(command)
    ownSend=true
    local ok,result,err
    if cache.sendChecked then ok,result,err=pcall(cache.sendChecked,'command',command)
    else ok,result,err=pcall(api.send,command,false) end
    ownSend=false
    return ok and result~=false and not (result==nil and err)
  end
  drive=function()
    wake=nil
    if active or frame or wire then return end
    if not queries.accepting(OWNER) then queued('Draining the previous collector response');return end
    local request
    for _,candidate in pairs(pending) do
      if not request or candidate.priority<request.priority then request=candidate end
    end
    if not request then queued(nil);release(); return end
    local eligible,reason=ready(request.kind)
    if not model.room or not eligible then
      queued(reason or 'Waiting for room identity')
      release();return
    end
    local delay=math.max(settle,lastRequest+1)-api.getEpoch()
    if delay>0 then queued('Waiting for room settle/cooldown');wake=api.tempTimer(delay,drive);return end
    local requestedVisit,requestedSession=visit,session
    queuedKind=request.kind
    queued('Waiting for informational response')
    wire=queries.request(OWNER,{priority=request.priority,timeout=10,timeoutFromStart=true,
      ready=function() return ready(request.kind) and not frame end,
      current=function() return self.enabled and requestedVisit==visit and requestedSession==session end,
      boundary=function(line)
        if request.kind=='rate' then return line==request.marker end
        return line:match('^%s*(.-)%s*$')=='{/scan}','AardwolfToolbox.tags'
      end,
      start=function()
        if request.kind~='rate' and options.automatic_setup and not setup then
          if not send('tags scan on') then return false,'Could not enable scan tags' end
          setup=true
        end
        sequence=sequence+1; pending[request.kind]=nil
        request.visit=visit; request.started=api.getEpoch(); request.revision=model.revision
        request.level=cache.get('char.status.level') or cache.get('char.base.level')
        request.session=session; request.bytes=0; request.lines=0
        active=request; lastRequest=api.getEpoch(); diagnostics.requests=diagnostics.requests+1; diagnostics.queued=nil
        if request.kind=='rate' then
          autoRated=true; request.entries={}
          request.marker='AWTB_CON_'..tostring(self):gsub('[^%w]','')..'_'..session..'_'..visit..'_'..sequence
          self.last='Rating room'
          if not send('consider all') or not send('echo '..request.marker) then return false,'Consider request failed' end
        else
          self.last=request.kind=='nearby' and 'Refreshing nearby rooms' or 'Refreshing room mobs'
          if not send(request.kind=='nearby' and 'scan' or 'scan here') then return false,'Room scan request failed' end
        end
        update();return true
      end,
      finish=function(ok,reason,handle)
        if wire~=handle then return end
        wire=nil;queuedKind=nil
        if requestedSession~=session or not self.enabled then return end
        if not ok then
          if requestedVisit~=visit then active=nil;frame=nil;schedule()
          else
            if reason=='Query deadline exceeded' then reason='Room '..request.kind..' response timed out' end
            fail(reason or 'Room request failed',true)
          end
        end
      end,
    })
  end

  schedule=function(event)
    -- Broker availability is already a wakeup, not a reason to emit another.
    -- Spellup emits status repeatedly; only its readiness transition matters.
    if event=='AardwolfToolbox.spellup.updated' then
      local blocking=spellupBlocking()
      if blocking==lastSpellupBlocking then return end
      lastSpellupBlocking=blocking
    end
    if event~='AardwolfToolbox.queries.available' then queries.poke() end
    kill(wake); wake=nil
    if self.enabled and next(pending) and not active and not frame then wake=api.tempTimer(0,drive) end
  end
  local function cancelAll()
    encounter=nil
    diagnostics.queued=nil;lastSpellupBlocking=nil
    if frame and tags.abortCapture then tags.abortCapture('scan','Room tracking stopped') end
    kill(wake);kill(timeout);kill(paintTimer);kill(evidenceTimer);kill(periodicTimer)
    wake,timeout,paintTimer,evidenceTimer,periodicTimer=nil,nil,nil,nil,nil
    active=nil;frame=nil;pending={};release(false,"Room tracking stopped",true)
  end
  local function reset()
    if view.closeMenu then view.closeMenu() end
    session=session+1;visit=visit+1;cancelAll();setup=false;setupConfirmed=false;autoRated=false;status={}
    encounter=nil
    model.clear(nil);nearby={fresh=false,sections={}};lastRows={}
    ratings={fresh=false,verified=false,last='Use Rate room to verify completion this session'}
    self.last='Waiting for fresh room data';update()
  end
  function self.select(id,revision)
    local state=cache.get('char.status.state')
    if not self.enabled or not connected() or state~=3 and state~=8 then return false,'Selection requires command readiness' end
    local ok,reason=model.select(id,revision)
    if not ok then self.last=reason end
    update(true); return ok,reason
  end
  function self.selected()
    if not self.enabled or not connected() or not model.fresh then return end
    for _,r in ipairs(model.snapshot(options.attack_window).rows) do if r.selected then return r end end
  end
  local function actionReady()
    local state=cache.get('char.status.state')
    if not self.enabled or not connected() then return false,'Room mobs are disabled or disconnected.' end
    if state~=3 and state~=8 then return false,'Waiting for fresh command readiness; close any pager/editor.' end
    return true
  end
  actions=Actions.new(api,{
    options=function() return options end,
    context=function() return {session=session,visit=visit,revision=model.revision,configuration=config and config.revision or configuration} end,
    row=function(id)
      if self.enabled and connected() and model.fresh then
        for _,row in ipairs(model.rows) do if row.id==id then return row end end
      end
    end,
    ready=actionReady,select=self.select,
    observed=function(command) model.command(command) end,
    feedback=function(ok,message) self.last=message;update(true) end,
  })
  function self.activateAction(actionId,id,revision)
    local token,reason=actions.capture(id,revision)
    if not token then self.last=reason;update(true);return false,reason end
    return actions.activate(actionId,token)
  end
  function self.doubleClick(id,revision)
    local token,reason=actions.capture(id,revision)
    if not token then return false,reason end
    return actions.doubleClick(token)
  end
  function self.attack(id,revision)
    local ok,reason=self.select(id,revision);if not ok then return false,reason end
    local token=actions.capture(id,revision);local row,target=actions.resolve(token)
    if not row then return false,target end
    return actions.dispatch('kill '..target,'command',token)
  end
  function self.clearSelection() model.selected=nil;update(true);return true end
  local function current(request)
    return request.visit==visit and request.session==session and not request.discard
  end
  local function receive(text,context)
    if not self.enabled or not connected() or type(text)~='string' then return false end
    if not frame and tags.isCapturing and tags.isCapturing() then return false end
    if active then
      diagnostics.lines=diagnostics.lines+1;diagnostics.bytes=diagnostics.bytes+#text
      if active.error then
        if text==active.marker or frame and text:match('^%s*{/scan}%s*$') then
          local reason=active.error;fail(reason,true);return true,true,'AardwolfToolbox.tags'
        end
        return false
      end
      if active.kind=='rate' then
        active.lines=active.lines+1;active.bytes=active.bytes+#text
        if active.lines>1024 or active.bytes>262144 then fail('Consider response too large');return false end
      end
    end
    if active and active.kind=='rate' and text==active.marker then
      local request=active
      ratings.verified=true
      if current(request) and request.revision==model.revision and request.level==(cache.get('char.status.level') or cache.get('char.base.level')) then
        model.command('consider all');for _,rating in ipairs(request.entries) do model.consider(rating) end
        ratings.fresh=true;ratings.last='Ratings updated';self.last='Visible mobs · current visit'
      else diagnostics.stale=diagnostics.stale+1;ratings.fresh=false;ratings.last='Room changed; Rate room to retry' end
      finish();update();return true,true
    end
    if text:match('^%s*{scan}%s*$') then
      if frame then fail('Interrupted room scan');return false end
      if active and active.kind=='rate' then active.discard=true;return false end
      local request=active
      if not request then
        request={kind='nearby',visit=visit,session=session,started=api.getEpoch(),passive=true}
        active=request;timeout=api.tempTimer(10,function() timeout=nil;fail('Player scan timed out') end)
      end
      frame={capture=Protocol.scan(),request=request,events={}}
      return true,not request.passive,'AardwolfToolbox.tags'
    end
    if frame then
      local request=frame.request
      if text:match('^%s*{/scan}%s*$') then
        local saved=frame;local hidden=not request.passive
        if not saved.capture.valid or request.kind=='room' and not saved.capture.seen then
          fail('No recognized scan section',true);return true,hidden,'AardwolfToolbox.tags'
        end
        setupConfirmed=true
        if current(request) then
          if saved.capture.seen then
            model.observe(saved.capture.entries);diagnostics.rosterError=nil;pending.room=nil
            for _,event in ipairs(saved.events) do model[event[1]](event[2]) end
          end
          if request.kind=='nearby' then
            nearby={fresh=true,updated=api.getEpoch(),sections=copy(saved.capture.sections)};pending.nearby=nil
          end
          self.last='Visible mobs · current visit'
        else diagnostics.stale=diagnostics.stale+1 end
        finish();autoRate();update();return true,hidden,'AardwolfToolbox.tags'
      end
      local ok,claimed=pcall(frame.capture.line,text)
      if not ok then fail(tostring(claimed));return false end
      if claimed then return true,not request.passive,'AardwolfToolbox.tags' end
    end
    if tags.isCapturing and tags.isCapturing() and not frame then return false end
    if not frame and Protocol.killReward(text) then recordDefeat() end
    local rating=(consider.parseLine or consider.parse)(text,context)
    if rating then
      if active and active.kind=='rate' then
        if #active.entries>=512 then fail('Too many consider ratings');return false end
        if current(active) then active.entries[#active.entries+1]=rating end
        return true,not active.passive
      end
      if model.consider(rating) then update() end
      if frame then frame.events[#frame.events+1]={'consider',rating} end
    else
      local event,name=Protocol.combat(text,model.known)
      if event=='attack' then
        local changed=model.attack(name)
        if changed then update() end
        if frame then frame.events[#frame.events+1]={event,name} end
      end
    end
    if frame and #frame.events>512 then fail('Too many interleaved room events') end
    return false
  end
  recordDefeat=function()
    local token=encounter
    if not token or token.used then return end
    token.used=true -- One normal award consumes this opponent, even when ambiguous.
    local age=api.getEpoch()-(token.ended or token.seen)
    if not model.room or not connected() or token.session~=session or token.visit~=visit
        or token.revision~=model.revision or age<0 or age>(token.ended and 3 or 10) then return end
    if token.ambiguous then
      self.last='Kill not attributed: opponent changed before experience arrived';update();return
    end
    if token.grouped or sharedExperience() then
      self.last='Kill not attributed: shared group experience';update();return
    end
    local changed,row=model.kill(token.name,token.id)
    if not changed then return end
    update()
    local room=cache.get('room.info') or {}
    local observed={session=session,visit=visit,rowId=row.id,name=row.name,flags=row.flags,
      uncertain=row.uncertainDeath==true,room={num=tonumber(model.room)},source='room-mobs',evidence='gmcp-opponent-xp'}
    if tostring(room.num)==model.room then observed.room.name=room.name;observed.room.area=room.zone end
    local ownedSession,ownedVisit=session,visit
    local function notify()
      if self.enabled and connected() and session==ownedSession and visit==ownedVisit then
        api.raiseEvent(OWNER..'.death',observed)
      end
    end
    if incoming.defer then incoming.defer(notify) else notify() end
  end
  local function gmcp(_,path)
    if path=='room.info' then
      local room=cache.get(path)
      local key=type(room)=='table' and type(room.num)=='number' and room.num>0 and room.num<2147483648 and room.num%1==0 and tostring(room.num) or nil
      if key==model.room and key~=nil then return end
      encounter=nil
      if view.closeMenu then view.closeMenu() end
      visit=visit+1;pending={};diagnostics.queued=nil;kill(wake);wake=nil
      -- A sent response still owns its boundary. Drain it before acquiring again.
      if active then active.discard=true;queries.poke() else release(false,'Room or configuration changed') end
      model.clear(key);status={};nearby={fresh=false,sections={}};autoRated=false
      ratings.fresh=false;diagnostics.rosterError=nil;settle=api.getEpoch()+0.25
      model.level(cache.get('char.status.level') or cache.get('char.base.level'))
      self.last=key and 'Waiting for room scan' or 'Room identity unavailable'
      if key and options.on_entry then queue('room',false) end
      if key and options.nearby and options.nearby_mode=='entry' then queue('nearby',false) end
      armPeriodic();update()
    elseif path=='char.base' or path=='char.status' then
      local level=cache.get(path..'.level');local levelChanged=model.level(level)
      if levelChanged then ratings.fresh=false;ratings.last='Player level changed; Rate room to refresh' end
      local changed=levelChanged or false
      if path=='char.status' then
        local s=cache.get(path) or {};local was=status.state==8;local oldEnemy=State.name(status.enemy)
        for _,key in ipairs({'state','enemy','enemypct','level'}) do
          if s[key]~=nil and status[key]~=s[key] then status[key]=s[key];changed=true end
        end
        local name=State.name(status.enemy)
        local key=name and name:lower()
        local oldKey=oldEnemy and oldEnemy:lower()
        if changed then model.enemy(status.enemy,status.state==8,status.enemypct) end
        if status.state==8 and key then
          local newFight=not was or key~=oldKey
          local positive=type(s.enemypct)=='number' and s.enemypct>0 and s.enemypct<=100
          if not encounter or newFight or encounter.used and positive then
            local id=model.deathCandidate(name)
            local age=encounter and api.getEpoch()-(encounter.ended or encounter.seen)
            local ambiguous=encounter and not encounter.used and newFight and age>=0 and age<=(encounter.ended and 3 or 10)
            encounter={id=id,name=name,revision=model.revision,session=session,visit=visit,
              seen=api.getEpoch(),used=id==nil,ambiguous=ambiguous,grouped=sharedExperience()}
          elseif not encounter.used and (s.enemy~=nil or s.enemypct~=nil) then
            encounter.seen=api.getEpoch()
            if model.deathCandidate(name)~=encounter.id then encounter.ambiguous=true end
          end
        elseif encounter and not encounter.ended then
          -- Status can clear before text delivery. Keep the exact row, not the
          -- next living duplicate, for a bounded late reward in this room visit.
          encounter.ended=api.getEpoch()
          if status.state~=3 then encounter=nil end
        end
        if was and status.state==3 and options.after_combat then queue('room',false) end
        if active and (s.state==5 or s.state==6 or s.state==7) then active.discard=true end
      else changed=level~=nil end
      schedule();if changed then update() end
    end
  end
  function self.stop()
    self.enabled=false;session=session+1;cancelAll()
    for _,event in ipairs(handlers) do api.deleteNamedEventHandler(OWNER,event) end;handlers={}
    incoming.remove(OWNER)
    if api.gmod then for _,m in ipairs({'Char','Room'}) do api.gmod.disableModule(OWNER,m) end end
    model.clear(nil);nearby={fresh=false,sections={}};questHint=nil;questKey=nil;objectiveHints={};objectiveKey='';view.destroy();self.last='Disabled'
  end
  self.destroy=self.stop
  function self.start()
    if self.enabled then return true end
    local ok,err=pcall(function()
      self.enabled=true;readQuest();readObjectives();view.configure(options);reset()
      incoming.add(OWNER,17,receive,function(message) self.stop();self.last='Stopped: '..tostring(message);api.echo('Aardwolf mobs: '..self.last..'\n') end,nil,true)
      local function on(event,fn) handlers[#handlers+1]=event;assert(api.registerNamedEventHandler(OWNER,event,event,fn)) end
      on('AardwolfToolbox.gmcp.updated',gmcp);on('AardwolfToolbox.gmcp.cleared',reset);on('sysDisconnectionEvent',reset)
      on('AardwolfToolbox.dashboardData.updated',function() if readQuest() and options.quest_hints then update() end end)
      for _,event in ipairs({'AardwolfToolbox.campaign.updated','AardwolfToolbox.campaign.reset','AardwolfToolbox.globalQuest.updated','AardwolfToolbox.globalQuest.reset'}) do
        on(event,function() if readObjectives() then update() end end)
      end
      on('AardwolfToolbox.queries.available',schedule);on('AardwolfToolbox.spellup.updated',schedule)
      on('AardwolfToolbox.settings.changed',function() if view.closeMenu then view.closeMenu() end end)
      on('AardwolfToolbox.settings.visibility',function(open) if view.closeMenu then view.closeMenu() end end)
      on('sysWindowResizeEvent',view.layout);on('AardwolfToolbox.ui.changed',view.layout)
      on('sysDataSendRequest',function(_,command)
        if ownSend or not connected() then return end
        local state=cache.get('char.status.state')
        if state~=3 and state~=8 then return end
        if type(command)=='string' and command:lower():match('^%s*flee%s*$') then encounter=nil end
        if type(command)=='string' and command:lower():match('^%s*recall%s*$') then encounter=nil end
        if model.command(command) then update(true) end
        if type(command)=='string' and (command:match('^%s*scan%s*$') or command:match('^%s*scan%s+')) then
          if active then active.discard=true;active.passive=true end
        elseif type(command)=='string' and (command:match('^%s*con%s') or command:match('^%s*consider%s') or command:match('^%s*con%s*$') or command:match('^%s*consider%s*$')) and active and active.kind=='rate' then
          active.discard=true;active.passive=true
        end
      end)
      api.gmod.enableModule(OWNER,'Char');api.gmod.enableModule(OWNER,'Room')
      if connected() then api.sendGMCP('request room');api.sendGMCP('request char') end
    end)
    if not ok then self.stop();self.last='Stopped: '..tostring(err);return false,self.last end
    return true
  end
  function self.configure(values)
    encounter=nil
    configuration=configuration+1
    if view.closeMenu then view.closeMenu() end
    local valid,message=Actions.validate(values)
    if not valid then self.stop();self.last=message;return false,message end
    if values.nearby~=options.nearby then nearby={fresh=false,sections={}} end
    options=copy(values)
    if not options.enabled then self.stop();return true end
    if self.enabled then
      pending={};diagnostics.queued=nil;if active then active.discard=true;queries.poke() else release(false,'Room or configuration changed') end
      view.configure(options);armPeriodic();update();return true
    end
    return self.start()
  end
  return self
end
return Mobs
