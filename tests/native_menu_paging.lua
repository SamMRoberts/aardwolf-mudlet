-- Thirty local-only actions exercise paging without server or storage changes.
assert(getProfileName()=='AardwolfToolboxSettingsTest' and not select(3,getConnectionInfo()))
assert(AardwolfToolboxAcceptance,'Run native_foundation.lua first')
assert(not AardwolfToolboxPagingAcceptance,'Restore the previous fixture first')
local t=AardwolfToolbox
local initial=#AardwolfToolboxAcceptance.commands
local registered={};local invoked={}
local fixture={invoked=invoked}
AardwolfToolboxPagingAcceptance=fixture
function fixture.restore()
  assert(getProfileName()=='AardwolfToolboxSettingsTest' and not select(3,getConnectionInfo()))
  t.launcher.close()
  for _,id in ipairs(registered) do t.launcher.unregister(id) end
  assert(#AardwolfToolboxAcceptance.commands==initial,'Unexpected dispatch during paging test')
  AardwolfToolboxPagingAcceptance=nil
  echo('PAGING_NATIVE: local utilities removed; no dispatch.\n')
end
local ok,why=pcall(function()
  for i=1,30 do
    local number=i;local id='paging.fixture.'..i
    t.launcher.register({id=id,label=string.format('Paging fixture %02d · Éowyn <literal>',i),
      description='Synthetic local callback only. No gameplay or preference changes.',
      callback=function() invoked[#invoked+1]=number;echo('PAGING_SELECTED '..number..'\n') end})
    registered[#registered+1]=id
  end
  assert(t.launcher.open())
end)
if not ok then fixture.restore();error(why) end
echo('PAGING_NATIVE: search Paging fixture. Alt+J/K must cross pages; Alt+H/L must not select.\n')
echo('Resize with selection: keep it visible. Enter filters; Alt+Enter invokes exactly one local callback.\n')
echo('Check previous/next mouse controls, literal labels, Large appearance and unsent main-input text.\n')
echo('Restore this fixture before foundation interceptors; restore any manually changed appearance.\n')
