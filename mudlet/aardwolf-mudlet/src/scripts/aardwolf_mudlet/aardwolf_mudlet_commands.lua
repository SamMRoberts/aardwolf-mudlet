aardwolf_mudlet.commands = aardwolf_mudlet.commands or {}
local function message(value) if aardwolf_mudlet.ui and aardwolf_mudlet.ui.message then aardwolf_mudlet.ui.message(value) else cecho("\n<cyan>[aardwolf-mudlet]<reset> "..value) end end

function aardwolf_mudlet.commands.show() aardwolf_mudlet.settings.update("visible",true); aardwolf_mudlet.settings.data.collapsed_by_user=false; aardwolf_mudlet.ui.show() end
function aardwolf_mudlet.commands.hide() aardwolf_mudlet.settings.update("visible",false); aardwolf_mudlet.ui.hide() end
function aardwolf_mudlet.commands.status()
  local data=aardwolf_mudlet.settings.data
  local layout=aardwolf_mudlet.ui and aardwolf_mudlet.ui.layout or {}
  message(string.format("visible=%s tab=%s width=%d theme=%s density=%s scale=%d%% dock-pinned=%s dock-width=%s suspended=%s console=%s initialization-deferred=%s connection=%s",tostring(data.visible),data.active_tab,data.workspace_width,data.theme,data.density,data.text_scale,tostring(data.inspector_pinned),tostring(layout.dock or 0),tostring(layout.suspended==true),tostring(layout.window_width and math.max(0,layout.window_width-layout.base-layout.total) or "--"),tostring(aardwolf_mudlet.lifecycle and aardwolf_mudlet.lifecycle.deferred==true),aardwolf_mudlet.state.connection))
end
function aardwolf_mudlet.commands.repair()
  local ok=aardwolf_mudlet.lifecycle and aardwolf_mudlet.lifecycle.repair and aardwolf_mudlet.lifecycle.repair()
  message(ok and "Interface viewport repaired and rebuilt." or "Interface repair could not build Geyser; use 'aard status' for text output.")
end
function aardwolf_mudlet.commands.set_tab(tab)
  if tab=="map" then tab="overview" end
  if ({overview=true,character=true,group=true,inventory=true,chat=true})[tab] then aardwolf_mudlet.ui.set_tab(tab) end
end
aardwolf_mudlet.commands.select_tab=aardwolf_mudlet.commands.set_tab
function aardwolf_mudlet.commands.toggle_pin(tab)
  local data=aardwolf_mudlet.settings.data
  if tab=="map" then tab="overview" end
  if tab=="off" then data.inspector_pinned=false elseif tab then data.inspector_pinned=true; data.active_tab=tab else data.inspector_pinned=not data.inspector_pinned end
  aardwolf_mudlet.settings.save(); aardwolf_mudlet.ui.reflow(); aardwolf_mudlet.ui.request_render()
