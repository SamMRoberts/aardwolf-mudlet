-- Presentation for the Aardwolf Adaptive Command Deck.
-- This module deliberately consumes validated state and delegates behavior; it
-- does not read GMCP or send commands itself.
aardwolf_interface = aardwolf_interface or {}
aardwolf_interface.ui = aardwolf_interface.ui or {}

local ui = aardwolf_interface.ui
local util = aardwolf_interface.util
local settings = aardwolf_interface.settings
local state = aardwolf_interface.state
local actions = aardwolf_interface.actions
local commands = aardwolf_interface.commands
local constants = aardwolf_interface.constants

local PREFIX = "aardwolf-interface::ui::"
local TIMER_USER = "aardwolf_interface"
local RENDER_TIMER = "aardwolf-interface::timer::render"
local WORKSPACE_MIN, WORKSPACE_DEFAULT, WORKSPACE_MAX = 360, 440, 520
local INSPECTOR_MIN, INSPECTOR_MAX = 360, 440
local COLLAPSED_WIDTH, GAP = 44, 6
local HUD_MARGIN, HUD_GAP, HUD_ROW_HEIGHT = 6, 4, 24
local CONTENT_MARGIN = 8
local TABS = {"map", "character", "group", "inventory"}
local SCALE = {[90] = 0.90, [100] = 1.00, [115] = 1.15, [130] = 1.30}

local fallback_themes = {
  obsidian = {
    panel = "#080b12", section = "#111827", elevated = "#172033", border = "#3d4d68",
    text = "#f7f3ff", muted = "#aab6cc", accent = "#55d6ff", jewel = "#c55cff",
    good = "#35e08d", warning = "#ffd166", danger = "#ff5d73", hp = "#35e08d",
    mana = "#55a7ff", moves = "#ffd166", enemy = "#ff5d73", hunger = "#ff9f43",
    thirst = "#45d7ff", track = "#273248", selected = "#263a58",
  },
  ["high-contrast"] = {
    panel = "#000000", section = "#080808", elevated = "#111111", border = "#ffffff",
    text = "#ffffff", muted = "#eeeeee", accent = "#00ffff", jewel = "#ff00ff",
    good = "#00ff66", warning = "#ffff00", danger = "#ff3333", hp = "#00ff66",
    mana = "#00aaff", moves = "#ffff00", enemy = "#ff3333", hunger = "#ff9900",
    thirst = "#00ffff", track = "#444444", selected = "#222222",
  },
}

local function finite(value)
  if util and util.finite then return util.finite(value) end
  local number = tonumber(value)
  if not number or number ~= number or number == math.huge or number == -math.huge then return nil end
  return number
end

local function bounded(value, minimum, maximum, fallback)
  if util and util.bounded then
    local result = util.bounded(value, minimum, maximum)
    if result ~= nil then return result end
  end
  local number = finite(value)
  if not number then return fallback end
  return math.max(minimum, math.min(maximum, number))
end

local function clean(value, maximum)
  if util and util.text then return util.text(value, maximum or 240) end
  if type(value) ~= "string" and type(value) ~= "number" then return nil end
  local result = tostring(value):gsub("[%z\1-\8\11\12\14-\31]", "")
  if #result > (maximum or 240) then result = result:sub(1, maximum or 240) .. "..." end
  return result
end

local function escape(value)
  if util and util.escape then return util.escape(value) end
  local result = clean(value, 2000) or ""
  return result:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
    :gsub('"', "&quot;"):gsub("'", "&#39;")
end

local function display(value)
  if util and util.display then return util.display(value) end
  local number = finite(value)
  if not number then return clean(value, 80) or "--" end
  if number == math.floor(number) then return string.format("%d", number) end
  return string.format("%.1f", number)
end

local function safe(object, method, ...)
  if util and util.safe_call then return util.safe_call(object, method, ...) end
  if type(object) ~= "table" or type(object[method]) ~= "function" then return false end
  return pcall(object[method], object, ...)
end

local function value(section)
  local result = state and state.value and state.value(section)
  return type(result) == "table" and result or {}
end

local function envelope(section)
  local result = state and state.envelope and state.envelope(section)
  return type(result) == "table" and result or {status = "unavailable"}
end

local function data()
  settings.data = settings.data or {}
  return settings.data
end

local function theme()
  local name = data().theme == "high-contrast" and "high-contrast" or "obsidian"
  local configured = constants and constants.themes and constants.themes[name]
  local base = fallback_themes[name]
  if type(configured) ~= "table" then return base end
  return setmetatable(configured, {__index = base})
end

local function font_size(base)
  local selected = tonumber(data().text_scale) or 100
  return math.max(7, math.floor(base * (SCALE[selected] or 1) + 0.5))
end

local function density(compact, comfortable)
  return data().density == "compact" and compact or comfortable
end

local function widget(name)
  return ui.widgets and ui.widgets[name]
end

local function window_size()
  if type(getMainWindowSize) == "function" then
    local ok, width, height = pcall(getMainWindowSize)
    if ok and finite(width) and finite(height) then return width, height end
  end
  return 1200, 800
end

local function tooltip(object, text)
  if not safe(object, "setToolTip", text) then safe(object, "setToolTip", text, 0) end
end

local function new_label(name, parent)
  return Geyser.Label:new({name = PREFIX .. name, x = 0, y = 0, width = 10, height = 10}, parent)
end

local function new_container(name, parent)
  return Geyser.Container:new({name = PREFIX .. name, x = 0, y = 0, width = 10, height = 10}, parent)
end

local function new_button(name, parent, callback, tip)
  local class = type(Geyser.Button) == "table" and Geyser.Button or Geyser.Label
  local button = class:new({name = PREFIX .. name, x = 0, y = 0, width = 10, height = 10}, parent)
  safe(button, "setClickCallback", callback)
  safe(button, "setCursor", "PointingHand")
  if tip then tooltip(button, tip) end
  return button
end

local function set_button_text(object, text)
  if not safe(object, "setText", text) then safe(object, "echo", "<div align='center'>" .. escape(text) .. "</div>") end
end

local function persist()
  if settings and settings.save then settings.save() end
end

function ui.message(message)
  if type(echo) == "function" then echo("\n[aardwolf-interface] " .. tostring(message) .. "\n") end
end

function ui.available()
  return type(Geyser) == "table" and type(Geyser.Container) == "table"
    and type(Geyser.Label) == "table" and type(Geyser.Mapper) == "table"
    and type(getBorderRight) == "function" and type(setBorderRight) == "function"
end

local function layout()
  local window_width, window_height = window_size()
  local current_right = finite(type(getBorderRight) == "function" and getBorderRight() or 0) or 0
  local claim = data().border_claim
  local base = type(claim) == "table" and current_right == claim.applied and finite(claim.base) or current_right
  base = base or 0
  local usable = math.max(0, window_width - base)
  local minimum_console = math.max(640, usable * 0.50)
  local desired = math.floor(bounded(data().workspace_width, WORKSPACE_MIN, WORKSPACE_MAX, WORKSPACE_DEFAULT))
  local suspended = usable < minimum_console + COLLAPSED_WIDTH
  local collapsed = suspended or data().collapsed_by_user == true or usable - desired < minimum_console
  local workspace = suspended and 0 or (collapsed and COLLAPSED_WIDTH or desired)
  local inspector = 0
  if not collapsed and data().inspector_pinned == true then
    inspector = math.floor(bounded(usable * 0.22, INSPECTOR_MIN, INSPECTOR_MAX, INSPECTOR_MIN))
    if usable - workspace - GAP - inspector < minimum_console then inspector = 0 end
  end
  return {
    window_width = window_width, height = window_height, base = base, usable = usable,
    console_min = minimum_console, collapsed = collapsed, suspended = suspended, workspace = workspace,
    inspector = inspector, total = workspace + (inspector > 0 and GAP + inspector or 0),
  }
