local ChatModel = {}

local MAX_TABS = 24
local MAX_CHANNELS_PER_TAB = 64
local MAX_MESSAGE_BYTES = 65536

local KNOWN_CHANNELS = {
  "answer", "auction", "barter", "cant", "chant", "claninfo", "clantalk",
  "commune", "curse", "debate", "ftalk", "gametalk", "gclan", "gossip",
  "grapevine", "gratz", "gsocial", "gtell", "helper", "immtalk", "inform",
  "ltalk", "market", "mobsay", "music", "newbie", "nobletalk", "pokerinfo",
  "question", "quote", "racetalk", "restores", "rp", "say", "spouse",
  "tech", "telepathy", "tell", "tiertalk", "wangrp", "wardrums", "yell",
}

local DEFAULT_TABS = {
  {id = "all", label = "All", channels = {"*"}},
  {id = "tell", label = "Tell", channels = {"tell"}},
  {id = "group", label = "Group", channels = {"gtell"}},
  {id = "clan", label = "Clan", channels = {"clantalk", "gclan", "claninfo"}},
  {id = "newbie", label = "Newbie",
    channels = {"newbie", "helper", "nobletalk", "question", "answer"}},
  {id = "gossip", label = "Gossip", channels = {"gossip"}},
}

local ANSI = {
  {0, 0, 0}, {170, 0, 0}, {0, 170, 0}, {170, 85, 0},
  {0, 0, 170}, {170, 0, 170}, {0, 170, 170}, {170, 170, 170},
  {85, 85, 85}, {255, 85, 85}, {85, 255, 85}, {255, 255, 85},
  {85, 85, 255}, {255, 85, 255}, {85, 255, 255}, {255, 255, 255},
}

local RAW_COLORS = {
  b = 4, B = 12, c = 6, C = 14, r = 1, R = 9, m = 5, M = 13,
  g = 2, G = 10, w = 7, W = 15, y = 3, Y = 11, D = 8,
}

