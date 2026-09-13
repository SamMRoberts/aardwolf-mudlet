-- Local discovery UI. Registered callbacks run only on an explicit click.
local Launcher={}
local OWNER='AardwolfToolbox.launcher'
local STEPS={
  {title='Layout and migration',feature='shell',text='Automatic sidebar ownership keeps an existing starter UI. Fresh profiles receive the Toolbox sidebar. To migrate, first back up the profile and native map, then choose Toolbox standalone. Supported chat buffers and the mapper move rather than being copied. Returning to compatibility mode restores their original owners.'},
  {title='Readable fonts and windows',feature='appearance',text='Choose Comfortable or Large in Appearance. Existing larger console fonts are preserved. Use the Views menu to float Player, Quest, Group, Buffs or chat outside the main window. Closing a view hides it; Views reopens it. Dashboard settings control section proportions and layout locking.'},
  {title='Monitoring and login readiness',feature='diagnostics',text='Panels can be configured while disconnected. Fresh GMCP character and room updates are required after login. Diagnostics distinguishes requested monitoring from observed data and explains blocked refreshes. Inventory, ability and spell tracking have their own automatic-setup preferences. Automatic spellup casting starts disabled and is a separate opt-in preference.'},
  {title='Manual actions and shortcuts',feature='actions',text='Add commands, aliases or learned abilities in Action bar settings. No keys are assigned by default. Toolbox rejects duplicate local shortcuts; check Mudlet’s Keys editor for collisions with other packages. Shortcuts pause while Toolbox editors are open. Navigation and mob actions run only when you activate them.'},
  {title='Chat and console preferences',feature='console_cleanup',text='Chat view menus provide local Search and Latest / Mark read. Sidebar settings configure timestamps, channel exclusions, mentions and the incoming color format. Console cleanup offers Off, Captured queries and Compact output. Captured maps and help retain their spacing. Use Apply to save edits in settings; Cancel discards the draft.'},
}
function Launcher.definition(apply)
  return {id='launcher',label='Utility menu and setup',description='Search available views, settings and manual refresh actions. The setup walkthrough is available offline and changes no gameplay preferences.',settings={
    {key='enabled',type='boolean',default=true,label='Show utility menu'},
  },apply=apply}
