aardwolf_interface.settings = aardwolf_interface.settings or {}

local SCHEMA_VERSION = 5
local VALID_TABS = {overview = true, character = true, group = true, inventory = true}
local VALID_SCALES = {[90] = true, [100] = true, [115] = true, [130] = true}

local function defaults()
  return {
    schema_version = SCHEMA_VERSION,
    visible = true,
    details_visible = false,
    theme = "obsidian",
    density = "comfortable",
    text_scale = 100,
    workspace_width = 440,
    active_tab = "overview",
    inspector_pinned = false,
    palette_open = false,
    inventory_tab = "equipment",
    show_empty_slots = false,
    collapsed_by_user = false,
    sync_map_theme = true,
    custom_actions = {},
    next_action_id = 1,
    border_claim = nil,
    bottom_border_claim = nil,
  }
end

local function normalized_tab(value)
  if value == "map" then return "overview" end
  return VALID_TABS[value] and value or nil
end

local function border_claim(value, size_key, maximum)
  if type(value) ~= "table" then return nil end
  local base = aardwolf_interface.util.bounded(value.base, 0, 10000)
  local size = aardwolf_interface.util.bounded(value[size_key], 0, maximum)
  local applied = aardwolf_interface.util.bounded(value.applied, 0, 12000)
  if not base or not size or not applied or applied ~= base + size then return nil end
  return {base = base, [size_key] = size, applied = applied}
end

local function custom_action(value)
  if type(value) ~= "table" then return nil end
  local id = aardwolf_interface.util.text(value.id, 48)
  local label = aardwolf_interface.util.text(value.label, 32)
  local command = aardwolf_interface.util.text(value.command, 200)
  local category = aardwolf_interface.util.text(value.category, 24) or "Custom"
  local order = aardwolf_interface.util.bounded(value.order, 1, 24)
  if not id or id == "" or not label or label == "" or not command or command == "" then return nil end
  if label:find("[%c]") or category:find("[%c]") or command:find("[%c]") then return nil end
  return {id = id, label = label, command = command, category = category, order = order or 24}
end

function aardwolf_interface.settings.validate(candidate)
  local output = defaults()
  if type(candidate) ~= "table" then return output end
  local version = tonumber(candidate.schema_version)
  if not version or version < 1 or version > SCHEMA_VERSION then return output end
  if type(candidate.visible) == "boolean" then output.visible = candidate.visible end
  if type(candidate.details_visible) == "boolean" then output.details_visible = candidate.details_visible end
  if candidate.theme == "dark" then output.theme = "obsidian"
  elseif candidate.theme == "obsidian" or candidate.theme == "high-contrast" then output.theme = candidate.theme end
  if candidate.density == "compact" or candidate.density == "comfortable" then output.density = candidate.density end
  local scale = tonumber(candidate.text_scale)
  if VALID_SCALES[scale] then output.text_scale = scale end
  output.workspace_width = aardwolf_interface.util.bounded(candidate.workspace_width, 360, 520) or output.workspace_width
  local active_tab = normalized_tab(candidate.active_tab)
  -- Schema 4 could retain a separate selected inspector view. When that
  -- inspector was pinned it is the view the player was actually using, so it
  -- becomes the schema-5 dock selection. Otherwise the former Map tab maps to
  -- Overview as expected.
  if version < 5 and candidate.inspector_pinned == true then
    active_tab = normalized_tab(candidate.inspector_tab) or active_tab
  end
  if active_tab then output.active_tab = active_tab end
  if candidate.inventory_tab == "equipment" or candidate.inventory_tab == "bags" then output.inventory_tab = candidate.inventory_tab end
  for _, name in ipairs({"inspector_pinned", "palette_open", "show_empty_slots", "collapsed_by_user", "sync_map_theme"}) do
    if type(candidate[name]) == "boolean" then output[name] = candidate[name] end
  end
  if version < 4 and output.details_visible then
    output.inspector_pinned = true
    output.active_tab = "inventory"
  end
  local seen = {}
  if type(candidate.custom_actions) == "table" then
    for _, value in ipairs(candidate.custom_actions) do
      if #output.custom_actions >= 24 then break end
      local action = custom_action(value)
      if action and not seen[action.id] then
        seen[action.id] = true
        output.custom_actions[#output.custom_actions + 1] = action
      end
    end
  end
  table.sort(output.custom_actions, function(left, right)
    if left.order == right.order then return left.id < right.id end
    return left.order < right.order
  end)
  output.next_action_id = math.max(1, math.floor(tonumber(candidate.next_action_id) or 1))
  output.border_claim = border_claim(candidate.border_claim, "width", 2000)
  output.bottom_border_claim = border_claim(candidate.bottom_border_claim, "height", 1000)
  return output
end

function aardwolf_interface.settings.directory()
  return getMudletHomeDir() .. "/aardwolf-interface"
end

function aardwolf_interface.settings.path()
  return aardwolf_interface.settings.directory() .. "/settings.lua"
end

function aardwolf_interface.settings.ensure_directory()
  local directory = aardwolf_interface.settings.directory()
  if type(lfs) == "table" and type(lfs.attributes) == "function" and lfs.attributes(directory, "mode") == "directory" then
    return true
  end
  if type(lfs) ~= "table" or type(lfs.mkdir) ~= "function" then return false end
  local ok = pcall(lfs.mkdir, directory)
  return ok and (type(lfs.attributes) ~= "function" or lfs.attributes(directory, "mode") == "directory")
end

function aardwolf_interface.settings.load()
  local file = io.open(aardwolf_interface.settings.path(), "r")
  local candidate
  if file then
    local contents = file:read("*a")
    file:close()
    if type(yajl) == "table" and type(yajl.to_value) == "function" then
      local ok, decoded = pcall(yajl.to_value, contents)
      if ok then candidate = decoded end
    end
  end
  aardwolf_interface.settings.data = aardwolf_interface.settings.validate(candidate)
  return aardwolf_interface.settings.data
end

function aardwolf_interface.settings.save()
  aardwolf_interface.settings.data = aardwolf_interface.settings.validate(aardwolf_interface.settings.data)
  if type(yajl) ~= "table" or type(yajl.to_string) ~= "function" then return false, "Mudlet JSON support is unavailable" end
  if not aardwolf_interface.settings.ensure_directory() then return false, "Unable to create settings directory" end
  local ok, encoded = pcall(yajl.to_string, aardwolf_interface.settings.data)
  if not ok then return false, encoded end
  local temporary = aardwolf_interface.settings.path() .. ".tmp"
  local file, error_message = io.open(temporary, "w")
  if not file then return false, error_message end
  file:write(encoded)
  file:close()
  local renamed, rename_error = os.rename(temporary, aardwolf_interface.settings.path())
  if not renamed then return false, rename_error end
  return true
end

function aardwolf_interface.settings.update(name, value)
  aardwolf_interface.settings.data = aardwolf_interface.settings.data or defaults()
  aardwolf_interface.settings.data[name] = value
  return aardwolf_interface.settings.save()
end

function aardwolf_interface.settings.is_visible()
  return not aardwolf_interface.settings.data or aardwolf_interface.settings.data.visible ~= false
end

function aardwolf_interface.settings.details_are_visible()
  local data = aardwolf_interface.settings.data or defaults()
  return data.active_tab == "inventory"
end
