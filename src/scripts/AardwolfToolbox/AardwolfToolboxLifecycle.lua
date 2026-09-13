-- Preserve session state when this script is compiled again in the editor.
-- A different package version must release its old instances before rebuilding.
if AardwolfToolbox and AardwolfToolbox.config and AardwolfToolbox.loadedVersion~="@VERSION@" then
  local previous=AardwolfToolbox
  local ok,result=pcall(previous.stop)
  if not ok or result==false then
    echo("Aardwolf upgrade stopped: existing resources could not be released.\n")
    return
  end
  AardwolfToolbox={active=false,calls=previous.calls or 0}
end
AardwolfToolbox = AardwolfToolbox or { active = false, calls = 0 }

local function resource(name)
  return dofile(getMudletHomeDir() .. "/@PKGNAME@/" .. name .. ".lua")
end

local function own(id,value,dependencies,method)
  AardwolfToolbox.components.register(id,value,dependencies,method)
  AardwolfToolbox[id]=value
  return value
end

local function initialize()
  local config = resource("configuration").new(_G)
  own("config",config,{},"deactivate")
  own("ui",resource("appearance").new(_G,config),{},"stop")
  config.registerFeature({id="appearance",label="Appearance",description="Shared readable fonts for Toolbox, console, input, and chat. Larger existing console text is preserved.",settings={
    {key="enabled",type="boolean",default=true,label="Manage console and input fonts"},
    {key="preset",type="choice",default="comfortable",label="Reading preset",options={{value="comfortable",label="Comfortable"},{value="large",label="Large"}}},
    {key="ui_font",type="text",default="Arial",maxLength=80,label="Interface font"},
    {key="mono_font",type="text",default="Menlo",maxLength=80,label="Monospaced reading font"},
    {key="ui_size",type="number",default=12,min=11,max=24,integer=true,label="Interface font size"},
    {key="reading_size",type="number",default=13,min=11,max=24,integer=true,label="Reading font size"},
  },apply=AardwolfToolbox.ui.configure})
  own("gmcp",resource("gmcp-cache").new(_G),{},"stop")
  config.registerFeature({id="gmcp",label="GMCP data",
    description="Keep session-only character, communication, group, and room values for Toolbox features.",
    settings={{key="enabled",type="boolean",default=true,label="Enable GMCP cache"}},
    apply=AardwolfToolbox.gmcp.configure})
  own("mapper",resource("automapper").new(_G, function(key)
    return config.get("mapper", key)
  end, resource("mapper-identity")),{},"stop")
  own("mapTravel",resource("map-travel").new(_G, AardwolfToolbox.gmcp),{"gmcp"},"stop")
  config.registerFeature({
    id = "mapper", label = "Auto-mapper",
    description = "Use game room numbers and authoritative GMCP room fields. Legacy Toolbox maps are backed up and renumbered on the next fresh room update.",
    settings = {
      {key = "enabled", type = "boolean", default = true, label = "Enable mapping",
        description = "Record rooms and exits. Turning this off releases the mapper's listeners."},
      {key = "double_click_run", type = "boolean", default = true, label = "Double-click map rooms to run",
        description = "Send one run command along a mapped path. Requires fresh room data and a standing, command-ready character."},
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
        if not AardwolfToolbox.mapper.enabled then
          AardwolfToolbox.mapTravel.stop()
          return false, AardwolfToolbox.mapper.last
        end
      else
        AardwolfToolbox.mapper.stop()
      end
      return AardwolfToolbox.mapTravel.configure(values.double_click_run)
    end,
  })
  own("borders",resource("borders").new(_G,config),{},"stop")
  local Shell=resource("sidebar-shell")
  own("shell",Shell.new(_G,config,AardwolfToolbox.gmcp,AardwolfToolbox.ui,resource("console-text")),{"config","gmcp","ui"})
  config.registerFeature(Shell.definition(function(values)
    local shell=AardwolfToolbox.shell
    local changed=shell.configuredMode and shell.configuredMode~=values.mode
    local dashboard=AardwolfToolbox.dashboard
    local running=changed and dashboard and dashboard.enabled
    if running then dashboard.stop() end
    if changed then shell.stop() end
    shell.configure(values)
    if running then local draft=config.draft();return dashboard.configure(draft.dashboard) end
    return true
  end))
  own("incoming",resource("incoming").new(_G),{},"destroy")
  own("help",resource("help-pane").new(_G,AardwolfToolbox.incoming,AardwolfToolbox.ui),{"incoming","ui"},"stop")
  config.registerFeature({id="help",label="Help pane",
    description="Open tagged help in a floating window, titled with its keywords.",settings={
      {key="enabled",type="boolean",default=true,label="Enable floating help"},

    },apply=AardwolfToolbox.help.configure})
  own("vitals",resource("vitals").new(_G,AardwolfToolbox.borders,AardwolfToolbox.ui),{"borders","ui"},"stop")
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

  own("tags",resource("tags").new(_G,AardwolfToolbox.incoming),{"incoming"},"stop")
  config.registerFeature({id="tags",label="Game tags",
    description="Capture brace-tagged records and complete blocks for Toolbox features.",
    settings={
      {key="enabled",type="boolean",default=true,label="Enable tag capture"},
      {key="suppress",type="boolean",default=true,label="Suppress captured output",
        description="Hide tag lines and all text inside tagged blocks from the main console."},
      {key="block_timeout",type="number",default=10,min=1,max=120,label="Block timeout (seconds)",
        description="Stop hiding unfinished blocks after this many seconds."},
    },apply=AardwolfToolbox.tags.configure})
  own("ascii",resource("ascii-map").new(_G,config,AardwolfToolbox.incoming,
    AardwolfToolbox.borders,function()
      AardwolfToolbox.openSettings(); AardwolfToolbox.settingsWindow.select("ascii")
    end,AardwolfToolbox.ui),{"incoming","borders","ui"},"stop")
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

  local Cleanup=resource("console-cleanup")
  own("consoleCleanup",Cleanup.new(_G,AardwolfToolbox.incoming),{"incoming"})
  config.registerFeature(Cleanup.definition(AardwolfToolbox.consoleCleanup.configure))
  own("consider",resource("consider").new(_G,AardwolfToolbox.incoming),{"incoming"},"stop")
  config.registerFeature({id="consider",label="Consider",
    description="Replace consider messages with clear difficulty labels and relative level ranges.",settings={
      {key="enabled",type="boolean",default=true,label="Enable consider formatting"},
      {key="colors",type="boolean",default=true,label="Use difficulty colors",
        description="Difficulty labels and relative level ranges remain visible with colors disabled."},
    },apply=AardwolfToolbox.consider.configure})

  own("player",resource("player-panel").new(_G,AardwolfToolbox.gmcp,AardwolfToolbox.ui),{"gmcp","ui"},"stop")
  config.registerFeature({id="player",label="Player panel",
    description="Compact player level, stats, and status between the map and chat.",settings={
      {key="enabled",type="boolean",default=true,label="Enable player panel"},

    },apply=AardwolfToolbox.player.configure})


  own("queries",resource("query-coordinator").new(_G),{},"destroy")
  own("readiness",resource("readiness").new(_G,AardwolfToolbox.gmcp),{"gmcp"},"stop")
  own("inventory",resource("inventory").new(_G,AardwolfToolbox.gmcp,AardwolfToolbox.incoming,AardwolfToolbox.queries,AardwolfToolbox.readiness,resource("item-state")),{"gmcp","incoming","queries","readiness"},"stop")
  own("utilityBar",resource("utility-bar").new(_G,AardwolfToolbox.gmcp,
    AardwolfToolbox.inventory,AardwolfToolbox.borders,function() AardwolfToolbox.openSettings() end,AardwolfToolbox.ui),{"gmcp","inventory","borders","ui"},"stop")
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

  own("abilityStore",resource("ability-store").new(_G),{},"destroy")
  own("spells",resource("spells").new(_G,AardwolfToolbox.gmcp,AardwolfToolbox.incoming,AardwolfToolbox.tags,AardwolfToolbox.abilityStore,AardwolfToolbox.queries),{"gmcp","incoming","tags","abilityStore","queries"},"stop")
  own("spellup",resource("spellup").new(_G,AardwolfToolbox.gmcp,AardwolfToolbox.spells,AardwolfToolbox.queries),{"gmcp","spells","queries"},"stop")
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

  local Views=resource("view-hosts")
  own("views",Views.new(_G,config,AardwolfToolbox.ui,function()
    AardwolfToolbox.openSettings(); AardwolfToolbox.settingsWindow.select("views")
  end),{"config","ui"})
  config.registerFeature(Views.definition(AardwolfToolbox.views.configure))
  own("dashboardData",resource("dashboard-data").new(_G,AardwolfToolbox.gmcp),{"gmcp"},"stop")
  own("dashboard",resource("dashboard").new(_G,config,AardwolfToolbox.gmcp,
    AardwolfToolbox.dashboardData,AardwolfToolbox.ui,AardwolfToolbox.borders,
    AardwolfToolbox.ascii,AardwolfToolbox.player,AardwolfToolbox.utilityBar,AardwolfToolbox.spells,AardwolfToolbox.spellup,AardwolfToolbox.views,resource("dashboard-panels"),AardwolfToolbox.shell,resource("chat-search")),{"gmcp","dashboardData","ui","borders","ascii","player","utilityBar","spells","spellup"},"stop")
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
    {key="tab",type="choice",default="player",label="Dashboard view",options={{value="player",label="Player"},{value="quest",label="Quest"},{value="group",label="Group"},{value="buffs",label="Buffs"}}},
  },validate=function(values) return values.map_percent+values.dashboard_percent<=80,"Map and dashboard shares must leave at least 20% for chat." end,apply=AardwolfToolbox.dashboard.configure})

  config.registerFeature({id="diagnostics",label="Diagnostics",description="Feature activation, freshness and request status. Reports contain no raw gameplay logs.",settings={
    {key="details",type="boolean",default=true,label="Include feature details in status reports"},
  },apply=function() return AardwolfToolbox.queries.start(AardwolfToolbox.gmcp,AardwolfToolbox.incoming) end})

  local AbilityFields=resource("ability-fields")
  own("abilities",resource("abilities").new(_G,config,AardwolfToolbox.gmcp,AardwolfToolbox.incoming,
    AardwolfToolbox.tags,AardwolfToolbox.abilityStore,AardwolfToolbox.queries,resource("ability-capture"),resource("ability-model"),AardwolfToolbox.spellup),{"gmcp","incoming","tags","abilityStore","queries","spellup"},"stop")
  config.registerFeature(AbilityFields.definition(AardwolfToolbox.abilities.configure))
  local Mobs=resource("mobs")
  local MobActions=resource("mob-actions")
  own("mobs",Mobs.new(_G,AardwolfToolbox.gmcp,AardwolfToolbox.incoming,AardwolfToolbox.tags,
    AardwolfToolbox.queries,AardwolfToolbox.spellup,resource("mob-state"),resource("mob-protocol"),resource("mob-pane"),
    AardwolfToolbox.ui,AardwolfToolbox.borders,function()
      AardwolfToolbox.openSettings(); AardwolfToolbox.settingsWindow.select("mobs")
    end,AardwolfToolbox.consider,MobActions,config),{"config","gmcp","incoming","queries"})
  config.registerFeature(Mobs.definition(AardwolfToolbox.mobs.configure,MobActions))

  local Shortcuts=resource("shortcuts")
  local Actions=resource("action-bar")
  own("actionBar",Actions.new(_G,config,AardwolfToolbox.gmcp,AardwolfToolbox.borders,AardwolfToolbox.ui,
    Shortcuts,resource("navigation"),function(id,add)
      AardwolfToolbox.openSettings()
      AardwolfToolbox.settingsWindow.editRecord("actions","buttons",id,add)
    end,function() return (AardwolfToolbox.settingsWindow and AardwolfToolbox.settingsWindow.opened) or (AardwolfToolbox.mobs and AardwolfToolbox.mobs.menuOpen) or (AardwolfToolbox.views and AardwolfToolbox.views.isEditing()) or (AardwolfToolbox.dashboard and AardwolfToolbox.dashboard.isEditing()) or (AardwolfToolbox.launcher and AardwolfToolbox.launcher.isEditing()) or (AardwolfToolbox.browser and AardwolfToolbox.browser.isEditing()) end,AardwolfToolbox.abilities),{"config","gmcp","borders","ui"})
  AardwolfToolbox.navigation=AardwolfToolbox.actionBar.navigation
  AardwolfToolbox.shortcuts=AardwolfToolbox.actionBar.shortcuts
  config.registerFeature(Actions.definition(Shortcuts,AardwolfToolbox.actionBar.configure,AbilityFields.buttons()))


  own("itemActions",resource("item-actions").new(AardwolfToolbox.inventory,AardwolfToolbox.readiness,resource("item-state")),{"inventory","readiness"},"stop")
  local Browser=resource("workspace-browser")
  own("browser",Browser.new(_G,config,AardwolfToolbox.ui,AardwolfToolbox.views,AardwolfToolbox.inventory,
    AardwolfToolbox.abilities,AardwolfToolbox.readiness,resource("console-text"),function(feature)
      AardwolfToolbox.openSettings();AardwolfToolbox.settingsWindow.select(feature)
    end,AardwolfToolbox.itemActions),{"config","ui","views","inventory","abilities","readiness","itemActions"},"stop")
  config.registerFeature(Browser.definition(AardwolfToolbox.browser.configure))

  local Launcher=resource("launcher")
  local launcher=own("launcher",Launcher.new(_G,config,AardwolfToolbox.ui,AardwolfToolbox.utilityBar,function(feature)
    AardwolfToolbox.openSettings(); AardwolfToolbox.settingsWindow.select(feature)
  end,AardwolfToolbox.readiness),{"config","ui","utilityBar","readiness"},"stop")
  config.registerFeature(Launcher.definition(launcher.configure))
  launcher.register({id="setup",label="Setup walkthrough",description="Offline guide to layout, fonts, monitoring, shortcuts and chat",callback=function() return launcher.open("setup") end})
  for _,id in ipairs({"player","quest","group","buffs","all","tells","channels","inventory","equipment","abilities"}) do
    local view=id
    launcher.register({id="view."..view,label="Open "..view,description="Open the existing sidebar or floating view",available=function()
      return AardwolfToolbox.views.available(view),"View is disabled or unavailable"
    end,callback=function() return AardwolfToolbox.views.open(view) end})
  end
  for _,id in ipairs(config.order) do
    local feature=id
    launcher.register({id="settings."..feature,label="Settings: "..config.features[feature].label,
      description=config.features[feature].description,callback=function()
        AardwolfToolbox.openSettings(); AardwolfToolbox.settingsWindow.select(feature)
      end})
  end
  for _,entry in ipairs({
    {"mobs","Refresh current-room mobs","mobs","refresh"},
    {"nearby","Refresh Nearby scan","mobs","refreshNearby"},
    {"ratings","Rate current-room mobs","mobs","rateRoom"},
    {"abilities","Refresh learned abilities","abilities","refresh"},
    {"buffs","Sync buffs and recoveries","spellup","sync"},
    {"inventory","Refresh carried inventory","inventory","refresh","carried"},
    {"equipment","Refresh equipment","inventory","refresh","equipped"},
    {"quest","Refresh quest status","dashboardData","requestQuest"},
  }) do
    local request=entry
    launcher.register({id="refresh."..request[1],label=request[2],policy="information",
      description="Manual informational request; unavailable until fresh login readiness",
      available=function() return AardwolfToolbox[request[3]].enabled,"Feature is disabled" end,
      callback=function() return AardwolfToolbox[request[3]][request[4]](request[5]) end})
  end

