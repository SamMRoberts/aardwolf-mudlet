aardwolf_mudlet = aardwolf_mudlet or {}
aardwolf_mudlet.chat = aardwolf_mudlet.chat or {}

local chat = aardwolf_mudlet.chat
local DEFAULT_LIMIT = 500
local MAX_LIMIT = 5000
local DEFAULT_TABS = {
  {name = "All", filters = {"*"}},
  {name = "Tells", filters = {"tell", "ptell", "dtell"}},
  {name = "Group", filters = {"group", "gtell"}},
  {name = "Clan", filters = {"claninfo", "clantalk", "gclan"}},
  {name = "System", filters = {"info", "raidinfo", "global_quest", "warfare", "remort_auction", "remote_socials"}},
}

local function clean(value, limit)
  return aardwolf_mudlet.util.text(value, limit or 200)
end

local function normalize_filter(value)
  local result = clean(value, 32)
  if not result then return nil end
  result = result:lower():match("^%s*(.-)%s*$")
  if result == "*" or result:match("^[a-z0-9_.%-]+$") then return result end
  return nil
end

local function copy_tabs(source)
  local result, seen = {}, {}
  for _, candidate in ipairs(type(source) == "table" and source or {}) do
    if #result >= 12 then break end
    if type(candidate) == "table" then
      local name = clean(candidate.name, 24)
      if name then name = name:match("^%s*(.-)%s*$") end
      local key = name and name:lower() or nil
      if key and name ~= "" and not seen[key] then
        local filters, filter_seen = {}, {}
        for _, value in ipairs(type(candidate.filters) == "table" and candidate.filters or {}) do
          local filter = normalize_filter(value)
          if filter and not filter_seen[filter] and #filters < 64 then
            filter_seen[filter] = true
            filters[#filters + 1] = filter
          end
        end
        if #filters == 0 then filters[1] = "*" end
        seen[key] = true
        result[#result + 1] = {name = name, filters = filters}
      end
    end
  end
  return result
end

function chat.validate_settings(candidate, fallback)
  local base = type(fallback) == "table" and fallback or {
    visible = true, preserve_main = true, logging = false,
    max_messages = DEFAULT_LIMIT, active_tab = "All", tabs = DEFAULT_TABS,
  }
  local output = {
    visible = base.visible ~= false,
    preserve_main = base.preserve_main ~= false,
    logging = base.logging == true,
    max_messages = math.floor(tonumber(base.max_messages) or DEFAULT_LIMIT),
    active_tab = clean(base.active_tab, 24) or "All",
    tabs = copy_tabs(base.tabs),
  }
  if type(candidate) == "table" then
    if type(candidate.visible) == "boolean" then output.visible = candidate.visible end
    if type(candidate.preserve_main) == "boolean" then output.preserve_main = candidate.preserve_main end
    if type(candidate.logging) == "boolean" then output.logging = candidate.logging end
    output.max_messages = math.floor(aardwolf_mudlet.util.bounded(candidate.max_messages, 1, MAX_LIMIT) or output.max_messages)
    local tabs = copy_tabs(candidate.tabs)
    if #tabs > 0 then output.tabs = tabs end
    local active = clean(candidate.active_tab, 24)
    if active then output.active_tab = active end
  end
  if #output.tabs == 0 then output.tabs = copy_tabs(DEFAULT_TABS) end
  local active_found = false
  for _, tab in ipairs(output.tabs) do if tab.name == output.active_tab then active_found = true end end
  if not active_found then output.active_tab = output.tabs[1].name end
  return output
end

local function settings()
  local data = aardwolf_mudlet.settings and aardwolf_mudlet.settings.data
  if not data then return chat.validate_settings(nil) end
  data.chat = chat.validate_settings(data.chat)
  return data.chat
end

local function tab_matches(tab, channel)
  for _, filter in ipairs(tab.filters or {}) do
    if filter == "*" or filter == channel then return true end
  end
  return false
end

local function buffer_for(name)
  chat.buffers = chat.buffers or {}
  chat.buffers[name] = chat.buffers[name] or {messages = {}, unread = 0}
  return chat.buffers[name]
end

local function trim(buffer, maximum)
  while #buffer.messages > maximum do table.remove(buffer.messages, 1) end
end

local function log_path()
  return aardwolf_mudlet.settings.directory() .. "/chat.log"
end

local function rotate_log(path)
  if type(lfs) ~= "table" or type(lfs.attributes) ~= "function" then return end
  local size = tonumber(lfs.attributes(path, "size")) or 0
  if size < 5 * 1024 * 1024 then return end
  for index = 4, 1, -1 do
    local old = path .. "." .. index
    local next_name = path .. "." .. (index + 1)
    if lfs.attributes(old, "mode") == "file" then os.rename(old, next_name) end
  end
  os.rename(path, path .. ".1")
end

local function write_log(message)
  if not settings().logging or not aardwolf_mudlet.settings.ensure_directory() then return false end
  local path = log_path()
  rotate_log(path)
  local file = io.open(path, "a")
  if not file then return false end
  local line = string.format("[%s] [%s] %s%s\n", os.date("%Y-%m-%d %H:%M:%S", message.time), message.channel,
    message.player ~= "" and (message.player .. ": ") or "", message.plain)
  file:write(line)
  file:close()
  return true
end

function chat.initialize()
  chat.buffers = chat.buffers or {}
  chat.active = true
  local valid = {}
  for _, tab in ipairs(settings().tabs) do valid[tab.name] = true; buffer_for(tab.name) end
  for name in pairs(chat.buffers) do if not valid[name] then chat.buffers[name] = nil end end
end

function chat.shutdown()
  chat.active = false
end

function chat.record(channel, player, message, raw)
  if not chat.active then chat.initialize() end
  channel = normalize_filter(channel or "system") or "system"
  player = clean(player, 80) or ""
  message = clean(message, 2000)
  if not message or message == "" then return false end
  local entry = {channel = channel, player = player, plain = message, raw = clean(raw, 2400) or message, time = os.time()}
  local config = settings()
  for _, tab in ipairs(config.tabs) do
    if tab_matches(tab, channel) then
      local buffer = buffer_for(tab.name)
      buffer.messages[#buffer.messages + 1] = entry
      trim(buffer, config.max_messages)
      if tab.name ~= config.active_tab or aardwolf_mudlet.settings.data.active_tab ~= "chat" then
        buffer.unread = math.min(999, (buffer.unread or 0) + 1)
      end
    end
  end
  write_log(entry)
  if aardwolf_mudlet.accessibility and aardwolf_mudlet.accessibility.on_chat then
    aardwolf_mudlet.accessibility.on_chat(entry)
  end
  if aardwolf_mudlet.sound and aardwolf_mudlet.sound.on_event then
    aardwolf_mudlet.sound.on_event("chat." .. channel)
  end
  if aardwolf_mudlet.ui and aardwolf_mudlet.ui.request_render then aardwolf_mudlet.ui.request_render() end
  return true
end

function chat.on_gmcp()
  local payload = gmcp and gmcp.comm and gmcp.comm.channel
  if type(payload) ~= "table" then return false end
  return chat.record(payload.chan or payload.channel or payload.name or "channel",
    payload.player or payload.from or payload.sender or "", payload.msg or payload.message or payload.text, payload.msg or payload.message or payload.text)
end

function chat.capture_system_line(line)
  local prefix, body = tostring(line or ""):match("^([A-Z][A-Z _]+):%s*(.*)$")
  if not prefix then return false end
  local tags = {INFO="info", RAIDINFO="raidinfo", CLANINFO="claninfo", WARFARE="warfare", ["GLOBAL QUEST"]="global_quest", ["CLAN DONATIONS"]="clan_donations"}
  local tag = tags[prefix]
  if not tag then return false end
  return chat.record(tag, "", body, line)
end

function chat.tabs() return settings().tabs end
function chat.active_name() return settings().active_tab end
function chat.active_buffer() return buffer_for(chat.active_name()) end

function chat.select(name_or_index)
  local tabs = settings().tabs
  local selected = type(name_or_index) == "number" and tabs[name_or_index] or nil
  if not selected then
    for _, tab in ipairs(tabs) do if tab.name:lower() == tostring(name_or_index or ""):lower() then selected = tab end end
  end
  if not selected then return false, "Unknown chat tab" end
  settings().active_tab = selected.name
  buffer_for(selected.name).unread = 0
  aardwolf_mudlet.settings.save()
  if aardwolf_mudlet.ui and aardwolf_mudlet.ui.request_render then aardwolf_mudlet.ui.request_render() end
  return true
end

function chat.add_tab(name, filters)
  name = clean(name, 24)
  local config = settings()
  if not name or name == "" or #config.tabs >= 12 then return false, "Tab name is invalid or the 12-tab limit was reached" end
  for _, tab in ipairs(config.tabs) do if tab.name:lower() == name:lower() then return false, "Chat tab already exists" end end
  local values = {}
  for value in tostring(filters or "*"):gmatch("[^,]+") do values[#values + 1] = value end
  local normalized = copy_tabs({{name = name, filters = values}})[1]
  if not normalized then return false, "Chat filters are invalid" end
  config.tabs[#config.tabs + 1] = normalized
  buffer_for(name)
  aardwolf_mudlet.settings.save()
  return true
end

function chat.rename_tab(old_name, new_name)
  local config = settings()
  new_name = clean(new_name, 24)
  if not new_name or new_name == "" then return false, "New tab name is invalid" end
  for _, tab in ipairs(config.tabs) do if tab.name:lower() == new_name:lower() then return false, "Chat tab already exists" end end
  for _, tab in ipairs(config.tabs) do
    if tab.name:lower() == tostring(old_name or ""):lower() then
      local old = tab.name; tab.name = new_name
      chat.buffers[new_name] = chat.buffers[old] or {messages = {}, unread = 0}; chat.buffers[old] = nil
      if config.active_tab == old then config.active_tab = new_name end
      aardwolf_mudlet.settings.save(); return true
    end
  end
  return false, "Unknown chat tab"
end

function chat.remove_tab(name)
  local config = settings()
  if #config.tabs <= 1 then return false, "At least one chat tab is required" end
  for index, tab in ipairs(config.tabs) do
    if tab.name:lower() == tostring(name or ""):lower() then
      table.remove(config.tabs, index); chat.buffers[tab.name] = nil
      if config.active_tab == tab.name then config.active_tab = config.tabs[1].name end
      aardwolf_mudlet.settings.save(); return true
    end
  end
  return false, "Unknown chat tab"
end

function chat.move_tab(name, position)
  position = math.floor(tonumber(position) or 0)
  local tabs = settings().tabs
  if position < 1 or position > #tabs then return false, "Chat tab position is out of range" end
  for index, tab in ipairs(tabs) do
    if tab.name:lower() == tostring(name or ""):lower() then
      table.remove(tabs, index); table.insert(tabs, position, tab)
      aardwolf_mudlet.settings.save(); return true
    end
  end
  return false, "Unknown chat tab"
end

function chat.set_limit(value)
  local limit = math.floor(tonumber(value) or 0)
  if limit < 1 or limit > MAX_LIMIT then return false, "Chat limit must be between 1 and 5000" end
  settings().max_messages = limit
  for _, buffer in pairs(chat.buffers or {}) do trim(buffer, limit) end
  aardwolf_mudlet.settings.save(); return true
end

function chat.set_filters(name, filters)
  local config = settings()
  for _, tab in ipairs(config.tabs) do
    if tab.name:lower() == tostring(name or ""):lower() then
      local values = {}; for value in tostring(filters or ""):gmatch("[^,]+") do values[#values + 1] = value end
      local normalized = copy_tabs({{name = tab.name, filters = values}})[1]
      if not normalized then return false, "Chat filters are invalid" end
      tab.filters = normalized.filters; aardwolf_mudlet.settings.save(); return true
    end
  end
  return false, "Unknown chat tab"
end

function chat.clear(name)
  local target = name or chat.active_name()
  local buffer = chat.buffers and chat.buffers[target]
  if not buffer then return false end
  buffer.messages, buffer.unread = {}, 0
  return true
end

function chat.set_preserve(value) settings().preserve_main = value == true; aardwolf_mudlet.settings.save(); return true end
function chat.set_logging(value) settings().logging = value == true; aardwolf_mudlet.settings.save(); return true end

function chat.render(limit)
  local buffer = chat.active_buffer()
  local output = {}
  local first = math.max(1, #buffer.messages - (limit or 80) + 1)
  for index = first, #buffer.messages do
    local entry = buffer.messages[index]
    local player = entry.player ~= "" and ("<b>" .. aardwolf_mudlet.util.escape(entry.player) .. ":</b> ") or ""
    output[#output + 1] = string.format("<font color='#8fa3bc'>[%s] [%s]</font> %s%s", os.date("%H:%M:%S", entry.time),
      aardwolf_mudlet.util.escape(entry.channel), player, aardwolf_mudlet.util.escape(entry.plain))
  end
  if #output == 0 then output[1] = "<font color='#8fa3bc'>No messages captured for this tab.</font>" end
  return table.concat(output, "<br>")
end

function chat.copy_active(raw)
  if type(setClipboardText) ~= "function" then return false, "Clipboard support is unavailable" end
  local rows = {}
  for _, entry in ipairs(chat.active_buffer().messages) do rows[#rows + 1] = raw and entry.raw or entry.plain end
  setClipboardText(table.concat(rows, "\n"))
  return true
end

function chat.open_url(url)
  url = clean(url, 500)
  if not url or not url:match("^https?://[%w%-%._~:/%?#%[%]@!$&'()%*+,;=%%]+$") then return false, "Only valid HTTP or HTTPS URLs are allowed" end
  if type(openUrl) ~= "function" then return false, "URL support is unavailable" end
  openUrl(url); return true
end
