aardwolf_mudlet.settings = aardwolf_mudlet.settings or {}

local SCHEMA_VERSION = 6
local VALID_TABS = {overview = true, character = true, group = true, inventory = true, chat = true}
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
    chat = {
      visible = true, preserve_main = true, logging = false, max_messages = 500,
      active_tab = "All",
      tabs = {
        {name = "All", filters = {"*"}},
        {name = "Tells", filters = {"tell", "ptell", "dtell"}},
        {name = "Group", filters = {"group", "gtell"}},
        {name = "Clan", filters = {"claninfo", "clantalk", "gclan"}},
        {name = "System", filters = {"info", "raidinfo", "global_quest", "warfare", "remort_auction", "remote_socials"}},
      },
    },
    accessibility = {enabled = false, rate = 0, volume = 1, voice = nil},
    sounds = {enabled = false, mappings = {}},
    data = {auto_backup = false, retain_backups = 30},
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
  local base = aardwolf_mudlet.util.bounded(value.base, 0, 10000)
  local size = aardwolf_mudlet.util.bounded(value[size_key], 0, maximum)
  local applied = aardwolf_mudlet.util.bounded(value.applied, 0, 12000)
  if not base or not size or not applied or applied ~= base + size then return nil end
  return {base = base, [size_key] = size, applied = applied}
end

local function custom_action(value)
  if type(value) ~= "table" then return nil end
  local id = aardwolf_mudlet.util.text(value.id, 48)
  local label = aardwolf_mudlet.util.text(value.label, 32)
  local command = aardwolf_mudlet.util.text(value.command, 200)
  local category = aardwolf_mudlet.util.text(value.category, 24) or "Custom"
  local order = aardwolf_mudlet.util.bounded(value.order, 1, 24)
  if not id or id == "" or not label or label == "" or not command or command == "" then return nil end
  if label:find("[%c]") or category:find("[%c]") or command:find("[%c]") then return nil end
  return {id = id, label = label, command = command, category = category, order = order or 24}
end

function aardwolf_mudlet.settings.validate(candidate)
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
  output.workspace_width = aardwolf_mudlet.util.bounded(candidate.workspace_width, 360, 520) or output.workspace_width
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
  if aardwolf_mudlet.chat and type(aardwolf_mudlet.chat.validate_settings) == "function" then
    output.chat = aardwolf_mudlet.chat.validate_settings(candidate.chat, output.chat)
  end
  if aardwolf_mudlet.accessibility and type(aardwolf_mudlet.accessibility.validate_settings) == "function" then
    output.accessibility = aardwolf_mudlet.accessibility.validate_settings(candidate.accessibility, output.accessibility)
  end
  if aardwolf_mudlet.sound and type(aardwolf_mudlet.sound.validate_settings) == "function" then
    output.sounds = aardwolf_mudlet.sound.validate_settings(candidate.sounds, output.sounds)
  end
  if type(candidate.data) == "table" then
    output.data.auto_backup = candidate.data.auto_backup == true
    output.data.retain_backups = math.floor(aardwolf_mudlet.util.bounded(candidate.data.retain_backups, 1, 30) or 30)
  end
  output.border_claim = border_claim(candidate.border_claim, "width", 2000)
  output.bottom_border_claim = border_claim(candidate.bottom_border_claim, "height", 1000)
  return output
end

function aardwolf_mudlet.settings.directory()
  return getMudletHomeDir() .. "/aardwolf-mudlet"
end

function aardwolf_mudlet.settings.path()
  return aardwolf_mudlet.settings.directory() .. "/settings.json"
end

function aardwolf_mudlet.settings.ensure_directory()
  local directory = aardwolf_mudlet.settings.directory()
  if type(lfs) == "table" and type(lfs.attributes) == "function" and lfs.attributes(directory, "mode") == "directory" then
    return true
  end
  if type(lfs) ~= "table" or type(lfs.mkdir) ~= "function" then return false end
  local ok = pcall(lfs.mkdir, directory)
  return ok and (type(lfs.attributes) ~= "function" or lfs.attributes(directory, "mode") == "directory")
end

function aardwolf_mudlet.settings.load()
  local file = io.open(aardwolf_mudlet.settings.path(), "r")
  local candidate
  if file then
    local contents = file:read("*a")
    file:close()
    if type(yajl) == "table" and type(yajl.to_value) == "function" then
      local ok, decoded = pcall(yajl.to_value, contents)
      if ok then candidate = decoded end
    end
  end
  aardwolf_mudlet.settings.data = aardwolf_mudlet.settings.validate(candidate)
  return aardwolf_mudlet.settings.data
end

function aardwolf_mudlet.settings.save()
  aardwolf_mudlet.settings.data = aardwolf_mudlet.settings.validate(aardwolf_mudlet.settings.data)
  if type(yajl) ~= "table" or type(yajl.to_string) ~= "function" then return false, "Mudlet JSON support is unavailable" end
  if not aardwolf_mudlet.settings.ensure_directory() then return false, "Unable to create settings directory" end
  local ok, encoded = pcall(yajl.to_string, aardwolf_mudlet.settings.data)
  if not ok then return false, encoded end
  local temporary = aardwolf_mudlet.settings.path() .. ".tmp"
  local file, error_message = io.open(temporary, "w")
  if not file then return false, error_message end
  file:write(encoded)
  file:close()
  local renamed, rename_error = os.rename(temporary, aardwolf_mudlet.settings.path())
  if not renamed then return false, rename_error end
  return true
end

function aardwolf_mudlet.settings.update(name, value)
  aardwolf_mudlet.settings.data = aardwolf_mudlet.settings.data or defaults()
  aardwolf_mudlet.settings.data[name] = value
  return aardwolf_mudlet.settings.save()
end

function aardwolf_mudlet.settings.is_visible()
  return not aardwolf_mudlet.settings.data or aardwolf_mudlet.settings.data.visible ~= false
end

function aardwolf_mudlet.settings.details_are_visible()
  local data = aardwolf_mudlet.settings.data or defaults()
  return data.active_tab == "inventory"
end
