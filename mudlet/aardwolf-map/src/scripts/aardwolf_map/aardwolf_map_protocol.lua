aardwolf_map = aardwolf_map or {}
aardwolf_map.protocol = aardwolf_map.protocol or {}

function aardwolf_map.protocol.on_room_info()
  local room_info = gmcp and gmcp.room and gmcp.room.info
  if type(room_info) ~= "table" then
    return
  end
  local vnum = tonumber(room_info.num)
  if not vnum or vnum % 1 ~= 0 then
    return
  end
  local room_id = aardwolf_map.state.room_id_for_vnum(vnum)
  local resolved_room_id = nil
  if room_id and aardwolf_map.state.is_owned_room(room_id) then
    if room_id then resolved_room_id = room_id end
    centerview(room_id)
  end
  if aardwolf_map.lifecycle and aardwolf_map.lifecycle.record_room_resolution then
    aardwolf_map.lifecycle.record_room_resolution(vnum, resolved_room_id)
  end
end