end

local function apply_right_claim(size)
  local d = data()
  local current = finite(getBorderRight()) or 0
  local claim = d.border_claim
  local base = type(claim) == "table" and current == claim.applied and claim.base or current
  if type(claim) == "table" and current ~= claim.applied then ui.border_conflict = true end
  if size <= 0 then
    d.border_claim = nil
    persist()
    return base
  end
  setBorderRight(base + size)
  d.border_claim = {base = base, width = size, applied = base + size}
  ui.border_conflict = false
  persist()
  return base
end

local function release_right_claim()
  local claim = data().border_claim
  if type(claim) ~= "table" then return true end
  local current = finite(getBorderRight()) or 0
  if current == claim.applied then setBorderRight(claim.base) else ui.border_conflict = true end
  data().border_claim = nil
  persist()
  return not ui.border_conflict
end

local function hud_rows(width)
  if width < 640 then return {{"hp", "mana"}, {"moves", "tnl", "enemy"}, {"hunger", "thirst"}} end
  return {{"hp", "mana", "moves"}, {"tnl", "enemy", "hunger", "thirst"}}
end

local function hud_height(width)
  return HUD_MARGIN * 2 + #hud_rows(width) * HUD_ROW_HEIGHT + (#hud_rows(width) - 1) * HUD_GAP
end

local function apply_bottom_claim(height)
  if type(getBorderBottom) ~= "function" or type(setBorderBottom) ~= "function" then return 0 end
  local d = data()
  local current = finite(getBorderBottom()) or 0
  local claim = d.bottom_border_claim
  local base = type(claim) == "table" and current == claim.applied and claim.base or current
  setBorderBottom(base + height)
  d.bottom_border_claim = {base = base, height = height, applied = base + height}
  persist()
  return base
end

local function release_bottom_claim()
  if type(getBorderBottom) ~= "function" or type(setBorderBottom) ~= "function" then return end
  local claim = data().bottom_border_claim
  if type(claim) ~= "table" then return end
  if (finite(getBorderBottom()) or 0) == claim.applied then setBorderBottom(claim.base) else ui.bottom_border_conflict = true end
  data().bottom_border_claim = nil
  persist()
end

function ui.release_saved_claims()
  -- Claim records are proof of ownership only when the live border still
  -- equals the exact applied value. The release helpers deliberately leave a
  -- conflicting border untouched, but discard stale ownership either way.
  release_bottom_claim()
  release_right_claim()
end

local function make_gauge(name, parent)
  local gauge = new_container("hud-" .. name, parent)
  gauge.surface = new_label("hud-" .. name .. "-surface", gauge)
  gauge.track = new_label("hud-" .. name .. "-track", gauge)
  gauge.fill = new_label("hud-" .. name .. "-fill", gauge)
  gauge.text = new_label("hud-" .. name .. "-text", gauge)
  return gauge
end

local function set_gauge(name, label, current, maximum, explicit_percent)
  local gauge = widget("gauge_" .. name)
  if not gauge then return end
  local percent = finite(explicit_percent)
  if percent == nil and finite(current) and finite(maximum) and finite(maximum) > 0 then percent = current / maximum * 100 end
  percent = bounded(percent, 0, 100, 0)
  safe(gauge.fill, "resize", string.format("%.1f%%", percent), 3)
  local suffix = maximum ~= nil and (" " .. display(current) .. "/" .. display(maximum)) or (" " .. display(current))
  safe(gauge.text, "echo", "<div align='center'><b>" .. escape(label .. suffix) .. "</b></div>")
end

local function status_badge(section)
  local status = clean(envelope(section).status, 20) or "unavailable"
  local labels = {current = "CURRENT", partial = "PARTIAL", stale = "STALE", error = "ERROR", unavailable = "UNAVAILABLE"}
  return labels[status] or status:upper(), status
end

