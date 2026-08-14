local helper = {}
helper.path = "C:\\Aardwolf\\helper.dll"
local loaded = package.loadlib(helper.path, "start")
return helper
