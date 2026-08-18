-- Test-only contract stub. It is deliberately not a reusable package template.
aardwolf_map = aardwolf_map or { owner = "Aardwolf.db/v11", state = {} }

function aardwolf_map.import_batch(snapshot, cancel_requested)
  if cancel_requested then
    aardwolf_map.state.resume = { sha256 = snapshot.source.sha256, cursor = aardwolf_map.state.cursor or 1 }
    return "cancelled"
  end
  for index = aardwolf_map.state.cursor or 1, #snapshot.rooms do
    local room = snapshot.rooms[index]
    local hash = "aardwolf-map:vnum:" .. room.vnum
    local existing = getRoomIDbyHash(hash)
    if existing and getRoomUserData(existing, "aardwolf_map.owner") ~= aardwolf_map.owner then
      aardwolf_map.state.collisions = (aardwolf_map.state.collisions or 0) + 1
    else
      local id = existing or createRoomID()
      setRoomIDbyHash(id, hash)
      setRoomUserData(id, "aardwolf_map.owner", aardwolf_map.owner)
    end
    aardwolf_map.state.cursor = index + 1
  end
  aardwolf_map.state.resume = nil
  return "complete"
end

function aardwolf_map.center_from_gmcp(info)
  if type(info) ~= "table" or type(info.num) ~= "number" then return end
  local id = getRoomIDbyHash("aardwolf-map:vnum:" .. info.num)
  if id and getRoomUserData(id, "aardwolf_map.owner") == aardwolf_map.owner then
    centerview(id)
  end
end

function aardwolf_map.cleanup()
  if aardwolf_map.event then killAnonymousEventHandler(aardwolf_map.event) end
  if aardwolf_map.timer then killTimer(aardwolf_map.timer) end
end