local function key_value(rows)
  local output = {"<table width='100%' cellspacing='2' cellpadding='1'>"}
  for _, row in ipairs(rows) do
    output[#output + 1] = "<tr><td><font color='" .. theme().muted .. "'>" .. escape(row[1]) .. "</font></td><td align='right'><b>" .. escape(display(row[2])) .. "</b></td></tr>"
  end
  output[#output + 1] = "</table>"
  return table.concat(output)
end

local function tab_callback(name)
  return function()
    if commands and commands.set_tab then commands.set_tab(name) else ui.set_tab(name) end
  end
end

local function inventory_callback(name)
  return function()
    if commands and commands.select_inventory_tab then commands.select_inventory_tab(name)
    else data().inventory_tab = name; persist(); ui.request_render() end
  end
end

local function toggle_empty()
  if commands and commands.toggle_empty then commands.toggle_empty()
  else data().show_empty_slots = not data().show_empty_slots; persist(); ui.request_render() end
end

local function execute_action(id)
  return function() if actions and actions.execute then actions.execute(id); ui.request_render() end end
end

local function pending_action()
  if not actions then return nil end
  if type(actions.pending) == "function" then return actions.pending() end
  return type(actions.pending) == "table" and actions.pending or nil
end

local function confirm_action()
  if not actions then return end
  if actions.confirm_pending then actions.confirm_pending()
  elseif actions.confirm then actions.confirm() end
  ui.request_render()
end

local function cancel_action()
  if not actions then return end
  if actions.cancel_pending then actions.cancel_pending()
  elseif actions.cancel then actions.cancel() end
  ui.request_render()
end

local function command_line_text(object)
  if type(object) ~= "table" then return nil end
  for _, method in ipairs({"getText", "getCommandLine", "text"}) do
    if type(object[method]) == "function" then
      local ok, result = pcall(object[method], object)
      if ok and type(result) == "string" then return result end
    end
  end
  return nil
end

local function submit_custom_editor()
  local specification = command_line_text(widget("editor_command")) or ""
  local label, category, command = specification:match("^%s*([^|]+)%s*|%s*([^|]+)%s*|%s*(.-)%s*$")
  if not label then label, command = specification:match("^%s*([^|]+)%s*|%s*(.-)%s*$"); category = "Custom" end
  local ok, error_message
  if ui.editing_action_id then
    local update = actions and (actions.update_custom or actions.update)
    if update then ok, error_message = update(ui.editing_action_id, label, command, category) end
  else
    local add = actions and (actions.add_custom or actions.add)
    if add then ok, error_message = add(label, command, category) end
  end
  if ok then
    ui.editor_open, ui.editing_action_id = false, nil
  else
    ui.message(error_message or "Enter Label | Category | command.")
  end
  ui.request_render()
end

local function create_content(parent)
  local content_parent = parent
  ui.scroll_capable = type(Geyser.ScrollBox) == "table"
  if ui.scroll_capable then
    ui.widgets.scroll = Geyser.ScrollBox:new({name = PREFIX .. "scroll", x = 0, y = 0, width = 10, height = 10}, parent)
    content_parent = ui.widgets.scroll
  else
    ui.widgets.pager = new_container("pager", parent)
    ui.widgets.page_prev = new_button("page-prev", ui.widgets.pager, function() ui.page = math.max(1, (ui.page or 1) - 1); ui.request_render() end, "Previous page")
    ui.widgets.page_next = new_button("page-next", ui.widgets.pager, function() ui.page = (ui.page or 1) + 1; ui.request_render() end, "Next page")
    ui.widgets.page_status = new_label("page-status", ui.widgets.pager)
    content_parent = ui.widgets.pager
  end
  for _, tab in ipairs(TABS) do
    ui.widgets[tab .. "_content"] = new_container(tab .. "-content", content_parent)
  end
  return content_parent
end

function ui.build()
  if ui.root then return true end
  if not ui.available() then return false end
  local l = layout()
  local base = apply_right_claim(l.total)
  local console_width = math.max(0, l.window_width - base - l.total)
  local bottom_height = hud_height(console_width)
  local bottom_base = apply_bottom_claim(bottom_height)
  ui.root = Geyser.Container:new({name = PREFIX .. "root", x = -(base + l.total), y = 0, width = l.total, height = "100%"})
  ui.bottom_root = Geyser.Container:new({name = PREFIX .. "bottom-root", x = 0, y = -(bottom_base + bottom_height), width = console_width, height = bottom_height})
  ui.widgets = {}
  local w = ui.widgets
  w.background = new_label("background", ui.root)
  w.rail = new_button("restore-rail", ui.root, function()
    data().collapsed_by_user = false; persist(); ui.reflow(); ui.request_render()
  end, "Restore Aardwolf Command Deck")
  w.workspace = new_container("workspace", ui.root)
  w.header = new_label("header", w.workspace)
  w.palette_toggle = new_button("palette-toggle", w.workspace, function()
    if commands and commands.toggle_palette then commands.toggle_palette() else ui.toggle_palette() end
  end, "Open the contextual action drawer")
  w.pin_toggle = new_button("pin-toggle", w.workspace, function()
    if commands and commands.toggle_pin then commands.toggle_pin() else data().inspector_pinned = not data().inspector_pinned; persist(); ui.reflow() end
  end, "Pin or unpin the wide-screen inspector")
  w.context = new_container("context-strip", w.workspace)
  for index = 1, 4 do w["context_" .. index] = new_button("context-" .. index, w.context, function() end) end
  w.tabs = new_container("tabs", w.workspace)
  for _, tab in ipairs(TABS) do w["tab_" .. tab] = new_button("tab-" .. tab, w.tabs, tab_callback(tab), "Show " .. tab .. " data") end
  w.content = new_container("content", w.workspace)
  create_content(w.content)

  local map = w.map_content
  w.map_toolbar = new_container("map-toolbar", map)
  w.map_import = new_button("map-import", w.map_toolbar, execute_action("map-import"), "Merge the packaged Aardwolf snapshot; do not use Mudlet's native map loader")
  w.map_center = new_button("map-center", w.map_toolbar, function() if aardwolf_interface.lifecycle and aardwolf_interface.lifecycle.center_map then aardwolf_interface.lifecycle.center_map() end end, "Center the map on the current room")
  w.map_zoom_in = new_button("map-zoom-in", w.map_toolbar, execute_action("map-zoom-in"), "Zoom map in")
  w.map_zoom_out = new_button("map-zoom-out", w.map_toolbar, execute_action("map-zoom-out"), "Zoom map out")
  w.map_status = new_label("map-status", map)
  w.mapper = Geyser.Mapper:new({name = PREFIX .. "mapper", x = 0, y = 0, width = 10, height = 10}, map)
  w.map_legend = new_label("map-legend", map)
  w.character_card = new_label("character-card", w.character_content)
  w.group_card = new_label("group-card", w.group_content)
  w.inventory_toolbar = new_container("inventory-toolbar", w.inventory_content)
  w.inventory_equipment = new_button("inventory-equipment", w.inventory_toolbar, inventory_callback("equipment"), "Show equipped items")
  w.inventory_bags = new_button("inventory-bags", w.inventory_toolbar, inventory_callback("bags"), "Show containers and weight")
  w.inventory_empty = new_button("inventory-empty", w.inventory_toolbar, toggle_empty, "Show or hide empty equipment slots")
  w.inventory_refresh = new_button("inventory-refresh", w.inventory_toolbar, function() if aardwolf_interface.details and aardwolf_interface.details.refresh then aardwolf_interface.details.refresh() end end, "Refresh equipment and bag details")
  w.inventory_card = new_label("inventory-card", w.inventory_content)

  w.inspector = new_container("inspector", ui.root)
  w.inspector_background = new_label("inspector-background", w.inspector)
  w.inspector_header = new_label("inspector-header", w.inspector)
  w.inspector_body = new_label("inspector-body", w.inspector)

  w.drawer = new_container("action-drawer", w.workspace)
  w.drawer_background = new_label("action-drawer-background", w.drawer)
  w.drawer_header = new_label("action-drawer-header", w.drawer)
  w.drawer_close = new_button("action-drawer-close", w.drawer, function() ui.toggle_palette(false) end, "Close action drawer")
  w.drawer_actions = new_label("action-drawer-actions", w.drawer)
  w.drawer_buttons = new_container("action-drawer-buttons", w.drawer)
  for index = 1, 12 do w["drawer_action_" .. index] = new_button("action-drawer-action-" .. index, w.drawer_buttons, function() end) end
  w.drawer_prev = new_button("action-drawer-prev", w.drawer, function() ui.action_page = math.max(1, (ui.action_page or 1) - 1); ui.request_render() end, "Previous action page")
  w.drawer_next = new_button("action-drawer-next", w.drawer, function() ui.action_page = (ui.action_page or 1) + 1; ui.request_render() end, "Next action page")
  w.drawer_page = new_label("action-drawer-page", w.drawer)
  w.drawer_add = new_button("action-drawer-add", w.drawer, function() ui.prompt_custom_editor() end, "Add a custom action")

  w.editor = new_container("custom-editor", w.workspace)
  w.editor_background = new_label("custom-editor-background", w.editor)
  w.editor_title = new_label("custom-editor-title", w.editor)
  w.editor_help = new_label("custom-editor-help", w.editor)
  if type(Geyser.CommandLine) == "table" then
    w.editor_command = Geyser.CommandLine:new({name = PREFIX .. "custom-editor-command", x = 0, y = 0, width = 10, height = 26}, w.editor)
  else
    w.editor_command = new_label("custom-editor-command-fallback", w.editor)
  end
  w.editor_save = new_button("custom-editor-save", w.editor, submit_custom_editor, "Validate and save the custom action")
  w.editor_cancel = new_button("custom-editor-cancel", w.editor, function() ui.editor_open = false; ui.request_render() end, "Cancel editing")

  w.confirm = new_container("custom-confirm", w.workspace)
  w.confirm_background = new_label("custom-confirm-background", w.confirm)
  w.confirm_text = new_label("custom-confirm-text", w.confirm)
  w.confirm_send = new_button("custom-confirm-send", w.confirm, confirm_action, "Send this custom command")
  w.confirm_cancel = new_button("custom-confirm-cancel", w.confirm, cancel_action, "Cancel without sending")

  w.bottom_background = new_label("bottom-background", ui.bottom_root)
  for _, name in ipairs({"hp", "mana", "moves", "tnl", "enemy", "hunger", "thirst"}) do w["gauge_" .. name] = make_gauge(name, ui.bottom_root) end
  ui.page = 1
  ui.action_page = 1
  ui.mapper = w.mapper
  ui.apply_theme()
  ui.reflow()
  return true
end

function ui.apply_theme()
  if not ui.widgets then return end
  local t = theme()
  local panel = string.format("background-color:%s;color:%s;border:1px solid %s;", t.panel, t.text, t.border)
  local section = string.format("background-color:%s;color:%s;border:1px solid %s;padding:%dpx;font-size:%dpt;", t.section, t.text, t.border, density(3, 6), font_size(9))
  local header = string.format("background-color:%s;color:%s;border-bottom:2px solid %s;padding:%dpx;font-size:%dpt;font-weight:bold;", t.section, t.accent, t.jewel, density(4, 7), font_size(11))
  local button = string.format("background-color:%s;color:%s;border:1px solid %s;padding:3px;font-size:%dpt;font-weight:bold;", t.elevated, t.text, t.border, font_size(9))
  local selected = string.format("background-color:%s;color:%s;border:1px solid %s;padding:3px;font-size:%dpt;font-weight:bold;", t.selected, t.accent, t.accent, font_size(9))
  for _, name in ipairs({"background", "bottom_background", "inspector_background", "drawer_background", "editor_background", "confirm_background"}) do safe(widget(name), "setStyleSheet", panel) end
  for _, name in ipairs({"header", "inspector_header", "drawer_header", "editor_title"}) do safe(widget(name), "setStyleSheet", header) end
  for _, name in ipairs({"map_status", "map_legend", "character_card", "group_card", "inventory_card", "inspector_body", "drawer_actions", "editor_help", "confirm_text"}) do safe(widget(name), "setStyleSheet", section) end
  for _, name in ipairs({"rail", "palette_toggle", "pin_toggle", "map_import", "map_center", "map_zoom_in", "map_zoom_out", "inventory_equipment", "inventory_bags", "inventory_empty", "inventory_refresh", "drawer_close", "drawer_add", "drawer_prev", "drawer_next", "editor_save", "editor_cancel", "confirm_send", "confirm_cancel", "page_prev", "page_next"}) do safe(widget(name), "setStyleSheet", button) end
  for index = 1, 4 do safe(widget("context_" .. index), "setStyleSheet", button) end
  for index = 1, 12 do safe(widget("drawer_action_" .. index), "setStyleSheet", button) end
  for _, tab in ipairs(TABS) do safe(widget("tab_" .. tab), "setStyleSheet", data().active_tab == tab and selected or button) end
  safe(widget("inventory_equipment"), "setStyleSheet", data().inventory_tab ~= "bags" and selected or button)
  safe(widget("inventory_bags"), "setStyleSheet", data().inventory_tab == "bags" and selected or button)
  local colors = {hp = t.hp, mana = t.mana, moves = t.moves, tnl = t.accent, enemy = t.enemy, hunger = t.hunger, thirst = t.thirst}
  for name, color in pairs(colors) do
    local gauge = widget("gauge_" .. name)
    safe(gauge.surface, "setStyleSheet", string.format("background-color:%s;border:1px solid %s;", t.section, t.border))
    safe(gauge.track, "setStyleSheet", "background-color:" .. t.track .. ";")
    safe(gauge.fill, "setStyleSheet", "background-color:" .. color .. ";")
    safe(gauge.text, "setStyleSheet", string.format("background-color:transparent;color:%s;font-size:%dpt;", t.text, font_size(8)))
  end
end

local function resize_claim(l)
  if l.total <= 0 then
    release_right_claim()
    ui.base_right = l.base
    return
  end
  local claim = data().border_claim
  if type(claim) ~= "table" then ui.base_right = apply_right_claim(l.total); return end
  local current = finite(getBorderRight()) or 0
  if current == claim.applied then
    setBorderRight(claim.base + l.total); claim.width = l.total; claim.applied = claim.base + l.total
    ui.base_right = claim.base
  else ui.border_conflict = true; ui.base_right = claim.base or 0 end
end

function ui.reflow()
  if not ui.root then return false end
  local l = layout()
  resize_claim(l)
  ui.layout = l
  safe(ui.root, "move", -(ui.base_right + l.total), 0); safe(ui.root, "resize", l.total, "100%")
  safe(widget("background"), "move", 0, 0); safe(widget("background"), "resize", "100%", "100%")
  if l.suspended then
    safe(ui.root, "hide")
  elseif l.collapsed then
    safe(ui.root, "show")
    safe(widget("rail"), "move", 0, 0); safe(widget("rail"), "resize", COLLAPSED_WIDTH, "100%"); safe(widget("rail"), "show")
    safe(widget("workspace"), "hide"); safe(widget("inspector"), "hide")
  else
    safe(ui.root, "show")
    safe(widget("rail"), "hide"); safe(widget("workspace"), "show")
    safe(widget("workspace"), "move", 0, 0); safe(widget("workspace"), "resize", l.workspace, "100%")
    safe(widget("header"), "move", CONTENT_MARGIN, CONTENT_MARGIN); safe(widget("header"), "resize", l.workspace - 112, density(92, 112))
    safe(widget("palette_toggle"), "move", l.workspace - 96, CONTENT_MARGIN); safe(widget("palette_toggle"), "resize", 40, 32)
    safe(widget("pin_toggle"), "move", l.workspace - 52, CONTENT_MARGIN); safe(widget("pin_toggle"), "resize", 44, 32)
    local header_bottom = CONTENT_MARGIN + density(92, 112) + GAP
    safe(widget("context"), "move", CONTENT_MARGIN, header_bottom); safe(widget("context"), "resize", l.workspace - CONTENT_MARGIN * 2, 32)
    local action_width = (l.workspace - CONTENT_MARGIN * 2 - GAP * 3) / 4
    for index = 1, 4 do safe(widget("context_" .. index), "move", (index - 1) * (action_width + GAP), 0); safe(widget("context_" .. index), "resize", action_width, 32) end
    local tabs_y = header_bottom + 32 + GAP
    safe(widget("tabs"), "move", CONTENT_MARGIN, tabs_y); safe(widget("tabs"), "resize", l.workspace - CONTENT_MARGIN * 2, 32)
    local tab_width = (l.workspace - CONTENT_MARGIN * 2 - GAP * 3) / 4
    for index, tab in ipairs(TABS) do safe(widget("tab_" .. tab), "move", (index - 1) * (tab_width + GAP), 0); safe(widget("tab_" .. tab), "resize", tab_width, 32) end
    local content_y = tabs_y + 32 + GAP
    safe(widget("content"), "move", CONTENT_MARGIN, content_y); safe(widget("content"), "resize", l.workspace - CONTENT_MARGIN * 2, math.max(80, l.height - content_y - CONTENT_MARGIN))
    local content_width, content_height = l.workspace - CONTENT_MARGIN * 2, math.max(80, l.height - content_y - CONTENT_MARGIN)
    if widget("scroll") then safe(widget("scroll"), "move", 0, 0); safe(widget("scroll"), "resize", content_width, content_height) end
    if widget("pager") then
      safe(widget("pager"), "move", 0, 0); safe(widget("pager"), "resize", content_width, content_height)
      safe(widget("page_prev"), "move", 0, content_height - 28); safe(widget("page_prev"), "resize", 36, 26)
      safe(widget("page_next"), "move", content_width - 36, content_height - 28); safe(widget("page_next"), "resize", 36, 26)
      safe(widget("page_status"), "move", 42, content_height - 28); safe(widget("page_status"), "resize", content_width - 84, 26)
    end
    local page_reserved = widget("pager") and 32 or 0
    for _, tab in ipairs(TABS) do safe(widget(tab .. "_content"), "move", 0, 0); safe(widget(tab .. "_content"), "resize", content_width, content_height - page_reserved) end
    safe(widget("map_toolbar"), "move", 0, 0); safe(widget("map_toolbar"), "resize", content_width, 32)
    safe(widget("map_import"), "move", 0, 0); safe(widget("map_import"), "resize", 78, 30)
    safe(widget("map_center"), "move", 84, 0); safe(widget("map_center"), "resize", 78, 30)
    safe(widget("map_zoom_in"), "move", 168, 0); safe(widget("map_zoom_in"), "resize", 38, 30)
    safe(widget("map_zoom_out"), "move", 212, 0); safe(widget("map_zoom_out"), "resize", 38, 30)
    safe(widget("map_status"), "move", 0, 36); safe(widget("map_status"), "resize", content_width, 58)
    safe(widget("mapper"), "move", 0, 100); safe(widget("mapper"), "resize", content_width, math.max(120, content_height - 190))
    safe(widget("map_legend"), "move", 0, math.max(226, content_height - 84)); safe(widget("map_legend"), "resize", content_width, 80)
    for _, name in ipairs({"character_card", "group_card"}) do safe(widget(name), "move", 0, 0); safe(widget(name), "resize", content_width, content_height) end
    safe(widget("inventory_toolbar"), "move", 0, 0); safe(widget("inventory_toolbar"), "resize", content_width, 32)
    safe(widget("inventory_equipment"), "move", 0, 0); safe(widget("inventory_equipment"), "resize", 86, 30)
    safe(widget("inventory_bags"), "move", 92, 0); safe(widget("inventory_bags"), "resize", 64, 30)
    safe(widget("inventory_empty"), "move", 162, 0); safe(widget("inventory_empty"), "resize", 100, 30)
    safe(widget("inventory_refresh"), "move", content_width - 72, 0); safe(widget("inventory_refresh"), "resize", 72, 30)
    safe(widget("inventory_card"), "move", 0, 38); safe(widget("inventory_card"), "resize", content_width, content_height - 38)
    if l.inspector > 0 then
      safe(widget("inspector"), "move", l.workspace + GAP, 0); safe(widget("inspector"), "resize", l.inspector, "100%"); safe(widget("inspector"), "show")
      safe(widget("inspector_background"), "move", 0, 0); safe(widget("inspector_background"), "resize", "100%", "100%")
      safe(widget("inspector_header"), "move", CONTENT_MARGIN, CONTENT_MARGIN); safe(widget("inspector_header"), "resize", l.inspector - CONTENT_MARGIN * 2, 38)
      safe(widget("inspector_body"), "move", CONTENT_MARGIN, 52); safe(widget("inspector_body"), "resize", l.inspector - CONTENT_MARGIN * 2, l.height - 60)
    else safe(widget("inspector"), "hide") end
    local overlay_width = l.workspace - CONTENT_MARGIN * 4
    for _, name in ipairs({"drawer", "editor", "confirm"}) do safe(widget(name), "move", CONTENT_MARGIN * 2, density(150, 180)); safe(widget(name), "resize", overlay_width, math.min(460, l.height - density(170, 200))) end
    for _, prefix in ipairs({"drawer", "editor", "confirm"}) do safe(widget(prefix .. "_background"), "move", 0, 0); safe(widget(prefix .. "_background"), "resize", "100%", "100%") end
    safe(widget("drawer_header"), "move", 8, 8); safe(widget("drawer_header"), "resize", overlay_width - 54, 34)
    safe(widget("drawer_close"), "move", overlay_width - 42, 8); safe(widget("drawer_close"), "resize", 34, 34)
    safe(widget("drawer_actions"), "move", 8, 48); safe(widget("drawer_actions"), "resize", overlay_width - 16, 26)
    local drawer_body_height = math.min(306, l.height - 330)
    safe(widget("drawer_buttons"), "move", 8, 78); safe(widget("drawer_buttons"), "resize", overlay_width - 16, drawer_body_height)
    local drawer_button_height = math.max(22, (drawer_body_height - GAP * 5) / 6)
    local drawer_column_width = (overlay_width - 16 - GAP) / 2
    for index = 1, 12 do
      local column, row = math.floor((index - 1) / 6), (index - 1) % 6
      safe(widget("drawer_action_" .. index), "move", column * (drawer_column_width + GAP), row * (drawer_button_height + GAP)); safe(widget("drawer_action_" .. index), "resize", drawer_column_width, drawer_button_height)
    end
    local drawer_controls_y = 84 + drawer_body_height
    safe(widget("drawer_prev"), "move", 8, drawer_controls_y); safe(widget("drawer_prev"), "resize", 34, 28)
    safe(widget("drawer_page"), "move", 48, drawer_controls_y); safe(widget("drawer_page"), "resize", overlay_width - 104, 28)
    safe(widget("drawer_next"), "move", overlay_width - 42, drawer_controls_y); safe(widget("drawer_next"), "resize", 34, 28)
    safe(widget("drawer_add"), "move", 8, drawer_controls_y + 34); safe(widget("drawer_add"), "resize", overlay_width - 16, 30)
    safe(widget("editor_title"), "move", 8, 8); safe(widget("editor_title"), "resize", overlay_width - 16, 34)
    safe(widget("editor_help"), "move", 8, 48); safe(widget("editor_help"), "resize", overlay_width - 16, 110)
    safe(widget("editor_command"), "move", 8, 166); safe(widget("editor_command"), "resize", overlay_width - 16, 28)
    safe(widget("editor_save"), "move", 8, 204); safe(widget("editor_save"), "resize", 90, 32)
    safe(widget("editor_cancel"), "move", 104, 204); safe(widget("editor_cancel"), "resize", 90, 32)
    safe(widget("confirm_text"), "move", 8, 48); safe(widget("confirm_text"), "resize", overlay_width - 16, 116)
    safe(widget("confirm_send"), "move", 8, 174); safe(widget("confirm_send"), "resize", 90, 34)
    safe(widget("confirm_cancel"), "move", 104, 174); safe(widget("confirm_cancel"), "resize", 90, 34)
  end

  local console_width = math.max(0, l.window_width - (ui.base_right or l.base) - l.total)
  local height = hud_height(console_width)
  local bottom_claim = data().bottom_border_claim
  local bottom_base = type(bottom_claim) == "table" and bottom_claim.base or 0
  if type(bottom_claim) == "table" and type(getBorderBottom) == "function" and getBorderBottom() == bottom_claim.applied and bottom_claim.height ~= height then
    setBorderBottom(bottom_base + height); bottom_claim.height = height; bottom_claim.applied = bottom_base + height
  end
  safe(ui.bottom_root, "move", 0, -(bottom_base + height)); safe(ui.bottom_root, "resize", console_width, height)
  safe(widget("bottom_background"), "move", 0, 0); safe(widget("bottom_background"), "resize", "100%", "100%")
  local rows = hud_rows(console_width)
  for row_index, row in ipairs(rows) do
    local available = console_width - HUD_MARGIN * 2 - HUD_GAP * (#row - 1)
    local item_width = math.max(40, available / #row)
    for index, name in ipairs(row) do
      local gauge = widget("gauge_" .. name); local x = HUD_MARGIN + (index - 1) * (item_width + HUD_GAP); local y = HUD_MARGIN + (row_index - 1) * (HUD_ROW_HEIGHT + HUD_GAP)
      safe(gauge, "move", x, y); safe(gauge, "resize", item_width, HUD_ROW_HEIGHT)
      safe(gauge.surface, "move", 0, 0); safe(gauge.surface, "resize", "100%", "100%")
      safe(gauge.track, "move", 3, HUD_ROW_HEIGHT - 6); safe(gauge.track, "resize", item_width - 6, 3)
      safe(gauge.fill, "move", 3, HUD_ROW_HEIGHT - 6); safe(gauge.fill, "resize", 0, 3)
      safe(gauge.text, "move", 0, 2); safe(gauge.text, "resize", "100%", HUD_ROW_HEIGHT - 7)
    end
  end
  ui.apply_theme()
  return true
end

local function render_header()
  local room, base, status = value("room"), value("base"), value("status")
  local tick = state and state.tick_remaining and state.tick_remaining() or nil
  local state_name = constants and constants.character_states and constants.character_states[finite(status.state)] or status.state_name or "Unknown"
  local room_badge = status_badge("room")
  local exits = room.exits
  local exit_names = {}
  if type(exits) == "table" then for direction, destination in pairs(exits) do if destination ~= nil and destination ~= false then exit_names[#exit_names + 1] = clean(direction, 12) end end end
  table.sort(exit_names)
  local html = string.format("<b>%s</b> <font color='%s'>%s</font><br><font color='%s'>%s</font><br>%s &middot; vnum %s &middot; %s &middot; tick %s<br><font color='%s'>%s</font>",
    escape(base.name or base.character or "Aardwolf"), theme().accent, escape(state_name), theme().text,
    escape(room.name or "Room unavailable"), escape(room.area or room.zone or "Unknown area"), escape(room.num or room.vnum),
    escape(room.terrain or room.environment or "unknown"), escape(display(tick)), theme().muted,
    escape(#exit_names > 0 and ("Exits: " .. table.concat(exit_names, " ")) or ("Room data: " .. room_badge)))
  safe(widget("header"), "echo", html)
  set_button_text(widget("palette_toggle"), "Actions")
  set_button_text(widget("pin_toggle"), ui.layout and ui.layout.inspector > 0 and "Unpin" or "Pin")
  set_button_text(widget("rail"), "A\nA\nR\nD")
end

local function render_context()
  local list = actions and actions.context and actions.context() or {}
  for index = 1, 4 do
    local action = type(list) == "table" and list[index] or nil
    local button = widget("context_" .. index)
    set_button_text(button, action and (action.label or action.name or action.id) or "--")
    safe(button, "setClickCallback", action and execute_action(action.id) or function() end)
    tooltip(button, action and (action.description or action.label or action.id) or "No contextual action")
  end
end

local function render_map()
  local room, map = value("room"), value("map")
  local badge = status_badge("map")
  set_button_text(widget("map_import"), "Import")
  set_button_text(widget("map_center"), "Center")
  set_button_text(widget("map_zoom_in"), "+")
  set_button_text(widget("map_zoom_out"), "-")
  local phase = map.phase or map.import_phase or "idle"
  local owned = finite(map.owned_room_count or map.owned_count) or 0
  local guidance = owned == 0 and phase ~= "rooms" and phase ~= "exits" and "<br><font color='" .. theme().warning .. "'>Use Import here or 'aard map import'—not Mudlet's Map Load.</font>" or ""
  safe(widget("map_status"), "echo", string.format("<b>Map %s</b> &middot; %s<br>Room %s &rarr; %s &middot; owned %s &middot; source %s<br>Coordinates: %s, %s, %s%s",
    escape(badge), escape(phase), escape(room.num or room.vnum), escape(map.room_id or map.resolved_room_id), escape(display(owned)), escape(map.source_hash or "--"), escape(display(room.x)), escape(display(room.y)), escape(display(room.z)), guidance))
  local legend = map.legend or room.legend
  if type(legend) == "table" then
    local entries = {}; for name, color in pairs(legend) do entries[#entries + 1] = "<font color='" .. escape(color) .. "'>&#9670;</font> " .. escape(name) end; table.sort(entries)
    safe(widget("map_legend"), "echo", "<b>Terrain</b><br>" .. table.concat(entries, " &nbsp; "))
  else safe(widget("map_legend"), "echo", "<b>Terrain</b><br>" .. escape(room.terrain or room.environment or "No terrain data")) end
end

local function render_character()
  local base, vitals, maximum = value("base"), value("vitals"), value("maxstats")
  local stats, worth, status, quest = value("stats"), value("worth"), value("status"), value("quest")
  local badge = status_badge("base")
  local identity = key_value({{"Name", base.name or base.character}, {"Race", base.race}, {"Class", base.class}, {"Subclass", base.subclass}, {"Clan", base.clan}, {"Level", base.level or stats.level}, {"Tier", base.tier}, {"Remorts", base.remorts or base.remort}})
  local attributes = key_value({{"Strength", stats.str or stats.strength}, {"Intelligence", stats.int or stats.intelligence}, {"Wisdom", stats.wis or stats.wisdom}, {"Dexterity", stats.dex or stats.dexterity}, {"Constitution", stats.con or stats.constitution}, {"Luck", stats.luck}})
  local combat = key_value({{"HP", display(vitals.hp) .. " / " .. display(maximum.maxhp or vitals.maxhp)}, {"Mana", display(vitals.mana) .. " / " .. display(maximum.maxmana or vitals.maxmana)}, {"Moves", display(vitals.moves) .. " / " .. display(maximum.maxmoves or vitals.maxmoves)}, {"Hitroll", stats.hitroll or stats.hr}, {"Damroll", stats.damroll or stats.dr}, {"Saves", stats.saves}, {"Alignment", worth.align or stats.align or stats.alignment}})
  local progression = key_value({{"TNL", vitals.tnl or stats.tnl}, {"QP", worth.qp or worth.questpoints}, {"Gold", worth.gold}, {"Bank", worth.bank}, {"Practices", worth.pracs or stats.practices}, {"Trains", worth.trains or stats.trains}, {"Quest", quest.status or quest.state}, {"Quest timer", quest.timer or quest.time}})
  safe(widget("character_card"), "echo", "<b>CHARACTER &middot; " .. escape(badge) .. "</b><br><table width='100%'><tr><td valign='top' width='50%'><b>Identity</b>" .. identity .. "<br><b>Attributes</b>" .. attributes .. "</td><td valign='top'><b>Combat</b>" .. combat .. "<br><b>Progression &amp; currencies</b>" .. progression .. "</td></tr></table><br><b>Conditions</b><br>State " .. escape(status.state_name or status.state) .. " &middot; hunger " .. escape(display(vitals.hunger or worth.hunger)) .. " &middot; thirst " .. escape(display(vitals.thirst or worth.thirst)) .. " &middot; enemy " .. escape(display(vitals.enemy)) )
end

local function render_group()
  local group = value("group")
  local badge, envelope_status = status_badge("group")
  local members = type(group.members) == "table" and group.members or {}
  local rows = {"<b>GROUP &middot; " .. escape(badge) .. "</b><br>"}
  if envelope_status == "unavailable" then rows[#rows + 1] = "Group GMCP is unavailable for this session."
  elseif #members == 0 then rows[#rows + 1] = "Not currently grouped."
  else
    rows[#rows + 1] = "<table width='100%' cellspacing='2'><tr><td><b>Member</b></td><td><b>Level / Align</b></td><td><b>HP</b></td><td><b>Mana</b></td><td><b>Moves</b></td><td><b>TNL / Quest</b></td></tr>"
    for index = 1, math.min(#members, 20) do
      local member = members[index]; local info = member.info or member
      rows[#rows + 1] = string.format("<tr><td>%s</td><td>%s / %s</td><td>%s/%s</td><td>%s/%s</td><td>%s/%s</td><td>%s / %s</td></tr>", escape(member.name or info.name or "Unknown"), escape(display(info.level or info.lvl)), escape(display(info.align or info.alignment)), escape(display(info.hp)), escape(display(info.maxhp or info.mhp)), escape(display(info.mana)), escape(display(info.maxmana or info.mmn)), escape(display(info.moves)), escape(display(info.maxmoves or info.mmv)), escape(display(info.tnl)), escape(display(info.quest_timer or info.qtimer)))
    end
    rows[#rows + 1] = "</table>"
  end
  safe(widget("group_card"), "echo", table.concat(rows))
end

local function item_line(item, prefix)
  return string.format("<tr><td>%s</td><td><b>%s</b></td><td>Lvl %s &middot; type %s &middot; %s%s%s</td></tr>", escape(prefix or ""), escape(item.name or "Unknown item"), escape(display(item.level)), escape(display(item.item_type or item.type)), escape(item.flags or "no flags"), item.unique and " &middot; unique" or "", finite(item.timer) and (" &middot; timer " .. escape(display(item.timer))) or "")
end

local function render_inventory()
  local details = value("details")
  local badge = status_badge("details")
  set_button_text(widget("inventory_equipment"), "Equipment")
  set_button_text(widget("inventory_bags"), "Bags")
  set_button_text(widget("inventory_empty"), data().show_empty_slots and "Hide empty" or "Show empty")
  set_button_text(widget("inventory_refresh"), details.refreshing and "Refreshing" or "Refresh")
  local rows = {"<b>INVENTORY &middot; " .. escape(badge) .. "</b> &middot; " .. escape(details.error or (details.stale and "stale" or "current")) .. "<br><table width='100%' cellspacing='2'>"}
  if data().inventory_tab == "bags" then
    local bags=type(details.bags)=="table" and details.bags or {}
    local first,last=1,#bags
    if not ui.scroll_capable then first=(ui.page-1)*12+1; last=math.min(#bags,first+11) end
    for index=first,last do local bag=bags[index]
      local used, maximum = finite(bag.used_weight), finite(bag.max_weight)
      local percent = used and maximum and maximum > 0 and math.floor(used / maximum * 100) or nil
      rows[#rows + 1] = string.format("<tr><td><b>%s</b></td><td>%s / %s weight%s</td><td>%s</td></tr>", escape(bag.name or "Container"), escape(display(used)), escape(display(maximum)), percent and (" (" .. percent .. "%%)") or "", escape(bag.error or (bag.pending and "pending" or bag.status or "current")))
    end
    if #bags == 0 then rows[#rows + 1] = "<tr><td>No bag data.</td></tr>" end
  else
    local equipment = type(details.equipment) == "table" and details.equipment or {}
    local wear = constants and constants.wear_locations or {}
    local first,last=0,32
    if not ui.scroll_capable then first=(ui.page-1)*17; last=math.min(32,first+16) end
    for location = first, last do
      local item = equipment[location] or equipment[tostring(location)]
      if item then rows[#rows + 1] = item_line(item, wear[location] or ("Slot " .. location))
      elseif data().show_empty_slots then rows[#rows + 1] = "<tr><td>" .. escape(wear[location] or ("Slot " .. location)) .. "</td><td colspan='2'><font color='" .. theme().muted .. "'>Empty</font></td></tr>" end
    end
  end
  rows[#rows + 1] = "</table>"
  safe(widget("inventory_card"), "echo", table.concat(rows))
end

local function render_inspector()
  if not ui.layout or ui.layout.inspector == 0 then return end
  local tab = data().active_tab or "map"
  safe(widget("inspector_header"), "echo", "<b>INSPECTOR &middot; " .. escape(tab:upper()) .. "</b>")
  local room, quest, details = value("room"), value("quest"), value("details")
  safe(widget("inspector_body"), "echo", key_value({{"Room", room.name}, {"Area", room.area}, {"Vnum", room.num or room.vnum}, {"Terrain", room.terrain}, {"Quest", quest.status or quest.state}, {"Quest timer", quest.timer or quest.time}, {"Equipment", details.equipment and "loaded" or "unavailable"}, {"Bags", details.bags and #details.bags or "unavailable"}}))
end

local function render_drawer()
  local configured = actions and actions.curated or {}
  local list = type(configured) == "function" and configured() or configured
  local custom = actions and actions.custom and actions.custom() or {}
  local combined = {}
  if type(list) == "table" then
    if #list > 0 then for _, action in ipairs(list) do combined[#combined + 1] = action end
    else
      local keys = {}; for id in pairs(list) do keys[#keys + 1] = id end; table.sort(keys)
      for _, id in ipairs(keys) do combined[#combined + 1] = list[id] end
    end
  end
  for _, action in ipairs(type(custom) == "table" and custom or {}) do combined[#combined + 1] = action end
  local pages = math.max(1, math.ceil(#combined / 12))
  ui.action_page = math.max(1, math.min(ui.action_page or 1, pages))
  local first = (ui.action_page - 1) * 12 + 1
  for index = 1, 12 do
    local action = combined[first + index - 1]
    local button = widget("drawer_action_" .. index)
    if action then
      set_button_text(button, (action.category or "General") .. ": " .. (action.label or action.id))
      safe(button, "setClickCallback", execute_action(action.id)); tooltip(button, action.description or action.command or action.label or action.id); safe(button, "show")
    else safe(button, "hide") end
  end
  safe(widget("drawer_header"), "echo", "<b>ACTION PALETTE</b>"); set_button_text(widget("drawer_close"), "X"); set_button_text(widget("drawer_add"), "Add custom action")
  safe(widget("drawer_actions"), "echo", "Curated and profile-local commands &middot; custom actions confirm before sending")
  set_button_text(widget("drawer_prev"), "<"); set_button_text(widget("drawer_next"), ">")
  safe(widget("drawer_page"), "echo", "<div align='center'>Page " .. ui.action_page .. " / " .. pages .. "</div>")
  if data().palette_open == true then safe(widget("drawer"), "show") else safe(widget("drawer"), "hide") end
end

local function render_overlays()
  if ui.editor_open then
    safe(widget("editor"), "show"); safe(widget("editor_title"), "echo", "<b>CUSTOM ACTION EDITOR</b>")
    safe(widget("editor_help"), "echo", "Enter: Label | Category | command<br>Label: up to 32 characters; category: up to 24<br>Command: one printable line, up to 200 characters.<br>Custom commands always require Send/Cancel confirmation.")
    set_button_text(widget("editor_save"), "Save"); set_button_text(widget("editor_cancel"), "Cancel")
  else safe(widget("editor"), "hide") end
  local pending = pending_action()
  if type(pending) == "table" then
    safe(widget("confirm"), "show")
    safe(widget("confirm_text"), "echo", "<b>CONFIRM CUSTOM COMMAND</b><br><br>" .. escape(pending.label or "Custom action") .. "<br><font color='" .. theme().warning .. "'>" .. escape(pending.command or "") .. "</font><br><br>Send this command once?")
    set_button_text(widget("confirm_send"), "Send"); set_button_text(widget("confirm_cancel"), "Cancel")
  else safe(widget("confirm"), "hide") end
end

function ui.render()
  if not ui.root then return end
  ui.render_pending = false
  render_header(); render_context(); render_map(); render_character(); render_group(); render_inventory(); render_inspector(); render_drawer(); render_overlays()
  local active = data().active_tab or "map"
  for _, tab in ipairs(TABS) do if tab == active then safe(widget(tab .. "_content"), "show") else safe(widget(tab .. "_content"), "hide") end; set_button_text(widget("tab_" .. tab), tab:sub(1, 1):upper() .. tab:sub(2)) end
  if widget("pager") then
    local pages = active == "inventory" and 2 or 1; ui.page = math.max(1, math.min(ui.page or 1, pages))
    set_button_text(widget("page_prev"), "<"); set_button_text(widget("page_next"), ">"); safe(widget("page_status"), "echo", "Page " .. ui.page .. " / " .. pages)
  end
  local vitals, maximum, worth, base = value("vitals"), value("maxstats"), value("worth"), value("base")
  set_gauge("hp", "HP", vitals.hp, maximum.maxhp or vitals.maxhp)
  set_gauge("mana", "Mana", vitals.mana, maximum.maxmana or vitals.maxmana)
  set_gauge("moves", "Moves", vitals.moves, maximum.maxmoves or vitals.maxmoves)
  set_gauge("tnl", "TNL", vitals.tnl or vitals.to_level, vitals.tnl_max or base.perlevel or 1000)
  set_gauge("enemy", "Enemy", vitals.enemy or vitals.enemyhp or vitals.enemy_percent, nil, vitals.enemyhp or vitals.enemy_percent)
  set_gauge("hunger", "Hunger", vitals.hunger or worth.hunger, nil, vitals.hunger or worth.hunger)
  set_gauge("thirst", "Thirst", vitals.thirst or worth.thirst, nil, vitals.thirst or worth.thirst)
  ui.apply_theme()
end

function ui.request_render()
  if ui.render_pending then return end
  ui.render_pending = true
  if type(registerNamedTimer) == "function" and type(deleteNamedTimer) == "function" then
    deleteNamedTimer(TIMER_USER, RENDER_TIMER); registerNamedTimer(TIMER_USER, RENDER_TIMER, 0.08, ui.render, true)
  else ui.render() end
end

function ui.show(persist_setting)
  if not ui.root and not ui.build() then ui.message("Geyser is unavailable. Use 'aard interface summary all' for text output."); return false end
  if not data().border_claim then ui.base_right = apply_right_claim(layout().total) end
  if not data().bottom_border_claim then local l = layout(); ui.base_bottom = apply_bottom_claim(hud_height(math.max(0, l.window_width - l.base - l.total))) end
  if persist_setting ~= false then data().visible = true; persist() end
  safe(ui.root, "show"); safe(ui.bottom_root, "show"); ui.reflow(); ui.render()
  if data().active_tab == "inventory" and aardwolf_interface.details and aardwolf_interface.details.start then aardwolf_interface.details.start() end
  return true
end

function ui.hide(persist_setting)
  if persist_setting ~= false then data().visible = false; persist() end
  if aardwolf_interface.details and aardwolf_interface.details.stop then aardwolf_interface.details.stop(true) end
  safe(ui.root, "hide"); safe(ui.bottom_root, "hide"); release_bottom_claim(); release_right_claim()
end

function ui.destroy()
  ui.hide(false)
  if type(deleteNamedTimer) == "function" then deleteNamedTimer(TIMER_USER, RENDER_TIMER) end
  if ui.root and type(ui.root.delete) == "function" then pcall(ui.root.delete, ui.root) end
  if ui.bottom_root and type(ui.bottom_root.delete) == "function" then pcall(ui.bottom_root.delete, ui.bottom_root) end
  ui.root, ui.bottom_root, ui.widgets, ui.layout = nil, nil, nil, nil
end

function ui.set_tab(tab)
  local valid = {map = true, character = true, group = true, inventory = true}
  if not valid[tab] then return false, "Unknown tab" end
  if data().active_tab == "inventory" and tab ~= "inventory" and aardwolf_interface.details and aardwolf_interface.details.stop then aardwolf_interface.details.stop(true) end
  data().active_tab = tab; ui.page = 1; persist()
  if tab == "inventory" and aardwolf_interface.details and aardwolf_interface.details.start then aardwolf_interface.details.start() end
  ui.request_render(); return true
end

function ui.toggle_palette(force)
  data().palette_open = type(force) == "boolean" and force or not data().palette_open
  if not data().palette_open then ui.editor_open = false end
  persist(); ui.request_render(); return data().palette_open
end

function ui.prompt_custom_editor(action_id)
  ui.editor_open = true; ui.editing_action_id = action_id
  data().palette_open = true; persist()
  local command_line = widget("editor_command")
  if command_line then
    safe(command_line, "setText", "")
    safe(command_line, "setFocus")
  end
  ui.request_render(); return true
end

function ui.editor_value()
  local editor=widget("editor_command")
  if not editor then return nil end
  local raw
  if type(editor.getText)=="function" then local ok,value=pcall(editor.getText,editor); if ok then raw=value end end
  if type(raw)~="string" then return nil end
  local label,category,command=raw:match("^%s*([^|]-)%s*|%s*([^|]-)%s*|%s*(.-)%s*$")
  return label,category,command
end

-- Compatibility callback used by the command module after theme changes.
function ui.theme()
  ui.apply_theme()
  ui.request_render()
end
