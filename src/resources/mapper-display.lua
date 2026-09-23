local MapperDisplay = {}

local OWNER = "aardwolf-vibe.mapper-display"

function MapperDisplay.new(api, workspace)
  local self = {enabled = false, lastError = nil}
  local root, mapper, panelHandle

  local function unmount()
    if root then root:delete() end
    root, mapper = nil, nil
    return true
  end

  function self:start()
    if self.enabled then return true end
    local handle, message = workspace:registerPanel({
      id = OWNER,
      title = "Map",
      minimumWidth = 280,
      minimumHeight = 260,
      mount = function(parent)
        local geyser = assert(api.Geyser, "Geyser is required for the mapper display")
        assert(type(geyser.Container) == "table" and type(geyser.Mapper) == "table",
          "Embedded mapper widgets are required")
        root = geyser.Container:new({name = OWNER .. ".root", x = 0, y = 0,
          width = "100%", height = "100%"}, parent)
        mapper = geyser.Mapper:new({name = OWNER .. ".map", x = 0, y = 0,
          width = "100%", height = "100%", embedded = true}, root)
        return root
      end,
      unmount = unmount,
    })
    if not handle then
      unmount()
      self.lastError = "Cannot start mapper display: " .. tostring(message)
      return false
    end
    panelHandle = handle
    self.enabled, self.lastError = true, nil
    return true
  end

  function self:show()
    if not self.enabled and not self:start() then return false, self.lastError end
    return panelHandle:show()
  end

  function self:stop()
    if self.enabled then workspace:unregisterPanel(OWNER) end
    unmount()
    panelHandle, self.enabled = nil, false
    return true
  end

  function self:status()
    return {enabled = self.enabled, lastError = self.lastError}
  end

  return self
end

return MapperDisplay