end

function AardwolfToolbox.start()
  if not AardwolfToolbox.initialized then
    AardwolfToolbox.components=resource("components").new()
    local ok,err=pcall(initialize)
    if not ok then
      local _,entries=AardwolfToolbox.components.stop()
      for _,entry in ipairs(entries) do AardwolfToolbox[entry.id]=nil end
      AardwolfToolbox.navigation=nil; AardwolfToolbox.shortcuts=nil
      AardwolfToolbox.lastError=tostring(err); AardwolfToolbox.active=false
      echo("Aardwolf startup failed: "..tostring(err).."\n")
      return false,tostring(err)
    end
    AardwolfToolbox.initialized=true
    AardwolfToolbox.loadedVersion="@VERSION@"
  end
  local ok,err=pcall(AardwolfToolbox.config.activate)
  if not ok then
    AardwolfToolbox.components.stop(); AardwolfToolbox.active=false
    AardwolfToolbox.lastError=tostring(err)
    return false,tostring(err)
  end
  AardwolfToolbox.active=true; AardwolfToolbox.lastError=nil
  return true
end

function AardwolfToolbox.stop()
  if AardwolfToolbox.settingsWindow then
    local ok,err=pcall(AardwolfToolbox.settingsWindow.destroy)
    if not ok then AardwolfToolbox.lastError=tostring(err) end
  end
  local ok,errors=true,{}
  if AardwolfToolbox.components then ok,errors=AardwolfToolbox.components.stop() end
  AardwolfToolbox.active=false
  return ok,errors
