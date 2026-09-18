local Character = {}

local OWNER = "aardwolf-vibe.character"
local GROUPS = {"base", "vitals", "stats", "maxstats", "status", "worth"}

local CLASS_NAMES = {
  [0] = "Mage",
  [1] = "Cleric",
  [2] = "Thief",
  [3] = "Warrior",
  [4] = "Ranger",
  [5] = "Paladin",
  [6] = "Psionicist",
}

local STATE_NAMES = {
  [1] = "At login screen, no player yet",
  [2] = "Player at MOTD or other login sequence",
  [3] = "Player fully active and able to receive MUD commands",
  [4] = "Player AFK",
  [5] = "Player in note mode",
  [6] = "Player in building/edit mode",
  [7] = "Player at paged output prompt",
  [8] = "Player in combat",
  [9] = "Player sleeping",
  [11] = "Player resting or sitting",
  [12] = "Player running",
}

local SCHEMA = {
  base = {
    name = "string", ["class"] = "string", subclass = "string", race = "string",
    clan = "string", pretitle = "string", classes = "classes", perlevel = "integer",
    tier = "integer", remorts = "integer", redos = "integer", level = "integer",
    pups = "integer", totpups = "integer",
  },
  vitals = {hp = "integer", mana = "integer", moves = "integer"},
  stats = {
    str = "integer", int = "integer", wis = "integer", dex = "integer",
    con = "integer", luck = "integer", hr = "integer", dr = "integer",
    saves = "integer",
  },
  maxstats = {
    maxhp = "integer", maxmana = "integer", maxmoves = "integer",
    maxstr = "integer", maxint = "integer", maxwis = "integer",
    maxdex = "integer", maxcon = "integer", maxluck = "integer",
  },
  status = {
    level = "integer", tnl = "integer", hunger = "integer", thirst = "integer",
    align = "integer", state = "integer", pos = "string", enemy = "string",
    enemypct = "integer",
  },
  worth = {
    gold = "integer", bank = "integer", qp = "integer", tp = "integer",
    trains = "integer", pracs = "integer", qpearned = "integer",
  },
}

local GROUP_SET = {}
for _, group in ipairs(GROUPS) do GROUP_SET[group] = true end

local function finite(number)
  return type(number) == "number" and number == number
    and number ~= math.huge and number ~= -math.huge
end

local function exactInteger(value)
  return finite(value) and value % 1 == 0 and math.abs(value) <= 9007199254740991
end

local function validString(value)
  return type(value) == "string" and #value <= 4096
    and not value:find("[%z\1-\31\127]")
end

local function validClasses(value)
  if not validString(value) or not value:match("^[0-6]*$") then return false end
  local seen = {}
  for id in value:gmatch(".") do
    if seen[id] then return false end
    seen[id] = true
  end
  return true
end

