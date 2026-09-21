local Workspace = {}

local OWNER = "aardwolf-vibe.workspace"
local WINDOW_NAME = OWNER .. ".window"
local LAYOUT_MARKER = "AardwolfVibeWorkspaceWindowLayout"
local LAYOUT_VERSION = 1
local SCHEMA_VERSION = 1
local MAX_BYTES = 64 * 1024
local MAX_DEPTH = 16
local MAX_NODES = 128
local MIN_RATIO = 0.10
local MAX_RATIO = 0.90
local TAB_HEIGHT = 28
local SPLITTER_SIZE = 6

local function finite(value)
  return type(value) == "number" and value == value
    and value ~= math.huge and value ~= -math.huge
end

local function copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then error("cyclic workspace data", 0) end
  local result = {}
  seen[value] = result
  for key, item in pairs(value) do result[copy(key, seen)] = copy(item, seen) end
  seen[value] = nil
  return result
end

local function validID(value)
  return type(value) == "string" and #value > 0 and #value <= 128
    and value:match("^[A-Za-z0-9_.-]+$") ~= nil
end

local function defaultTree()
  return {
    type = "split",
    orientation = "vertical",
    ratio = 0.45,
    first = {
      type = "stack",
      tabs = {"aardwolf-vibe.ascii-map"},
      active = "aardwolf-vibe.ascii-map",
    },
    second = {
      type = "stack",
      tabs = {
        "aardwolf-vibe.character-window",
        "aardwolf-vibe.chat",
        "aardwolf-vibe.buffs-window",
      },
      active = "aardwolf-vibe.chat",
    },
  }
end

function Workspace.defaultState()
  return {
    schemaVersion = SCHEMA_VERSION,
    enabled = false,
    visible = true,
    tree = defaultTree(),
    hidden = {},
  }
end

local function validateTree(node, depth, context)
  if type(node) ~= "table" then return nil, "layout node must be an object" end
  if context.seen[node] then return nil, "layout contains a cycle" end
  if depth > MAX_DEPTH then return nil, "layout exceeds maximum depth" end
  context.nodes = context.nodes + 1
  if context.nodes > MAX_NODES then return nil, "layout exceeds maximum node count" end
  context.seen[node] = true
  local result
  if node.type == "stack" then
    if type(node.tabs) ~= "table" or #node.tabs < 1 then
      context.seen[node] = nil
      return nil, "stack must contain at least one panel"
    end
    local tabs = {}
    for index, id in ipairs(node.tabs) do
      if not validID(id) then
        context.seen[node] = nil
        return nil, "stack contains an invalid panel id"
      end
      if context.panels[id] then
        context.seen[node] = nil
        return nil, "duplicate panel id: " .. id
      end
      context.panels[id] = true
      tabs[index] = id
    end
    if node.active ~= nil and not context.panels[node.active] then
      context.seen[node] = nil
      return nil, "active panel is not present in its stack"
    end
    local activeFound = node.active == nil
    for _, id in ipairs(tabs) do
      if id == node.active then activeFound = true end
    end
    if not activeFound then
      context.seen[node] = nil
      return nil, "active panel is not present in its stack"
    end
    result = {type = "stack", tabs = tabs, active = node.active or tabs[1]}
  elseif node.type == "split" then
    if node.orientation ~= "horizontal" and node.orientation ~= "vertical" then
      context.seen[node] = nil
      return nil, "split orientation must be horizontal or vertical"
    end
    if not finite(node.ratio) or node.ratio < MIN_RATIO or node.ratio > MAX_RATIO then
      context.seen[node] = nil
      return nil, "split ratio is outside the supported range"
    end
    local first, message = validateTree(node.first, depth + 1, context)
    if not first then context.seen[node] = nil; return nil, message end
    local second
    second, message = validateTree(node.second, depth + 1, context)
    if not second then context.seen[node] = nil; return nil, message end
    result = {
      type = "split",
      orientation = node.orientation,
      ratio = node.ratio,
      first = first,
      second = second,
    }
  else
    context.seen[node] = nil
    return nil, "unknown layout node type"
  end
  context.seen[node] = nil
  return result
end

function Workspace.validateState(value)
  if type(value) ~= "table" or value.schemaVersion ~= SCHEMA_VERSION then
    return nil, "unsupported workspace schema"
  end
  if type(value.enabled) ~= "boolean" or type(value.visible) ~= "boolean" then
    return nil, "workspace mode and visibility must be boolean"
  end
  local context = {seen = {}, panels = {}, nodes = 0}
  local tree, message = validateTree(value.tree, 1, context)
  if not tree then return nil, message end
  if type(value.hidden) ~= "table" then return nil, "hidden panels must be an object" end
  local hidden = {}
  for id, state in pairs(value.hidden) do
    if not validID(id) or state ~= true then
      return nil, "hidden panel entries must map valid ids to true"
    end
    hidden[id] = true
  end
  return {
    schemaVersion = SCHEMA_VERSION,
    enabled = value.enabled,
    visible = value.visible,
    tree = tree,
    hidden = hidden,
  }