end

function AardwolfToolbox.openSettings()
  local started,err=AardwolfToolbox.start()
  if not started then return false,err end
  if not AardwolfToolbox.settingsWindow then
    own("settingsWindow",resource("settings-window").new(_G, AardwolfToolbox.config, function(id)
      if id=="mapper" then
        local mapper=AardwolfToolbox.mapper
        return "Saved: "..(AardwolfToolbox.config.get("mapper","enabled") and "enabled" or "disabled")..
          " · Actual: "..(mapper.enabled and "running" or "stopped").." · "..mapper.last
      end
      if id=="spellups" then return AardwolfToolbox.spells.last.." · "..AardwolfToolbox.spellup.last end
      local key=id=="actions" and "actionBar" or id=="appearance" and "ui" or id=="utility" and "utilityBar" or id
      local component=AardwolfToolbox[key]
      return AardwolfToolbox.config.runtimeErrors[id] or (component and component.last) or "Settings ready"
    end,AardwolfToolbox.ui,function() return AardwolfToolbox.dashboard.resetLayout() end,AardwolfToolbox.abilities,resource("ability-picker"),AardwolfToolbox.health,AardwolfToolbox.exportDiagnostics),{"config","mapper","spells","spellup","ui","dashboard","abilities"},"stop")
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
  if not ok then echo("Aardwolf buffs: "..message.."\n") else AardwolfToolbox.views.open("buffs") end
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

