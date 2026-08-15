aardwolf_interface.lifecycle = aardwolf_interface.lifecycle or {handlers={},initialized=false,quest_requested=false}
local USER="aardwolf-interface"
local HEARTBEAT="aardwolf-interface::heartbeat"
local events={
  {"base","gmcp.char.base",aardwolf_interface.protocol.base},{"vitals","gmcp.char.vitals",aardwolf_interface.protocol.vitals},
  {"maxstats","gmcp.char.maxstats",aardwolf_interface.protocol.maxstats},{"status","gmcp.char.status",aardwolf_interface.protocol.status},
  {"stats","gmcp.char.stats",aardwolf_interface.protocol.stats},{"worth","gmcp.char.worth",aardwolf_interface.protocol.worth},
  {"group","gmcp.group",aardwolf_interface.protocol.group},{"room","gmcp.room.info",aardwolf_interface.protocol.room},
  {"quest","gmcp.comm.quest",aardwolf_interface.protocol.quest},{"tick","gmcp.comm.tick",aardwolf_interface.protocol.tick},
  {"map-status","aardwolf-map::status-changed",aardwolf_interface.protocol.map_status},
}
local function connected()
  if type(getConnectionInfo)~="function" then return false end
  local ok,info,port,is_connected=pcall(getConnectionInfo); if not ok then return false end
  if type(is_connected)=="boolean" then return is_connected end
  if type(info)=="table" then return info.connected==true or info.state=="connected" or info[1]==true end
  return info==true
end
function aardwolf_interface.lifecycle.center_map() if aardwolf_interface.ui and aardwolf_interface.ui.mapper and centerview then local room=aardwolf_interface.state.value("room"); pcall(centerview,tonumber(room.num)) end end
function aardwolf_interface.lifecycle.request_quest(force)
  if aardwolf_interface.state.connection~="connected" or (aardwolf_interface.lifecycle.quest_requested and not force) then return false end
  aardwolf_interface.lifecycle.quest_requested=true
  if sendGMCP then sendGMCP("request quest"); return true end
  return false
end
function aardwolf_interface.lifecycle.on_connect()
  aardwolf_interface.state.reset_session("connected"); aardwolf_interface.lifecycle.quest_requested=false
  tempTimer(0.5,function() aardwolf_interface.lifecycle.request_quest(false) end); aardwolf_interface.ui.request_render()
end
function aardwolf_interface.lifecycle.on_disconnect() aardwolf_interface.details.stop("Disconnected"); aardwolf_interface.state.reset_session("disconnected"); aardwolf_interface.lifecycle.quest_requested=false; aardwolf_interface.ui.request_render() end
function aardwolf_interface.lifecycle.on_resize() aardwolf_interface.ui.reflow() end
function aardwolf_interface.lifecycle.on_heartbeat()
  local now=os.time()
  for name,envelope in pairs(aardwolf_interface.state.sections or {}) do
    if name~="details" and envelope.status=="current" and envelope.received_at and now-envelope.received_at>180 then envelope.status="stale"; envelope.error="No update received for 180 seconds" end
  end
  aardwolf_interface.ui.request_render()
end
function aardwolf_interface.lifecycle.on_exit() aardwolf_interface.lifecycle.shutdown(true) end
function aardwolf_interface.lifecycle.on_uninstall(_,name) if not name or tostring(name):find("aardwolf%-interface") then aardwolf_interface.lifecycle.shutdown(false) end end
function aardwolf_interface.lifecycle.hydrate()
  if not connected() then return end
  aardwolf_interface.state.connection="connected"
  for _,event in ipairs(events) do if event[2]:match("^gmcp%.") and event[2]~="gmcp.comm.tick" then pcall(event[3]) end end
  pcall(aardwolf_interface.protocol.map_status)
end
function aardwolf_interface.lifecycle.register()
  for _,event in ipairs(events) do registerNamedEventHandler(USER,"aardwolf-interface::"..event[1],event[2],event[3]) end
  registerNamedEventHandler(USER,"aardwolf-interface::resize","sysWindowResizeEvent",aardwolf_interface.lifecycle.on_resize)
  registerNamedEventHandler(USER,"aardwolf-interface::connect","sysConnectionEvent",aardwolf_interface.lifecycle.on_connect)
  registerNamedEventHandler(USER,"aardwolf-interface::disconnect","sysDisconnectionEvent",aardwolf_interface.lifecycle.on_disconnect)
  registerNamedEventHandler(USER,"aardwolf-interface::exit","sysExitEvent",aardwolf_interface.lifecycle.on_exit)
  registerNamedEventHandler(USER,"aardwolf-interface::uninstall","sysUninstallPackage",aardwolf_interface.lifecycle.on_uninstall)
  registerNamedTimer(USER,HEARTBEAT,1,aardwolf_interface.lifecycle.on_heartbeat,false)
end
function aardwolf_interface.lifecycle.shutdown(keep_visibility)
  if not aardwolf_interface.lifecycle.initialized then return end
  aardwolf_interface.details.stop()
  if deleteNamedEventHandler then
    for _,event in ipairs(events) do pcall(deleteNamedEventHandler,USER,"aardwolf-interface::"..event[1]) end
    for _,name in ipairs({"resize","connect","disconnect","exit","uninstall"}) do pcall(deleteNamedEventHandler,USER,"aardwolf-interface::"..name) end
  end
  if deleteNamedTimer then pcall(deleteNamedTimer,USER,HEARTBEAT) end
  aardwolf_interface.ui.destroy(); aardwolf_interface.actions.cancel(); aardwolf_interface.lifecycle.initialized=false
  if not keep_visibility then aardwolf_interface.settings.data.visible=false end
end
function aardwolf_interface.lifecycle.initialize()
  aardwolf_interface.lifecycle.shutdown(true); aardwolf_interface.settings.load(); aardwolf_interface.state.reset_session("disconnected")
  aardwolf_interface.ui.build(); aardwolf_interface.details.start(); aardwolf_interface.lifecycle.register(); aardwolf_interface.lifecycle.initialized=true
  aardwolf_interface.lifecycle.hydrate(); if aardwolf_interface.state.connection=="connected" then aardwolf_interface.lifecycle.request_quest(false) end
  if aardwolf_interface.settings.is_visible() then aardwolf_interface.ui.show() else aardwolf_interface.ui.hide() end
end
aardwolf_interface.lifecycle.initialize()
