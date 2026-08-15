aardwolf_interface.details = aardwolf_interface.details or {runtime={generation=0,queue={},capture=nil,trigger_id=nil}}
local LIMIT, TIMER = 100, "aardwolf-interface::details-timeout"

local function details() return aardwolf_interface.state.value("details") end
local function finish(success, message)
  local runtime, capture = aardwolf_interface.details.runtime, aardwolf_interface.details.runtime.capture
  if not capture then return end
  runtime.capture=nil
  if killNamedTimer then pcall(killNamedTimer, "aardwolf-interface", TIMER) end
  local value=details(); value.refreshing=false; value.last_updated=os.time(); value.stale=not success
  value.sections[capture.kind == "eqdata" and "equipment" or "bags"]={status=success and "current" or "error",received_at=os.time(),error=message}
  if not success then value.errors[#value.errors+1]=message; value.error=message end
  aardwolf_interface.state.set_details(value, success and "current" or "partial", message)
  if aardwolf_interface.ui then aardwolf_interface.ui.request_render() end
  if #runtime.queue>0 then tempTimer(capture.kind=="invdetails" and 1 or 0.1, aardwolf_interface.details.next) end
end

local function fields(csv)
  local result={}; for field in (csv..","):gmatch("(.-),") do result[#result+1]=field end; return result
end
local function pipe_fields(value) local result={}; for field in (value.."|"):gmatch("(.-)|") do result[#result+1]=field end; return result end
local function item(payload)
  local f=fields(payload)
  if not tonumber(f[1]) or not f[3] or f[3]=="" or not tonumber(f[4]) or not tonumber(f[5]) or not tonumber(f[7]) or not tonumber(f[8]) then return nil end
  return {id=tonumber(f[1]),flags=f[2],name=f[3]:gsub("@x%d%d%d",""):gsub("@.",""),level=tonumber(f[4]),type=tonumber(f[5]),unique=f[6]=="1",slot=tonumber(f[7]),timer=tonumber(f[8])}
end
local function tag(line,name) return line:match("^%{"..name.."%}%s*(.-)%s*$") end

function aardwolf_interface.details.capture_timeout() finish(false,"Tagged response timed out; previous valid data retained") end
function aardwolf_interface.details.next()
  local runtime=aardwolf_interface.details.runtime
  if runtime.capture or #runtime.queue==0 or aardwolf_interface.state.connection~="connected" then return end
  local request=table.remove(runtime.queue,1)
  runtime.capture={kind=request.kind,id=request.id,rows={},generation=runtime.generation,invalid=0}
  send(request.command,false)
  registerNamedTimer("aardwolf-interface",TIMER,3,aardwolf_interface.details.capture_timeout,true)
end

function aardwolf_interface.details.capture_line(raw)
  local line=tostring(raw or ""):gsub("\27%[[0-9;]*m","")
  local capture=aardwolf_interface.details.runtime.capture
  if not capture then return false end
  local owned=false
  if capture.kind=="eqdata" then
    local payload=tag(line,"eqdata")
    if line:match("^%{/eqdata%}$") then local value=details(); value.equipment={}; for _,item in ipairs(capture.rows) do value.equipment[item.slot]=item end; finish(capture.invalid==0 or #capture.rows>0,capture.invalid>0 and "Malformed equipment records skipped" or nil); return true end
    if payload then local parsed=item(payload); if parsed and parsed.slot>=0 then capture.rows[#capture.rows+1]=parsed else capture.invalid=capture.invalid+1 end; owned=true end
  elseif capture.kind=="invdata" then
    local payload=tag(line,"invdata")
    if line:match("^%{/invdata%}$") then local value=details(); value.bags=capture.rows; for _,bag in ipairs(capture.rows) do aardwolf_interface.details.runtime.queue[#aardwolf_interface.details.runtime.queue+1]={kind="invdetails",command="invdetails "..bag.id,id=bag.id} end; finish(true); return true end
    if payload then local parsed=item(payload); if parsed and parsed.type==11 then capture.rows[#capture.rows+1]={id=parsed.id,name=parsed.name,level=parsed.level,type=parsed.type,flags=parsed.flags,unique=parsed.unique,timer=parsed.timer,items={}} elseif not parsed then capture.invalid=capture.invalid+1 end; owned=true end
  elseif capture.kind=="invdetails" then
    if line:match("^%{/invdetails%}$") then
      if not capture.verified_id then finish(false,"Container ID was not verified"); return true end
      local value=details(); for _,bag in ipairs(value.bags or {}) do if bag.id==capture.id then bag.used_weight=capture.used_weight; bag.max_weight=capture.max_weight; bag.items=capture.rows; bag.status="current" end end
      finish(true); return true
    end
    local header=tag(line,"invheader") or tag(line,"container")
    local item_payload=tag(line,"invitem")
    if header then local f=pipe_fields(header); if line:match("^%{invheader%}") then local response_id=tonumber(f[1]); if not response_id or response_id~=capture.id then finish(false,"Container ID did not match request"); return true end; capture.verified_id=true; capture.header_weight=tonumber(f[5]) else if not capture.verified_id then finish(false,"Container details arrived before verified header"); return true end; capture.max_weight=tonumber(f[1]); capture.used_weight=tonumber(f[3]) end; owned=true
    elseif item_payload then local parsed=item(item_payload); if parsed and #capture.rows<LIMIT then capture.rows[#capture.rows+1]=parsed else capture.invalid=capture.invalid+1 end; owned=true end
  end
  if owned and #capture.rows>LIMIT then finish(false,"Tagged response exceeded record limit") end
  return owned
end

function aardwolf_interface.details.on_line()
  local line=line or (getCurrentLine and getCurrentLine()) or ""
  if aardwolf_interface.details.capture_line(line) and deleteLine then deleteLine() end
end
function aardwolf_interface.details.refresh()
  if aardwolf_interface.state.connection~="connected" then return false,"Disconnected" end
  local runtime=aardwolf_interface.details.runtime; runtime.generation=runtime.generation+1; runtime.queue={{kind="eqdata",command="eqdata"},{kind="invdata",command="invdata"}}
  local value=details(); value.refreshing=true; value.error=nil; value.generation=runtime.generation; aardwolf_interface.state.set_details(value,"partial")
  aardwolf_interface.details.next()
  return true
end
function aardwolf_interface.details.start()
  if not aardwolf_interface.details.runtime.trigger_id and tempRegexTrigger then
    aardwolf_interface.details.runtime.trigger_id=tempRegexTrigger("^.*$",aardwolf_interface.details.on_line)
  end
end
function aardwolf_interface.details.stop(reason)
  if killNamedTimer then pcall(killNamedTimer,"aardwolf-interface",TIMER) end
  if aardwolf_interface.details.runtime.trigger_id and killTrigger then pcall(killTrigger,aardwolf_interface.details.runtime.trigger_id) end
  aardwolf_interface.details.runtime.trigger_id=nil
  aardwolf_interface.details.runtime.capture=nil; aardwolf_interface.details.runtime.queue={}
  if type(reason)=="string" then local value=details(); value.refreshing=false; value.stale=true; value.error=reason; aardwolf_interface.state.set_details(value,"stale",reason) end
end
