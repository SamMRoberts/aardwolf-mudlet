-- Literal target templates shared by mob double-clicks, menus and public calls.
local Actions={}
local function line(text)
  return type(text)=='string' and #text<=1024 and text:match('%S') and not text:find('[%z\1-\31\127]')
end
function Actions.preview(template,target)
  if not line(template) then return nil,'Enter one command line (maximum 1,024 characters).' end
  if not template:find('{target}',1,true) then return nil,'Include {target} in the command.' end
  local rest=template:gsub('{target}','')
  if rest:find('[{}]') then return nil,'Only the {target} placeholder is supported.' end
  if not line(target) then return nil,'Mob target is unavailable.' end
  local command=template:gsub('{target}',function() return target end)
  if not line(command) then return nil,'The resolved command exceeds the single-line limit.' end
  return command
end
function Actions.settings()
  return {
    {key='double_click',type='text',default='attack',label='Double-click action',recordSource='mob_actions',
      options={{value='@disabled',label='Disabled'},{value='@select',label='Select only'}}},
    {key='context_menu',type='boolean',default=true,label='Enable right-click menu'},
    {key='mob_actions',type='records',maxItems=48,label='Mob actions',addLabel='Add mob action',
      default={{id='attack',label='Attack',enabled=true,mode='command',command='kill {target}'},
        {id='consider',label='Consider',enabled=true,mode='command',command='consider {target}'}},
      fields={{key='label',type='text',default='New action',maxLength=120,label='Action label'},
        {key='enabled',type='boolean',default=true,label='Enabled'},
        {key='mode',type='choice',default='command',label='Execution mode',options={{value='command',label='Command — send literally'},{value='alias',label='Alias — normal expansion'}}},
        {key='command',type='text',default='',maxLength=1024,label='Command or alias template',
          description='Use {target} for the numbered last-word target, for example: cast 123 {target}. Preview never executes.',
          preview=function(value) return Actions.preview(value,'2.bat') end}}},
  }
end
function Actions.validate(values)
  local found=values.double_click=='@disabled' or values.double_click=='@select'
  if type(values.mob_actions)~='table' then return nil,'Mob actions are missing.' end
  for _,action in ipairs(values.mob_actions) do
    if not line(action.label) then return nil,'Every mob action needs a label.' end
    local valid,message=Actions.preview(action.command,'2.bat')
    if not valid then return nil,action.label..': '..message end
    if action.mode~='command' and action.mode~='alias' then return nil,'Invalid mob execution mode.' end
    if action.id==values.double_click then found=true end
  end
  if not found then return nil,'Double-click action was deleted; choose another action, Select only, or Disabled.' end
  return true
end
function Actions.new(api,access)
  local self={}
  function self.capture(id,revision)
    local context=access.context()
    if context.revision~=revision then return nil,'Room list changed; choose the mob again.' end
    context.id=id
    return context
  end
  function self.resolve(token)
    if type(token)~='table' then return nil,'Choose a current-room mob.' end
    local current=access.context()
    for _,key in ipairs({'session','visit','revision','configuration'}) do
      if current[key]~=token[key] then return nil,'Room or settings changed; choose the mob again.' end
    end
    local row=access.row(token.id)
    if not row or row.alive~=1 or row.missing~=0 or row.killed~=0 or row.unclassified or not row.ordinal then
      return nil,'This mob is no longer available.'
    end
    return row,tostring(row.ordinal)..'.'..row.name:match('%S+$')
  end
  function self.describe()
    local values=access.options()
    if values.double_click=='@disabled' then return 'Double-click disabled' end
    if values.double_click=='@select' then return 'Double-click to select' end
    for _,action in ipairs(values.mob_actions or {}) do
      if action.id==values.double_click then return 'Double-click: '..action.label..(not action.enabled and ' (disabled)' or '') end
    end
    return 'Double-click action unavailable'
  end
  local function report(ok,message) access.feedback(ok,message);return ok,message end
  function self.dispatch(command,mode,token)
    local row,reason=self.resolve(token);if not row then return report(false,reason) end
    local ready,message=access.ready();if not ready then return report(false,message) end
    if not line(command) then return report(false,'One command line is required.') end
    local fn=mode=='alias' and api.expandAlias or api.send
    if type(fn)~='function' then return report(false,'Command transport unavailable.') end
    local ok,result,err=pcall(fn,command,true)
    if not ok or result==false or err then return report(false,'Mob action could not be sent: '..tostring(err or result)) end
    -- Alias expansion reports actual outgoing commands through sysDataSendRequest.
    if mode=='command' then access.observed(command) end
    return report(true,'Sent: '..command)
  end
  function self.activate(actionId,token)
    local row,target=self.resolve(token);if not row then return report(false,target) end
    for _,action in ipairs(access.options().mob_actions or {}) do
      if action.id==actionId then
        if not action.enabled then return report(false,'Mob action is disabled.') end
        local command,message=Actions.preview(action.command,target)
        if not command then return report(false,message) end
        return self.dispatch(command,action.mode,token)
      end
    end
    return report(false,'Mob action is unavailable.')
  end
  function self.doubleClick(token)
    local choice=access.options().double_click
    if choice=='@disabled' then return true end
    local row,reason=self.resolve(token);if not row then return report(false,reason) end
    if choice=='@select' then return access.select(token.id,token.revision) end
    return self.activate(choice,token)
  end
  function self.menu(token)
    local row,target=self.resolve(token);if not row then return nil,target end
    local items={}
    for _,action in ipairs(access.options().mob_actions or {}) do
      if action.enabled then
        local command,reason=Actions.preview(action.command,target)
        if command then items[#items+1]={id=action.id,label=action.label,command=command,mode=action.mode}
        else return nil,reason end
      end
    end
    return {name=row.name,target=target,items=items}
  end
  return self
end
return Actions
