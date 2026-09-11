-- Run only in the disconnected disposable profile, never in Aardwolf.
assert(getProfileName()=="AardwolfToolboxSettingsTest" and not select(3,getConnectionInfo()))
local t=AardwolfToolbox
assert(t.config.set("tags","enabled",true))
t.utilityBar.unregisterItem("native_test")
local originalY=BaseUI.container.y
local originalHeight=BaseUI.container.height
local function check()
  local r=Geyser.windowList['AardwolfToolbox.utilityBar.root']
  assert(r and r:get_x()==0 and r:get_width()==select(1,getMainWindowSize()))
  assert(BaseUI.container:get_y()>=28)
  assert(BaseUI.container.y==originalY and BaseUI.container.height==originalHeight)
  assert(t.utilityBar.enabled,t.utilityBar.last)
  assert(not t.inventory.ready())
  t.utilityBar.registerItem({id='native_test',label='Literal <tag>',order=8,overflowPriority=0,
    callback=function() echo('UTILITY_NATIVE_CLICK\n') end})
  t.utilityBar.updateItem('native_test',{text='Ready & waiting'})
  gmcp=gmcp or {}; gmcp.char={base={level=116,tier=0,redos=0,remorts=2},worth={gold=175956,bank=12723477}}
  raiseEvent('gmcp.char','gmcp.char')
  feedTriggers('{invdata}\n'); feedTriggers('42,,a bag,1,11,0,-1,-1\n'); feedTriggers('{/invdata}\n')
  tempTimer(0.2,function()
    local ok,err=pcall(function()
      assert(t.inventory.count==1)
      assert(t.gmcp.get('char.base.level')==116)
      assert(t.tags.latest('invdata'))
      local bottom=getBorderBottom()
      assert(t.config.set('ascii','dock','top'))
      local ascii=Geyser.windowList['AardwolfToolbox.ascii.window']
      assert(ascii and ascii:get_y()>=28)
      assert(getBorderBottom()==bottom)
      assert(t.config.set('ascii','dock','floating'))
      t.utilityBar.unregisterItem('native_test')
      t.utilityBar.stop()
      assert(BaseUI.container:get_y()==0)
      assert(not Geyser.windowList['AardwolfToolbox.utilityBar.root'])
      assert(t.utilityBar.start())
      assert(BaseUI.container:get_y()>=28)
    end)
    echo('UTILITY_NATIVE '..tostring(ok)..' '..tostring(err)..'\n')
  end)
end
local ok,err=pcall(check)
if not ok then echo('UTILITY_NATIVE false '..tostring(err)..'\n') end