local function copy(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, item in pairs(value) do result[key] = copy(item) end
  return result
end

local function boundedCopy(value, depth, budget)
  budget.items = budget.items + 1
  if depth > 8 or budget.items > 512 then error("character group exceeds item limits", 0) end
  local kind = type(value)
  if kind == "table" then
    local result = {}
    for key, item in pairs(value) do
      if type(key) == "string" then
        if #key > 128 or key:find("[%z\1-\31\127]") then
          error("character group contains an invalid key", 0)
        end
      elseif not exactInteger(key) or key < 1 or key > 1000000 then
        error("character group contains an invalid key", 0)
      end
      result[key] = boundedCopy(item, depth + 1, budget)
    end
    return result
  elseif kind == "string" then
    if value:find("[%z\1-\31\127]") then
      error("character group contains invalid text", 0)
    end
    budget.bytes = budget.bytes + #value
    if budget.bytes > 65536 then error("character group exceeds text limits", 0) end
  elseif kind == "number" then
    if not finite(value) then error("character group contains a non-finite number", 0) end
  elseif kind ~= "boolean" then
    error("character group contains an unsupported value", 0)
  end
  return value
end

local function normalize(group, data)
  if not GROUP_SET[group] then return nil, nil, "Unknown character group: " .. tostring(group) end
  if type(data) ~= "table" then return nil, nil, "Missing char." .. group end
  local ok, raw = pcall(boundedCopy, data, 0, {items = 0, bytes = 0})
  if not ok then return nil, nil, raw end
  local normalized = {}
  for field, expected in pairs(SCHEMA[group]) do
    local value = data[field]
    if value ~= nil then
      local valid = expected == "integer" and exactInteger(value)
        or expected == "string" and validString(value)
        or expected == "classes" and validClasses(value)
      if not valid then
        return nil, nil, "Invalid char." .. group .. "." .. field
      end
      normalized[field] = value
    end
  end
  return normalized, raw
end

function Character.new(api)
  local self = {
    enabled = false,
    accepted = 0,
    rejected = 0,
    eventErrors = 0,
    failedStarts = 0,
    lastError = nil,
  }
  local groups, rawGroups, fresh = {}, {}, {}
  local generation, session, sequence = 0, 0, 0
  local moduleRequested = false

  local function clearState()
    groups, rawGroups, fresh = {}, {}, {}
    for _, group in ipairs(GROUPS) do fresh[group] = false end
    sequence = 0
  end

  local function emit(name, ...)
    local ok, message = pcall(api.raiseEvent, name, ...)
    if not ok then
      self.eventErrors = self.eventErrors + 1
      self.lastError = "Cannot raise " .. name .. ": " .. tostring(message)
    end
  end

  local function reset(reason, token, beginSession)
    if not self.enabled or token ~= generation then return false end
    if beginSession then session = session + 1 end
    clearState()
    emit("aardwolf-vibe.character.reset", reason, session)
    return true
  end

  local function receive(group, token)
    if not self.enabled or token ~= generation then return false end
    local gmcp = api.gmcp
    local char = type(gmcp) == "table" and gmcp.char or nil
    local data = type(char) == "table" and char[group] or nil
    local normalized, raw, message = normalize(group, data)
    if not normalized then
      self.rejected = self.rejected + 1
      self.lastError = message
      return false
    end
    groups[group], rawGroups[group], fresh[group] = normalized, raw, true
    sequence = sequence + 1
    self.accepted = self.accepted + 1
    self.lastError = nil
    emit("aardwolf-vibe.character.updated", group, copy(normalized), copy(raw), session, sequence)
    emit("aardwolf-vibe.character.updated." .. group,
      copy(normalized), copy(raw), session, sequence)
    return true
  end

  local function removeHandlers()
    for _, group in ipairs(GROUPS) do api.deleteNamedEventHandler(OWNER, group) end
    for _, name in ipairs({"disconnect", "connect", "protocol"}) do
      api.deleteNamedEventHandler(OWNER, name)
    end
  end

  local function cleanup()
    generation = generation + 1
    self.enabled = false
    removeHandlers()
    if moduleRequested then
      api.gmod.disableModule(OWNER, "Char")
      moduleRequested = false
    end
    clearState()
  end

  function self:start()
    if self.enabled then return true end
    cleanup()
    generation = generation + 1
    local token = generation
    local previousSession = session
    local ok, message = pcall(function()
      for _, group in ipairs(GROUPS) do
        local current = group
        if api.registerNamedEventHandler(OWNER, current, "gmcp.char." .. current,
            function() receive(current, token) end) ~= true then
          error("Cannot register char." .. current .. " handler", 0)
        end
      end
      if api.registerNamedEventHandler(OWNER, "disconnect", "sysDisconnectionEvent",
          function() reset("disconnect", token, false) end) ~= true then
        error("Cannot register disconnect handler", 0)
      end
      if api.registerNamedEventHandler(OWNER, "connect", "sysConnectionEvent",
          function() reset("connect", token, true) end) ~= true then
        error("Cannot register connect handler", 0)
      end
      if api.registerNamedEventHandler(OWNER, "protocol", "sysProtocolDisabled",
          function(_, protocol)
            if protocol == "GMCP" then reset("gmcp-disabled", token, false) end
          end) ~= true then
        error("Cannot register protocol handler", 0)
      end
      session = session + 1
      clearState()
      self.enabled = true
      moduleRequested = true
      api.gmod.enableModule(OWNER, "Char")
    end)
    if not ok then
      self.failedStarts = self.failedStarts + 1
      cleanup()
      session = previousSession
      self.lastError = "Cannot start character handler: " .. tostring(message)
      return false
    end
    self.lastError = nil
    return true
  end

  function self:stop()
    cleanup()
    return true
  end

  function self:status()
    return {
      enabled = self.enabled,
      lifecycle = self.enabled and "active" or "stopped",
      accepted = self.accepted,
      rejected = self.rejected,
      eventErrors = self.eventErrors,
      failedStarts = self.failedStarts,
      lastError = self.lastError,
      session = session,
      sequence = sequence,
      fresh = copy(fresh),
    }
  end

  function self:snapshot()
    return {
      session = session,
      sequence = sequence,
      fresh = copy(fresh),
      groups = copy(groups),
      raw = copy(rawGroups),
    }
  end

  function self:getGroup(group)
    if not GROUP_SET[group] then return nil, nil, false end
    return copy(groups[group]), copy(rawGroups[group]), fresh[group]
  end

  function self:isFresh(group)
    return GROUP_SET[group] and fresh[group] or false
  end

  function self:stateName(code)
    if not exactInteger(code) then return nil end
    return STATE_NAMES[code]
  end

  function self:className(id)
    if not exactInteger(id) then return nil end
    return CLASS_NAMES[id]
  end

  return self
end

return Character
