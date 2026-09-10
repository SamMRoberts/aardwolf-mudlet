-- Incoming text is data: this module never executes it or sends game commands.
local Tags = {}
local OWNER = "AardwolfToolbox.tags"
local MAX_BYTES, MAX_BLOCK_BYTES = 4 * 1024 * 1024, 1024 * 1024
local function copy(value)
  if type(value) ~= "table" then return value end
  local result = {}; for k,v in pairs(value) do result[k] = copy(v) end; return result
end
local function fields(payload)
  local result, start = {}, 1
  while true do
    local pos = payload:find("|", start, true)
    result[#result+1] = payload:sub(start, pos and pos-1 or #payload)
    if not pos then return result end
    start = pos+1
  end
end
local function parse(text)
  local closing, name, tail, payload = text:match("^%s*{(/?)([A-Za-z][A-Za-z0-9_-]*)([^}]*)}(.*)$")
  if not name or (tail ~= "" and not tail:match("^%s")) then return nil end
  if closing == "/" and (tail ~= "" or payload:find("%S")) then return nil end
  local arguments = tail:match("^%s*(.-)%s*$")
  return {name=name, arguments=arguments, payload=payload,
    kind=closing == "/" and "close" or (payload == "" and "open" or "data")}
end
-- Count retained text conservatively, including each string-valued field.
local function textBytes(value)
  if type(value) == "string" then return #value end
  local n=0
  if type(value) == "table" then for _,v in pairs(value) do n=n+textBytes(v) end end
  return n
end

function Tags.new(api, incoming)
  local self = {enabled=false, last="Disabled"}
  local options = {enabled=true,suppress=true,block_timeout=10}
  local trigger, timer, notificationTimer, generation, session, sequence = nil,nil,nil,0,0,0
  local handlers, stack, history, records, blocks = {},{},{},{},{}
  local retained, recordCount, blockCount, activeLines, activeBytes = 0,0,0,0,0
  local function nextID() sequence=sequence+1; return sequence end
  local function cancelTimer()
    if timer then api.killTimer(timer); timer=nil end
  end
  local function clear()
    cancelTimer()
    if notificationTimer then api.killTimer(notificationTimer); notificationTimer=nil end
    stack,history,records,blocks={},{},{},{}
    retained,recordCount,blockCount,activeLines,activeBytes=0,0,0,0,0
    session=session+1; generation=generation+1
  end
  local function store(kind, value)
    local size=textBytes(value)
    if size>MAX_BYTES then return false end
    local item={kind=kind,id=value.id,size=size,pending=true}
    history[#history+1]=item; retained=retained+size
    if kind=="record" then records[value.id]=value; recordCount=recordCount+1
    else blocks[value.id]=value; blockCount=blockCount+1 end
    while retained>MAX_BYTES or recordCount>500 or blockCount>100 do
      local old=table.remove(history,1); retained=retained-old.size
      if old.kind=="record" then records[old.id]=nil; recordCount=recordCount-1
      else blocks[old.id]=nil; blockCount=blockCount-1 end
    end
    return true
  end
  local function publish()
    if notificationTimer then return end
    local epoch=generation
    -- deleteLine moves the native output cursor. Notify after input processing,
    -- so consumer echoes cannot join the preceding game line or be gagged.
    notificationTimer=assert(api.tempTimer(0,function()
      notificationTimer=nil
      if generation~=epoch or not self.enabled then return end
      local pending={}
      for _,item in ipairs(history) do
        if item.pending then item.pending=nil; pending[#pending+1]=item end
      end
      for _,item in ipairs(pending) do
        if generation~=epoch or not self.enabled then return end
        local retainedValue=item.kind=="record" and records[item.id] or blocks[item.id]
        if retainedValue then
          if item.diagnostic then api.echo("Aardwolf tags: unfinished block ("..item.diagnostic.."); ordinary output is visible again.\n") end
          local ok,err=pcall(api.raiseEvent,OWNER.."."..item.kind,item.id)
          if not ok then api.echo("Aardwolf tags: consumer notification failed: "..tostring(err).."\n") end
        end
      end
    end),"Cannot schedule tag notifications")
  end
  local function finish(reason)
    cancelTimer()
    local finished={}
    for i=#stack,1,-1 do
      local block=stack[i]
      block.status="incomplete"; block.reason=reason
      finished[#finished+1]=block
    end
    stack={}; activeLines,activeBytes=0,0
    return finished
  end
  local function publishBlocks(finished, epoch)
    for index,block in ipairs(finished) do
      if generation~=epoch then return end
      if store("block",block) then
        if index==#finished and block.reason=="mismatched closing tag" then history[#history].diagnostic=block.reason end
        publish()
      end
    end
  end
  local function diagnostic(reason)
    self.last="Capture resumed after "..reason
    api.echo("Aardwolf tags: unfinished block ("..reason.."); ordinary output is visible again.\n")
  end
  function self.stop()
    self.enabled=false
    if incoming then incoming.remove(OWNER) elseif trigger then api.killTrigger(trigger); trigger=nil end
    for _,name in ipairs(handlers) do api.deleteNamedEventHandler(OWNER,name) end
    handlers={}; clear(); self.last="Disabled"
  end
  self.destroy=self.stop
  local function failed(err)
    self.stop(); self.last="Stopped: "..tostring(err)
    api.echo("Aardwolf tags: "..self.last.."; output is visible.\n")
  end
  local function armTimer()
    local epoch=generation
    timer=assert(api.tempTimer(options.block_timeout,function()
      timer=nil
      if not self.enabled or generation~=epoch then return end
      local finished=finish("timeout")
      diagnostic("timeout"); publishBlocks(finished,epoch)
    end),"Cannot register tag block timer")
  end
  local function receive(text)
    if not self.enabled or type(text)~="string" then return end
    local tag=parse(text)
    if not tag and #stack==0 then return end
    local reason
    if #stack>0 and (activeLines>=4096 or activeBytes+#text>MAX_BLOCK_BYTES) then reason="size limit"
    elseif tag and tag.kind=="open" and #stack>=16 then reason="nesting limit"
    elseif #text>MAX_BLOCK_BYTES then reason="size limit" end
    if reason then
      local epoch=generation; local finished=finish(reason)
      diagnostic(reason); publishBlocks(finished,epoch)
      return -- the offending line stays visible; do not reopen it as a block
    end
    local epoch=generation
    local record=tag or {kind="text",payload=text}
    record.id=nextID(); record.session=session; record.line=text
    record.blockId=stack[#stack] and stack[#stack].id or nil
    if record.kind=="data" then record.fields=fields(record.payload) end
    if record.kind=="open" then
      if #stack==0 then armTimer(); activeLines,activeBytes=0,0 end
      local block={id=nextID(),session=session,name=record.name,arguments=record.arguments,
        parentId=record.blockId,contents={},status="open"}
      stack[#stack+1]=block; record.blockId=block.id
    end
    if #stack>0 then
      activeLines=activeLines+1; activeBytes=activeBytes+#text
      for _,block in ipairs(stack) do block.contents[#block.contents+1]=record end
    end
    local finished={}
    if record.kind=="close" and #stack>0 then
      if stack[#stack].name~=record.name then
        reason="mismatched closing tag"; finished=finish(reason)
      else
        local block=table.remove(stack); block.status="complete"
        finished[1]=block
        if #stack==0 then cancelTimer(); activeLines,activeBytes=0,0 end
      end
    end
    assert(store("record",record),"Tag record exceeds retention limit")
    -- Gag before any diagnostic or consumer can echo another line.
    if not incoming and options.suppress then api.deleteLine() end
    self.last="Capturing game tags"
    publish("record",record.id)
    if reason then self.last="Incomplete block: "..reason end
    publishBlocks(finished,epoch)
    return true, options.suppress
  end
  function self.start()
    if self.enabled then return true end
    local ok,err=pcall(function()
      clear()
      if incoming then incoming.add(OWNER,20,receive,failed) else
      trigger=assert(api.tempRegexTrigger([[^.*$]],function()
        local text=api.line -- snapshot before any other callback changes trigger globals
        local worked,message=pcall(receive,text)
        if not worked then failed(message) end
      end),"Cannot register tag capture trigger")
      end
      for _,event in ipairs({"sysConnectionEvent","sysDisconnectionEvent"}) do
        handlers[#handlers+1]=event
        assert(api.registerNamedEventHandler(OWNER,event,event,function()
          clear(); self.last="Waiting for game tags"
        end),"Cannot register tag connection handler")
      end
      self.enabled=true; self.last="Waiting for game tags"
    end)
    if not ok then failed(err); return false,self.last end
    return true
  end
  function self.configure(values)
    if options.enabled~=values.enabled or options.suppress~=values.suppress or options.block_timeout~=values.block_timeout then
      local epoch=generation
      local finished=finish("settings changed")
      publishBlocks(finished,epoch)
    end
    options={enabled=values.enabled,suppress=values.suppress,block_timeout=values.block_timeout}
    if not options.enabled then self.stop(); return true end
    return self.start()
  end
  function self.getRecord(id) return copy(records[id]) end
  function self.getBlock(id) return copy(blocks[id]) end
  function self.latest(name)
    for i=#history,1,-1 do
      local item=history[i]; local record=item.kind=="record" and records[item.id]
      if record and record.name==name then return copy(record) end
    end
  end
  function self.recent(limit)
    limit=tonumber(limit) or 500
    assert(limit==limit and limit>=0 and limit<math.huge,"Invalid recent limit")
    limit=math.min(500,math.floor(limit))
    local result={}
    for i=#history,1,-1 do
      local item=history[i]
      if item.kind=="record" and #result<limit then table.insert(result,1,copy(records[item.id])) end
    end
    return result
  end
  return self
end
return Tags
