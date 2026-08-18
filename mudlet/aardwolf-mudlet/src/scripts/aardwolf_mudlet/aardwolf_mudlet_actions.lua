aardwolf_mudlet.actions = aardwolf_mudlet.actions or {}
aardwolf_mudlet.actions.pending_action = nil

local curated = {
  look={id="look",label="Look",category="Room",command="look"}, exits={id="exits",label="Exits",category="Room",command="exits"},
  scan={id="scan",label="Scan",category="Room",command="scan"}, score={id="score",label="Score",category="Character",command="score"},
  affects={id="affects",label="Affects",category="Character",command="aff"}, attributes={id="attributes",label="Attributes",category="Character",command="attr"},
  resists={id="resists",label="Resists",category="Character",command="resists"},
  character_refresh={id="character-refresh",label="Refresh Character",category="Refresh",local_action="character"},
  quest_refresh={id="quest-refresh",label="Refresh Quest",category="Refresh",local_action="quest"},
  details_refresh={id="details-refresh",label="Refresh Inventory",category="Refresh",local_action="details"},
  map_import={id="map-import",label="Import Map",category="Map",local_action="import"},
  map_center={id="map-center",label="Center Map",category="Map",local_action="center"},
  map_zoom_in={id="map-zoom-in",label="Zoom In",category="Map",local_action="zoom-in"},
  map_zoom_out={id="map-zoom-out",label="Zoom Out",category="Map",local_action="zoom-out"},
}
function aardwolf_mudlet.actions.curated()
  local result={}
  for _,action in pairs(curated) do result[#result+1]=action end
  table.sort(result,function(left,right) if left.category==right.category then return left.label<right.label end return left.category<right.category end)
  return result
end

function aardwolf_mudlet.actions.gameplay_available()
  if aardwolf_mudlet.state.connection ~= "connected" then return false end
  local state = tonumber(aardwolf_mudlet.state.value("status").state)
  return not ({[1]=true,[2]=true,[5]=true,[6]=true,[7]=true})[state]
end

function aardwolf_mudlet.actions.context()
  local result = {curated.look, curated.exits, curated.scan}
  local exits = aardwolf_mudlet.state.value("room").exits or {}
  for _, direction in ipairs({"n","e","s","w","u","d"}) do
    if exits[direction] ~= nil then
      result[#result + 1] = {id="exit-"..direction,label=direction:upper(),category="Exits",command=direction}
      break
    end
  end
  if #result < 4 then result[#result + 1] = curated.score end
  return result
end

local function safe_curated(action)
  if not action or type(action.command) ~= "string" then return false end
  if action.id:match("^exit%-[neswud]$") then return action.command == action.id:sub(-1) end
  return curated[action.id] == action
end

function aardwolf_mudlet.actions.execute(id)
  if id=="character-refresh" then return aardwolf_mudlet.lifecycle.request_character(true) end
  if id=="quest-refresh" then return aardwolf_mudlet.lifecycle.request_quest(true) end
  if id=="details-refresh" then aardwolf_mudlet.details.refresh(); return true end
  if id=="map-import" then
    if aardwolf_mudlet.map and aardwolf_mudlet.map.start_import then aardwolf_mudlet.map.start_import(); return true end
    return false, "The packaged map importer is unavailable"
  end
  if id=="map-center" then aardwolf_mudlet.lifecycle.center_map(); return true end
  if id=="map-zoom-in" or id=="map-zoom-out" then
    local mapper=aardwolf_mudlet.ui and aardwolf_mudlet.ui.mapper
    local method=id=="map-zoom-in" and "zoomIn" or "zoomOut"
    return aardwolf_mudlet.util.safe_call(mapper,method)
  end
  if not aardwolf_mudlet.actions.gameplay_available() then return false, "Gameplay actions are unavailable in the current connection state" end
  local action = curated[id]
  if not action and type(id) == "string" and id:match("^exit%-[neswud]$") then
    local direction = id:sub(-1)
    if aardwolf_mudlet.state.value("room").exits[direction] ~= nil then action={id=id,command=direction} end
  end
  if safe_curated(action) then send(action.command, false); return true end
  for _, custom in ipairs(aardwolf_mudlet.settings.data.custom_actions or {}) do
    if custom.id == id then send(custom.command, false); return true end
  end
  return false, "Unknown action"
end

function aardwolf_mudlet.actions.confirm()
  local pending = aardwolf_mudlet.actions.pending_action
  aardwolf_mudlet.actions.pending_action = nil
  if not pending or not aardwolf_mudlet.actions.gameplay_available() then return false end
  send(pending.command, false)
  return true
end
function aardwolf_mudlet.actions.cancel() aardwolf_mudlet.actions.pending_action = nil end
function aardwolf_mudlet.actions.pending() return aardwolf_mudlet.actions.pending_action end
aardwolf_mudlet.actions.confirm_pending=aardwolf_mudlet.actions.confirm
aardwolf_mudlet.actions.cancel_pending=aardwolf_mudlet.actions.cancel

local function valid(label, command, category)
  category=category or "Custom"
  return type(label)=="string" and label:match("%S") and #label<=32 and not label:find("[%c]")
    and type(category)=="string" and category:match("%S") and #category<=24 and not category:find("[%c]")
    and type(command)=="string" and command:match("%S") and #command<=200 and not command:find("[%c]")
end
function aardwolf_mudlet.actions.add(label, command, category)
  local list = aardwolf_mudlet.settings.data.custom_actions
  if #list >= 24 or not valid(label, command, category) then return false, "Action requires a printable 1-32 character label, 1-24 character category, and 1-200 character command" end
  local numeric = aardwolf_mudlet.settings.data.next_action_id or 1
  list[#list+1] = {id="custom-"..numeric,label=label,command=command,category=category or "Custom",order=#list+1}
  aardwolf_mudlet.settings.data.next_action_id = numeric + 1
  aardwolf_mudlet.settings.save(); return true
end
function aardwolf_mudlet.actions.update(id, label, command, category)
  if not valid(label, command, category) then return false end
  for _, action in ipairs(aardwolf_mudlet.settings.data.custom_actions) do if action.id==id then action.label=label; action.command=command; action.category=category or action.category; aardwolf_mudlet.settings.save(); return true end end
  return false
end
function aardwolf_mudlet.actions.remove(id)
  for index, action in ipairs(aardwolf_mudlet.settings.data.custom_actions) do if action.id==id then table.remove(aardwolf_mudlet.settings.data.custom_actions,index); aardwolf_mudlet.settings.save(); return true end end
  return false
end
function aardwolf_mudlet.actions.move(id, order)
  order=math.floor(tonumber(order) or 0); local list=aardwolf_mudlet.settings.data.custom_actions
  if order<1 or order>#list then return false end
  for index, action in ipairs(list) do if action.id==id then table.remove(list,index); table.insert(list,order,action); for position,item in ipairs(list) do item.order=position end; aardwolf_mudlet.settings.save(); return true end end
  return false
end
function aardwolf_mudlet.actions.custom() return aardwolf_mudlet.settings.data.custom_actions or {} end
