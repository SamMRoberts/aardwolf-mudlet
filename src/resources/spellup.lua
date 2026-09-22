-- Coordinates one server-owned self-spellup batch at a time.  Individual
-- abilities are never cast or retried by this component.
local Spellup = {}

local OWNER = "aardwolf-vibe.spellup"
local COMMAND = "spellup learned"
local COALESCE_SECONDS = 2
local MIN_INTERVAL = 30
local BATCH_TIMEOUT = 120

local FAILURE_TEXT = {
  [1] = "Lost concentration; retrying in a later batch",
  [2] = "Already affected",
  [3] = "Waiting for recovery",
  [4] = "Waiting for mana",
  [5] = "Waiting for a room change",
  [6] = "Waiting for command readiness",
  [8] = "Spell is not learned",
  [9] = "Invalid spell target",
  [10] = "Waiting to stand",
  [11] = "Spell is disabled",
  [12] = "Waiting for moves",
}

local function copy(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, item in pairs(value) do result[key] = copy(item) end
  return result
end

function Spellup.new(api, character, spells, settings)
  local self = {enabled = false, automatic = false, lastError = nil}
  local handlers = {}
  local generation = 0
  local timer, batchTimer
  local pendingAt, lastSent
  local inflight, external = false, false
  local paused, blocked
  local initial = false
  local observed, unresolvedQueued = false, 0
  local baseline, namedTargets, resolvedUnknown = {}, {}, {}
  local targets, settled = {}, {}
  local failures = {}
  local pump, schedule

  local function now()
    if type(api.getEpoch) == "function" then return api.getEpoch() end
    return os.time()
  end

  local function connected()
    if type(api.getConnectionInfo) ~= "function" then return false end
    local ok, _, _, value = pcall(api.getConnectionInfo)
    return ok and value == true
  end

  local function emit()
    pcall(api.raiseEvent, OWNER .. ".updated", self:status())
  end

  local function cancel(id)
    if id then pcall(api.killTimer, id) end
  end

  local function gate()
    if not self.enabled then return "Controller is stopped" end
    if not connected() then return "Disconnected" end
    if not spells:isFresh() then return "Waiting for synchronized spell data" end
    if not character:isFresh("status") then return "Waiting for fresh character status" end
    local status = select(1, character:getGroup("status"))
    if type(status) ~= "table" or status.state ~= 3 then
      return "Character is not active"
    end
    if type(status.pos) ~= "string" or status.pos:lower() ~= "standing" then
      return "Character is not standing"
    end
    return nil
  end

  local function activeSet()
    local result = {}
    for _, effect in ipairs(spells:snapshot().active) do
      -- Active, non-bad spellup effects are authoritative completion evidence.
      -- Aardwolf can queue granted, clan, and racial abilities even when their
      -- catalog practice is 0% or 1%.
      if spells:isTrackedSpellup(effect.id) and not effect.awaiting then
        result[effect.id] = true
      end
    end
    return result
  end

  local function finish(reason)
    cancel(batchTimer)
    batchTimer = nil
    inflight, external = false, false
    baseline, namedTargets, resolvedUnknown = {}, {}, {}
    targets, settled = {}, {}
    observed, unresolvedQueued = false, 0
    if paused == "Batch completion unconfirmed" then paused = nil end
    self.lastError = nil
    if self.enabled and self.automatic and pendingAt then schedule() end
    emit()
    return true, reason or "Spellup complete"
  end

  local function armBatchTimeout()
    cancel(batchTimer)
    local token = generation
    batchTimer = api.tempTimer(BATCH_TIMEOUT, function()
      batchTimer = nil
      if not self.enabled or token ~= generation or not inflight then return end
      paused = "Batch completion unconfirmed"
      self.lastError = paused
      emit()
    end)
  end

  schedule = function(delay)
    if not self.enabled or timer then return end
    local token = generation
    timer = api.tempTimer(delay or 0, function()
      timer = nil
      if self.enabled and token == generation then pump() end
    end)
  end

  local function queueWork()
    if not pendingAt then pendingAt = now() + COALESCE_SECONDS end
    schedule()
    emit()
  end

  local function beginBatch(isExternal)
    if paused then return false, "Paused: " .. paused end
    if inflight then return false, "A spellup batch is already outstanding" end
    if not isExternal then
      local reason = gate()
      if reason then return false, reason end
      if lastSent and now() - lastSent < MIN_INTERVAL then
        return false, "Waiting for the minimum batch interval"
      end
    end
    inflight, external = true, isExternal == true
    -- Only effects queued by this batch are completion targets.  The baseline
    -- is retained solely to reconcile server queue aliases after a snapshot.
    baseline, namedTargets, resolvedUnknown = activeSet(), {}, {}
    targets, settled = {}, {}
    observed, unresolvedQueued = false, 0
    failures, blocked = {}, nil
    pendingAt, initial = nil, false
    lastSent = now()
    armBatchTimeout()
    if not isExternal then
      local ok, result, message = pcall(api.send, COMMAND, false)
      if not ok or result == false then
        paused = "Send failed; server batch state is uncertain"
        self.lastError = tostring(ok and message or result)
        emit()
        return false, self.lastError
      end
    end
    emit()
    return true, isExternal and "Manual spellup observed" or "Spellup submitted"
  end

  pump = function()
    if not self.enabled or paused or inflight or not self.automatic then return end
    local reason = gate()
    if reason or blocked then emit(); return end
    if initial then
      if spells:status().busy or not spells:isFresh() then return end
      pendingAt, initial = pendingAt or now(), false
    end
    if not pendingAt then return end
    local due = math.max(pendingAt, (lastSent or -math.huge) + MIN_INTERVAL)
    if due > now() then schedule(due - now()); return end
    beginBatch(false)
  end

  local function statusChanged()
    if blocked and (blocked.code == 6 or blocked.code == 10) and not gate() then
      blocked = nil
      if self.automatic then queueWork() end
    end
    schedule()
    emit()
  end

  local function vitalsChanged()
    if blocked and (blocked.code == 4 or blocked.code == 12) then
      local vitals = select(1, character:getGroup("vitals")) or {}
      local field = blocked.code == 4 and "mana" or "moves"
      if type(vitals[field]) == "number" and type(blocked.value) == "number"
          and vitals[field] > blocked.value then
        blocked = nil
        if self.automatic then queueWork() end
      end
    end
    schedule()
  end

  local function manualCommand(command)
    if type(command) ~= "string" or inflight or not connected() then return end
    local words = {}
    for word in command:lower():gmatch("%S+") do words[#words + 1] = word end
    if words[1] ~= "spellup" then return end
    local allowed = {learned = true, all = true, silent = true, quick = true}
    for index = 2, #words do
      if not allowed[words[index]] then return end
    end
    beginBatch(true)
  end

  local function removeHandlers()
    for _, name in ipairs(handlers) do pcall(api.deleteNamedEventHandler, OWNER, name) end
    handlers = {}
  end

  local function on(name, event, callback, token)
    handlers[#handlers + 1] = name
    local result = api.registerNamedEventHandler(OWNER, name, event, function(...)
      if self.enabled and token == generation then callback(...) end
    end)
    if result ~= true then error("Cannot register " .. name .. " spellup handler", 0) end
  end

  function self:status()
    local reason = paused and ("Paused: " .. paused) or blocked and blocked.reason or gate()
    return {
      enabled = self.enabled,
      lifecycle = self.enabled and "active" or "stopped",
      automatic = self.automatic,
      inflight = inflight,
      external = external,
      pending = pendingAt ~= nil or initial,
      unresolvedQueued = unresolvedQueued,
      paused = paused,
      blocked = copy(blocked),
      blockingReason = reason,
      lastSent = lastSent,
      command = COMMAND,
      lastError = self.lastError,
    }
  end

  function self:setAutomatic(value)
    if type(value) ~= "boolean" then return false, "Automatic setting must be boolean" end
    if value == self.automatic then return true end
    if settings and type(settings.setSpellupsAutoCast) == "function" then
      local ok, message = settings.setSpellupsAutoCast(value)
      if not ok then return false, message end
    end
    self.automatic = value
    cancel(timer); timer = nil
    if value then
      paused, blocked, failures = nil, nil, {}
      initial = true
      local ok, message = spells:sync()
      if not ok and message ~= "Spell synchronization already running" then
        self.lastError = message
      end
      schedule()
    else
      initial, pendingAt = false, nil
    end
    emit()
    return true
  end

  function self:resume()
    paused, blocked, failures = nil, nil, {}
    self.lastError = nil
    if inflight then
      armBatchTimeout()
    elseif self.automatic then
      initial = true
      spells:sync()
      schedule()
    end
    emit()
    return true
  end

  function self:runOnce()
    return beginBatch(false)
  end

  function self:start(automatic)
    if self.enabled then return true end
    self:stop()
    generation = generation + 1
    local token = generation
    local ok, message = pcall(function()
      self.enabled = true
      self.automatic = automatic == true
      initial = self.automatic
      on("status", "aardwolf-vibe.character.updated.status", statusChanged, token)
      on("vitals", "aardwolf-vibe.character.updated.vitals", vitalsChanged, token)
      on("reset", "aardwolf-vibe.spells.reset", function()
        if not connected() then
          cancel(batchTimer); batchTimer = nil
          inflight, external = false, false
          lastSent = nil
        end
        baseline, namedTargets, resolvedUnknown = {}, {}, {}
        targets, settled = {}, {}
        observed, unresolvedQueued = false, 0
        blocked, failures = nil, {}
        pendingAt, initial = nil, self.automatic
        schedule()
        emit()
      end, token)
      on("synced", "aardwolf-vibe.spells.synced", function()
        if inflight then
          local active = activeSet()
          for id in pairs(active) do
            if unresolvedQueued > 0 and not baseline[id] and not namedTargets[id]
                and not resolvedUnknown[id] then
              resolvedUnknown[id] = true
              targets[id] = true
              unresolvedQueued = unresolvedQueued - 1
            end
          end
          local complete = observed and unresolvedQueued == 0
          for id in pairs(targets) do
            if not active[id] and not settled[id] then complete = false end
          end
          if complete then finish("Confirmed by synchronized effects") end
        end
        schedule()
      end, token)
      on("missing", "aardwolf-vibe.spells.missing", function(_, id)
        if self.automatic and spells:isTrackedSpellup(id) then queueWork() end
      end, token)
      on("recovered", "aardwolf-vibe.spells.recovered", function(_, id)
        if blocked and blocked.code == 3 and blocked.recovery == id then
          blocked = nil
          if self.automatic then queueWork() end
        end
      end, token)
      on("queued", "aardwolf-vibe.spells.queued", function(_, name)
        if not inflight then return end
        observed = true
        local found = spells:findByName(name)
        if #found == 1 then
          targets[found[1].id] = true
          namedTargets[found[1].id] = true
        else
          unresolvedQueued = unresolvedQueued + 1
        end
        emit()
      end, token)
      on("no-work", "aardwolf-vibe.spells.noWork", function()
        if not inflight then return end
        observed, unresolvedQueued, targets = true, 0, {}
        finish("Server reported no spellup work")
      end, token)
      on("complete", "aardwolf-vibe.spells.complete", function()
        if inflight then finish("Confirmed by spellup-end") end
      end, token)
      on("external", "aardwolf-vibe.spells.batchStarted", function()
        if not inflight then beginBatch(true) end
      end, token)
      on("applied", "aardwolf-vibe.spells.applied", function(_, id)
        -- Queue prose sometimes uses a command alias rather than the catalog
        -- name (for example, "chameleon" versus "chameleon power").
        if not inflight or unresolvedQueued == 0 or namedTargets[id]
            or resolvedUnknown[id] or not spells:isTrackedSpellup(id) then return end
        resolvedUnknown[id] = true
        targets[id] = true
        unresolvedQueued = unresolvedQueued - 1
        emit()
      end, token)
      on("failure", "aardwolf-vibe.spells.failure", function(_, event)
        if not inflight or type(event) ~= "table" or event.target ~= 0 then return end
        local reason = event.reason
        if reason == 1 then
          if self.automatic then queueWork() end
          emit()
          return
        end
        if unresolvedQueued > 0 and not namedTargets[event.id]
            and not resolvedUnknown[event.id] then
          resolvedUnknown[event.id] = true
          targets[event.id] = true
          unresolvedQueued = unresolvedQueued - 1
        end
        settled[event.id] = true
        if reason == 2 then targets[event.id] = nil; emit(); return end
        local key = tostring(event.id) .. ":" .. tostring(reason)
        failures[key] = (failures[key] or 0) + 1
        local text = FAILURE_TEXT[reason] or ("Unknown failure code " .. tostring(reason))
        local vitals = select(1, character:getGroup("vitals")) or {}
        local room = type(api.gmcp) == "table" and api.gmcp.room
          and api.gmcp.room.info and api.gmcp.room.info.num
        blocked = {reason = text, code = reason, recovery = event.recovery,
          room = room,
          value = reason == 4 and vitals.mana or reason == 12 and vitals.moves or nil}
        if reason == 8 or reason == 9 or reason == 11 or not FAILURE_TEXT[reason]
            or failures[key] >= 2 then
          paused, self.lastError = text, text
        end
        emit()
      end, token)
      on("room", "gmcp.room.info", function()
        if blocked and blocked.code == 5 then
          local room = type(api.gmcp) == "table" and api.gmcp.room
            and api.gmcp.room.info and api.gmcp.room.info.num
          if room ~= blocked.room then blocked = nil; if self.automatic then queueWork() end end
        end
        schedule()
      end, token)
      on("outgoing", "sysDataSendRequest", function(_, command) manualCommand(command) end, token)
      if self.automatic then spells:sync() end
      schedule()
    end)
    if not ok then
      self:stop()
      self.lastError = "Cannot start spellup controller: " .. tostring(message)
      return false, self.lastError
    end
    return true
  end

  function self:stop()
    generation = generation + 1
    self.enabled = false
    removeHandlers()
    cancel(timer); cancel(batchTimer)
    timer, batchTimer = nil, nil
    pendingAt, initial = nil, false
    inflight, external = false, false
    paused, blocked = nil, nil
    baseline, namedTargets, resolvedUnknown = {}, {}, {}
    targets, settled, failures = {}, {}, {}
    observed, unresolvedQueued = false, 0
    return true
  end

  return self
end

return Spellup
