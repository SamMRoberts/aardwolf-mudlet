-- Preserve session state when this script is compiled again in the editor.
AardwolfToolbox = AardwolfToolbox or { active = false, calls = 0 }

local function resource(name)
  return dofile(getMudletHomeDir() .. "/@PKGNAME@/" .. name .. ".lua")
end

local function initialize()
  if AardwolfToolbox.config then return end
  local config = resource("configuration").new(_G)
  AardwolfToolbox.config = config
  AardwolfToolbox.gmcp = resource("gmcp-cache").new(_G)
  config.registerFeature({id="gmcp",label="GMCP data",
    description="Keep session-only character, communication, group, and room values for Toolbox features.",
    settings={{key="enabled",type="boolean",default=true,label="Enable GMCP cache"}},
    apply=AardwolfToolbox.gmcp.configure})
  AardwolfToolbox.mapper = resource("automapper").new(_G, function(key)
    return config.get("mapper", key)
  end)
  config.registerFeature({
    id = "mapper", label = "Auto-mapper",
    description = "Discover rooms and connect known exits from Aardwolf room updates.",
    settings = {
      {key = "enabled", type = "boolean", default = true, label = "Enable mapping",
        description = "Record rooms and exits. Turning this off releases the mapper's listeners."},
      {key = "follow_room", type = "boolean", default = true, label = "Follow current room",
        description = "Center the map when fresh room information arrives."},
      {key = "terrain_colors", type = "boolean", default = true, label = "Color rooms by terrain",
        description = "Color visited rooms by terrain. Existing colors and manual overrides are preserved when disabled."},
    },
    apply = function(values)
      if values.enabled then
        AardwolfToolbox.mapper.start()
        if not AardwolfToolbox.mapper.enabled then return false, AardwolfToolbox.mapper.last end
      else
        AardwolfToolbox.mapper.stop()
      end
      return true
    end,
  })
  AardwolfToolbox.borders = resource("borders").new(_G)
  AardwolfToolbox.incoming = resource("incoming").new(_G)
  AardwolfToolbox.help = resource("help-pane").new(_G,AardwolfToolbox.incoming)
  config.registerFeature({id="help",label="Help pane",
    description="Open tagged help in a floating window, titled with its keywords.",settings={
      {key="enabled",type="boolean",default=true,label="Enable floating help"},
      {key="font_size",type="number",default=11,min=8,max=18,integer=true,label="Font size (points)"},
    },apply=AardwolfToolbox.help.configure})
  AardwolfToolbox.vitals = resource("vitals").new(_G,AardwolfToolbox.borders)
  config.registerFeature({id="vitals", label="Vitals",
    description="Compact HP, Mana, Moves, target health, and level progress above the command input.",
    settings={
      {key="enabled", type="boolean", default=true, label="Enable bottom Vitals"},
      {key="show_target", type="boolean", default=true, label="Show target health",
        description="Show the current enemy and its server-reported health percentage."},
      {key="show_tnl", type="boolean", default=true, label="Show TNL",
        description="Fill the bar as experience is earned; show the amount remaining."},
      {key="bar_height", type="number", default=22, min=16, max=36, integer=true, label="Bar height (pixels)"},
      {key="font_size", type="number", default=11, min=8, max=16, integer=true, label="Font size (points)",
        description="Text automatically shrinks when space is limited."},
    }, apply=AardwolfToolbox.vitals.configure})

  AardwolfToolbox.tags = resource("tags").new(_G,AardwolfToolbox.incoming)
  config.registerFeature({id="tags",label="Game tags",
    description="Capture brace-tagged records and complete blocks for Toolbox features.",
    settings={
      {key="enabled",type="boolean",default=true,label="Enable tag capture"},
      {key="suppress",type="boolean",default=true,label="Suppress captured output",
        description="Hide tag lines and all text inside tagged blocks from the main console."},
      {key="block_timeout",type="number",default=10,min=1,max=120,label="Block timeout (seconds)",
        description="Stop hiding unfinished blocks after this many seconds."},
    },apply=AardwolfToolbox.tags.configure})
  AardwolfToolbox.ascii = resource("ascii-map").new(_G,config,AardwolfToolbox.incoming,
    AardwolfToolbox.borders,function()
      AardwolfToolbox.openSettings(); AardwolfToolbox.settingsWindow.select("ascii")
    end)
  config.registerFeature({id="ascii",label="ASCII map",
    description="Show tagged ASCII maps exclusively in a movable, dockable pane.",settings={
      {key="enabled",type="boolean",default=true,label="Enable ASCII map"},
      {key="locked",type="boolean",default=false,label="Locked"},
      {key="dock",type="choice",default="floating",label="Dock position",options={
        {value="floating",label="Floating"},{value="left",label="Left"},{value="right",label="Right"},
        {value="top",label="Top"},{value="bottom",label="Bottom"}}},
      {key="font_size",type="number",default=11,min=6,max=20,integer=true,label="Font size (points)"},
      {key="capture_timeout",type="number",default=10,min=1,max=120,label="Capture timeout (seconds)"},
      {key="x",type="number",default=40,min=0,max=16384,integer=true,label="Floating X (pixels)"},
      {key="y",type="number",default=140,min=0,max=16384,integer=true,label="Floating Y (pixels)"},
      {key="width",type="number",default=265,min=160,max=16384,integer=true,label="Width (pixels)"},
      {key="height",type="number",default=330,min=100,max=16384,integer=true,label="Height (pixels)"},
    },apply=AardwolfToolbox.ascii.configure})

  AardwolfToolbox.consider = resource("consider").new(_G,AardwolfToolbox.incoming)
  config.registerFeature({id="consider",label="Consider",
    description="Replace consider messages with clear difficulty labels and relative level ranges.",settings={
      {key="enabled",type="boolean",default=true,label="Enable consider formatting"},
      {key="colors",type="boolean",default=true,label="Use difficulty colors",
        description="Difficulty labels and relative level ranges remain visible with colors disabled."},
    },apply=AardwolfToolbox.consider.configure})

  AardwolfToolbox.player = resource("player-panel").new(_G,AardwolfToolbox.gmcp)
  config.registerFeature({id="player",label="Player panel",
    description="Compact player level, stats, and status between the map and chat.",settings={
      {key="enabled",type="boolean",default=true,label="Enable player panel"},
      {key="font_size",type="number",default=10,min=8,max=13,integer=true,label="Font size (points)"},
    },apply=AardwolfToolbox.player.configure})