function AardwolfToolbox.health()
  local result={version="@VERSION@",active=AardwolfToolbox.active,error=AardwolfToolbox.lastError,features={}}
  for _,entry in ipairs(AardwolfToolbox.components and AardwolfToolbox.components.snapshot() or {}) do
    result.features[#result.features+1]=entry
  end
  if AardwolfToolbox.queries then result.queries=AardwolfToolbox.queries.snapshot() end
  if AardwolfToolbox.abilities then result.catalog=AardwolfToolbox.abilities.status() end
  if result.catalog then result.catalog.character=nil end
  if AardwolfToolbox.inventory then result.inventory=AardwolfToolbox.inventory.status() end
  if AardwolfToolbox.spells then result.spells=AardwolfToolbox.spells.status() end
  if AardwolfToolbox.mobs then result.mobs=AardwolfToolbox.mobs.status() end
  if AardwolfToolbox.dashboardData then result.dashboard=AardwolfToolbox.dashboardData.status() end
  return result
end

function AardwolfToolbox.exportDiagnostics()
  local path=getMudletHomeDir().."/AardwolfToolbox-diagnostics.json"
  local ok,encoded=pcall(yajl.to_string,AardwolfToolbox.health())
  if not ok then return false,"Cannot encode diagnostics" end
  local file,err=io.open(path..".tmp","wb"); if not file then return false,err end
  local written,message=file:write(encoded); local closed,closeError=file:close()
  if not written or not closed then os.remove(path..".tmp"); return false,message or closeError end
  local renamed,renameError=os.rename(path..".tmp",path)
  if not renamed then os.remove(path..".tmp"); return false,renameError end
  return true,"Diagnostics saved to "..path
end

function AardwolfToolbox.status()
  if AardwolfToolbox.active then AardwolfToolbox.calls=AardwolfToolbox.calls+1 end
  local report=AardwolfToolbox.health()
  local lines={string.format("Aardwolf Toolbox: %s; calls=%d",AardwolfToolbox.active and "ready" or "inactive",AardwolfToolbox.calls),
    "Version "..report.version}
  if report.error then lines[#lines+1]="Startup: "..report.error end
  if AardwolfToolbox.config and AardwolfToolbox.config.get('diagnostics','details') then
    for _,entry in ipairs(report.features) do
      if entry.last or entry.error then lines[#lines+1]=entry.id..": "..tostring(entry.error or entry.last) end
    end
    lines[#lines+1]="Query owner: "..tostring(report.queries and report.queries.owner or "none")
  end
  echo(table.concat(lines,"\n").."\n")
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
