-- Final main-console filter. Earlier capture owners retain all of their content.
local Cleanup={}
local OWNER='AardwolfToolbox.consoleCleanup'
local prompt='^%[%-?%d+/%d+hp%s+%-?%d+/%d+mn%s+%-?%d+/%d+mv%s+%d+qt%s+%-?%d+tnl%]%s*>$'
function Cleanup.definition(apply)
  return {id='console_cleanup',label='Console cleanup',description='Compact hides empty lines and repeated standard prompts. Captured queries cleans only gaps immediately after hidden query or monitoring output. Maps and help retain spacing.',settings={
    {key='enabled',type='boolean',default=true,label='Enable console cleanup'},
    {key='mode',type='choice',default='compact',label='Cleanup mode',options={{value='off',label='Off'},{value='queries',label='Captured queries'},{value='compact',label='Compact output'}}},
    {key='blank_lines',type='boolean',default=true,label='Hide blank and whitespace-only lines'},
    {key='repeated_prompts',type='boolean',default=true,label='Hide repeated identical standard prompts'},
  },apply=apply}
end
function Cleanup.new(api,incoming)
  local self={enabled=false,last='Disabled'}
  local options={}; local previous,gapUntil,gapLines; local handlers={}
  local function reset() previous,gapUntil,gapLines=nil,nil,0 end
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
    local gap=options.mode~='queries' or gapUntil and api.getEpoch()<=gapUntil and gapLines<16
    if trimmed=='' then
      if options.blank_lines and gap then gapLines=gapLines+1;return true,true end
      return false
    end
    if options.repeated_prompts and trimmed:match(prompt) then
      local duplicate=previous==trimmed; previous=trimmed
      gapUntil=nil;gapLines=0
      return true,duplicate and gap==true
    end
  end
  local function processed(text,hidden,owner,queryOutput)
    if hidden and queryOutput then gapUntil=api.getEpoch()+2;gapLines=0
    elseif owner and owner~=OWNER then gapUntil=nil;gapLines=0 end
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
      reset(); self.enabled=true; self.last=options.mode=='queries' and 'Cleaning captured-query gaps' or 'Filtering blank lines and repeated prompts'
    end)
    if not ok then failed(err); return false,self.last end
    return true
  end
  function self.configure(values)
    options={blank_lines=values.blank_lines,repeated_prompts=values.repeated_prompts,mode=values.mode or 'compact'}
    reset()
    if not values.enabled or options.mode=='off' then self.stop(); return true end
    local ok,reason=self.start()
    if ok then self.last=options.mode=='queries' and 'Cleaning captured-query gaps' or 'Filtering blank lines and repeated prompts' end
    return ok,reason
  end
  return self
end
return Cleanup
