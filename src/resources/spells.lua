local Spells = {}

local OWNER = "aardwolf-vibe.spells"
local MAX_ROWS = 4096
local MAX_BYTES = 1024 * 1024
local SNAPSHOT_TIMEOUT = 10
local TAG_TRIGGER = [[^\{(?:spellup-(?:start|end)\}|(?:affon|affoff|recon|recoff|sfail)\}|spellheaders(?:\s|\})|recoveries(?:\s|\})|/(?:spellheaders|recoveries)\})]]
local RESPONSE_TRIGGER = [[^(?:Queueing (?:spell|skill) : .+\.$|No spells or skills cast\.$|(?i:.*retry.*(?:unknown|invalid|syntax|usage).*))$]]

local REQUESTS = {
  {kind = "catalog", command = "slist noprompt"},
  {kind = "classification", command = "slist spellup noprompt"},
}
local ACTIVE_REQUEST = {kind = "active", command = "slist affected noprompt"}
local RECOVERY_REQUEST = {kind = "recoveries", command = "slist recoveries noprompt"}
local DELTA_REQUESTS = {ACTIVE_REQUEST, RECOVERY_REQUEST}

local function copy(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, item in pairs(value) do result[key] = copy(item) end
  return result
end

local function integer(value, minimum, maximum)
  local number = tonumber(value)
  if not number or number ~= number or number == math.huge or number == -math.huge
      or number % 1 ~= 0 or number < (minimum or 0)
      or number > (maximum or 2147483647) then return nil end
  return number
end

local function trim(value)
  return type(value) == "string" and value:match("^%s*(.-)%s*$") or ""
end

local function headerFor(text)
  local header, arguments = text:match("^{(spellheaders)([^}]*)}$")
  if not header then header, arguments = text:match("^{(recoveries)([^}]*)}$") end
  if not header then return nil end
  if arguments ~= "" and not arguments:match("^%s") then return nil end
  return header, trim(arguments)
end

local function expectedHeader(request, header, arguments)
  if not request then return false end
  if request.kind == "catalog" then
    return header == "spellheaders" and (arguments == "" or arguments == "noprompt")
  elseif request.kind == "classification" then
    return header == "spellheaders"
      and (arguments == "spellup" or arguments == "spellup noprompt")
  elseif request.kind == "active" then
    return header == "spellheaders"
      and (arguments == "affected" or arguments == "affected noprompt")
  elseif request.kind == "recoveries" then
    return header == "recoveries" and (arguments == "" or arguments == "noprompt"
      or arguments == "recoveries" or arguments == "recoveries noprompt")
  end
  return false
end

local function parseSpellRow(text)
  local id, name, target, duration, practice, recovery, abilityType =
    text:match("^(%d+),([^,]+),(%d+),(%d+),(%d+),(%-?%d+),(%d+)$")
  id = integer(id)
  target = integer(target, 0, 5)
  duration = integer(duration)
  practice = integer(practice, 0, 100)
  recovery = integer(recovery, -1)
  abilityType = integer(abilityType, 1, 2)
  if not id or not target or not duration or not practice or not recovery or not abilityType
      or type(name) ~= "string" or name == "" or #name > 1024 then return nil end
  return id, {
    id = id,
    name = name,
    target = target,
    duration = duration,
    practice = practice,
    recovery = recovery,
    type = abilityType,
  }
end

local function parseRecoveryRow(text)
  local id, name, duration = text:match("^(%d+),([^,]+),(%d+)$")
  id, duration = integer(id), integer(duration)
  if not id or not duration or type(name) ~= "string" or name == "" or #name > 1024 then
    return nil
  end
  return id, {id = id, name = name, duration = duration}
end

function Spells.new(api, character, settings)
  local self = {
    enabled = false,
    accepted = 0,
    rejected = 0,
    lastError = nil,
    hideTags = true,
  }
  local catalog, classification, active, expired, recoveries = {}, {}, {}, {}, {}
  local handlers = {}
  local triggerIDs, captureID = {}, nil
  local frame, timeout, driveTimer, hiddenFrame, hiddenFrameTimeout
  local generation, session = 0, 0
  local monitoring, fresh, busy, pending = false, false, false, true
  local resyncAfter = false
  local deltaRefreshPending = false
  local requestPlan, requestIndex, request
  local lastBaseSignature
  local receive

  local function now()
    if type(api.getEpoch) == "function" then return api.getEpoch() end
    return os.time()
  end

  local function connected()
    if type(api.getConnectionInfo) ~= "function" then return false end
    local ok, _, _, value = pcall(api.getConnectionInfo)
    return ok and value == true
  end

  local function commandReady()
    if not self.enabled or not connected() or type(character) ~= "table"
        or type(character.isFresh) ~= "function" or not character:isFresh("status") then
      return false
    end
    local status = select(1, character:getGroup("status"))
    return type(status) == "table" and status.state == 3
  end

  local function emit(name, ...)
    local ok, message = pcall(api.raiseEvent, OWNER .. "." .. name, ...)
    if not ok then self.lastError = "Cannot raise spell event: " .. tostring(message) end
  end

  local function changed()
    emit("updated", self:snapshot())
  end

  local function suppressOwnedLine()
    if self.hideTags then api.deleteLine() end
  end

  local function cancelTimer(id)
    if id then pcall(api.killTimer, id) end
  end

  local function cancelLineCapture()
    if captureID then pcall(api.killTrigger, captureID); captureID = nil end
  end

  local function startLineCapture()
    cancelLineCapture()
    local token = generation
    captureID = assert(api.tempLineTrigger(1, MAX_ROWS + 1, function()
      if self.enabled and token == generation then receive(api.line) end
    end), "Cannot register spell frame trigger")
  end

  local function clearHiddenFrame()
    local hadHiddenFrame = hiddenFrame ~= nil
    cancelTimer(hiddenFrameTimeout)
    hiddenFrame, hiddenFrameTimeout = nil, nil
    if hadHiddenFrame and not frame then cancelLineCapture() end
  end

  local function startHiddenFrame(header)
    clearHiddenFrame()
    hiddenFrame = {header = header, lines = 0, bytes = 0}
    local token = generation
    hiddenFrameTimeout = api.tempTimer(SNAPSHOT_TIMEOUT, function()
      hiddenFrameTimeout = nil
      if self.enabled and token == generation then
        cancelLineCapture()
        hiddenFrame = nil
      end
    end)
    startLineCapture()
  end

  local function cancelRequest()
    cancelTimer(timeout)
    cancelLineCapture()
    timeout, frame, request, busy = nil, nil, nil, false
  end

  local function scheduleDrive()
    if not self.enabled or driveTimer then return end
    local token = generation
    driveTimer = api.tempTimer(0, function()
      driveTimer = nil
      if self.enabled and token == generation then self:_drive() end
    end)
  end

  local function fail(reason)
    cancelRequest()
    requestPlan, requestIndex, pending, fresh = nil, nil, false, false
    self.rejected = self.rejected + 1
    self.lastError = tostring(reason)
    emit("invalid", self.lastError)
    changed()
  end

  local function armTimeout(kind)
    cancelTimer(timeout)
    local token = generation
    timeout = assert(api.tempTimer(SNAPSHOT_TIMEOUT, function()
      timeout = nil
      if self.enabled and token == generation and (request or frame) then
        fail("Spell snapshot timed out: " .. tostring(kind or "unknown"))
      end
    end), "Cannot schedule spell snapshot timeout")
  end

  local function effectName(id)
    return catalog[id] and catalog[id].name or "Spell #" .. tostring(id)
  end

  local function confirmExpired(id, at)
    if not active[id] then return false end
    expired[id] = {id = id, expiredAt = at}
    active[id] = nil
    return true
  end

  local function applyDelta(event)
    if event.kind == "affon" then
      expired[event.id] = nil
      active[event.id] = {
        id = event.id,
        reported = event.at,
        duration = event.duration,
        expires = event.at + event.duration,
      }
      emit("applied", event.id)
    elseif event.kind == "affoff" then
      confirmExpired(event.id, event.at)
      emit("missing", event.id)
    elseif event.kind == "recon" then
      local old = recoveries[event.id]
      recoveries[event.id] = {
        id = event.id,
        name = old and old.name or "Recovery #" .. tostring(event.id),
        reported = event.at,
        duration = event.duration,
        expires = event.at + event.duration,
      }
    elseif event.kind == "recoff" then
      recoveries[event.id] = nil
      emit("recovered", event.id)
    elseif event.kind == "sfail" then
      emit("failure", copy(event))
    end
  end

  local function commit(completed)
    if completed.kind == "catalog" then
      catalog = completed.rows
    elseif completed.kind == "classification" then
      classification = {}
      for id in pairs(completed.rows) do classification[id] = true end
    elseif completed.kind == "active" then
      local previous = active
      local replacement = {}
      for id, row in pairs(completed.rows) do
        if row.duration > 0 then
          expired[id] = nil
          replacement[id] = {
            id = id,
            reported = completed.at,
            duration = row.duration,
            expires = completed.at + row.duration,
          }
        end
        if not catalog[id] then catalog[id] = row end
      end
      for id in pairs(previous) do
        if not replacement[id] then
          expired[id] = {id = id, expiredAt = completed.at}
          emit("missing", id)
        end
      end
      active = replacement
    elseif completed.kind == "recoveries" then
      local replacement = {}
      for id, row in pairs(completed.rows) do
        if row.duration > 0 then
          replacement[id] = {
            id = id,
            name = row.name,
            reported = completed.at,
            duration = row.duration,
            expires = completed.at + row.duration,
          }
        end
      end
      recoveries = replacement
    end
    for _, event in ipairs(completed.deltas) do applyDelta(event) end
  end

  local function completeFrame()
    local completed = frame
    frame = nil
    cancelLineCapture()
    cancelTimer(timeout)
    timeout = nil
    commit(completed)
    self.accepted = self.accepted + 1
    request, busy = nil, false
    requestIndex = requestIndex + 1
    if requestIndex > #requestPlan then
      requestPlan, requestIndex = nil, nil
      fresh, pending = true, false
      self.lastError = nil
      emit("synced", self:snapshot())
      changed()
      if resyncAfter then
        resyncAfter = false
        requestPlan, requestIndex = REQUESTS, 1
        pending, fresh = true, false
        scheduleDrive()
      elseif deltaRefreshPending then
        deltaRefreshPending = false
        requestPlan, requestIndex = DELTA_REQUESTS, 1
        pending, fresh = true, false
        scheduleDrive()
      end
    else
      scheduleDrive()
    end
  end

  local function malformed(message)
    if frame then fail(message) else
      self.rejected = self.rejected + 1
      self.lastError = message
      emit("invalid", message)
      changed()
    end
  end

  local function deltaFor(tag, payload)
    local event = {kind = tag, at = now()}
    if tag == "sfail" then
      local id, target, reason, recovery = payload:match("^(%-?%d+),(%d+),(%d+),(%-?%d+)$")
      event.id = integer(id, -1)
      event.target = integer(target, 0, 1)
      event.reason = integer(reason, 0)
      event.recovery = integer(recovery, -1)
      if not event.id or not event.target or not event.reason or not event.recovery then return nil end
    elseif tag == "affon" or tag == "recon" then
      local id, duration = payload:match("^(%d+),(%d+)$")
      event.id, event.duration = integer(id), integer(duration)
      if not event.id or not event.duration then return nil end
    else
      event.id = integer(payload:match("^(%d+)$"))
      if not event.id then return nil end
    end
    return event
  end
  local function requestDeltaRefresh()
    deltaRefreshPending = true
    if not busy and not frame and not requestPlan and fresh then
      deltaRefreshPending = false
      requestPlan, requestIndex = DELTA_REQUESTS, 1
    end
    pending, fresh = true, false
    scheduleDrive()
  end

  receive = function(text)
    if not self.enabled or type(text) ~= "string" then return false end
    local value = trim(text)
    if value == "{spellup-start}" or value == "{spellup-end}" then
      suppressOwnedLine()
      emit(value == "{spellup-start}" and "batchStarted" or "complete")
      return true
    end

    local queued = not frame and (value:match("^Queueing spell : (.+)%.$")
      or value:match("^Queueing skill : (.+)%.$"))
    if queued then emit("queued", queued); return false end
    if not frame and value == "No spells or skills cast." then emit("noWork"); return false end
    local lower = value:lower()
    if not frame and lower:find("retry", 1, true)
        and (lower:find("unknown", 1, true) or lower:find("invalid", 1, true)
          or lower:find("syntax", 1, true) or lower:find("usage", 1, true)) then
      emit("unsupported", value)
      return false
    end

    local tag, payload = value:match("^{([%a]+)}(.*)$")
    if tag == "affon" or tag == "affoff" or tag == "recon"
        or tag == "recoff" or tag == "sfail" then
      suppressOwnedLine()
      local event = deltaFor(tag, payload)
      if not event then malformed("Malformed spell update: " .. tag); return true end
      if tag == "affon" or tag == "affoff" then requestDeltaRefresh() end
      if frame then
        if #frame.deltas >= MAX_ROWS then fail("Too many interleaved spell updates")
        else frame.deltas[#frame.deltas + 1] = event end
      else
        applyDelta(event)
      end
      changed()
      return true
    end

    local header, arguments = headerFor(value)
    if header then
      if expectedHeader(request, header, arguments) and not frame then
        clearHiddenFrame()
        frame = {
          header = header,
          kind = request.kind,
          rows = {},
          deltas = {},
          lines = 0,
          bytes = 0,
          at = now(),
        }
        armTimeout(request.kind)
        startLineCapture()
        suppressOwnedLine()
        return true
      end
      if frame then fail("Interrupted spell snapshot") end
      if self.hideTags then
        startHiddenFrame(header)
        api.deleteLine()
        return true
      end
      return false
    end

    if value == "{/spellheaders}" or value == "{/recoveries}" then
      if frame then
        suppressOwnedLine()
        if value ~= "{/" .. frame.header .. "}" then fail("Unmatched spell snapshot ending")
        else completeFrame() end
        return true
      end
      if hiddenFrame then clearHiddenFrame() end
      if self.hideTags then api.deleteLine(); return true end
      return false
    end

    if not frame then
      if hiddenFrame then
        local id
        if hiddenFrame.header == "recoveries" then id = parseRecoveryRow(value)
        else id = parseSpellRow(value) end
        if id then
          hiddenFrame.lines = hiddenFrame.lines + 1
          hiddenFrame.bytes = hiddenFrame.bytes + #text
          api.deleteLine()
          if hiddenFrame.lines >= MAX_ROWS or hiddenFrame.bytes >= MAX_BYTES then
            clearHiddenFrame()
          end
          return true
        end
        clearHiddenFrame()
      end
      return false
    end
    suppressOwnedLine()
    frame.lines = frame.lines + 1
    frame.bytes = frame.bytes + #text
    if frame.lines > MAX_ROWS or frame.bytes > MAX_BYTES then
      fail("Spell snapshot limit exceeded")
      return true
    end
    local id, row
    if frame.header == "recoveries" then id, row = parseRecoveryRow(value)
    else id, row = parseSpellRow(value) end
    if not id or frame.rows[id] then
      fail("Malformed or duplicate spell snapshot record")
    else
      frame.rows[id] = row
    end
    return true
  end

  local function clearState(reason)
    cancelRequest()
    clearHiddenFrame()
    cancelTimer(driveTimer)
    driveTimer = nil
    catalog, classification, active, expired, recoveries = {}, {}, {}, {}, {}
    requestPlan, requestIndex = nil, nil
    monitoring, fresh, busy, pending = false, false, false, true
    resyncAfter = false
    deltaRefreshPending = false
    lastBaseSignature = nil
    session = session + 1
    self.lastError = nil
    emit("reset", reason, session)
    changed()
  end

  function self:_drive()
    if not self.enabled or busy or frame or not pending or not commandReady() then return false end
    if not monitoring then
      local ok, message = pcall(api.sendTelnetChannel102, string.char(7, 1))
      if not ok then fail("Cannot enable Aardwolf spell tags: " .. tostring(message)); return false end
      monitoring = true
    end
    requestPlan = requestPlan or REQUESTS
    requestIndex = requestIndex or 1
    request = requestPlan[requestIndex]
    if not request then return false end
    busy = true
    armTimeout(request.kind)
    local ok, result, message = pcall(api.send, request.command, false)
    if not ok or result == false then
      fail("Spell request failed: " .. tostring(ok and message or result))
      return false
    end
    changed()
    return true
  end

  local function queue(plan)
    if not self.enabled then return false, "Tracking is disabled" end
    if busy or frame then return false, "Spell synchronization already running" end
    requestPlan = plan
    requestIndex = 1
    pending, fresh = true, false
    scheduleDrive()
    changed()
    return true, "Spell synchronization queued"
  end

  function self:sync()
    return queue(REQUESTS)
  end

  function self:confirm()
    return false, "Affected synchronization waits for affon or affoff"
  end

  function self:setHideTags(value)
    if type(value) ~= "boolean" then return nil, "Invalid spell tag setting" end
    if settings and type(settings.setSpellupsHideTags) == "function" then
      local ok, message = settings.setSpellupsHideTags(value)
      if not ok then return nil, message end
    end
    self.hideTags = value
    if not value then clearHiddenFrame() end
    changed()
    return true
  end

  function self:get(id)
    id = tonumber(id)
    if not id or not (catalog[id] or active[id]) then return nil end
    local result = copy(catalog[id] or {id = id, name = effectName(id)})
    result.spellup = classification[id] == true
    result.learned = type(result.practice) == "number" and result.practice > 1
    result.active = copy(active[id])
    return result
  end

  function self:findByName(name)
    local result = {}
    if type(name) ~= "string" then return result end
    local wanted = name:lower()
    for id, row in pairs(catalog) do
      if row.name:lower() == wanted then result[#result + 1] = self:get(id) end
    end
    table.sort(result, function(left, right) return left.id < right.id end)
    return result
  end

  function self:isLearnedSpellup(id)
    local row = catalog[id]
    return classification[id] == true and row ~= nil and row.practice > 1
  end

  function self:isAutomaticSpellup(id)
    local row = catalog[id]
    -- Aardwolf's "spellup learned" includes granted/clan abilities reported
    -- at 0% practice, while excluding ordinary 1% unlearned abilities.
    return classification[id] == true and row ~= nil and row.practice ~= 1
  end

  function self:isFresh()
    return self.enabled and connected() and fresh and monitoring
  end

  function self:snapshot()
    local timestamp = now()
    local effects = {}
    for id, effect in pairs(active) do
      local row = copy(effect)
      row.name = effectName(id)
      row.spellup = classification[id] == true
      row.learned = catalog[id] ~= nil and catalog[id].practice > 1
      row.remaining = math.max(0, math.ceil(effect.expires - timestamp))
      row.awaiting = row.remaining == 0
      effects[#effects + 1] = row
    end
    table.sort(effects, function(left, right)
      if left.expires == right.expires then return left.name < right.name end
      return left.expires < right.expires
    end)
    local expiredRows = {}
    for id, effect in pairs(expired) do
      local row = copy(effect)
      row.name = effectName(id)
      row.spellup = classification[id] == true
      row.learned = catalog[id] ~= nil and catalog[id].practice > 1
      row.elapsed = math.max(0, math.floor(timestamp - effect.expiredAt))
      expiredRows[#expiredRows + 1] = row
    end
    table.sort(expiredRows, function(left, right)
      if left.expiredAt == right.expiredAt then return left.name < right.name end
      return left.expiredAt > right.expiredAt
    end)
    local recoveryRows = {}
    for _, recovery in pairs(recoveries) do
      local row = copy(recovery)
      if row.expires then
        row.remaining = math.max(0, math.ceil(row.expires - timestamp))
        row.awaiting = row.remaining == 0
      end
      recoveryRows[#recoveryRows + 1] = row
    end
    table.sort(recoveryRows, function(left, right)
      if left.expires and right.expires and left.expires ~= right.expires then
        return left.expires < right.expires
      end
      return left.name < right.name
    end)
    return {
      session = session,
      fresh = self:isFresh(),
      monitoring = monitoring,
      busy = busy,
      pending = pending,
      catalog = copy(catalog),
      classification = copy(classification),
      active = effects,
      expired = expiredRows,
      recoveries = recoveryRows,
      lastError = self.lastError,
      hideTags = self.hideTags,
    }
  end

  function self:status()
    return {
      enabled = self.enabled,
      lifecycle = self.enabled and "active" or "stopped",
      session = session,
      fresh = self:isFresh(),
      monitoring = monitoring,
      busy = busy,
      pending = pending,
      accepted = self.accepted,
      rejected = self.rejected,
      lastError = self.lastError,
      hideTags = self.hideTags,
    }
  end

  local function removeHandlers()
    for _, name in ipairs(handlers) do pcall(api.deleteNamedEventHandler, OWNER, name) end
    handlers = {}
  end

  function self:start(hideTags)
    if type(hideTags) == "boolean" then self.hideTags = hideTags end
    if self.enabled then scheduleDrive(); return true end
    self:stop()
    generation = generation + 1
    local token = generation
    local ok, message = pcall(function()
      self.enabled = true
      local function registerTrigger(pattern)
        local id = assert(api.tempRegexTrigger(pattern, function()
          if self.enabled and token == generation and not frame and not hiddenFrame then
            receive(api.line)
          end
        end), "Cannot register spell signal trigger")
        triggerIDs[#triggerIDs + 1] = id
      end
      registerTrigger(TAG_TRIGGER)
      registerTrigger(RESPONSE_TRIGGER)
      local function on(name, event, callback)
        handlers[#handlers + 1] = name
        if api.registerNamedEventHandler(OWNER, name, event, function(...)
          if self.enabled and token == generation then callback(...) end
        end) ~= true then error("Cannot register " .. name .. " spell handler", 0) end
      end
      on("connect", "sysConnectionEvent", function() clearState("connect") end)
      on("disconnect", "sysDisconnectionEvent", function() clearState("disconnect") end)
      on("protocol", "sysProtocolDisabled", function(_, protocol)
        if protocol == "GMCP" then clearState("gmcp-disabled") end
      end)
      on("status", "aardwolf-vibe.character.updated.status", function() scheduleDrive() end)
      on("base", "aardwolf-vibe.character.updated.base", function(_, normalized)
        local signature = type(normalized) == "table" and table.concat({
          tostring(normalized.name), tostring(normalized.level), tostring(normalized.classes),
          tostring(normalized.subclass), tostring(normalized.remorts), tostring(normalized.tier),
          tostring(normalized.redos),
        }, ":") or nil
        if lastBaseSignature and signature and signature ~= lastBaseSignature then
          if busy or frame then resyncAfter = true else self:sync() end
        end
        lastBaseSignature = signature
      end)
      clearState("start")
      scheduleDrive()
    end)
    if not ok then
      self:stop()
      self.lastError = "Cannot start spell tracking: " .. tostring(message)
      return false, self.lastError
    end
    return true
  end

  function self:stop()
    generation = generation + 1
    self.enabled = false
    cancelRequest()
    clearHiddenFrame()
    cancelTimer(driveTimer)
    driveTimer = nil
    removeHandlers()
    cancelLineCapture()
    for _, id in ipairs(triggerIDs) do pcall(api.killTrigger, id) end
    triggerIDs = {}
    catalog, classification, active, expired, recoveries = {}, {}, {}, {}, {}
    requestPlan, requestIndex = nil, nil
    monitoring, fresh, busy, pending = false, false, false, false
    resyncAfter = false
    deltaRefreshPending = false
    return true
  end

  return self
end

return Spells
