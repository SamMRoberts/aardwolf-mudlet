-- A fully explored, unobstructed grid for refresh scaling checks. Seed one
-- real mapper room first so the fixture retains the current ownership schema.
function seedMapperGrid(side, outside)
  assert(mapper:receive(packet(1)))
  local template = {}
  for key, value in pairs(rooms[1].data) do template[key] = value end
  for row = 0, side - 1 do
    for column = 0, side - 1 do
      local id = row * side + column + 1
      if id ~= 1 then assert(addRoom(id)) end
      setRoomArea(id, areas.test)
      setRoomName(id, "Room " .. id)
      setRoomEnv(id, rooms[1].env)
      setRoomIDbyHash(id, "aardwolf-vibe:aardwolf:room:" .. id)
      setRoomCoordinates(id, column * 2, row * 2, 0)
      for key, value in pairs(template) do setRoomUserData(id, key, value) end
      setRoomUserData(id, "aardwolf-vibe:server-room-id", tostring(id))
      setRoomUserData(id, "aardwolf-vibe:placement-x", tostring(column * 2))
      setRoomUserData(id, "aardwolf-vibe:placement-y", tostring(row * 2))
      setRoomUserData(id, "aardwolf-vibe:placement-authority", "gmcp-reciprocal")
    end
  end
  for row = 0, side - 1 do
    for column = 0, side - 1 do
      local id = row * side + column + 1
      local exits = {n = row < side - 1 and id + side or nil,
        s = row > 0 and id - side or nil, e = column < side - 1 and id + 1 or nil,
        w = column > 0 and id - 1 or nil}
      for direction, target in pairs(exits) do
        assert(setExit(id, target, direction))
        setRoomUserData(id, "aardwolf-vibe:exit:" .. direction, tostring(target))
      end
    end
  end
  if outside and outside > 0 then
    local area = addAreaName("other")
    for id = side * side + 1, side * side + outside do
      assert(addRoom(id));setRoomArea(id, area);setRoomCoordinates(id, id * 2, 0, 0)
    end
  end
  local middle = math.floor(side / 2) * side + math.floor(side / 2) + 1
  return packet(middle, {n=middle+side,s=middle-side,e=middle+1,w=middle-1})
end

function countMapperAPI()
  apiCounts = {}
  for _, name in ipairs({"getRooms", "getRoomCoordinates", "getRoomUserData", "getRoomExits",
      "getRoomArea", "getRoomsByPosition", "updateMap", "centerview"}) do
    local original = _G[name]
    _G[name] = function(...)
      apiCounts[name] = (apiCounts[name] or 0) + 1
      return original(...)
    end
  end
end