end
function aardwolf_mudlet.commands.details_show() aardwolf_mudlet.commands.set_tab("inventory"); aardwolf_mudlet.commands.toggle_pin("inventory") end
function aardwolf_mudlet.commands.details_hide() aardwolf_mudlet.commands.toggle_pin("off"); if aardwolf_mudlet.settings.data.active_tab=="inventory" then aardwolf_mudlet.commands.set_tab("overview") end end
function aardwolf_mudlet.commands.details_toggle() if aardwolf_mudlet.settings.data.inspector_pinned or aardwolf_mudlet.settings.data.active_tab=="inventory" then aardwolf_mudlet.commands.details_hide() else aardwolf_mudlet.commands.details_show() end end
function aardwolf_mudlet.commands.details_refresh() aardwolf_mudlet.details.refresh() end
function aardwolf_mudlet.commands.details_status() local value=aardwolf_mudlet.state.value("details"); message(string.format("inventory status=%s generation=%d equipment=%d bags=%d",aardwolf_mudlet.state.envelope("details").status,value.generation or 0,#(value.equipment or {}),#(value.bags or {}))) end
function aardwolf_mudlet.commands.toggle_palette(mode)
  local value=mode=="show" or (mode~="hide" and not aardwolf_mudlet.settings.data.palette_open)
  aardwolf_mudlet.settings.update("palette_open",value); aardwolf_mudlet.ui.toggle_palette(value)
end
function aardwolf_mudlet.commands.select_inventory_tab(tab) if tab=="equipment" or tab=="bags" then aardwolf_mudlet.settings.update("inventory_tab",tab); aardwolf_mudlet.ui.request_render() end end
function aardwolf_mudlet.commands.toggle_empty() aardwolf_mudlet.settings.update("show_empty_slots",not aardwolf_mudlet.settings.data.show_empty_slots); aardwolf_mudlet.ui.request_render() end
function aardwolf_mudlet.commands.set_theme(theme) if theme=="obsidian" or theme=="high-contrast" then aardwolf_mudlet.settings.update("theme",theme); aardwolf_mudlet.ui.theme(); if aardwolf_mudlet.map and aardwolf_mudlet.map.set_palette and aardwolf_mudlet.settings.data.sync_map_theme then aardwolf_mudlet.map.set_palette(theme) end end end
function aardwolf_mudlet.commands.toggle_theme() aardwolf_mudlet.commands.set_theme(aardwolf_mudlet.settings.data.theme=="obsidian" and "high-contrast" or "obsidian") end
function aardwolf_mudlet.commands.set_density(value) if value=="compact" or value=="comfortable" then aardwolf_mudlet.settings.update("density",value); aardwolf_mudlet.ui.reflow() end end
function aardwolf_mudlet.commands.set_scale(value) value=tonumber(value); if ({[90]=true,[100]=true,[115]=true,[130]=true})[value] then aardwolf_mudlet.settings.update("text_scale",value); aardwolf_mudlet.ui.reflow() end end

local function summary_lines(section)
  local envelope=aardwolf_mudlet.state.envelope(section); local rows={section..": "..envelope.status}; local value=envelope.value or {}
  local count=0
  local function walk(prefix,item,depth)
    if count>=80 then return end
    if type(item)~="table" or depth<=0 then rows[#rows+1]=string.format("  %s: %s",prefix,tostring(item)); count=count+1; return end
    local keys={}; for key in pairs(item) do keys[#keys+1]=key end; table.sort(keys,function(left,right) return tostring(left)<tostring(right) end)
    for _,key in ipairs(keys) do walk(prefix=="" and tostring(key) or prefix.."."..tostring(key),item[key],depth-1); if count>=80 then break end end
  end
  walk("",value,3)
  if envelope.error then rows[#rows+1]="  error: "..envelope.error end; return rows
end
function aardwolf_mudlet.commands.summary(section)
  local map={room={"room"},character={"base","vitals","maxstats","status","stats","worth"},quest={"quest"},group={"group"},equipment={"details"},bags={"details"},actions={}}
  local sections=section=="all" and {"room","base","vitals","maxstats","status","stats","worth","quest","group","details","map"} or map[section]
  local rows={}
  if section=="actions" then for _,action in ipairs(aardwolf_mudlet.actions.context()) do rows[#rows+1]=action.id..": "..action.label end; for _,action in ipairs(aardwolf_mudlet.actions.custom()) do rows[#rows+1]=action.id..": "..action.label end
  elseif section=="equipment" or section=="bags" then
    local envelope=aardwolf_mudlet.state.envelope("details"); rows[#rows+1]=section..": "..envelope.status
    local selected=(envelope.value or {})[section] or {}; local keys={}; for key in pairs(selected) do keys[#keys+1]=key end; table.sort(keys,function(left,right) return tostring(left)<tostring(right) end)
    for _,key in ipairs(keys) do local item=selected[key]; rows[#rows+1]=string.format("  %s: %s%s",tostring(key),tostring(item.name or "Unknown"),item.used_weight and (" "..tostring(item.used_weight).."/"..tostring(item.max_weight or "--").." weight") or "") end
  elseif sections then for _,name in ipairs(sections) do for _,row in ipairs(summary_lines(name)) do rows[#rows+1]=row end end end
  message(table.concat(rows,"\n"))
end

local function result_message(ok, value, success)
  message(ok and (success or tostring(value or "Done.")) or tostring(value or "Command failed."))
  return ok
end

function aardwolf_mudlet.commands.action_add(label,command,category) local ok,error_message=aardwolf_mudlet.actions.add(label,command,category); message(ok and "Custom action added." or error_message) end
function aardwolf_mudlet.commands.action_edit(id,label,command,category) message(aardwolf_mudlet.actions.update(id,label,command,category) and "Custom action updated." or "Custom action was not updated.") end
function aardwolf_mudlet.commands.action_remove(id) message(aardwolf_mudlet.actions.remove(id) and "Custom action removed." or "Unknown custom action.") end
function aardwolf_mudlet.commands.action_move(id,order) message(aardwolf_mudlet.actions.move(id,order) and "Custom action moved." or "Unable to move custom action.") end
function aardwolf_mudlet.commands.action_list() aardwolf_mudlet.commands.summary("actions") end
function aardwolf_mudlet.commands.action_editor_submit(label,command,category)
  if not label and aardwolf_mudlet.ui and aardwolf_mudlet.ui.editor_value then label,category,command=aardwolf_mudlet.ui.editor_value() end
  if not label or not command then message("Enter Label | Category | command in the custom action editor."); return false end
  local ok,error_message=aardwolf_mudlet.actions.add(label,command,category); message(ok and "Custom action added." or error_message); if ok then aardwolf_mudlet.ui.editor_open=false; aardwolf_mudlet.ui.request_render() end; return ok
end

function aardwolf_mudlet.commands.tick_status()
  local envelope=aardwolf_mudlet.state.envelope("tick")
  message(string.format("tick status=%s remaining=%s",tostring(envelope.status),tostring(aardwolf_mudlet.state.tick_remaining() or "unavailable")))
end

function aardwolf_mudlet.commands.legacy_tts(input)
  local value=tostring(input or ""):match("^%s*(.-)%s*$")
  local lower=value:lower()
  if lower=="sapi on" then return aardwolf_mudlet.commands.dispatch("tts on") end
  if lower=="sapi off" then return aardwolf_mudlet.commands.dispatch("tts off") end
  if lower=="sapi clear" or lower=="sapi skip" or lower=="tts_stop" then return aardwolf_mudlet.commands.dispatch("tts clear") end
  local spoken=value:match("^[Ss][Aa][Pp][Ii]%s+[Ss][Aa][Yy]%s+(.+)$") or value:match("^tts_note%s+(.+)$") or value:match("^tts_interrupt%s+(.+)$")
  if spoken then return result_message(aardwolf_mudlet.accessibility.say(spoken,true)) end
  local rate=value:match("^[Ss][Aa][Pp][Ii]%s+[Rr][Aa][Tt][Ee]%s+([%-%.%d]+)$")
  if rate then return result_message(aardwolf_mudlet.accessibility.set_rate(rate)) end
  if lower=="sapi faster" or lower=="sapi slower" then
    local current=tonumber(aardwolf_mudlet.settings.data.accessibility.rate) or 0
    return result_message(aardwolf_mudlet.accessibility.set_rate(current+(lower=="sapi faster" and 0.1 or -0.1)))
  end
  local voice=value:match("^[Ss][Aa][Pp][Ii]%s+[Vv][Oo][Ii][Cc][Ee]%s+(.+)$")
  if voice then return result_message(aardwolf_mudlet.accessibility.set_voice(voice)) end
  if lower=="sapi list voices" then return message(table.concat(aardwolf_mudlet.accessibility.voices(),", ")) end
  if lower=="sapi test" then return result_message(aardwolf_mudlet.accessibility.say("Aardwolf Mudlet text to speech test.",true)) end
  return message(aardwolf_mudlet.accessibility.status())
end

local function call_result(callback, success, ...)
  local ok, value = callback(...)
  return result_message(ok, value, success)
end

local function boolean_word(value)
  if value == "on" or value == "show" or value == "true" then return true end
  if value == "off" or value == "hide" or value == "false" then return false end
end

function aardwolf_mudlet.commands.help()
  if aardwolf_mudlet.help and aardwolf_mudlet.help.summary then message(aardwolf_mudlet.help.summary()) end
end

function aardwolf_mudlet.commands.dispatch(argument)
  local text = tostring(argument or ""):match("^%s*(.-)%s*$")
  if text == "" or text == "status" then return aardwolf_mudlet.commands.status() end
  if text == "help" then return aardwolf_mudlet.commands.help() end
  local family, rest = text:match("^(%S+)%s*(.-)$")
  family = family and family:lower()
  if family == "ui" then
    if rest == "show" then return aardwolf_mudlet.commands.show() end
    if rest == "hide" then return aardwolf_mudlet.commands.hide() end
    if rest == "status" then return aardwolf_mudlet.commands.status() end
    local key, value = rest:match("^(theme|density|scale)%s+(%S+)$")
    if key == "theme" then return aardwolf_mudlet.commands.set_theme(value) end
    if key == "density" then return aardwolf_mudlet.commands.set_density(value) end
    if key == "scale" then return aardwolf_mudlet.commands.set_scale(value) end
  elseif family == "map" and aardwolf_mudlet.map then
    if rest == "import" then return call_result(aardwolf_mudlet.map.start_import, "Map import started or resumed.") end
    if rest == "import cancel" then return call_result(aardwolf_mudlet.map.cancel_import, "Map import cancellation requested.") end
    if rest == "status" then local value=aardwolf_mudlet.map.status(); return message(type(value)=="table" and string.format("map phase=%s rooms=%s exits=%s imported-exits=%s collisions=%s",tostring(value.phase),tostring(value.room_index),tostring(value.exit_index),tostring(value.imported_exits),tostring(value.collision_count)) or tostring(value)) end
    if rest == "center" then return call_result(aardwolf_mudlet.map.center_current, "Map centered.") end
    local palette = rest:match("^palette%s+(source|obsidian|high%-contrast)$")
    if palette then return call_result(aardwolf_mudlet.map.set_palette, "Map palette updated.", palette) end
    local zoom = rest:match("^zoom%s+(in|out)$")
    if zoom then return call_result(aardwolf_mudlet.map.zoom, "Map zoom updated.", zoom=="in" and -1 or 1) end
  elseif family == "inventory" then
    if rest == "refresh" then aardwolf_mudlet.details.refresh(); return message("Inventory refresh started.") end
    if rest == "status" then return aardwolf_mudlet.commands.details_status() end
  elseif family == "capture" then
    if rest == "copy" then return result_message(aardwolf_mudlet.capture.copy()) end
    return call_result(aardwolf_mudlet.capture.start, "Tagged command capture started.", rest)
  elseif family == "chat" then
    if rest == "show" then aardwolf_mudlet.commands.set_tab("chat"); return end
    if rest == "hide" then aardwolf_mudlet.commands.set_tab("overview"); return end
    if rest == "status" then local buffer=aardwolf_mudlet.chat.active_buffer(); return message(string.format("chat tab=%s messages=%d preserve-main=%s logging=%s",aardwolf_mudlet.chat.active_name(),#buffer.messages,tostring(aardwolf_mudlet.settings.data.chat.preserve_main),tostring(aardwolf_mudlet.settings.data.chat.logging))) end
    if rest == "clear" then return result_message(aardwolf_mudlet.chat.clear(), nil, "Active chat tab cleared.") end
    local mode = rest:match("^preserve%s+(on|off)$"); if mode then return result_message(aardwolf_mudlet.chat.set_preserve(mode=="on")) end
    mode = rest:match("^log%s+(on|off)$"); if mode then return result_message(aardwolf_mudlet.chat.set_logging(mode=="on")) end
    local name = rest:match("^tab%s+select%s+(.+)$"); if name then return result_message(aardwolf_mudlet.chat.select(name)) end
    local add_name, filters = rest:match("^tab%s+add%s+([^|]+)|(.+)$"); if add_name then return result_message(aardwolf_mudlet.chat.add_tab(add_name,filters)) end
    local old,new = rest:match("^tab%s+rename%s+([^|]+)|(.+)$"); if old then return result_message(aardwolf_mudlet.chat.rename_tab(old,new)) end
    local move_name,position = rest:match("^tab%s+move%s+([^|]+)|(%d+)$"); if move_name then return result_message(aardwolf_mudlet.chat.move_tab(move_name,position)) end
    name = rest:match("^tab%s+remove%s+(.+)$"); if name then return result_message(aardwolf_mudlet.chat.remove_tab(name)) end
    local filter_name, values = rest:match("^filter%s+([^|]+)|(.+)$"); if filter_name then return result_message(aardwolf_mudlet.chat.set_filters(filter_name,values)) end
    local limit = rest:match("^limit%s+(%d+)$"); if limit then return result_message(aardwolf_mudlet.chat.set_limit(limit)) end
    if rest == "copy" then return result_message(aardwolf_mudlet.chat.copy_active(false)) end
    if rest == "copy color" then return result_message(aardwolf_mudlet.chat.copy_active(true)) end
    local url = rest:match("^open%s+(.+)$"); if url then return result_message(aardwolf_mudlet.chat.open_url(url)) end
  elseif family == "action" then
    if rest == "list" then return aardwolf_mudlet.commands.action_list() end
    local label, category, command = rest:match("^add%s+([^|]+)|([^|]+)|(.+)$"); if label then return aardwolf_mudlet.commands.action_add(label,command,category) end
    local id,new_label,new_category,new_command = rest:match("^edit%s+(custom%-%d+)|([^|]+)|([^|]+)|(.+)$"); if id then return aardwolf_mudlet.commands.action_edit(id,new_label,new_command,new_category) end
    id = rest:match("^remove%s+(custom%-%d+)$"); if id then return aardwolf_mudlet.commands.action_remove(id) end
    local order; id,order = rest:match("^move%s+(custom%-%d+)%s+(%d+)$"); if id then return aardwolf_mudlet.commands.action_move(id,order) end
  elseif family == "tts" then
    local value = boolean_word(rest); if value ~= nil then return result_message(aardwolf_mudlet.accessibility.set_enabled(value)) end
    if rest == "clear" then return result_message(aardwolf_mudlet.accessibility.clear()) end
    if rest == "status" then return message(aardwolf_mudlet.accessibility.status()) end
    local say = rest:match("^say%s+(.+)$"); if say then return result_message(aardwolf_mudlet.accessibility.say(say,true)) end
    local rate = rest:match("^rate%s+([%-%.%d]+)$"); if rate then return result_message(aardwolf_mudlet.accessibility.set_rate(rate)) end
    local voice = rest:match("^voice%s+(.+)$"); if voice then return result_message(aardwolf_mudlet.accessibility.set_voice(voice)) end
  elseif family == "sound" then
    local value = boolean_word(rest); if value ~= nil then return result_message(aardwolf_mudlet.sound.set_enabled(value)) end
    if rest == "status" then return message(aardwolf_mudlet.sound.status()) end
    local event,file,volume = rest:match("^map%s+([^|]+)|([^|]+)|(%d+)$")
    if not event then event,file = rest:match("^map%s+([^|]+)|(.+)$") end
    if event then return call_result(aardwolf_mudlet.sound.map, nil, event,file,volume) end
    event = rest:match("^remove%s+(.+)$"); if event then return result_message(aardwolf_mudlet.sound.remove(event)) end
  elseif family == "data" then
    if rest == "status" then return message(aardwolf_mudlet.data.status()) end
    if rest == "export" then return result_message(aardwolf_mudlet.data.export()) end
    if rest == "import" then return result_message(aardwolf_mudlet.data.import()) end
    if rest == "backup" then return result_message(aardwolf_mudlet.data.backup()) end
    local backup_mode=rest:match("^backup%s+(on|off)$"); if backup_mode then return result_message(aardwolf_mudlet.data.set_auto_backup(backup_mode=="on")) end
  end
  message("Unknown aard command. Use 'aard help'.")
end