end
function Launcher.new(api,config,ui,bar,openSettings,readiness)
  local self={enabled=false,last='Disabled'}
  local items,order={},{}
  local root,title,input,body,feedback,closeButton,previous,nextButton,settingsButton,escapeKey
  local rows,handlers={},{}
  local generation,mode,step,filter=0,'menu',1,''
  local layout,render
  local function say(text) if feedback then feedback:echo(ui.escape(text)) end end
  function self.close()
    generation=generation+1
    if escapeKey then api.killKey(escapeKey);escapeKey=nil end
    if root then root:delete() end
    root,title,input,body,feedback,closeButton,previous,nextButton,settingsButton=nil,nil,nil,nil,nil,nil,nil,nil,nil
    rows={}
  end
  function self.isEditing() return root~=nil end
  function self.register(def)
    assert(type(def)=='table' and type(def.id)=='string' and #def.id<=80 and def.id:match('^[%a][%w_.%-]*$'),'Invalid utility action ID')
    assert(not items[def.id],'Duplicate utility action: '..def.id)
    assert(#order<128,'Too many utility actions')
    assert(type(def.label)=='string' and def.label:match('%S') and #def.label<=160 and not def.label:find('[%z\1-\31\127]'),'Invalid utility action label')
    assert(type(def.callback)=='function','Utility action needs a callback')
    assert(def.description==nil or type(def.description)=='string' and #def.description<=1024,'Invalid utility action description')
    assert(def.policy==nil or def.policy=='information' or def.policy=='manual' or def.policy=='spellup','Invalid utility readiness policy')
    assert(def.available==nil or type(def.available)=='function','Invalid utility availability callback')
    local copy={};for k,v in pairs(def) do copy[k]=v end
    items[def.id]=copy;order[#order+1]=def.id
    if root and mode=='menu' then render() end
  end
  function self.unregister(id)
    items[id]=nil
    for i,key in ipairs(order) do if key==id then table.remove(order,i);break end end
    if root and mode=='menu' then render() end
  end
  local function available(item)
    if item.available then
      local ok,yes,why=pcall(item.available)
      if not ok or not yes then return false,tostring(why or (not ok and yes) or 'Unavailable') end
    end
    if item.policy then return readiness.check(item.policy) end
    return true
  end
  function self.activate(id)
    local item=self.enabled and items[id]
    if not item then return false,'Utility action unavailable' end
    local ready,reason=available(item)
    if not ready then say(reason);return false,reason end
    self.close()
    local ok,result,err=pcall(item.callback)
    if not ok or result==false or (result==nil and err) then
      self.last='Action failed: '..tostring(err or result)
      api.echo('Aardwolf utilities: '..self.last..'\n');return false,self.last
    end
    self.last='Opened '..item.label;return true
  end
  local function label(name,parent,text,fn)
    local widget=api.Geyser.Label:new({name=OWNER..'.'..name,x=0,y=0,width='100%',height=32},parent)
    ui.style(widget,fn~=nil);widget:echo(ui.escape(text))
    if fn then widget:setClickCallback(fn) end
    return widget
  end
  local function wrapped(text,width)
    local lines,line={},''
    for word in text:gmatch('%S+') do
      local candidate=line=='' and word or line..' '..word
      if line~='' and ui.measure(candidate)>width then lines[#lines+1]=line;line=word else line=candidate end
    end
    if line~='' then lines[#lines+1]=line end
    for i,value in ipairs(lines) do lines[i]=ui.escape(value) end
    return table.concat(lines,'<br>'),#lines
  end
  render=function()
    generation=generation+1;local token=generation
    for _,row in ipairs(rows) do row:delete() end;rows={}
    if mode=='setup' then
      local entry=STEPS[step]
      title:echo('Setup '..step..' / '..#STEPS..' · '..ui.escape(entry.title))
      local text,count=wrapped(entry.text,math.max(120,root:get_width()-32))
      local row=label('step',body,'');rows[1]=row;row:resize('100%',count*ui.metrics().line+16);row:echo(text)
      nextButton:echo(step==#STEPS and 'Finish' or 'Next ›')
      say('Settings keep their usual Apply / Cancel draft. This guide sends no commands.')
    else
      title:echo('Toolbox utilities')
      local list={}
      for _,id in ipairs(order) do
        local item=items[id]
        if (item.label..' '..(item.description or '')):lower():find(filter:lower(),1,true) then list[#list+1]=item end
      end
      table.sort(list,function(a,b) if a.label==b.label then return a.id<b.id end;return a.label<b.label end)
      for i,item in ipairs(list) do
        local ready,reason=available(item)
        local row=label('action.'..i,body,'',function()
          if generation==token and items[item.id]==item then self.activate(item.id) end
        end)
        rows[#rows+1]=row;row:move(0,(i-1)*ui.metrics().height)
        row:resize('100%',ui.metrics().height)
        row:echo(ui.escape(ui.fit(item.label,math.max(1,root:get_width()-32))))
        row:setToolTip(ui.escape(item.description or item.label)..(not ready and '<br>Unavailable: '..ui.escape(reason) or ''))
      end
      say(#list..' actions · Enter filters; click to open. Refreshes require fresh login data.')
    end
  end
  layout=function()
    if not root then return end
    local w,h=api.getMainWindowSize();local row=ui.metrics().height
    local width,height=math.min(580,math.max(240,w-32)),math.min(560,math.max(240,h-48))
    root:move(math.max(0,(w-width)/2),math.max(0,(h-height)/2));root:resize(width,height)
    ui.style(title);title:resize('100%',row*2)
    ui.apply(input);input:move(8,row*2);input:resize('100%-16',row)
    if mode=='setup' then input:hide() else input:show() end
    local top=mode=='setup' and row*2 or row*3
    body:move(8,top+4);body:resize('100%-16',height-top-row*3-12)
    ui.style(feedback);feedback:move(8,height-row*3);feedback:resize('100%-16',row*2)
    for i,widget in ipairs({previous,settingsButton,nextButton,closeButton}) do
      ui.style(widget,true);widget:move((i-1)*width/4,height-row);widget:resize(width/4,row)
      if mode=='setup' or widget==closeButton then widget:show() else widget:hide() end
    end
    if mode=='menu' then closeButton:move(0,height-row);closeButton:resize('100%',row) end
    render();root:raiseAll()
  end
  function self.open(kind)
    if not self.enabled then return false,'Utility menu is disabled' end
    local selected=kind=='setup' and 'setup' or 'menu'
    if root and selected==mode then root:show();root:raiseAll();return true end
    self.close();mode=selected;filter=''
    local ok,err=pcall(function()
      root=api.Geyser.Container:new({name=OWNER..'.root',x=0,y=0,width=580,height=560})
      local owned=root
      local background=label('background',root,'');background:resize('100%','100%');background:setStyleSheet('QLabel { background: #151c23; border: 1px solid #83bde8; }')
      title=label('title',root,'')
      input=api.Geyser.CommandLine:new({name=OWNER..'.search',x=8,y=64,width='100%-16',height=32},root)
      ui.apply(input);input:setStyleSheet('QPlainTextEdit { background: #101820; color: #e0e6ec; border: 1px solid #83bde8; }')
      input:setAction(function(value)
        if root~=owned or mode~='menu' then return end
        if type(value)~='string' or #value>256 or value:find('[%z\1-\31\127]') then say('Enter up to 256 characters.');return end
        filter=value;render()
      end);input:print('')
      body=api.Geyser.ScrollBox:new({name=OWNER..'.body',x=8,y=96,width='100%-16',height=300},root)
      feedback=label('feedback',root,'')
      previous=label('previous',root,'‹ Back',function() if root==owned then step=math.max(1,step-1);render() end end)
      settingsButton=label('settings',root,'Settings',function()
        if root~=owned then return end
        local feature=STEPS[step].feature;self.close();openSettings(feature)
      end)
      nextButton=label('next',root,'Next ›',function()
        if root~=owned then return end
        if step<#STEPS then step=step+1;render();return end
        local saved,why=config.setMetadata('setupWalkthroughCompleted',true)
        if saved then step=1;self.close() else say('Could not save completion: '..tostring(why)) end
      end)
      closeButton=label('close',root,'Close',function() if root==owned then self.close() end end)
      if api.tempKey and api.mudlet and api.mudlet.key then escapeKey=assert(api.tempKey(api.mudlet.key.Escape,self.close),'Cannot register utility dismissal') end
      layout()
    end)
    if not ok then self.close();self.last='Utility menu failed: '..tostring(err);return false,self.last end
    return true
  end
  function self.stop()
    self.enabled=false;self.close()
    for _,event in ipairs(handlers) do api.deleteNamedEventHandler(OWNER,event) end;handlers={}
    bar.unregisterItem('utilities');self.last='Disabled'
  end
  self.destroy=self.stop
  function self.configure(values)
    if not values.enabled then self.stop();return true end
    if self.enabled then return true end
    local ok,err=pcall(function()
      self.enabled=true
      bar.registerItem({id='utilities',label='Tools',order=999997,overflowPriority=999997,tooltip='Search Toolbox views, settings and manual refresh actions',callback=function() self.open() end})
      bar.updateItem('utilities',{text=''})
      for _,event in ipairs({'sysWindowResizeEvent','AardwolfToolbox.ui.changed','sysDisconnectionEvent'}) do
        handlers[#handlers+1]=event
        assert(api.registerNamedEventHandler(OWNER,event,event,event=='sysDisconnectionEvent' and self.close or layout),'Cannot register utility layout handler')
      end
      self.last='Utility menu ready'
    end)
    if not ok then self.stop();self.last=tostring(err);return false,self.last end
    return true
  end
  return self
end
return Launcher
