aardwolf_interface.commands = aardwolf_interface.commands or {}
local function message(value) if aardwolf_interface.ui and aardwolf_interface.ui.message then aardwolf_interface.ui.message(value) else cecho("\n<cyan>[aardwolf-interface]<reset> "..value) end end

function aardwolf_interface.commands.show() aardwolf_interface.settings.update("visible",true); aardwolf_interface.settings.data.collapsed_by_user=false; aardwolf_interface.ui.show() end
function aardwolf_interface.commands.hide() aardwolf_interface.settings.update("visible",false); aardwolf_interface.ui.hide() end
function aardwolf_interface.commands.status()
  local data=aardwolf_interface.settings.data
  message(string.format("visible=%s tab=%s width=%d theme=%s density=%s scale=%d%% inspector=%s connection=%s",tostring(data.visible),data.active_tab,data.workspace_width,data.theme,data.density,data.text_scale,tostring(data.inspector_pinned),aardwolf_interface.state.connection))
end
function aardwolf_interface.commands.set_tab(tab) if ({map=true,character=true,group=true,inventory=true})[tab] then aardwolf_interface.settings.update("active_tab",tab); aardwolf_interface.ui.set_tab(tab) end end
aardwolf_interface.commands.select_tab=aardwolf_interface.commands.set_tab
function aardwolf_interface.commands.toggle_pin(tab)
  local data=aardwolf_interface.settings.data
  if tab=="off" then data.inspector_pinned=false elseif tab then data.inspector_pinned=true; data.inspector_tab=tab else data.inspector_pinned=not data.inspector_pinned end
  data.details_visible=data.inspector_pinned; aardwolf_interface.settings.save(); aardwolf_interface.ui.reflow()
end
function aardwolf_interface.commands.details_show() aardwolf_interface.commands.set_tab("inventory"); aardwolf_interface.commands.toggle_pin("inventory") end
function aardwolf_interface.commands.details_hide() aardwolf_interface.commands.toggle_pin("off"); if aardwolf_interface.settings.data.active_tab=="inventory" then aardwolf_interface.commands.set_tab("map") end end
function aardwolf_interface.commands.details_toggle() if aardwolf_interface.settings.data.inspector_pinned or aardwolf_interface.settings.data.active_tab=="inventory" then aardwolf_interface.commands.details_hide() else aardwolf_interface.commands.details_show() end end
function aardwolf_interface.commands.details_refresh() aardwolf_interface.details.refresh() end
function aardwolf_interface.commands.details_status() local value=aardwolf_interface.state.value("details"); message(string.format("inventory status=%s generation=%d equipment=%d bags=%d",aardwolf_interface.state.envelope("details").status,value.generation or 0,#(value.equipment or {}),#(value.bags or {}))) end
function aardwolf_interface.commands.toggle_palette(mode)
  local value=mode=="show" or (mode~="hide" and not aardwolf_interface.settings.data.palette_open)
  aardwolf_interface.settings.update("palette_open",value); aardwolf_interface.ui.toggle_palette(value)
end
function aardwolf_interface.commands.select_inventory_tab(tab) if tab=="equipment" or tab=="bags" then aardwolf_interface.settings.update("inventory_tab",tab); aardwolf_interface.ui.request_render() end end
function aardwolf_interface.commands.toggle_empty() aardwolf_interface.settings.update("show_empty_slots",not aardwolf_interface.settings.data.show_empty_slots); aardwolf_interface.ui.request_render() end
function aardwolf_interface.commands.set_theme(theme) if theme=="obsidian" or theme=="high-contrast" then aardwolf_interface.settings.update("theme",theme); aardwolf_interface.ui.theme(); if aardwolf_map and aardwolf_map.commands and aardwolf_map.commands.set_palette and aardwolf_interface.settings.data.sync_map_theme then aardwolf_map.commands.set_palette(theme) end end end
function aardwolf_interface.commands.toggle_theme() aardwolf_interface.commands.set_theme(aardwolf_interface.settings.data.theme=="obsidian" and "high-contrast" or "obsidian") end
function aardwolf_interface.commands.set_density(value) if value=="compact" or value=="comfortable" then aardwolf_interface.settings.update("density",value); aardwolf_interface.ui.reflow() end end
function aardwolf_interface.commands.set_scale(value) value=tonumber(value); if ({[90]=true,[100]=true,[115]=true,[130]=true})[value] then aardwolf_interface.settings.update("text_scale",value); aardwolf_interface.ui.reflow() end end

local function summary_lines(section)
  local envelope=aardwolf_interface.state.envelope(section); local rows={section..": "..envelope.status}; local value=envelope.value or {}
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
function aardwolf_interface.commands.summary(section)
  local map={room={"room"},character={"base","vitals","maxstats","status","stats","worth"},quest={"quest"},group={"group"},equipment={"details"},bags={"details"},actions={}}
  local sections=section=="all" and {"room","base","vitals","maxstats","status","stats","worth","quest","group","details","map"} or map[section]
  local rows={}
  if section=="actions" then for _,action in ipairs(aardwolf_interface.actions.context()) do rows[#rows+1]=action.id..": "..action.label end; for _,action in ipairs(aardwolf_interface.actions.custom()) do rows[#rows+1]=action.id..": "..action.label end
  elseif section=="equipment" or section=="bags" then
    local envelope=aardwolf_interface.state.envelope("details"); rows[#rows+1]=section..": "..envelope.status
    local selected=(envelope.value or {})[section] or {}; local keys={}; for key in pairs(selected) do keys[#keys+1]=key end; table.sort(keys,function(left,right) return tostring(left)<tostring(right) end)
    for _,key in ipairs(keys) do local item=selected[key]; rows[#rows+1]=string.format("  %s: %s%s",tostring(key),tostring(item.name or "Unknown"),item.used_weight and (" "..tostring(item.used_weight).."/"..tostring(item.max_weight or "--").." weight") or "") end
  elseif sections then for _,name in ipairs(sections) do for _,row in ipairs(summary_lines(name)) do rows[#rows+1]=row end end end
  message(table.concat(rows,"\n"))
end

function aardwolf_interface.commands.action_add(label,command,category) local ok,error_message=aardwolf_interface.actions.add(label,command,category); message(ok and "Custom action added." or error_message) end
function aardwolf_interface.commands.action_edit(id,label,command,category) message(aardwolf_interface.actions.update(id,label,command,category) and "Custom action updated." or "Custom action was not updated.") end
function aardwolf_interface.commands.action_remove(id) message(aardwolf_interface.actions.remove(id) and "Custom action removed." or "Unknown custom action.") end
function aardwolf_interface.commands.action_move(id,order) message(aardwolf_interface.actions.move(id,order) and "Custom action moved." or "Unable to move custom action.") end
function aardwolf_interface.commands.action_list() aardwolf_interface.commands.summary("actions") end
function aardwolf_interface.commands.action_editor_submit(label,command,category)
  if not label and aardwolf_interface.ui and aardwolf_interface.ui.editor_value then label,category,command=aardwolf_interface.ui.editor_value() end
  if not label or not command then message("Enter Label | Category | command in the custom action editor."); return false end
  local ok,error_message=aardwolf_interface.actions.add(label,command,category); message(ok and "Custom action added." or error_message); if ok then aardwolf_interface.ui.editor_open=false; aardwolf_interface.ui.request_render() end; return ok
end
