-- Run only in the disposable offline settings profile.
assert(getProfileName() == "AardwolfToolboxSettingsTest")
local toolbox = AardwolfToolbox
local config = toolbox.config
if not config.features.demo then
  config.registerFeature({id="demo",label="Example feature",description="Disposable controls for native input testing.",settings={
    {key="title",type="text",label="Title",default="Sample",maxLength=40,description="Enter text locally; Return never sends it to the game."},
    {key="count",type="number",label="Count",default=5,min=1,max=10,integer=true,description="An integer from 1 to 10."},
    {key="mode",type="choice",label="Mode",default="quiet",options={{value="quiet",label="Quiet"},{value="verbose",label="Verbose"}}}
  },apply=function(values) AardwolfSettingsTestApplied=values; return true end})
end
toolbox.openSettings()
echo("SETTINGS_NATIVE_READY\n")
