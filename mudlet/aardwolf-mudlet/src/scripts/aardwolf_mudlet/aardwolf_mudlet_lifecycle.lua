aardwolf_mudlet.lifecycle = aardwolf_mudlet.lifecycle or {}
local legacy_base_pending = aardwolf_mudlet.lifecycle.initialized == nil
  and aardwolf_mudlet.ui and aardwolf_mudlet.ui.root ~= nil
local legacy_base_right = legacy_base_pending and tonumber(aardwolf_mudlet.ui.base_right) or nil
local legacy_base_bottom = legacy_base_pending and tonumber(aardwolf_mudlet.ui.base_bottom) or nil
aardwolf_mudlet.lifecycle.handlers = aardwolf_mudlet.lifecycle.handlers or {}
aardwolf_mudlet.lifecycle.initialized = aardwolf_mudlet.lifecycle.initialized == true
aardwolf_mudlet.lifecycle.quest_requested = aardwolf_mudlet.lifecycle.quest_requested == true
aardwolf_mudlet.lifecycle.character_requested = aardwolf_mudlet.lifecycle.character_requested == true
local USER="aardwolf-mudlet"
local HEARTBEAT="aardwolf-mudlet::heartbeat"
local CONNECT_TIMER="aardwolf-mudlet::connect-hydrate"
local LEGACY_USER="aardwolf_mudlet"
local LEGACY_EVENT_PREFIX="aardwolf-mudlet::event::"
local LEGACY_EVENTS={
  "char-base","char-vitals","char-maxstats","char-status","char-stats","char-worth",
  "group","room-info","tick","config","install","uninstall","load","resize",
  "connect","disconnect","mapper-loaded","map-import-finished","exit",
}
local LEGACY_TIMERS={
  "aardwolf-mudlet::timer::render","aardwolf-mudlet::timer::start",
  "aardwolf-mudlet::timer::tick-countdown","aardwolf-mudlet::timer::details-queue",
  "aardwolf-mudlet::timer::details-capture","aardwolf-mudlet::timer::details-debounce",
}
local events={
  {"base","gmcp.char.base",aardwolf_mudlet.protocol.base},{"vitals","gmcp.char.vitals",aardwolf_mudlet.protocol.vitals},
  {"maxstats","gmcp.char.maxstats",aardwolf_mudlet.protocol.maxstats},{"status","gmcp.char.status",aardwolf_mudlet.protocol.status},
  {"stats","gmcp.char.stats",aardwolf_mudlet.protocol.stats},{"worth","gmcp.char.worth",aardwolf_mudlet.protocol.worth},
  {"group","gmcp.group",aardwolf_mudlet.protocol.group},{"room","gmcp.room.info",aardwolf_mudlet.protocol.room},
  {"quest","gmcp.comm.quest",aardwolf_mudlet.protocol.quest},{"tick","gmcp.comm.tick",aardwolf_mudlet.protocol.tick},
  {"channel","gmcp.comm.channel",aardwolf_mudlet.protocol.channel},
  {"map-status","aardwolf-mudlet::map-status-changed",aardwolf_mudlet.protocol.map_status},
}
local function legacy_conflict()
  local conflicts={}
  for _,candidate in ipairs({"aardwolf_interface","aardwolf_map","aardwolf_character","aardwolf_chat"}) do
    if type(rawget(_G,candidate))=="table" then conflicts[#conflicts+1]=candidate end
  end
  return #conflicts>0,conflicts
end
local function connected()
  if type(getConnectionInfo)~="function" then return false end
  local ok,info,port,is_connected=pcall(getConnectionInfo); if not ok then return false end
  if type(is_connected)=="boolean" then return is_connected end
  if type(info)=="table" then return info.connected==true or info.state=="connected" or info[1]==true end
  return info==true
end
function aardwolf_mudlet.lifecycle.center_map()
  if aardwolf_mudlet.map and aardwolf_mudlet.map.center_current then return aardwolf_mudlet.map.center_current() end
  return false,"The packaged map importer is unavailable."
end
function aardwolf_mudlet.lifecycle.request_quest(force)
  if aardwolf_mudlet.state.connection~="connected" or (aardwolf_mudlet.lifecycle.quest_requested and not force) then return false end
  aardwolf_mudlet.lifecycle.quest_requested=true
  if sendGMCP then sendGMCP("request quest"); return true end
  return false
end
function aardwolf_mudlet.lifecycle.request_character(force)
  if aardwolf_mudlet.state.connection~="connected" or (aardwolf_mudlet.lifecycle.character_requested and not force) then return false end
  aardwolf_mudlet.lifecycle.character_requested=true
  if sendGMCP then sendGMCP("request char"); return true end
  return false
end
function aardwolf_mudlet.lifecycle.on_connect()
  aardwolf_mudlet.state.reset_session("connected"); aardwolf_mudlet.lifecycle.quest_requested=false; aardwolf_mudlet.lifecycle.character_requested=false
  if deleteNamedTimer then pcall(deleteNamedTimer,USER,CONNECT_TIMER) end
  registerNamedTimer(USER,CONNECT_TIMER,0.5,function() aardwolf_mudlet.lifecycle.request_character(false); aardwolf_mudlet.lifecycle.request_quest(false) end,false)
  aardwolf_mudlet.ui.request_render()
end
function aardwolf_mudlet.lifecycle.on_disconnect()
  if deleteNamedTimer then pcall(deleteNamedTimer,USER,CONNECT_TIMER) end
  aardwolf_mudlet.details.stop("Disconnected")
  if aardwolf_mudlet.capture then aardwolf_mudlet.capture.cancel("Disconnected") end
  aardwolf_mudlet.state.reset_session("disconnected")
  aardwolf_mudlet.lifecycle.quest_requested=false
  aardwolf_mudlet.lifecycle.character_requested=false
  aardwolf_mudlet.ui.request_render()
end
function aardwolf_mudlet.lifecycle.on_resize() aardwolf_mudlet.ui.reflow() end
function aardwolf_mudlet.lifecycle.on_heartbeat()
  local now=os.time()
  for name,envelope in pairs(aardwolf_mudlet.state.sections or {}) do
    if name~="details" and envelope.status=="current" and envelope.received_at and now-envelope.received_at>180 then envelope.status="stale"; envelope.error="No update received for 180 seconds" end
  end
  if aardwolf_mudlet.capture and aardwolf_mudlet.capture.expire then aardwolf_mudlet.capture.expire() end
  aardwolf_mudlet.ui.request_render()
end
function aardwolf_mudlet.lifecycle.on_exit() aardwolf_mudlet.lifecycle.shutdown(true) end
function aardwolf_mudlet.lifecycle.on_uninstall(_,name) if tostring(name)=="aardwolf-mudlet" then aardwolf_mudlet.lifecycle.shutdown(false) end end
function aardwolf_mudlet.lifecycle.on_profile_save()
  if aardwolf_mudlet.data and aardwolf_mudlet.data.on_profile_save then pcall(aardwolf_mudlet.data.on_profile_save) end
end
function aardwolf_mudlet.lifecycle.hydrate()
  if not connected() then return end
  aardwolf_mudlet.state.connection="connected"
  for _,event in ipairs(events) do if event[2]:match("^gmcp%.") and event[2]~="gmcp.comm.tick" then pcall(event[3]) end end
  pcall(aardwolf_mudlet.protocol.map_status)
end
function aardwolf_mudlet.lifecycle.register()
  for _,event in ipairs(events) do registerNamedEventHandler(USER,"aardwolf-mudlet::"..event[1],event[2],event[3]) end
  registerNamedEventHandler(USER,"aardwolf-mudlet::resize","sysWindowResizeEvent",aardwolf_mudlet.lifecycle.on_resize)
  registerNamedEventHandler(USER,"aardwolf-mudlet::connect","sysConnectionEvent",aardwolf_mudlet.lifecycle.on_connect)
  registerNamedEventHandler(USER,"aardwolf-mudlet::disconnect","sysDisconnectionEvent",aardwolf_mudlet.lifecycle.on_disconnect)
  registerNamedEventHandler(USER,"aardwolf-mudlet::exit","sysExitEvent",aardwolf_mudlet.lifecycle.on_exit)
  registerNamedEventHandler(USER,"aardwolf-mudlet::uninstall","sysUninstallPackage",aardwolf_mudlet.lifecycle.on_uninstall)
  registerNamedEventHandler(USER,"aardwolf-mudlet::profile-save","sysProfileSaveEvent",aardwolf_mudlet.lifecycle.on_profile_save)
  -- The heartbeat is the one intentionally repeating named timer. Mudlet's
  -- fifth argument is `repeating`, not `one_shot`.
  registerNamedTimer(USER,HEARTBEAT,1,aardwolf_mudlet.lifecycle.on_heartbeat,true)
end
function aardwolf_mudlet.lifecycle.unregister()
  if deleteNamedEventHandler then
    for _,event in ipairs(events) do pcall(deleteNamedEventHandler,USER,"aardwolf-mudlet::"..event[1]) end
    for _,name in ipairs({"resize","connect","disconnect","exit","uninstall","profile-save"}) do pcall(deleteNamedEventHandler,USER,"aardwolf-mudlet::"..name) end
    -- Mudlet can retain static objects from a pre-1.5 package during an
    -- in-place upgrade. Remove that generation's handlers as well so it
    -- cannot reclaim the viewport after the command deck has rebuilt.
    for _,name in ipairs(LEGACY_EVENTS) do pcall(deleteNamedEventHandler,LEGACY_USER,LEGACY_EVENT_PREFIX..name) end
  end
  if deleteNamedTimer then
    pcall(deleteNamedTimer,USER,HEARTBEAT)
    pcall(deleteNamedTimer,USER,CONNECT_TIMER)
    for _,name in ipairs(LEGACY_TIMERS) do pcall(deleteNamedTimer,LEGACY_USER,name) end
  end
end
function aardwolf_mudlet.lifecycle.shutdown(keep_visibility)
  -- This must be idempotent even when the loaded namespace came from the
  -- legacy monolith, which had no `initialized` flag. Returning early here
  -- leaves its Geyser roots and border claims alive and can hide the console.
  if aardwolf_mudlet.details and aardwolf_mudlet.details.stop then pcall(aardwolf_mudlet.details.stop) end
  if aardwolf_mudlet.capture and aardwolf_mudlet.capture.cancel then pcall(aardwolf_mudlet.capture.cancel,"Package stopped") end
  if aardwolf_mudlet.chat and aardwolf_mudlet.chat.shutdown then pcall(aardwolf_mudlet.chat.shutdown) end
  if aardwolf_mudlet.sound and aardwolf_mudlet.sound.shutdown then pcall(aardwolf_mudlet.sound.shutdown) end
  if aardwolf_mudlet.map and aardwolf_mudlet.map.shutdown then pcall(aardwolf_mudlet.map.shutdown,"unloaded") end
  aardwolf_mudlet.lifecycle.unregister()
  if aardwolf_mudlet.ui and aardwolf_mudlet.ui.destroy then pcall(aardwolf_mudlet.ui.destroy) end
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
  if aardwolf_mudlet.actions and aardwolf_mudlet.actions.cancel then pcall(aardwolf_mudlet.actions.cancel) end
  aardwolf_mudlet.lifecycle.initialized=false
  if not keep_visibility and aardwolf_mudlet.settings.data then aardwolf_mudlet.settings.data.visible=false end
end
function aardwolf_mudlet.lifecycle.initialize()
  local conflict,names=legacy_conflict()
  if conflict then
    aardwolf_mudlet.lifecycle.deferred=true
    if type(echo)=="function" then echo("\n[aardwolf-mudlet] Initialization deferred: disable legacy Aardwolf packages ("..table.concat(names,", ")..") and reload. Trusted legacy map ownership markers remain reusable.\n") end
    return false
  end
  aardwolf_mudlet.lifecycle.deferred=false
  aardwolf_mudlet.lifecycle.shutdown(true); aardwolf_mudlet.settings.load(); aardwolf_mudlet.state.reset_session("disconnected")
  if aardwolf_mudlet.chat and aardwolf_mudlet.chat.initialize then aardwolf_mudlet.chat.initialize() end
  if aardwolf_mudlet.accessibility and aardwolf_mudlet.accessibility.apply then aardwolf_mudlet.accessibility.apply() end
  if aardwolf_mudlet.map and aardwolf_mudlet.map.initialize then aardwolf_mudlet.map.initialize() end
  -- A saved claim can survive a Mudlet/profile restart. Restore it only when
  -- the live border still exactly matches what this package applied, then
  -- clear the stale ownership record before calculating the new layout.
  if aardwolf_mudlet.ui and aardwolf_mudlet.ui.release_saved_claims then aardwolf_mudlet.ui.release_saved_claims() end
  aardwolf_mudlet.ui.build(); aardwolf_mudlet.lifecycle.register(); aardwolf_mudlet.lifecycle.initialized=true
  aardwolf_mudlet.lifecycle.hydrate(); if aardwolf_mudlet.state.connection=="connected" then aardwolf_mudlet.lifecycle.request_character(false); aardwolf_mudlet.lifecycle.request_quest(false) end
  if aardwolf_mudlet.settings.is_visible() then aardwolf_mudlet.ui.show() else aardwolf_mudlet.ui.hide() end
end
function aardwolf_mudlet.lifecycle.repair()
  aardwolf_mudlet.lifecycle.shutdown(true)
  aardwolf_mudlet.settings.load()
  if aardwolf_mudlet.ui and aardwolf_mudlet.ui.release_saved_claims then aardwolf_mudlet.ui.release_saved_claims() end
  aardwolf_mudlet.settings.data.visible=true
  aardwolf_mudlet.settings.data.collapsed_by_user=false
  aardwolf_mudlet.settings.save()
  aardwolf_mudlet.lifecycle.initialize()
  return aardwolf_mudlet.ui and aardwolf_mudlet.ui.root ~= nil
end
aardwolf_mudlet.lifecycle.initialize()
