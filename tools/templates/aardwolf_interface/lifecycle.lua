aardwolf_interface.lifecycle = aardwolf_interface.lifecycle or {}
local legacy_base_pending = aardwolf_interface.lifecycle.initialized == nil
  and aardwolf_interface.ui and aardwolf_interface.ui.root ~= nil
local legacy_base_right = legacy_base_pending and tonumber(aardwolf_interface.ui.base_right) or nil
local legacy_base_bottom = legacy_base_pending and tonumber(aardwolf_interface.ui.base_bottom) or nil
aardwolf_interface.lifecycle.handlers = aardwolf_interface.lifecycle.handlers or {}
aardwolf_interface.lifecycle.initialized = aardwolf_interface.lifecycle.initialized == true
aardwolf_interface.lifecycle.quest_requested = aardwolf_interface.lifecycle.quest_requested == true
local USER="aardwolf-interface"
local HEARTBEAT="aardwolf-interface::heartbeat"
local LEGACY_USER="aardwolf_interface"
local LEGACY_EVENT_PREFIX="aardwolf-interface::event::"
local LEGACY_EVENTS={
  "char-base","char-vitals","char-maxstats","char-status","char-stats","char-worth",
  "group","room-info","tick","config","install","uninstall","load","resize",
  "connect","disconnect","mapper-loaded","map-import-finished","exit",
}
local LEGACY_TIMERS={
  "aardwolf-interface::timer::render","aardwolf-interface::timer::start",
  "aardwolf-interface::timer::tick-countdown","aardwolf-interface::timer::details-queue",
  "aardwolf-interface::timer::details-capture","aardwolf-interface::timer::details-debounce",
}
local events={
  {"base","gmcp.char.base",aardwolf_interface.protocol.base},{"vitals","gmcp.char.vitals",aardwolf_interface.protocol.vitals},
  {"maxstats","gmcp.char.maxstats",aardwolf_interface.protocol.maxstats},{"status","gmcp.char.status",aardwolf_interface.protocol.status},
  {"stats","gmcp.char.stats",aardwolf_interface.protocol.stats},{"worth","gmcp.char.worth",aardwolf_interface.protocol.worth},
  {"group","gmcp.group",aardwolf_interface.protocol.group},{"room","gmcp.room.info",aardwolf_interface.protocol.room},
  {"quest","gmcp.comm.quest",aardwolf_interface.protocol.quest},{"tick","gmcp.comm.tick",aardwolf_interface.protocol.tick},
  {"map-status","aardwolf-map::status-changed",aardwolf_interface.protocol.map_status},
}
local function disable_legacy_script()
  if type(exists)~="function" or type(disableScript)~="function" then return false end
  local ok,count=pcall(exists,"aardwolf_interface.main","script")
  if not ok or (tonumber(count) or 0)<1 then return false end
  local disabled=pcall(disableScript,"aardwolf_interface.main")
  aardwolf_interface.lifecycle.legacy_script_disabled=disabled
  return disabled
end
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
  -- The heartbeat is the one intentionally repeating named timer. Mudlet's
  -- fifth argument is `repeating`, not `one_shot`.
  registerNamedTimer(USER,HEARTBEAT,1,aardwolf_interface.lifecycle.on_heartbeat,true)
end
function aardwolf_interface.lifecycle.unregister()
  if deleteNamedEventHandler then
    for _,event in ipairs(events) do pcall(deleteNamedEventHandler,USER,"aardwolf-interface::"..event[1]) end
    for _,name in ipairs({"resize","connect","disconnect","exit","uninstall"}) do pcall(deleteNamedEventHandler,USER,"aardwolf-interface::"..name) end
    -- Mudlet can retain static objects from a pre-1.5 package during an
    -- in-place upgrade. Remove that generation's handlers as well so it
    -- cannot reclaim the viewport after the command deck has rebuilt.
    for _,name in ipairs(LEGACY_EVENTS) do pcall(deleteNamedEventHandler,LEGACY_USER,LEGACY_EVENT_PREFIX..name) end
  end
  if deleteNamedTimer then
    pcall(deleteNamedTimer,USER,HEARTBEAT)
    for _,name in ipairs(LEGACY_TIMERS) do pcall(deleteNamedTimer,LEGACY_USER,name) end
  end
end
function aardwolf_interface.lifecycle.shutdown(keep_visibility)
  -- This must be idempotent even when the loaded namespace came from the
  -- legacy monolith, which had no `initialized` flag. Returning early here
  -- leaves its Geyser roots and border claims alive and can hide the console.
  if aardwolf_interface.details and aardwolf_interface.details.stop then pcall(aardwolf_interface.details.stop) end
  aardwolf_interface.lifecycle.unregister()
  if aardwolf_interface.ui and aardwolf_interface.ui.destroy then pcall(aardwolf_interface.ui.destroy) end
  -- A legacy root can retain its in-memory base even if an interrupted
  -- upgrade already erased the settings-file claim. Use that package-owned
  -- evidence once; never guess at or repeatedly reduce a foreign border.
  if legacy_base_pending then
    if legacy_base_right and type(getBorderRight)=="function" and type(setBorderRight)=="function" then
      local ok,current=pcall(getBorderRight)
      if ok and tonumber(current) and tonumber(current)>=legacy_base_right then pcall(setBorderRight,legacy_base_right) end
    end
    if legacy_base_bottom and type(getBorderBottom)=="function" and type(setBorderBottom)=="function" then
      local ok,current=pcall(getBorderBottom)
      if ok and tonumber(current) and tonumber(current)>=legacy_base_bottom then pcall(setBorderBottom,legacy_base_bottom) end
    end
    legacy_base_pending=false
  end
  if aardwolf_interface.actions and aardwolf_interface.actions.cancel then pcall(aardwolf_interface.actions.cancel) end
  aardwolf_interface.lifecycle.initialized=false
  if not keep_visibility and aardwolf_interface.settings.data then aardwolf_interface.settings.data.visible=false end
end
function aardwolf_interface.lifecycle.initialize()
  disable_legacy_script()
  aardwolf_interface.lifecycle.shutdown(true); aardwolf_interface.settings.load(); aardwolf_interface.state.reset_session("disconnected")
  -- A saved claim can survive a Mudlet/profile restart. Restore it only when
  -- the live border still exactly matches what this package applied, then
  -- clear the stale ownership record before calculating the new layout.
  if aardwolf_interface.ui and aardwolf_interface.ui.release_saved_claims then aardwolf_interface.ui.release_saved_claims() end
  aardwolf_interface.ui.build(); aardwolf_interface.details.start(); aardwolf_interface.lifecycle.register(); aardwolf_interface.lifecycle.initialized=true
  aardwolf_interface.lifecycle.hydrate(); if aardwolf_interface.state.connection=="connected" then aardwolf_interface.lifecycle.request_quest(false) end
  if aardwolf_interface.settings.is_visible() then aardwolf_interface.ui.show() else aardwolf_interface.ui.hide() end
end
function aardwolf_interface.lifecycle.repair()
  aardwolf_interface.lifecycle.shutdown(true)
  aardwolf_interface.settings.load()
  if aardwolf_interface.ui and aardwolf_interface.ui.release_saved_claims then aardwolf_interface.ui.release_saved_claims() end
  aardwolf_interface.settings.data.visible=true
  aardwolf_interface.settings.data.collapsed_by_user=false
  aardwolf_interface.settings.save()
  aardwolf_interface.lifecycle.initialize()
  return aardwolf_interface.ui and aardwolf_interface.ui.root ~= nil
end
aardwolf_interface.lifecycle.initialize()
