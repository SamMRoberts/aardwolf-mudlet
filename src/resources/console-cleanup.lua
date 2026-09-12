-- Final main-console filter. Earlier capture owners retain all of their content.
local Cleanup={}
local OWNER='AardwolfToolbox.consoleCleanup'
local prompt='^%[%-?%d+/%d+hp%s+%-?%d+/%d+mn%s+%-?%d+/%d+mv%s+%d+qt%s+%-?%d+tnl%]%s*>$'
function Cleanup.definition(apply)
  return {id='console_cleanup',label='Console cleanup',description='Hide empty game lines and consecutive identical standard Aardwolf prompts. Captured ASCII maps and help keep their original spacing.',settings={
    {key='enabled',type='boolean',default=true,label='Enable console cleanup'},
    {key='blank_lines',type='boolean',default=true,label='Hide blank and whitespace-only lines'},
    {key='repeated_prompts',type='boolean',default=true,label='Hide repeated identical standard prompts'},
  },apply=apply}
end
function Cleanup.new(api,incoming)
  local self={enabled=false,last='Disabled'}
  local options={}; local previous; local handlers={}
  local function reset() previous=nil end
  function self.stop()
    incoming.remove(OWNER)
    for _,event in ipairs(handlers) do api.deleteNamedEventHandler(OWNER,event) end
    handlers={}; reset(); self.enabled=false; self.last='Disabled'
  end
  self.destroy=self.stop
  local function failed(err)
    self.stop(); self.last='Stopped: '..tostring(err)
    api.echo('Aardwolf console cleanup: '..self.last..'; original output is visible.\n')
  end
  local function receive(text)
    if not self.enabled or type(text)~='string' then return end
    -- Mudlet's incoming line is plain text: ANSI formatting is already separated.
    local trimmed=text:match('^%s*(.-)%s*$')
    if trimmed=='' then return options.blank_lines,options.blank_lines end
    if options.repeated_prompts and trimmed:match(prompt) then
      local duplicate=previous==trimmed; previous=trimmed
      return true,duplicate
    end
  end
  local function processed(text,hidden,owner)
    -- A visible record claimed by another feature (including consider replacement
    -- or unsuppressed tags) breaks a prompt run just like ordinary game output.
    if not hidden and owner~=OWNER and type(text)=='string' and text:find('%S') then reset() end
  end
  function self.start()
    if self.enabled then return true end
    local ok,err=pcall(function()
      incoming.add(OWNER,40,receive,failed,processed)
      for _,event in ipairs({'sysConnectionEvent','sysDisconnectionEvent'}) do
        handlers[#handlers+1]=event
        assert(api.registerNamedEventHandler(OWNER,event,event,reset),'Cannot register console cleanup handler')
      end
      reset(); self.enabled=true; self.last='Filtering blank lines and repeated prompts'
    end)
    if not ok then failed(err); return false,self.last end
    return true
  end
  function self.configure(values)
    options={blank_lines=values.blank_lines,repeated_prompts=values.repeated_prompts}
    reset()
    if not values.enabled then self.stop(); return true end
    return self.start()
  end
  return self
end
return Cleanup