end

local function clampRatio(value)
  if not finite(value) then return 0.5 end
  return math.max(MIN_RATIO, math.min(MAX_RATIO, value))
end

local function pathParts(path)
  local result = {}
  if path == "root" then return result end
  for part in tostring(path):gmatch("[^.]+") do
    if part ~= "root" then result[#result + 1] = part end
  end
  return result
end

local function nodeAt(root, path)
  local node = root
  for _, part in ipairs(pathParts(path)) do
    if not node or node.type ~= "split" or (part ~= "first" and part ~= "second") then
      return nil
    end
    node = node[part]
  end
  return node
end

local function replaceAt(root, path, replacement)
  local parts = pathParts(path)
  if #parts == 0 then return replacement end
  local parent = root
  for index = 1, #parts - 1 do parent = parent[parts[index]] end
  parent[parts[#parts]] = replacement
  return root
end

local function removePanel(node, id)
  if node.type == "stack" then
    local result = {}
    for _, current in ipairs(node.tabs) do
      if current ~= id then result[#result + 1] = current end
    end
    node.tabs = result
    if node.active == id then node.active = result[1] end
    return
  end
  removePanel(node.first, id)
  removePanel(node.second, id)
end

local function normalizeTree(node)
  if node.type == "stack" then
    if #node.tabs == 0 then return nil end
    local found = false
    for _, id in ipairs(node.tabs) do if id == node.active then found = true end end
    if not found then node.active = node.tabs[1] end
    return node
  end
  node.first = normalizeTree(node.first)
  node.second = normalizeTree(node.second)
  if not node.first then return node.second end
  if not node.second then return node.first end
  return node
end

local function findPanel(node, id, path)
  path = path or "root"
  if node.type == "stack" then
    for index, current in ipairs(node.tabs) do
      if current == id then return node, path, index end
    end
    return nil
  end
  local stack, foundPath, index = findPanel(node.first, id, path .. ".first")
  if stack then return stack, foundPath, index end
  return findPanel(node.second, id, path .. ".second")
end

local function firstStack(node, path)
  path = path or "root"
  if node.type == "stack" then return node, path end
  local stack, foundPath = firstStack(node.first, path .. ".first")
  if stack then return stack, foundPath end
  return firstStack(node.second, path .. ".second")
end

function Workspace.movePanel(state, id, targetPath, zone, index)
  local validated, message = Workspace.validateState(state)
  if not validated then return nil, message end
  if not validID(id) then return nil, "invalid panel id" end
  if zone ~= "center" and zone ~= "left" and zone ~= "right"
      and zone ~= "top" and zone ~= "bottom" then
    return nil, "invalid drop zone"
  end
  local tree = validated.tree
  local target = nodeAt(tree, targetPath)
  if not target or target.type ~= "stack" then return nil, "drop target is not a stack" end
  local source = findPanel(tree, id)
  if source then removePanel(tree, id) end
  target = nodeAt(tree, targetPath)
  if not target or target.type ~= "stack" then return nil, "drop target changed during move" end
  if zone == "center" then
    local position = tonumber(index) or (#target.tabs + 1)
    position = math.max(1, math.min(#target.tabs + 1, math.floor(position)))
    table.insert(target.tabs, position, id)
    target.active = id
  else
    if #target.tabs == 0 then
      target.tabs[1], target.active = id, id
    else
      local added = {type = "stack", tabs = {id}, active = id}
      local orientation = (zone == "left" or zone == "right") and "horizontal" or "vertical"
      local before = zone == "left" or zone == "top"
      local split = {type = "split", orientation = orientation, ratio = 0.5}
      split.first, split.second = before and added or target, before and target or added
      tree = replaceAt(tree, targetPath, split)
    end
  end
  validated.tree = normalizeTree(tree)
  validated.hidden[id] = nil
  return Workspace.validateState(validated)
end

function Workspace.setRatio(state, path, ratio)
  local validated, message = Workspace.validateState(state)
  if not validated then return nil, message end
  local node = nodeAt(validated.tree, path)
  if not node or node.type ~= "split" then return nil, "ratio target is not a split" end
  node.ratio = clampRatio(ratio)
  return validated
end

function Workspace.setPanelHidden(state, id, hidden)
  local validated, message = Workspace.validateState(state)
  if not validated then return nil, message end
  if not validID(id) then return nil, "invalid panel id" end
  validated.hidden[id] = hidden and true or nil
  return validated
end

local function escape(value)
  return tostring(value or ""):gsub("&", "&amp;"):gsub("<", "&lt;")
    :gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&#39;")
end

local function close(file)
  local ok, result = pcall(file.close, file)
  return ok and result ~= false
end

function Workspace.new(api, settings)
  local self = {
    active = false,
    lastError = nil,
  }
  local path = settings.root .. "/workspace.json"
  local state = Workspace.defaultState()
  local source, locked = "defaults", false
  local records, handles = {}, {}
  local window, root, layoutRoot, parking
  local stackViews, stackOrder, splitViews, dropLabels = {}, {}, {}, {}
  local drag, splitterDrag
  local resizeRegistered = false

  local function readState()
    state, source, locked = Workspace.defaultState(), "defaults", false
    local file, openError = api.io.open(path, "rb")
    if not file then
      if api.lfs.attributes(path) == nil then return true end
      locked, source = true, "malformed"
      return nil, "Cannot read workspace configuration; original file preserved: "
        .. tostring(openError)
    end
    local data = file:read(MAX_BYTES + 1)
    local closed = close(file)
    local decodedOK, decoded = pcall(api.yajl.to_value, data or "")
    local validated, message
    if decodedOK then validated, message = Workspace.validateState(decoded) end
    if not closed or not data or #data > MAX_BYTES or not validated then
      locked, source = true, "malformed"
      state = Workspace.defaultState()
      return nil, "Malformed workspace configuration; original file preserved: "
        .. path .. (message and (" (" .. message .. ")") or "")
    end
    state, source = validated, "saved"
    return true
  end

  local function writeState()
    if locked then return nil, "Reset is required before replacing the preserved malformed workspace configuration" end
    local validated, message = Workspace.validateState(state)
    if not validated then return nil, message end
    local directoryOK
    directoryOK, message = settings.ensureDirectory()
    if not directoryOK then return nil, message end
    local encodedOK, encoded = pcall(api.yajl.to_string, validated)
    if not encodedOK or type(encoded) ~= "string" or #encoded > MAX_BYTES then
      return nil, "Cannot encode bounded workspace configuration"
    end
    local temporary, backup = path .. ".tmp", path .. ".bak"
    local file, openError = api.io.open(temporary, "wb")
    if not file then return nil, openError or "Cannot create temporary workspace configuration" end
    local writeOK = file:write(encoded)
    local closeOK = close(file)
    if not writeOK or not closeOK then
      api.os.remove(temporary)
      return nil, "Cannot write workspace configuration"
    end
    api.os.remove(backup)
    local hadOriginal = api.lfs.attributes(path) ~= nil
    if hadOriginal then
      local moved, moveError = api.os.rename(path, backup)
      if not moved then api.os.remove(temporary); return nil, moveError or "Cannot preserve workspace configuration" end
    end
    local installed, installError = api.os.rename(temporary, path)
    if not installed then
      if hadOriginal then api.os.rename(backup, path) end
      api.os.remove(temporary)
      return nil, installError or "Cannot replace workspace configuration"
    end
    if hadOriginal then api.os.remove(backup) end
    state, source = validated, "saved"
    return true
  end

  local function showWidget(widget)
    if widget and type(widget.show) == "function" then widget:show() end
  end

  local function hideWidget(widget)
    if widget and type(widget.hide) == "function" then widget:hide() end
  end

  local function deleteWidget(widget)
    if widget and type(widget.delete) == "function" then pcall(widget.delete, widget) end
  end

  local function standaloneHost(record, create)
    local options = record.spec.standalone
    if type(options) ~= "table" then return nil end
    if type(options.host) == "function" then return options.host() end
    if record.standalone then return record.standalone end
    if not create then return nil end
    local geyser = assert(api.Geyser, "Geyser is required for workspace panels")
    assert(type(geyser.UserWindow) == "table", "Geyser.UserWindow is required")
    local values = copy(options)
    values.host = nil
    values.name = values.name or (record.spec.id .. ".window")
    values.titleText = values.titleText or record.spec.title
    values.restoreLayout = values.restoreLayout ~= false
    values.autoDock = values.autoDock ~= false
    values.docked = values.docked ~= false
    values.dockPosition = values.dockPosition or "right"
    record.standalone = geyser.UserWindow:new(values)
    return record.standalone
  end

  local function setHostVisible(host, visible)
    if not host then return end
    if visible then showWidget(host) else hideWidget(host) end
  end

  local function mountRecord(record, parent)
    if not parent then return nil, "No host is available for " .. record.spec.id end
    if record.root and type(record.spec.unmount) == "function" then
      local ok, message = pcall(record.spec.unmount, record.root)
      if not ok or message == false then return nil, "Cannot unmount " .. record.spec.id .. ": " .. tostring(message) end
    end
    local ok, mounted, detail = pcall(record.spec.mount, parent)
    if not ok or mounted == nil or mounted == false then
      return nil, "Cannot mount " .. record.spec.id .. ": " .. tostring(ok and detail or mounted)
    end
    record.root = mounted
    record.parent = parent
    return true
  end

  local function panelStack(id)
    return findPanel(state.tree, id)
  end

  local function panelShouldShow(record)
    if state.hidden[record.spec.id] then return false end
    if not state.enabled then return true end
    if not state.visible then return false end
    local stack = panelStack(record.spec.id)
    if not stack then return false end
    local active = stack.active
    if not records[active] or state.hidden[active] then
      active = nil
      for _, id in ipairs(stack.tabs) do
        if records[id] and not state.hidden[id] then active = id; break end
      end
    end
    return active == record.spec.id
  end

  local function refreshVisibility()
    for _, record in pairs(records) do
      local show = panelShouldShow(record)
      local host = standaloneHost(record, false)
      if state.enabled then
        setHostVisible(host, false)
        if show then showWidget(record.root) else hideWidget(record.root) end
      else
        if state.hidden[record.spec.id] or not host then
          hideWidget(record.root)
          setHostVisible(host, false)
          show = false
        else
          showWidget(record.root)
          setHostVisible(host, true)
        end
      end
      record.visible = show
      if type(record.spec.onVisibilityChanged) == "function" then
        pcall(record.spec.onVisibilityChanged, show)
      end
    end
  end

  local function notifyResize()
    for _, record in pairs(records) do
      if type(record.spec.onResize) == "function" then
        pcall(record.spec.onResize, record.root)
      end
    end
  end

  local function ensureWindow()
    if window then return true end
    local geyser = assert(api.Geyser, "Geyser is required for the workspace")
    assert(type(geyser.UserWindow) == "table" and type(geyser.Container) == "table"
      and type(geyser.Label) == "table", "Geyser workspace widgets are required")
    local restoreLayout = api[LAYOUT_MARKER] == LAYOUT_VERSION
    window = geyser.UserWindow:new({
      name = WINDOW_NAME,
      titleText = "Aardwolf Workspace",
      x = 60,
      y = 80,
      width = 440,
      height = 760,
      restoreLayout = restoreLayout,
      autoDock = true,
      docked = true,
      dockPosition = "right",
    })
    assert(type(window.delete) == "function", "Geyser.UserWindow deletion is required")
    if type(window.setColor) == "function" then window:setColor(9, 14, 20, 255) end
    root = geyser.Container:new({name = OWNER .. ".root", x = 0, y = 0,
      width = "100%", height = "100%"}, window)
    parking = geyser.Container:new({name = OWNER .. ".parking", x = 0, y = 0,
      width = 1, height = 1}, root)
    hideWidget(parking)
    if not restoreLayout then
      api[LAYOUT_MARKER] = LAYOUT_VERSION
      if type(api.remember) == "function" then pcall(api.remember, LAYOUT_MARKER) end
    end
    return true
  end

  local function label(parent, name, text, style)
    local item = api.Geyser.Label:new({name = name, x = 0, y = 0,
      width = 1, height = 1, fgColor = "nocolor"}, parent)
    if type(item.rawEcho) == "function" then item:rawEcho(text) else item:echo(text) end
    if type(item.setStyleSheet) == "function" then item:setStyleSheet(style) end
    return item
  end

  local function setTabStyle(item, selected)
    item:setStyleSheet(selected
      and "QLabel { background:#35506f; color:#ffffff; border:1px solid #6b8eb4; padding:3px; }"
      or "QLabel { background:#172331; color:#dbe7f5; border:1px solid #34485f; padding:3px; } QLabel:hover { background:#25384d; }")
  end

  local function hideDropTargets()
    for _, item in ipairs(dropLabels) do hideWidget(item) end
    drag = nil
  end

  local rebuildLayout

  local function applyMutation(nextState)
    local previous = state
    state = nextState
    local ok, message = rebuildLayout()
    if not ok then
      state = previous
      rebuildLayout()
      self.lastError = message
      return nil, message
    end
    ok, message = writeState()
    if not ok then
      state = previous
      rebuildLayout()
      self.lastError = message
      return nil, message
    end
    self.lastError = nil
    return true
  end

  local function finishDrop(path, zone)
    if not drag then return false end
    local id = drag.id
    hideDropTargets()
    local nextState, message = Workspace.movePanel(state, id, path, zone)
    if not nextState then self.lastError = message; return false end
    return applyMutation(nextState)
  end

  local function showDropTargets(id)
    drag = {id = id}
    for _, item in ipairs(dropLabels) do showWidget(item); if type(item.raise) == "function" then item:raise() end end
  end

  local function addDropTarget(parent, path, zone, x, y, width, height, glyph)
    local item = label(parent, OWNER .. ".drop." .. path:gsub("%.", "-") .. "." .. zone,
      '<div align="center">' .. glyph .. "</div>",
      "QLabel { background:rgba(45,76,108,210); color:white; border:2px solid #8ab5df; font-size:18px; }")
    item:move(x, y); item:resize(width, height); item:hide()
    if type(item.setOnEnter) == "function" then
      item:setOnEnter(function() if drag then drag.targetPath, drag.zone = path, zone end end)
    end
    local release = function() return finishDrop(path, zone) end
    if type(item.setReleaseCallback) == "function" then item:setReleaseCallback(release) end
    item:setClickCallback(release)
    dropLabels[#dropLabels + 1] = item
  end

  local function activeRegistered(stack)
    if stack.active and records[stack.active] and not state.hidden[stack.active] then return stack.active end
    for _, id in ipairs(stack.tabs) do
      if records[id] and not state.hidden[id] then return id end
    end
    return nil
  end

  local function activate(path, id)
    local nextState = copy(state)
    local stack = nodeAt(nextState.tree, path)
    if not stack or stack.type ~= "stack" then return false end
    stack.active = id
    nextState.hidden[id] = nil
    return applyMutation(nextState)
  end

  local function menuAction(path, direction)
    local stack = nodeAt(state.tree, path)
    local id = stack and activeRegistered(stack)
    if not id then return false end
    if direction == "hide" then
      local nextState = assert(Workspace.setPanelHidden(state, id, true))
      return applyMutation(nextState)
    end
    if direction == "previous" or direction == "next" then
      local current = 1
      for index, stackPath in ipairs(stackOrder) do if stackPath == path then current = index end end
      local offset = direction == "previous" and -1 or 1
      local target = stackOrder[((current - 1 + offset) % #stackOrder) + 1]
      return applyMutation(assert(Workspace.movePanel(state, id, target, "center")))
    end
    return applyMutation(assert(Workspace.movePanel(state, id, path, direction)))
  end

  local function buildStack(node, path, parent)
    local frame = api.Geyser.Container:new({name = OWNER .. ".stack." .. path,
      x = 0, y = 0, width = "100%", height = "100%"}, parent)
    local tabs = api.Geyser.Container:new({name = OWNER .. ".tabs." .. path,
      x = 0, y = 0, width = "100%", height = TAB_HEIGHT}, frame)
    local slot = api.Geyser.Container:new({name = OWNER .. ".slot." .. path,
      x = 0, y = TAB_HEIGHT, width = "100%", height = "100%-" .. TAB_HEIGHT}, frame)
    stackViews[path] = {node = node, frame = frame, tabs = tabs, slot = slot}
    stackOrder[#stackOrder + 1] = path
    local visibleIDs = {}
    for _, id in ipairs(node.tabs) do if records[id] then visibleIDs[#visibleIDs + 1] = id end end
    local availableWidth = math.max(72, math.floor(360 / math.max(1, #visibleIDs)))
    for index, id in ipairs(visibleIDs) do
      local record = records[id]
      local item = label(tabs, OWNER .. ".tab." .. path:gsub("%.", "-") .. "." .. id,
        escape(record.spec.title), "")
      item:move((index - 1) * availableWidth, 0)
      item:resize(availableWidth, TAB_HEIGHT)
      setTabStyle(item, node.active == id)
      item:setClickCallback(function(event)
        if type(event) ~= "table" or event.button ~= "RightButton" then showDropTargets(id) end
      end)
      if type(item.setMoveCallback) == "function" then
        item:setMoveCallback(function() if not drag then showDropTargets(id) end end)
      end
      if type(item.setReleaseCallback) == "function" then
        item:setReleaseCallback(function()
          if drag and drag.targetPath then return finishDrop(drag.targetPath, drag.zone) end
          hideDropTargets()
          return activate(path, id)
        end)
      end
      if type(item.setToolTip) == "function" then item:setToolTip("Drag to move or split this panel") end
    end
    local menu = label(tabs, OWNER .. ".menu." .. path:gsub("%.", "-"),
      '<div align="center">&#8942;</div>',
      "QLabel { background:#24364a; color:white; border:1px solid #526d8c; }")
    menu:move("100%-28", 0); menu:resize(28, TAB_HEIGHT)
    local menuItems = {}
    local actions = {
      {"Move to previous stack", "previous"}, {"Move to next stack", "next"},
      {"Split left", "left"}, {"Split right", "right"},
      {"Split above", "top"}, {"Split below", "bottom"}, {"Hide panel", "hide"},
    }
    local function closeMenu() for _, entry in ipairs(menuItems) do entry:hide() end end
    for index, action in ipairs(actions) do
      local entry = label(frame, OWNER .. ".menu." .. path:gsub("%.", "-") .. "." .. index,
        escape(action[1]),
        "QLabel { background:#24364a; color:#eef5ff; border:1px solid #526d8c; padding:4px; } QLabel:hover { background:#304966; }")
      entry:move("100%-205", TAB_HEIGHT + (index - 1) * 27)
      entry:resize(200, 27); entry:hide()
      entry:setClickCallback(function() closeMenu(); return menuAction(path, action[2]) end)
      menuItems[#menuItems + 1] = entry
    end
    menu:setClickCallback(function()
      for _, entry in ipairs(menuItems) do entry:show(); if type(entry.raise) == "function" then entry:raise() end end
      if type(menu.raise) == "function" then menu:raise() end
    end)
    addDropTarget(slot, path, "center", "25%", "25%", "50%", "50%", "&#9673;")
    addDropTarget(slot, path, "left", 0, "25%", "25%", "50%", "&#9664;")
    addDropTarget(slot, path, "right", "75%", "25%", "25%", "50%", "&#9654;")
    addDropTarget(slot, path, "top", "25%", 0, "50%", "25%", "&#9650;")
    addDropTarget(slot, path, "bottom", "25%", "75%", "50%", "25%", "&#9660;")
  end

  local function pointer(event, axis)
    if type(event) == "table" then
      local value = axis == "x" and (event.globalX or event.x) or (event.globalY or event.y)
      if finite(value) then return value end
    end
    if type(api.getMousePosition) == "function" then
      local x, y = api.getMousePosition()
      return axis == "x" and x or y
    end
    return nil
  end

  local function minimumSize(node, axis)
    if node.type == "stack" then
      local result = axis == "x" and 80 or (TAB_HEIGHT + 40)
      for _, id in ipairs(node.tabs) do
        local record = records[id]
        if record then
          local value = axis == "x" and record.spec.minimumWidth or record.spec.minimumHeight
          if finite(value) then result = math.max(result, value) end
        end
      end
      return result
    end
    local first, second = minimumSize(node.first, axis), minimumSize(node.second, axis)
    local matching = (axis == "x" and node.orientation == "horizontal")
      or (axis == "y" and node.orientation == "vertical")
    return matching and (first + second + SPLITTER_SIZE) or math.max(first, second)
  end

  local function constrainedRatio(view, wanted)
    wanted = clampRatio(wanted)
    local horizontal = view.node.orientation == "horizontal"
    local size = horizontal and view.frame:get_width() or view.frame:get_height()
    if not finite(size) or size <= SPLITTER_SIZE then return wanted end
    local axis = horizontal and "x" or "y"
    local firstMinimum = minimumSize(view.node.first, axis)
    local secondMinimum = minimumSize(view.node.second, axis)
    if firstMinimum + secondMinimum + SPLITTER_SIZE >= size then return wanted end
    return math.max(firstMinimum / size, math.min(1 - secondMinimum / size, wanted))
  end

  local function applySplitGeometry(view)
    local ratio = constrainedRatio(view, view.node.ratio)
    local percent = tostring(ratio * 100) .. "%"
    if view.node.orientation == "horizontal" then
      view.first:move(0, 0); view.first:resize(percent .. "-" .. math.floor(SPLITTER_SIZE / 2), "100%")
      view.splitter:move(percent .. "-" .. math.floor(SPLITTER_SIZE / 2), 0)
      view.splitter:resize(SPLITTER_SIZE, "100%")
      view.second:move(percent .. "+" .. math.ceil(SPLITTER_SIZE / 2), 0)
      view.second:resize(tostring((1 - ratio) * 100) .. "%-"
        .. math.ceil(SPLITTER_SIZE / 2), "100%")
    else
      view.first:move(0, 0); view.first:resize("100%", percent .. "-" .. math.floor(SPLITTER_SIZE / 2))
      view.splitter:move(0, percent .. "-" .. math.floor(SPLITTER_SIZE / 2))
      view.splitter:resize("100%", SPLITTER_SIZE)
      view.second:move(0, percent .. "+" .. math.ceil(SPLITTER_SIZE / 2))
      view.second:resize("100%", tostring((1 - ratio) * 100) .. "%-"
        .. math.ceil(SPLITTER_SIZE / 2))
    end
  end

  local function buildNode(node, path, parent)
    if node.type == "stack" then buildStack(node, path, parent); return end
    local frame = api.Geyser.Container:new({name = OWNER .. ".split." .. path,
      x = 0, y = 0, width = "100%", height = "100%"}, parent)
    local first = api.Geyser.Container:new({name = OWNER .. ".split." .. path .. ".first",
      x = 0, y = 0, width = 1, height = 1}, frame)
    local second = api.Geyser.Container:new({name = OWNER .. ".split." .. path .. ".second",
      x = 0, y = 0, width = 1, height = 1}, frame)
    local splitter = label(frame, OWNER .. ".splitter." .. path,
      "", "QLabel { background:#40556d; } QLabel:hover { background:#7193b5; }")
    if type(splitter.setToolTip) == "function" then splitter:setToolTip("Drag to resize this split") end
    local view = {node = node, frame = frame, first = first, second = second, splitter = splitter}
    splitViews[path] = view
    applySplitGeometry(view)
    local function press(event)
      splitterDrag = {path = path, start = pointer(event, node.orientation == "horizontal" and "x" or "y"),
        ratio = node.ratio}
    end
    local function move(event)
      if not splitterDrag or splitterDrag.path ~= path then press(event); return end
      local current = pointer(event, node.orientation == "horizontal" and "x" or "y")
      local size = node.orientation == "horizontal" and frame:get_width() or frame:get_height()
      if current and splitterDrag.start and finite(size) and size > 0 then
        node.ratio = constrainedRatio(view,
          splitterDrag.ratio + (current - splitterDrag.start) / size)
        applySplitGeometry(view)
      end
    end
    local function release()
      if not splitterDrag or splitterDrag.path ~= path then return false end
      local original = splitterDrag.ratio
      splitterDrag = nil
      local ok, message = writeState()
      if not ok then
        node.ratio = original
        applySplitGeometry(view)
        self.lastError = message
        return false
      end
      self.lastError = nil
      return true
    end
    splitter:setClickCallback(press)
    if type(splitter.setMoveCallback) == "function" then splitter:setMoveCallback(move) end
    if type(splitter.setReleaseCallback) == "function" then splitter:setReleaseCallback(release) end
    buildNode(node.first, path .. ".first", first)
    buildNode(node.second, path .. ".second", second)
  end

  rebuildLayout = function()
    if not state.enabled then return true end
    local ok, message = pcall(function()
      ensureWindow()
      for _, record in pairs(records) do
        local parked, why = mountRecord(record, parking)
        if not parked then error(why, 0) end
        hideWidget(record.root)
      end
      deleteWidget(layoutRoot)
      stackViews, stackOrder, splitViews, dropLabels = {}, {}, {}, {}
      layoutRoot = api.Geyser.Container:new({name = OWNER .. ".layout", x = 0, y = 0,
        width = "100%", height = "100%"}, root)
      buildNode(state.tree, "root", layoutRoot)
      for id, record in pairs(records) do
        local _, stackPath = panelStack(id)
        local target = stackPath and stackViews[stackPath] and stackViews[stackPath].slot or nil
        if target then
          local mounted, why = mountRecord(record, target)
          if not mounted then error(why, 0) end
        end
      end
      refreshVisibility()
      notifyResize()
      if state.visible then showWidget(window) else hideWidget(window) end
    end)
    if not ok then return nil, "Cannot build workspace layout: " .. tostring(message) end
    return true
  end

  local function mountStandalone(record)
    local host = standaloneHost(record, true)
    if not host then
      if record.root then
        local ok, message = pcall(record.spec.unmount, record.root)
        if not ok or message == false then
          return nil, "Cannot unmount " .. record.spec.id .. ": " .. tostring(message)
        end
      end
      record.parent = nil
      return true
    end
    if record.parent ~= host then return mountRecord(record, host) end
    return true
  end

  local function rollbackMode(previous)
    state = previous
    if state.enabled then
      rebuildLayout()
    else
      for _, record in pairs(records) do pcall(mountStandalone, record) end
      refreshVisibility()
      if window then hideWidget(window) end
    end
  end

  local function registerResizeHandler()
    if resizeRegistered or type(api.registerNamedEventHandler) ~= "function" then return end
    local ok, registered = pcall(api.registerNamedEventHandler, OWNER, "resize",
      "sysWindowResizeEvent", function()
        for _, view in pairs(splitViews) do applySplitGeometry(view) end
        notifyResize()
      end)
    resizeRegistered = ok and registered == true
  end

  function self:start()
    if self.active then return not locked, self.lastError end
    local loaded, message = readState()
    self.active = true
    registerResizeHandler()
    if not loaded then
      self.lastError = message
      return false, message
    end
    if state.enabled then
      local ok
      ok, message = rebuildLayout()
      if not ok then
        state.enabled = false
        self.lastError = message
        return false, message
      end
    end
    self.lastError = nil
    return true
  end

  function self:stop()
    drag, splitterDrag = nil, nil
    for _, record in pairs(records) do
      if state.enabled then pcall(mountStandalone, record) end
    end
    deleteWidget(layoutRoot); layoutRoot = nil
    deleteWidget(parking); parking = nil
    deleteWidget(root); root = nil
    deleteWidget(window); window = nil
    stackViews, stackOrder, splitViews, dropLabels = {}, {}, {}, {}
    if resizeRegistered and type(api.deleteNamedEventHandler) == "function" then
      pcall(api.deleteNamedEventHandler, OWNER, "resize")
    end
    resizeRegistered = false
    self.active = false
    return true
  end

  function self:registerPanel(spec)
    if type(spec) ~= "table" or not validID(spec.id) then return nil, "Panel id is invalid" end
    if records[spec.id] then return nil, "Panel id is already registered: " .. spec.id end
    if type(spec.title) ~= "string" or #spec.title < 1 or #spec.title > 256 then
      return nil, "Panel title is invalid"
    end
    if type(spec.mount) ~= "function" or type(spec.unmount) ~= "function" then
      return nil, "Panel mount and unmount callbacks are required"
    end
    for _, field in ipairs({"minimumWidth", "minimumHeight"}) do
      local value = spec[field]
      if value ~= nil and (not finite(value) or value < 1 or value > 10000) then
        return nil, "Panel " .. field .. " is invalid"
      end
    end
    local previousState = copy(state)
    local record = {spec = spec, root = spec.root, parent = spec.parent, visible = false}
    records[spec.id] = record
    local stack = findPanel(state.tree, spec.id)
    local added = false
    if not stack then
      local target = firstStack(state.tree)
      target.tabs[#target.tabs + 1] = spec.id
      added = true
    end
    local ok, message
    if state.enabled then ok, message = rebuildLayout()
    else
      ok, message = mountStandalone(record)
      if ok then refreshVisibility() end
    end
    if not ok then
      if record.root then pcall(record.spec.unmount, record.root) end
      deleteWidget(record.standalone)
      records[spec.id] = nil
      if added then removePanel(state.tree, spec.id); state.tree = normalizeTree(state.tree) end
      if state.enabled then rebuildLayout() end
      return nil, message
    end
    if added and not locked then
      ok, message = writeState()
      if not ok then
        if record.root then pcall(record.spec.unmount, record.root) end
        deleteWidget(record.standalone)
        records[spec.id] = nil
        state = previousState
        if state.enabled then rebuildLayout() end
        self.lastError = message
        return nil, message
      end
    end
    local handle = {}
    function handle:show() return self._workspace:_setPanelVisible(spec.id, true) end
    function handle:hide() return self._workspace:_setPanelVisible(spec.id, false) end
    function handle:status() return self._workspace:_panelStatus(spec.id) end
    handle._workspace = self
    handles[spec.id] = handle
    return handle
  end

  function self:unregisterPanel(id)
    local record = records[id]
    if not record then return true end
    if record.root then pcall(record.spec.unmount, record.root) end
    deleteWidget(record.standalone)
    records[id], handles[id] = nil, nil
    if state.enabled then
      local ok, message = rebuildLayout()
      if not ok then self.lastError = message; return false, message end
    end
    return true
  end

  function self:_setPanelVisible(id, visible)
    local record = records[id]
    if not record then return false, "Panel is not registered: " .. tostring(id) end
    local previous = copy(state)
    if visible then state.hidden[id] = nil else state.hidden[id] = true end
    if visible and state.enabled then
      local stack = findPanel(state.tree, id)
      if stack then stack.active = id end
      state.visible = true
    end
    refreshVisibility()
    if state.enabled and state.visible then showWidget(window) end
    if locked then return true end
    local ok, message = writeState()
    if not ok then
      state = previous
      refreshVisibility()
      self.lastError = message
      return false, message
    end
    self.lastError = nil
    return true
  end

  function self:_panelStatus(id)
    local record = records[id]
    if not record then return {registered = false, visible = false} end
    local host = state.enabled and "workspace"
      or (standaloneHost(record, false) and "standalone" or "unavailable")
    return {
      registered = true,
      visible = record.visible,
      hidden = state.hidden[id] == true,
      host = host,
    }
  end

  function self:setEnabled(enabled)
    enabled = enabled == true
    if locked then return false, "Reset is required before workspace mode can change" end
    if state.enabled == enabled then return true end
    local previous = copy(state)
    state.enabled = enabled
    local ok, message
    if enabled then
      ok, message = rebuildLayout()
    else
      for _, record in pairs(records) do
        ok, message = mountStandalone(record)
        if not ok then break end
      end
      if ok ~= false then
        if window then hideWidget(window) end
        refreshVisibility()
        ok = true
      end
    end
    if not ok then rollbackMode(previous); self.lastError = message; return false, message end
    ok, message = writeState()
    if not ok then rollbackMode(previous); self.lastError = message; return false, message end
    self.lastError = nil
    return true
  end

  function self:show()
    if not state.enabled then return false, "Workspace mode is off" end
    local previous = state.visible
    state.visible = true
    refreshVisibility(); showWidget(window)
    local ok, message = writeState()
    if not ok then state.visible = previous; refreshVisibility(); self.lastError = message; return false, message end
    self.lastError = nil
    return true
  end

  function self:hide()
    if not state.enabled then return false, "Workspace mode is off" end
    local previous = state.visible
    state.visible = false
    refreshVisibility(); hideWidget(window)
    local ok, message = writeState()
    if not ok then state.visible = previous; refreshVisibility(); self.lastError = message; return false, message end
    self.lastError = nil
    return true
  end

  function self:reset()
    local wasEnabled = state.enabled
    if locked and api.lfs.attributes(path) ~= nil then
      local preserved = path .. ".corrupt-" .. api.os.date("%Y%m%d-%H%M%S")
      local moved, message = api.os.rename(path, preserved)
      if not moved then return false, message or "Cannot preserve malformed workspace configuration" end
    end
    locked = false
    local nextState = Workspace.defaultState()
    nextState.enabled = wasEnabled
    local target = nextState.tree.second
    for id in pairs(records) do
      if not findPanel(nextState.tree, id) then target.tabs[#target.tabs + 1] = id end
    end
    if nextState.enabled then return applyMutation(nextState) end
    local previous = state
    state = nextState
    local ok, message = writeState()
    if not ok then state = previous; self.lastError = message; return false, message end
    refreshVisibility()
    self.lastError = nil
    return true
  end

  function self:status()
    local registered, placeholders = 0, 0
    for _ in pairs(records) do registered = registered + 1 end
    local function countPlaceholders(node)
      if node.type == "stack" then
        for _, id in ipairs(node.tabs) do if not records[id] then placeholders = placeholders + 1 end end
      else countPlaceholders(node.first); countPlaceholders(node.second) end
    end
    countPlaceholders(state.tree)
    local visible = state.visible
    if state.enabled and window and type(api.windowVisible) == "function" then
      local ok, result = pcall(api.windowVisible, WINDOW_NAME)
      if ok and type(result) == "boolean" then visible = result end
    end
    return {
      active = self.active,
      enabled = state.enabled,
      mode = state.enabled and "on" or "off",
      visible = state.enabled and visible or false,
      source = source,
      locked = locked,
      registered = registered,
      placeholders = placeholders,
      tree = copy(state.tree),
      hidden = copy(state.hidden),
      lastError = self.lastError,
    }
  end

  return self
end

return Workspace