local function copy(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, item in pairs(value) do result[copy(key)] = copy(item) end
  return result
end

local function dense(value)
  if type(value) ~= "table" then return false end
  local count = 0
  for key in pairs(value) do
    if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then return false end
    count = count + 1
  end
  return count == #value
end

local function validString(value, maximum, allowEmpty)
  return type(value) == "string" and #value <= maximum
    and (allowEmpty or #value > 0) and not value:find("[%z\1-\31\127]")
end

local function validChannel(value)
  return type(value) == "string" and #value >= 1 and #value <= 80
    and value:match("^[%w_%-]+$") ~= nil
end

local function xterm(number)
  if number < 16 then return copy(ANSI[number + 1]) end
  if number < 232 then
    local levels = {0, 95, 135, 175, 215, 255}
    local value = number - 16
    return {
      levels[math.floor(value / 36) + 1],
      levels[math.floor(value / 6) % 6 + 1],
      levels[value % 6 + 1],
    }
  end
  local gray = 8 + (number - 232) * 10
  return {gray, gray, gray}
end

function ChatModel.copy(value)
  return copy(value)
end

function ChatModel.knownChannels()
  return copy(KNOWN_CHANNELS)
end

function ChatModel.defaultConfig()
  return {schemaVersion = 1, colorMode = "ansi", tabs = copy(DEFAULT_TABS)}
end

function ChatModel.validateConfig(value)
  if type(value) ~= "table" or value.schemaVersion ~= 1
      or (value.colorMode ~= "ansi" and value.colorMode ~= "raw")
      or not dense(value.tabs) or #value.tabs < 1 or #value.tabs > MAX_TABS then
    return nil, "Chat configuration must contain schemaVersion 1, a color mode, and 1-24 tabs"
  end
  local ids = {}
  for index, tab in ipairs(value.tabs) do
    if type(tab) ~= "table" or not validChannel(tab.id)
        or not validString(tab.label, 80, false)
        or not dense(tab.channels) or #tab.channels < 1
        or #tab.channels > MAX_CHANNELS_PER_TAB then
      return nil, "Invalid chat tab at position " .. tostring(index)
    end
    if ids[tab.id] then return nil, "Duplicate chat tab ID: " .. tab.id end
    ids[tab.id] = true
    local channels = {}
    for _, channel in ipairs(tab.channels) do
      if channel ~= "*" and not validChannel(channel) then
        return nil, "Invalid channel in " .. tab.label
      end
      local normalized = channel:lower()
      if channels[normalized] then return nil, "Duplicate channel in " .. tab.label end
      channels[normalized] = true
    end
  end
  return copy(value)
end

function ChatModel.normalize(raw)
  if type(raw) ~= "table" or not validChannel(raw.chan)
      or type(raw.msg) ~= "string" or #raw.msg > MAX_MESSAGE_BYTES
      or raw.msg:find("[%z\1-\8\11\12\14-\26\28-\31\127]")
      or raw.msg:find("[\r\n]")
      or (raw.player ~= nil and not validString(raw.player, 160, true)) then
    return nil, "Malformed comm.channel payload"
  end
  return {
    channel = raw.chan:lower(),
    text = raw.msg,
    player = raw.player or "",
  }
end

function ChatModel.destinations(message, config)
  local result = {}
  if type(message) ~= "table" or type(message.channel) ~= "string" then return result end
  for _, tab in ipairs(config.tabs or {}) do
    for _, channel in ipairs(tab.channels or {}) do
      if channel == "*" or channel:lower() == message.channel then
        result[#result + 1] = tab.id
        break
      end
    end
  end
  return result
end

local function addRun(runs, text, foreground, background)
  if text == "" then return end
  text = text:gsub("[%z\1-\8\11\12\14-\31\127]", "")
  if text == "" then return end
  local previous = runs[#runs]
  if previous and previous.fg[1] == foreground[1] and previous.fg[2] == foreground[2]
      and previous.fg[3] == foreground[3] and previous.bg[1] == background[1]
      and previous.bg[2] == background[2] and previous.bg[3] == background[3] then
    previous.text = previous.text .. text
  else
    runs[#runs + 1] = {
      text = text,
      fg = copy(foreground),
      bg = copy(background),
    }
  end
end

local function applySGR(codes, foreground, background)
  local defaultForeground, defaultBackground = {224, 230, 236}, {0, 0, 0}
  local index = 1
  while index <= #codes do
    local code = codes[index]
    if code == 0 then
      foreground, background = copy(defaultForeground), copy(defaultBackground)
    elseif code == 39 then
      foreground = copy(defaultForeground)
    elseif code == 49 then
      background = copy(defaultBackground)
    elseif code >= 30 and code <= 37 then
      foreground = xterm(code - 30)
    elseif code >= 40 and code <= 47 then
      background = xterm(code - 40)
    elseif code >= 90 and code <= 97 then
      foreground = xterm(code - 90 + 8)
    elseif code >= 100 and code <= 107 then
      background = xterm(code - 100 + 8)
    elseif code == 38 or code == 48 then
      local color
      if codes[index + 1] == 5 and codes[index + 2]
          and codes[index + 2] >= 0 and codes[index + 2] <= 255 then
        color = xterm(codes[index + 2])
        index = index + 2
      elseif codes[index + 1] == 2 and codes[index + 4]
          and codes[index + 2] >= 0 and codes[index + 2] <= 255
          and codes[index + 3] >= 0 and codes[index + 3] <= 255
          and codes[index + 4] >= 0 and codes[index + 4] <= 255 then
        color = {codes[index + 2], codes[index + 3], codes[index + 4]}
        index = index + 4
      end
      if color then
        if code == 38 then foreground = color else background = color end
      end
    end
    index = index + 1
  end
  return foreground, background
end

function ChatModel.colorRuns(text, mode)
  if type(text) ~= "string" or #text > MAX_MESSAGE_BYTES
      or (mode ~= "ansi" and mode ~= "raw") then return nil, "Invalid chat text" end
  local runs = {}
  local foreground, background = {224, 230, 236}, {0, 0, 0}
  local position, start = 1, 1
  local function flush(last)
    if last >= start then addRun(runs, text:sub(start, last), foreground, background) end
  end
  while position <= #text do
    local first, last, sequence = text:find("^\27%[([%d;]*)m", position)
    local marker = mode == "raw" and text:sub(position, position) == "@"
      and text:sub(position + 1, position + 1) or nil
    local digits = marker == "x" and text:sub(position + 2, position + 4):match("^%d%d%d") or nil
    if first then
      flush(position - 1)
      local codes = {}
      for part in (sequence .. ";"):gmatch("(.-);") do
        local code = tonumber(part)
        codes[#codes + 1] = code or 0
      end
      foreground, background = applySGR(codes, foreground, background)
      position, start = last + 1, last + 1
    elseif marker and (RAW_COLORS[marker] or marker == "@" or marker == "-"
        or (digits and tonumber(digits) <= 255)) then
      flush(position - 1)
      if RAW_COLORS[marker] then
        foreground = xterm(RAW_COLORS[marker])
        position = position + 2
      elseif digits then
        foreground = xterm(tonumber(digits))
        position = position + 5
      else
        addRun(runs, marker == "@" and "@" or "~", foreground, background)
        position = position + 2
      end
      start = position
    elseif text:byte(position) == 27 then
      flush(position - 1)
      position = position + 1
      start = position
    else
      position = position + 1
    end
  end
  flush(#text)
  return runs
end

return ChatModel