end

function AardwolfToolbox.start()
  initialize()
  AardwolfToolbox.active = true
  AardwolfToolbox.config.activate()
end

function AardwolfToolbox.stop()
  if AardwolfToolbox.settingsWindow then AardwolfToolbox.settingsWindow.destroy() end
  if AardwolfToolbox.config then AardwolfToolbox.config.deactivate() end
  if AardwolfToolbox.player then AardwolfToolbox.player.stop() end
  if AardwolfToolbox.help then AardwolfToolbox.help.stop() end
  if AardwolfToolbox.consider then AardwolfToolbox.consider.stop() end
  if AardwolfToolbox.gmcp then AardwolfToolbox.gmcp.stop() end
  if AardwolfToolbox.ascii then AardwolfToolbox.ascii.stop() end
  if AardwolfToolbox.tags then AardwolfToolbox.tags.stop() end
  if AardwolfToolbox.vitals then AardwolfToolbox.vitals.stop() end
  if AardwolfToolbox.mapper then AardwolfToolbox.mapper.stop() end
  AardwolfToolbox.active = false
end

function AardwolfToolbox.openSettings()
  AardwolfToolbox.start()
  if not AardwolfToolbox.settingsWindow then
    AardwolfToolbox.settingsWindow = resource("settings-window").new(_G, AardwolfToolbox.config, function()
      local mapper = AardwolfToolbox.mapper
      local mapperState = not AardwolfToolbox.config.get("mapper", "enabled") and "disabled in settings"
        or ((mapper.enabled and "running — " or "stopped — ") .. mapper.last)
      return "Mapper: " .. mapperState .. " | Vitals: " .. AardwolfToolbox.vitals.last .. " | Tags: " .. AardwolfToolbox.tags.last .. " | ASCII: " .. AardwolfToolbox.ascii.last .. " | Consider: " .. AardwolfToolbox.consider.last .. " | GMCP: " .. AardwolfToolbox.gmcp.last .. " | Player: " .. AardwolfToolbox.player.last .. " | Help: " .. AardwolfToolbox.help.last
    end)
  end
  AardwolfToolbox.settingsWindow.open()
end

function AardwolfToolbox.mapCommand(command)
  AardwolfToolbox.start()
  if command == "on" or command == "off" then
    local ok, message = AardwolfToolbox.config.set("mapper", "enabled", command == "on")
    if not ok or message ~= "Settings saved and applied." then echo("Aardwolf settings: " .. message .. "\n") end
    -- An unchanged enabled preference also serves as an explicit retry after a runtime stop.
    if ok and command == "on" then AardwolfToolbox.mapper.start() end
  end
  AardwolfToolbox.mapper.status()
end

function AardwolfToolbox.status()
  if AardwolfToolbox.active then
    AardwolfToolbox.calls = AardwolfToolbox.calls + 1
  end
  echo(string.format("Aardwolf Toolbox: %s; calls=%d\n",
    AardwolfToolbox.active and "ready" or "inactive", AardwolfToolbox.calls))
end

-- Mudlet owns the permanent alias and these script event registrations.
-- The mapper owns its named handlers; compilation creates no new registrations.
function AardwolfToolboxLifecycle(event, packageName)
  if event == "sysLoadEvent"
      or (event == "sysInstallPackage" and packageName == "@PKGNAME@") then
    AardwolfToolbox.start()
  elseif event == "sysUninstallPackage" and packageName == "@PKGNAME@" then
    AardwolfToolbox.stop()
    AardwolfToolbox = nil
    AardwolfToolboxLifecycle = nil
  end
end
