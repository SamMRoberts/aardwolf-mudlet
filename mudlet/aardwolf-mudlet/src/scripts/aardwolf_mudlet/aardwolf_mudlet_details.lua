aardwolf_mudlet.details = aardwolf_mudlet.details or {runtime={generation=0,queue={},capture=nil,trigger_id=nil}}
local LIMIT, TIMER = 100, "aardwolf-mudlet::details-timeout"
local QUEUE_TIMER = "aardwolf-mudlet::details-queue"

local function details() return aardwolf_mudlet.state.value("details") end
local function section_for(kind) return kind == "eqdata" and "equipment" or "bags" end
local function finish(success, message)
  local runtime, capture = aardwolf_mudlet.details.runtime, aardwolf_mudlet.details.runtime.capture
  if not capture then return end
  runtime.capture=nil
  if deleteNamedTimer then pcall(deleteNamedTimer, "aardwolf-mudlet", TIMER) end
  if not success then
    runtime.queue={}
    local previous=aardwolf_mudlet.util.copy(runtime.previous or details())
    previous.refreshing=false; previous.stale=true; previous.error=message
    previous.errors=previous.errors or {}; previous.errors[#previous.errors+1]=message
    previous.sections=previous.sections or {}
    previous.sections[section_for(capture.kind)]={status="error",received_at=os.time(),error=message}
    runtime.previous=nil
    aardwolf_mudlet.state.set_details(previous,"stale",message)
    if aardwolf_mudlet.ui then aardwolf_mudlet.ui.request_render() end
    return
  end
  local value=details()
  value.refreshing=#runtime.queue>0
  value.last_updated=os.time()
  value.stale=false
  value.sections[section_for(capture.kind)]={status="current",received_at=os.time(),error=nil}
  if #runtime.queue==0 then value.error=nil; runtime.previous=nil end
  aardwolf_mudlet.state.set_details(value,#runtime.queue>0 and "partial" or "current")
  if aardwolf_mudlet.ui then aardwolf_mudlet.ui.request_render() end
  if #runtime.queue>0 then
    if deleteNamedTimer then pcall(deleteNamedTimer,"aardwolf-mudlet",QUEUE_TIMER) end
    registerNamedTimer("aardwolf-mudlet",QUEUE_TIMER,(capture.kind=="invdetails" or capture.kind=="bagdata") and 1 or 0.1,aardwolf_mudlet.details.next,false)
  end
end

local function fields(csv)
  local result={}; for field in (csv..","):gmatch("(.-),") do result[#result+1]=field end; return result
end
local function pipe_fields(value) local result={}; for field in (value.."|"):gmatch("(.-)|") do result[#result+1]=field end; return result end
local function item(payload)
  local f=fields(payload)
  if #f~=8 or not tonumber(f[1]) or not f[3] or f[3]=="" or not tonumber(f[4]) or not tonumber(f[5])
      or (f[6]~="0" and f[6]~="1") or not tonumber(f[7]) or not tonumber(f[8]) then return nil end
  return {id=tonumber(f[1]),flags=f[2],name=f[3]:gsub("@x%d%d%d",""):gsub("@.",""),level=tonumber(f[4]),type=tonumber(f[5]),unique=f[6]=="1",slot=tonumber(f[7]),timer=tonumber(f[8])}
end
local function tagged_payload(line,name) return line:match("^%{"..name.."%}%s*(.-)%s*$") end
local function opening_argument(line,name)
  local argument=line:match("^%{"..name.."%s*([^}]*)%}%s*$")
  if argument==nil then return nil end
  return argument:match("^%s*(.-)%s*$")
end
local function find_bag(value,id)
  for _,bag in ipairs(value.bags or {}) do if bag.id==id then return bag end end
end
local function append(capture,parsed)
  if #capture.rows>=LIMIT then finish(false,"Tagged response exceeded record limit"); return false end
  capture.rows[#capture.rows+1]=parsed
  return true
end

function aardwolf_mudlet.details.capture_timeout() finish(false,"Tagged response timed out; previous valid data retained") end
function aardwolf_mudlet.details.next()
  local runtime=aardwolf_mudlet.details.runtime
  if runtime.capture or #runtime.queue==0 or aardwolf_mudlet.state.connection~="connected" then return end
  local request=table.remove(runtime.queue,1)
  runtime.capture={kind=request.kind,id=request.id,rows={},generation=runtime.generation,invalid=0,opened=false}
  send(request.command,false)
  registerNamedTimer("aardwolf-mudlet",TIMER,3,aardwolf_mudlet.details.capture_timeout,false)
end

local function capture_item_row(capture,line,predicate)
  if not capture.opened then return false end
  local parsed=item(line)
  if not parsed then
    if line:match("^%d+,[^,]*,") then capture.invalid=capture.invalid+1 end
    return false
  end
  if predicate and not predicate(parsed) then capture.invalid=capture.invalid+1; return true end
  append(capture,parsed)
  return true
end

function aardwolf_mudlet.details.capture_line(raw)
  local line=tostring(raw or ""):gsub("\27%[[0-9;]*m",""):match("^%s*(.-)%s*$")
  local capture=aardwolf_mudlet.details.runtime.capture
  if not capture then return false end

  if capture.kind=="eqdata" then
    local argument=opening_argument(line,"eqdata")
    if argument~=nil then
      if argument~="" then finish(false,"Equipment opening tag was malformed"); return true end
      capture.opened=true; return true
    end
    if line=="{/eqdata}" then
      if not capture.opened then finish(false,"Equipment response ended before its opening tag"); return true end
      if capture.invalid>0 then finish(false,"Malformed equipment response; previous valid snapshot retained"); return true end
      local replacement={}; for _,record in ipairs(capture.rows) do replacement[record.slot]=record end
      details().equipment=replacement
      finish(true)
      return true
    end
    return capture_item_row(capture,line,function(record) return record.slot>=0 and record.slot<=32 end)
  end

  if capture.kind=="invdata" or capture.kind=="bagdata" then
    local argument=opening_argument(line,"invdata")
    if argument~=nil then
      if capture.kind=="bagdata" then
        local response_id=tonumber(argument)
        if not response_id or response_id~=capture.id then finish(false,"Container ID did not match invdata request"); return true end
        capture.verified_id=true
      elseif argument~="" then finish(false,"Top-level inventory returned an unexpected container ID"); return true end
      capture.opened=true
      return true
    end
    if line=="{/invdata}" then
      if not capture.opened or (capture.kind=="bagdata" and not capture.verified_id) then finish(false,"Inventory response was not verified"); return true end
      if capture.invalid>0 then finish(false,"Malformed inventory response; previous valid snapshot retained"); return true end
      local value=details()
      if capture.kind=="invdata" then
        value.inventory=capture.rows
        value.bags={}
        for _,record in ipairs(capture.rows) do
          if record.type==11 then
            value.bags[#value.bags+1]={id=record.id,name=record.name,level=record.level,type=record.type,flags=record.flags,unique=record.unique,timer=record.timer,items={},pending=true,status="partial"}
          end
        end
        for _,bag in ipairs(value.bags) do
          aardwolf_mudlet.details.runtime.queue[#aardwolf_mudlet.details.runtime.queue+1]={kind="invdetails",command="invdetails "..bag.id,id=bag.id}
          aardwolf_mudlet.details.runtime.queue[#aardwolf_mudlet.details.runtime.queue+1]={kind="bagdata",command="invdata "..bag.id,id=bag.id}
        end
      else
        local bag=find_bag(value,capture.id)
        if bag then bag.items=capture.rows; bag.pending=false; bag.status="current" end
      end
      finish(true)
      return true
    end
    return capture_item_row(capture,line)
  end

  if capture.kind=="invdetails" then
    local argument=opening_argument(line,"invdetails")
    if argument~=nil then
      if argument~="" then finish(false,"Container detail opening tag was malformed"); return true end
      capture.opened=true; return true
    end
    if line=="{/invdetails}" then
      if not capture.opened or not capture.verified_id then finish(false,"Container ID was not verified"); return true end
      if capture.max_weight==nil or capture.used_weight==nil then finish(false,"Container weights were malformed; previous valid snapshot retained"); return true end
      local value=details(); local bag=find_bag(value,capture.id)
      if bag then
        bag.own_weight=capture.header_weight
        bag.max_weight=capture.max_weight
        bag.used_weight=capture.used_weight or capture.header_weight
        bag.pending=true
        bag.status="partial"
      end
      finish(true)
      return true
    end
    if not capture.opened then return false end
    local header=tagged_payload(line,"invheader")
    if header then
      local f=pipe_fields(header); local response_id=tonumber(f[1])
      if not response_id or response_id~=capture.id then finish(false,"Container ID did not match request"); return true end
      capture.verified_id=true; capture.header_weight=tonumber(f[5]); return true
    end
    local container=tagged_payload(line,"container")
    if container then
      if not capture.verified_id then finish(false,"Container details arrived before verified header"); return true end
      local f=pipe_fields(container); capture.max_weight=tonumber(f[1]); capture.used_weight=tonumber(f[3]); return true
    end
    return false
  end
  return false
end

function aardwolf_mudlet.details.on_line()
  local line=line or (getCurrentLine and getCurrentLine()) or ""
  if aardwolf_mudlet.details.capture_line(line) and deleteLine then deleteLine() end
end
function aardwolf_mudlet.details.refresh()
  if aardwolf_mudlet.state.connection~="connected" then return false,"Disconnected" end
  aardwolf_mudlet.details.start()
  local runtime=aardwolf_mudlet.details.runtime; runtime.generation=runtime.generation+1; runtime.queue={{kind="eqdata",command="eqdata"},{kind="invdata",command="invdata"}}
  local value=details(); runtime.previous=aardwolf_mudlet.util.copy(value); value.refreshing=true; value.error=nil; value.errors={}; value.generation=runtime.generation; aardwolf_mudlet.state.set_details(value,"partial")
  aardwolf_mudlet.details.next()
  return true
end
function aardwolf_mudlet.details.start()
  if not aardwolf_mudlet.details.runtime.trigger_id and tempRegexTrigger then
    aardwolf_mudlet.details.runtime.trigger_id=tempRegexTrigger("^.*$",aardwolf_mudlet.details.on_line)
  end
end
function aardwolf_mudlet.details.stop(reason)
  if deleteNamedTimer then pcall(deleteNamedTimer,"aardwolf-mudlet",TIMER); pcall(deleteNamedTimer,"aardwolf-mudlet",QUEUE_TIMER) end
  if aardwolf_mudlet.details.runtime.trigger_id and killTrigger then pcall(killTrigger,aardwolf_mudlet.details.runtime.trigger_id) end
  aardwolf_mudlet.details.runtime.trigger_id=nil
  aardwolf_mudlet.details.runtime.capture=nil; aardwolf_mudlet.details.runtime.queue={}; aardwolf_mudlet.details.runtime.previous=nil
  if type(reason)=="string" then local value=details(); value.refreshing=false; value.stale=true; value.error=reason; aardwolf_mudlet.state.set_details(value,"stale",reason) end
end
