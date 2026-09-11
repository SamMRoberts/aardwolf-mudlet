-- Preserve session state when this script is compiled again in the editor.
AardwolfToolbox = AardwolfToolbox or { active = false, calls = 0 }

local function resource(name)
  return dofile(getMudletHomeDir() .. "/@PKGNAME@/" .. name .. ".lua")
end

local function initialize()
  if AardwolfToolbox.config then return end
  local config = resource("configuration").new(_G)
  AardwolfToolbox.config = config
  AardwolfToolbox.ui = resource("appearance").new(_G,config)
  config.registerFeature({id="appearance",label="Appearance",description="Shared readable fonts for Toolbox, console, input, and chat. Larger existing console text is preserved.",settings={
    {key="enabled",type="boolean",default=true,label="Manage console and input fonts"},
    {key="preset",type="choice",default="comfortable",label="Reading preset",options={{value="comfortable",label="Comfortable"},{value="large",label="Large"}}},
    {key="ui_font",type="text",default="Arial",maxLength=80,label="Interface font"},
    {key="mono_font",type="text",default="Menlo",maxLength=80,label="Monospaced reading font"},
    {key="ui_size",type="number",default=12,min=11,max=24,integer=true,label="Interface font size"},
    {key="reading_size",type="number",default=13,min=11,max=24,integer=true,label="Reading font size"},
  },apply=AardwolfToolbox.ui.configure})
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
      {key = "unexplored_rooms", type = "boolean", default = true, label = "Create unexplored room placeholders",
        description = "Show reported destinations as gray ? rooms and unknown or obstructed destinations as exit stubs. Existing placeholders remain when disabled."},
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
  AardwolfToolbox.borders = resource("borders").new(_G,config)
  AardwolfToolbox.incoming = resource("incoming").new(_G)
  AardwolfToolbox.help = resource("help-pane").new(_G,AardwolfToolbox.incoming,AardwolfToolbox.ui)
  config.registerFeature({id="help",label="Help pane",
    description="Open tagged help in a floating window, titled with its keywords.",settings={
      {key="enabled",type="boolean",default=true,label="Enable floating help"},

    },apply=AardwolfToolbox.help.configure})
  AardwolfToolbox.vitals = resource("vitals").new(_G,AardwolfToolbox.borders,AardwolfToolbox.ui)
  config.registerFeature({id="vitals", label="Vitals",
    description="Compact HP, Mana, Moves, target health, and level progress above the command input.",
    settings={
      {key="enabled", type="boolean", default=true, label="Enable bottom Vitals"},
      {key="show_target", type="boolean", default=true, label="Show target health",
        description="Show the current enemy and its server-reported health percentage."},
      {key="show_tnl", type="boolean", default=true, label="Show TNL",
        description="Fill the bar as experience is earned; show the amount remaining."},
      {key="bar_height", type="number", default=22, min=16, max=36, integer=true, label="Bar height (pixels)"},
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
    end,AardwolfToolbox.ui)
  config.registerFeature({id="ascii",label="ASCII map",
    description="Capture maps for the ASCII tab. Dock and geometry preferences apply to its pop-out pane. Fonts are shared in Appearance.",settings={
      {key="enabled",type="boolean",default=true,label="Enable ASCII map"},
      {key="locked",type="boolean",default=false,label="Locked"},
      {key="dock",type="choice",default="floating",label="Dock position",options={
        {value="floating",label="Floating"},{value="left",label="Left"},{value="right",label="Right"},
        {value="top",label="Top"},{value="bottom",label="Bottom"}}},

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

  AardwolfToolbox.player = resource("player-panel").new(_G,AardwolfToolbox.gmcp,AardwolfToolbox.ui)
  config.registerFeature({id="player",label="Player panel",
    description="Compact player level, stats, and status between the map and chat.",settings={
      {key="enabled",type="boolean",default=true,label="Enable player panel"},

    },apply=AardwolfToolbox.player.configure})


  AardwolfToolbox.inventory = resource("inventory").new(_G,AardwolfToolbox.gmcp,AardwolfToolbox.incoming)
  AardwolfToolbox.utilityBar = resource("utility-bar").new(_G,AardwolfToolbox.gmcp,
    AardwolfToolbox.inventory,AardwolfToolbox.borders,function() AardwolfToolbox.openSettings() end,AardwolfToolbox.ui)
  local utilitySettings={
    {key="enabled",type="boolean",default=true,label="Enable utility bar"},

    {key="inventory_tracking",type="boolean",default=true,label="Automatic inventory tracking",
      description="Enable server inventory monitoring and request a snapshot when command-ready. Monitoring stays enabled on teardown."},
  }
  for _,entry in ipairs({{"level","Level"},{"total","Total levels"},{"tier","Tier"},{"remorts","Remorts"},
      {"worth","Total worth"},{"gold","Gold on hand"},{"items","Loose inventory count"},{"spellups","spellup indicator"}}) do
    utilitySettings[#utilitySettings+1]={key="show_"..entry[1],type="boolean",default=true,label="Show "..entry[2]}
  end
  config.registerFeature({id="utility",label="Utility bar",
    description="Full-width player progression, gold, and loose inventory above the console and sidebar.",
    settings=utilitySettings,apply=AardwolfToolbox.utilityBar.configure})

  AardwolfToolbox.spells=resource("spells").new(_G,AardwolfToolbox.gmcp,AardwolfToolbox.incoming,AardwolfToolbox.tags)
  AardwolfToolbox.spellup=resource("spellup").new(_G,AardwolfToolbox.gmcp,AardwolfToolbox.spells)
  AardwolfToolbox.utilityBar.bindSpellups(AardwolfToolbox.spells,AardwolfToolbox.spellup,function() AardwolfToolbox.openBuffs() end)
  config.registerFeature({id="spellups",label="Spellups",description="Track buffs and recoveries. Optional spellup learned retry starts batches only while standing outside combat. Pause stops new batches; already queued server casts may continue.",settings={
    {key="enabled",type="boolean",default=true,label="Enable spell tracking"},
    {key="automatic_setup",type="boolean",default=true,label="Automatic spell monitoring setup"},
    {key="auto_refresh",type="boolean",default=false,label="Automatically refresh spellups"},
    {key="show_tab",type="boolean",default=true,label="Show Buffs dashboard tab"},
    {key="min_interval",type="number",default=30,min=10,max=300,integer=true,label="Minimum batch interval (seconds)"},
  },apply=function(values)
    local ok,message=AardwolfToolbox.spells.configure(values)
    if not ok then AardwolfToolbox.spellup.stop(); return false,message end
    return AardwolfToolbox.spellup.configure(values)
  end})

  AardwolfToolbox.dashboardData=resource("dashboard-data").new(_G,AardwolfToolbox.gmcp)
  AardwolfToolbox.dashboard=resource("dashboard").new(_G,config,AardwolfToolbox.gmcp,
    AardwolfToolbox.dashboardData,AardwolfToolbox.ui,AardwolfToolbox.borders,
    AardwolfToolbox.ascii,AardwolfToolbox.player,AardwolfToolbox.utilityBar,AardwolfToolbox.spells,AardwolfToolbox.spellup)
  config.registerFeature({id="dashboard",label="Dashboard and layout",description="Tabbed maps and gameplay views above chat. Drag the dividers to resize. Reset layout restores placement without clearing data.",settings={
    {key="enabled",type="boolean",default=true,label="Enable tabbed sidebar"},
    {key="automatic_data",type="boolean",default=true,label="Automatic GMCP data setup"},
    {key="show_events",type="boolean",default=true,label="Show quest and event indicators"},
    {key="locked",type="boolean",default=false,label="Lock layout"},
    {key="collapsed",type="boolean",default=true,label="Collapse sidebar in narrow windows"},
    {key="width",type="number",default=0,min=0,max=3000,integer=true,label="Sidebar width (0 = automatic)"},
    {key="map_percent",type="number",default=40,min=20,max=60,integer=true,label="Map height share (%)"},
    {key="dashboard_percent",type="number",default=30,min=20,max=60,integer=true,label="Dashboard height share (%)"},
    {key="map_tab",type="choice",default="graphical",label="Map view",options={{value="graphical",label="Graphical"},{value="ascii",label="ASCII"}}},
    {key="ascii_popout",type="boolean",default=false,label="Pop out ASCII map"},
    {key="tab",type="choice",default="player",label="Dashboard view",options={{value="player",label="Player"},{value="quest",label="Quest"},{value="group",label="Group"},{value="combat",label="Combat"},{value="buffs",label="Buffs"}}},
  },validate=function(values) return values.map_percent+values.dashboard_percent<=80,"Map and dashboard shares must leave at least 20% for chat." end,apply=AardwolfToolbox.dashboard.configure})

  local Shortcuts=resource("shortcuts")
  local Actions=resource("action-bar")
  AardwolfToolbox.actionBar=Actions.new(_G,config,AardwolfToolbox.gmcp,AardwolfToolbox.borders,AardwolfToolbox.ui,
    Shortcuts,resource("navigation"),function(id,add)
      AardwolfToolbox.openSettings()
      AardwolfToolbox.settingsWindow.editRecord("actions","buttons",id,add)
    end,function() return AardwolfToolbox.settingsWindow and AardwolfToolbox.settingsWindow.opened end)
  AardwolfToolbox.navigation=AardwolfToolbox.actionBar.navigation
  AardwolfToolbox.shortcuts=AardwolfToolbox.actionBar.shortcuts
  config.registerFeature(Actions.definition(Shortcuts,AardwolfToolbox.actionBar.configure))

end

function AardwolfToolbox.start()
  initialize()
  AardwolfToolbox.active = true
  if not AardwolfToolbox.config.getMetadata("layout013") then
    local ok,message=pcall(function()
      AardwolfToolbox.borders.resetExternal({top=0,bottom=0})
      assert(AardwolfToolbox.config.setMetadata("layout013",true))
    end)
    if not ok then echo("Aardwolf layout: "..tostring(message).."\n") end
  end
  AardwolfToolbox.config.activate()
end

function AardwolfToolbox.stop()
  if AardwolfToolbox.settingsWindow then AardwolfToolbox.settingsWindow.destroy() end
  if AardwolfToolbox.config then AardwolfToolbox.config.deactivate() end
  if AardwolfToolbox.actionBar then AardwolfToolbox.actionBar.stop() end
  if AardwolfToolbox.dashboard then AardwolfToolbox.dashboard.stop() end
  if AardwolfToolbox.utilityBar then AardwolfToolbox.utilityBar.stop() end
  if AardwolfToolbox.player then AardwolfToolbox.player.stop() end
  if AardwolfToolbox.help then AardwolfToolbox.help.stop() end
  if AardwolfToolbox.consider then AardwolfToolbox.consider.stop() end
  if AardwolfToolbox.spellup then AardwolfToolbox.spellup.stop() end
  if AardwolfToolbox.spells then AardwolfToolbox.spells.stop() end
  if AardwolfToolbox.gmcp then AardwolfToolbox.gmcp.stop() end
  if AardwolfToolbox.ascii then AardwolfToolbox.ascii.stop() end
  if AardwolfToolbox.tags then AardwolfToolbox.tags.stop() end
  if AardwolfToolbox.vitals then AardwolfToolbox.vitals.stop() end
  if AardwolfToolbox.mapper then AardwolfToolbox.mapper.stop() end
  if AardwolfToolbox.ui then AardwolfToolbox.ui.stop() end
  AardwolfToolbox.active = false
end

function AardwolfToolbox.openSettings()
  AardwolfToolbox.start()
  if not AardwolfToolbox.settingsWindow then
    AardwolfToolbox.settingsWindow = resource("settings-window").new(_G, AardwolfToolbox.config, function(id)
      if id=="mapper" then
        local mapper=AardwolfToolbox.mapper
        return "Saved: "..(AardwolfToolbox.config.get("mapper","enabled") and "enabled" or "disabled")..
          " · Actual: "..(mapper.enabled and "running" or "stopped").." · "..mapper.last
      end
      if id=="spellups" then return AardwolfToolbox.spells.last.." · "..AardwolfToolbox.spellup.last end
      local key=id=="actions" and "actionBar" or id=="appearance" and "ui" or id=="utility" and "utilityBar" or id
      local component=AardwolfToolbox[key]
      return AardwolfToolbox.config.runtimeErrors[id] or (component and component.last) or "Settings ready"
    end,AardwolfToolbox.ui,function() return AardwolfToolbox.dashboard.resetLayout() end)
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

function AardwolfToolbox.openBuffs()
  AardwolfToolbox.start()
  local draft,revision=AardwolfToolbox.config.draft()
  draft.spellups.show_tab=true; draft.dashboard.enabled=true; draft.dashboard.tab="buffs"
  local ok,message=AardwolfToolbox.config.apply(draft,revision)
  if not ok then echo("Aardwolf buffs: "..message.."\n") end
end

function AardwolfToolbox.spellupCommand(command)
  AardwolfToolbox.start()
  local ok,message=true,nil
  if command=="on" or command=="off" then
    ok,message=AardwolfToolbox.config.set("spellups","auto_refresh",command=="on")
    if ok and command=="on" then AardwolfToolbox.spellup.resume() end
  elseif command=="sync" then ok,message=AardwolfToolbox.spellup.sync()
  elseif command=="now" then ok,message=AardwolfToolbox.spellup.runOnce() end
  echo("Aardwolf spellups: "..(message or AardwolfToolbox.spellup.last).."\n")
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
