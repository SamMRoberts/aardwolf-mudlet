local Store = {}

local DATABASE_NAME = "aardwolfvibemobdeaths"

local function key(row)
  -- Length prefixes avoid collisions when names or areas contain punctuation.
  local name, area = row.name:lower(), row.area:lower()
  return #name .. ":" .. name .. row.level .. ":" .. #area .. ":" .. area
end

function Store.new(api)
  local self = {lastError = nil}
  local database

  function self:open()
    if database then return true end
    local ok, result = pcall(api.db.create, api.db, DATABASE_NAME, {
      mobs = {identity = "", name = "", level = 0, area = "", killed = 0,
        observed = 0, _unique = {"identity"},
        _index = {"name", "area", "level"}},
    })
    if not ok or type(result) ~= "table" or not result.mobs then
      self.lastError = "Cannot open mob deaths database: " .. tostring(result)
      return false, self.lastError
    end
    database = result
    self.lastError = nil
    return true
  end

  function self:save(rows, observed)
    if not database then return false, "Mob deaths database is not open" end
    if type(rows) ~= "table" or type(observed) ~= "number" then
      return false, "Invalid mob deaths snapshot"
    end
    local ok, failure = pcall(function()
      local begun, beginError = database:_begin()
      assert(begun ~= false and not (begun == nil and beginError),
        beginError or "Cannot begin mob deaths transaction")
      for _, row in ipairs(rows) do
        local identity = key(row)
        local existing = api.db:fetch(database.mobs,
          api.db:eq(database.mobs.identity, identity))
        assert(type(existing) == "table", "Cannot read mob deaths record")
        if existing[1] then
          local record = existing[1]
          record.name, record.level, record.area = row.name, row.level, row.area
          record.killed, record.observed = row.killed, observed
          local updated, message = api.db:update(database.mobs, record)
          assert(updated ~= false and not (updated == nil and message),
            message or "Cannot update mob deaths record")
        else
          local added, message = api.db:add(database.mobs, {
            identity = identity, name = row.name, level = row.level,
            area = row.area, killed = row.killed, observed = observed,
          })
          assert(added ~= false and not (added == nil and message),
            message or "Cannot add mob deaths record")
        end
      end
      local committed, commitError = database:_commit()
      assert(committed ~= false and not (committed == nil and commitError),
        commitError or "Cannot commit mob deaths transaction")
      local ended, endError = database:_end()
      assert(ended ~= false and not (ended == nil and endError),
        endError or "Cannot end mob deaths transaction")
    end)
    if not ok then
      pcall(database._rollback, database)
      pcall(database._end, database)
      self.lastError = "Cannot save mob deaths: " .. tostring(failure)
      return false, self.lastError
    end
    self.lastError = nil
    return true
  end

  function self:search(filters)
    if not database then return nil, "Mob deaths database is not open" end
    filters = filters or {}
    local name = type(filters.name) == "string" and filters.name:lower() or ""
    local area = type(filters.area) == "string" and filters.area:lower() or ""
    local minimum, maximum = filters.minimum, filters.maximum
    local ok, records = pcall(api.db.fetch, api.db, database.mobs)
    if not ok or type(records) ~= "table" then
      return nil, "Cannot read mob deaths database: " .. tostring(records)
    end
    local matched = {}
    for _, record in ipairs(records) do
      if type(record.name) == "string" and type(record.area) == "string"
          and type(record.level) == "number" and type(record.killed) == "number"
          and record.name:lower():find(name, 1, true)
          and record.area:lower():find(area, 1, true)
          and (not minimum or record.level >= minimum)
          and (not maximum or record.level <= maximum) then
        matched[#matched + 1] = {name = record.name, area = record.area,
          level = record.level, killed = record.killed, observed = record.observed}
      end
    end
    table.sort(matched, function(a, b)
      local an, bn = a.name:lower(), b.name:lower()
      if an ~= bn then return an < bn end
      local aa, ba = a.area:lower(), b.area:lower()
      if aa ~= ba then return aa < ba end
      return a.level < b.level
    end)
    return matched
  end

  function self:close()
    if database then pcall(api.db.close, api.db, DATABASE_NAME) end
    database = nil
    return true
  end

  return self
end

return Store
