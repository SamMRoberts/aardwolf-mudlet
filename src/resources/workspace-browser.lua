-- On-demand observations, with explicit guarded single-item actions.
local Browser={}
local OWNER='AardwolfToolbox.browser'
local IDS={'inventory','equipment','abilities'}
local LABELS={inventory='Inventory',equipment='Equipment',abilities='Abilities'}
local PAGE=24
function Browser.definition(apply)
  local settings={{key='enabled',type='boolean',default=true,label='Enable inventory and ability workspace'},
    {key='item_actions',type='boolean',default=true,label='Enable manual item actions',description='Wear, remove, get or put one observed item by its object ID. Actions never queue or repeat.'}}
  for _,id in ipairs(IDS) do settings[#settings+1]={key=id,type='choice',default='tabbed',label=LABELS[id]..' placement',options={
    {value='tabbed',label='Workspace tab'},{value='floating',label='External window'}}} end
  return {id='browser',label='Inventory and ability workspace',description='Browse observed items and locally stored learned abilities. Refresh and Inspect request information only. Unobserved container contents and missing fields remain unknown.',settings=settings,apply=apply}
end
function Browser.new(api,config,ui,views,inventory,abilities,readiness,Text,openSettings,itemActions)
  local self={enabled=false,last='Disabled'}
  local root,header,closeButton,active,escapeKey
  local entries,tabs,handlers={}, {}, {}
  local epoch,building=0,false
  local menu,menuKey,menuEpoch=nil,nil,0
  local layout,render,selectView
  local function label(name,parent,text,callback)
    local w=api.Geyser.Label:new({name=OWNER..'.'..name,x=0,y=0,width='100%',height=32},parent)
    ui.style(w,callback~=nil);w:echo(ui.escape(text or ''));if callback then w:setClickCallback(callback) end
    return w
  end
  local function value(v) return v==nil and '--' or tostring(v) end
  local function itemName(row) return row.name and Text.plain(row.name,'raw') or ('Item #'..row.id) end
  local function status(id) return id=='abilities' and abilities.status() or inventory.status() end
  local function message(e,text) e.feedback:echo(ui.escape(text)) end
  function self.closeMenu()
    menuEpoch=menuEpoch+1
    if menuKey then api.killKey(menuKey);menuKey=nil end
    if menu then menu:delete();menu=nil end
  end
  local function visible(id) return self.enabled and not building and views.available(id) and (views.mode(id)=='floating' or active==id) and views.visible(id) end
  local function clearRows(e)
    for _,w in ipairs(e.rows) do w:delete() end;e.rows={}
  end
  local function resetSelection(e)
    e.selected=nil;e.detailText=nil
    if e.detail then e.detail:echo('Select a row for details.') end
  end
  local function detail(e)
    local row=e.selected and (e.id=='abilities' and abilities.get(e.selected) or inventory.get(e.selected))
    if not row then resetSelection(e);return end
    local lines={}
    local function add(text) lines[#lines+1]=ui.escape(text) end
    if e.id=='abilities' then
      add(row.name..' · #'..row.id)
      add((row.kind or 'Unknown kind')..' · Required level '..value(row.level)..' · Practice '..value(row.practice)..'%')
      add('Cost '..value(row.cost)..' '..(row.resource or '(resource unknown)')..' · Target '..(row.targeting or 'unknown'))
      add(row.learned and 'Learned' or 'Not currently learned')
      add(row.passive and 'Passive: cannot be activated' or row.command and 'Command: '..row.command or row.command_reason or 'Command syntax unverified')
      for _,m in ipairs(row.memberships or {}) do add(m.role..' / '..m.type..(m.corrected and ' (local correction)' or '')) end
      if row.command_source then add('Verification source: '..row.command_source) end
      for _,button in ipairs(config.get('actions','buttons') or {}) do
        if button.ability_mode and button.ability_mode~='manual' then
          local command,resolved=abilities.preview(button)
          if command and resolved.id==row.id then add('Selected by button: '..button.label..(button.enabled and '' or ' (disabled)')) end
        end
      end
    else
      add(itemName(row)..' · #'..row.id)
      add('Level '..value(row.level)..' · Type '..value(row.type)..' · Flags '..(row.flags or '--'))
      add('Location '..(row.location or 'unknown')..' · Wear slot '..value(row.wear)..' · Timer '..value(row.timer))
      if row.container then add('Container #'..row.container) end
      add(row.fresh and 'Location observed' or 'Stale location; refresh before requesting details')
      if row.details then
        add(row.detailsFresh and 'Observed details:' or 'Previous details (stale):')
        for i,record in ipairs(row.details) do
          if i>512 then add('Further detail records omitted from this view.');break end
          add(Text.plain(record.line,'raw'))
        end
      else add('Details not observed. Inspect requests them without changing the item.') end
      if row.type==11 then add('Contents shows only this explicitly inspected container.') end
    end
    local text=table.concat(lines,'<br>')
    if e.detailText~=text then e.detail:echo(text);e.detailText=text end
    e.detail:resize('100%',math.max(ui.metrics().line*#lines+12,e.details:get_height()))
  end
  local function choose(e,title,options,page)
    self.closeMenu();page=page or 1
    local token=menuEpoch;local h=ui.metrics().height
    local w,height=e.root:get_width(),e.root:get_height()
    menu=api.Geyser.Container:new({name=OWNER..'.menu',x=0,y=0,width='100%',height='100%'},e.root)
    local bg=label('menu.background',menu,'');bg:resize('100%','100%');ui.style(bg)
    local header=label('menu.title',menu,ui.fit(title,math.max(1,w-80)));header:resize('100%-80',h)
    local close=label('menu.close',menu,'Close',self.closeMenu);close:move(w-80,0);close:resize(80,h)
    local body=api.Geyser.ScrollBox:new({name=OWNER..'.menu.body',x=0,y=h,width='100%',height=math.max(h,height-2*h)},menu)
    for index=(page-1)*PAGE+1,math.min(page*PAGE,#options) do
      local option=options[index]
      local button=label('menu.row.'..index,body,ui.fit(option.label,math.max(1,w-16)),function()
        if token~=menuEpoch or not visible(e.id) then return end
        self.closeMenu();option.run()
      end)
      button:move(0,(index-(page-1)*PAGE-1)*h);button:resize('100%',h)
      button:setToolTip(ui.escape(option.tooltip or option.label))
    end
    local pages=math.max(1,math.ceil(#options/PAGE))
    for i,entry in ipairs({{'‹ Previous',math.max(1,page-1)},{page..' / '..pages,page},{'Next ›',math.min(pages,page+1)}}) do
      local button=label('menu.page.'..i,menu,entry[1],function() if token==menuEpoch then choose(e,title,options,entry[2]) end end)
      button:move((i-1)*w/3,height-h);button:resize(w/3,h)
    end
    if not escapeKey then
      menuKey=api.tempKey(api.mudlet.key.Escape,self.closeMenu)
      if not menuKey then self.closeMenu();message(e,'Cannot register menu dismissal');return end
    end
    menu:raiseAll()
  end
  local function itemMenu(e,comparison)
    if not itemActions then return end
    local context,why=itemActions.context(e.selected)
    if not context then message(e,why);return end
    local selected=inventory.get(context.id);local options={}
    local function add(action,title,target)
      local command=itemActions.preview(context,action,target)
      if not command then return end
      options[#options+1]={label=title..' · '..command,tooltip=command,run=function()
        local ok,reason=itemActions.activate(context,action,target)
        message(e,ok and ('Sent '..command..'; waiting for server observation.') or reason)
      end}
    end
    if comparison then
      for _,other in ipairs(inventory.list('equipped')) do
        if other.id~=selected.id then
          local otherId=other.id
          options[#options+1]={label=itemName(other)..' · #'..otherId,run=function()
            local report,reason=itemActions.compare(context,otherId)
            if not report then message(e,reason);return end
            local lines={ui.escape(itemName(report.left)..' / '..itemName(report.right)),
              'Selected / compared / difference',report.detailsFresh and 'Observed item details' or 'Inspect both items for fresh detailed values.'}
            for _,r in ipairs(report.rows) do
              lines[#lines+1]=ui.escape(r.label..': '..value(r.left)..' / '..value(r.right)..' / '..(r.delta and string.format('%+g',r.delta) or '--'))
            end
            lines[#lines+1]='Missing values are unknown. No slot compatibility or best-item ranking is inferred.'
            e.detailText=table.concat(lines,'<br>');e.detail:echo(e.detailText)
            e.detail:resize('100%',math.max(ui.metrics().line*#lines+12,e.details:get_height()))
          end}
        end
      end
    else
      add('wear','Wear');add('remove','Remove');add('get','Get from container')
      if selected.location=='carried' then
        for _,bag in ipairs(inventory.list('carried')) do
          if bag.type==11 and bag.id~=selected.id then add('put','Put in '..itemName(bag),bag.id) end
        end
      end
    end
    if #options==0 then message(e,comparison and 'No other equipped item observed. Refresh equipment first.' or 'No available item actions. Check settings and refresh item locations.');return end
    choose(e,(comparison and 'Compare: ' or 'Actions: ')..itemName(selected),options)
  end
  local function request(e,kind)
    local ok,why=readiness.check('information')
    if not ok then message(e,why);return false,why end
    if kind=='details' or kind=='container' then
      local row=e.selected and inventory.get(e.selected)
      if not row or not row.fresh or (kind=='container' and row.type~=11) then
        message(e,'Select a fresh '..(kind=='container' and 'container' or 'item')..' first.');return false
      end
      ok,why=inventory.refresh(kind,row.id)
      if ok and kind=='container' then e.scope='container:'..row.id;e.page=1;resetSelection(e) end
    elseif e.id=='abilities' then ok,why=abilities.refresh()
    else ok,why=inventory.refresh(e.scope and e.scope:match('^container:') and 'container' or e.scope,e.scope and e.scope:match('^container:(%d+)$')) end
    message(e,ok and 'Information requested; waiting for a complete response.' or why or 'Request unavailable')
    if ok then e.dirty=true end
    return ok,why
  end
  local function renderRows(e)
    if not visible(e.id) then e.dirty=true;return end
    e.revision=e.revision+1;local token=e.revision
    clearRows(e)
    local rows=e.id=='abilities' and abilities.list() or inventory.list(e.scope)
    local matches={};local query=e.search:lower()
    for _,row in ipairs(rows) do
      local name=e.id=='abilities' and row.name or itemName(row)
      local keywords=name..' '..row.id
      if e.id=='abilities' then
        keywords=keywords..' '..(row.kind or '')
        for _,m in ipairs(row.memberships or {}) do keywords=keywords..' '..m.role..' '..m.type end
      else keywords=keywords..' '..(row.flags or '')..' '..value(row.type) end
      if keywords:lower():find(query,1,true) then matches[#matches+1]={id=row.id,name=name,row=row} end
    end
    local pages=math.max(1,math.ceil(#matches/PAGE));e.page=math.min(e.page,pages)
    e.pageLabel:echo(e.page..' / '..pages);e.pages=pages
    local rowHeight=ui.metrics().line*2+12
    for i=(e.page-1)*PAGE+1,math.min(e.page*PAGE,#matches) do
      local item=matches[i];local r=item.row;local subtitle
      if e.id=='abilities' then
        subtitle='#'..r.id..' · Lv '..value(r.level)..' · '..value(r.cost)..' '..(r.resource or '?')..' · '..(r.passive and 'Passive' or r.command and 'Verified' or 'Unverified')
      else subtitle='#'..r.id..' · Lv '..value(r.level)..' · Type '..value(r.type)..' · '..(r.fresh and 'Observed' or 'Stale') end
      local w=label(e.id..'.row.'..(#e.rows+1),e.list,'',function()
        if self.enabled and e.revision==token and entries[e.id]==e then e.selected=item.id;detail(e) end
      end)
      w:move(0,#e.rows*rowHeight);w:resize('100%',rowHeight);e.rows[#e.rows+1]=w
      w:echo(ui.escape(ui.fit(item.name,math.max(1,e.root:get_width()-28)))..'<br>'..ui.escape(ui.fit(subtitle,math.max(1,e.root:get_width()-28))))
      w:setToolTip(ui.escape(item.name)..'<br>'..ui.escape(subtitle))
    end
    local state=status(e.id);e.dataRevision=state.revision
    message(e,#matches..' records · '..(e.id=='abilities' and (state.fresh and 'Fresh catalog' or 'Stored catalog / stale') or (state.fresh[e.scope] and 'Observed '..e.scope or 'Waiting / stale '..e.scope)))
    detail(e);e.dirty=false
  end
  render=function(e)
    local ok,why=pcall(renderRows,e)
    if not ok then
      clearRows(e);resetSelection(e);e.dirty=false
      self.last='Workspace read failed: '..tostring(why);message(e,self.last)
    end
    return ok,why
  end
  local function layoutEntry(e)
    local w,h=e.root:get_width(),e.root:get_height();local row=ui.metrics().height
    local signature=w..':'..h..':'..row..':'..ui.metrics().size..':'..ui.metrics().font
    if e.geometry==signature then return end;e.geometry=signature
    ui.apply(e.input);e.input:move(4,0);e.input:resize('100%-8',row)
    local controls={e.refresh,e.inspect,e.contents,e.homeButton,e.view}
    for i,button in ipairs(controls) do
      ui.style(button,true);button:move((i-1)*w/5,row);button:resize(w/5,row)
    end
    local top=row*2
    if e.actions then
      for i,button in ipairs({e.actions,e.compare}) do ui.style(button,true);button:move((i-1)*w/2,top);button:resize(w/2,row) end
      top=top+row
    end
    local bodyHeight=math.max(row*2,h-top-row*2)
    e.list:move(4,top);e.list:resize('100%-8',math.floor(bodyHeight*.55))
    e.details:move(4,top+math.floor(bodyHeight*.55));e.details:resize('100%-8',math.ceil(bodyHeight*.45))
    ui.style(e.detail);e.feedback:move(4,h-row*2);e.feedback:resize('100%-8',row);ui.style(e.feedback)
    for i,button in ipairs({e.previous,e.pageLabel,e.next}) do
      ui.style(button,i~=2);button:move((i-1)*w/3,h-row);button:resize(w/3,row)
    end
    render(e)
  end
  layout=function()
    if not self.enabled or building or not root then return end
    local w,h=api.getMainWindowSize();local row=ui.metrics().height
    local width,height=math.min(820,w-16),math.min(700,h-24)
    root:move(math.max(0,(w-width)/2),math.max(0,(h-height)/2));root:resize(width,height)
    ui.style(header);header:resize('100%-80',row);closeButton:move(width-80,0);closeButton:resize(80,row);ui.style(closeButton,true)
    for i,id in ipairs(IDS) do
      ui.style(tabs[id],true,active==id);tabs[id]:move((i-1)*width/3,row);tabs[id]:resize(width/3,row)
      local e=entries[id];e.home:move(0,row*2);e.home:resize('100%',height-row*2)
      if views.mode(id)=='tabbed' then e.root:resize('100%','100%') end
      if visible(id) then layoutEntry(e);if e.dirty then render(e) end end
    end
  end
  function self.close()
    self.closeMenu()
    active=nil
    if root then root:hide() end
    for _,id in ipairs(IDS) do
      local e=entries[id]
      if e then
        if e.root and views.mode(id)~='floating' then e.root:hide() end
        if views.mode(id)~='floating' then clearRows(e);resetSelection(e);e.dirty=true end
      end
    end
    if escapeKey then api.killKey(escapeKey);escapeKey=nil end
  end
  selectView=function(id)
    self.closeMenu()
    active=id;root:show();root:raiseAll()
    for key,e in pairs(entries) do
      if views.mode(key)=='tabbed' then if key==id then e.root:show() else e.root:hide();clearRows(e);e.dirty=true end end
    end
    if not escapeKey and api.tempKey and api.mudlet and api.mudlet.key then
      escapeKey=api.tempKey(api.mudlet.key.Escape,function() if menu then self.closeMenu() else self.close() end end)
    end
    layout();local e=entries[id];if e.dirty then render(e) end
  end
  function self.open(id)
    if not self.enabled or building or not entries[id] then return false,'Workspace unavailable' end
    local ok,why=views.open(id)
    if ok then layoutEntry(entries[id]);if entries[id].dirty then render(entries[id]) end end
    return ok,why
  end
  function self.isEditing()
    if not self.enabled or building then return false end
    if active then return true end
    for _,id in ipairs(IDS) do if entries[id] and views.available(id) and views.mode(id)=='floating' and visible(id) then return true end end
    return false
  end
  function self.stop()
    if itemActions then itemActions.stop() end
    self.enabled=false;building=false;epoch=epoch+1;self.close()
    for _,event in ipairs(handlers) do api.deleteNamedEventHandler(OWNER,event) end;handlers={}
    for _,id in ipairs(IDS) do if entries[id] then views.unregister(id) end end
    if root then root:delete() end;root=nil;entries={};tabs={};self.last='Disabled'
  end
  self.destroy=self.stop
  function self.configure(values)
    self.closeMenu()
    if itemActions then itemActions.configure({enabled=values.enabled and values.item_actions}) end
    if not values.enabled then self.stop();return true end
    if self.enabled then
      local ok,why=views.configure()
      for id,e in pairs(entries) do
        local current=views.mode(id)
        if current=='tabbed' and e.mode=='floating' then selectView(id) end
        e.mode=current
      end
      layout();return ok,why
    end
    local ok,why=pcall(function()
      -- Native widget creation can synchronously invoke other components’ layout hooks.
      -- Publish editing/placement state only after every view is registered.
      self.enabled=true;building=true;epoch=epoch+1;local owned=epoch
      root=api.Geyser.Container:new({name=OWNER,x=20,y=60,width=820,height=700})
      local bg=label('background',root,'');bg:resize('100%','100%');bg:setStyleSheet('QLabel { background: #151c23; border: 1px solid #83bde8; }')
      header=label('title',root,'Inventory and ability workspace')
      closeButton=label('close',root,'Close',function() if epoch==owned then self.close() end end)
      for _,id in ipairs(IDS) do
        local key=id
        local e={id=id,rows={},search='',page=1,revision=0,dirty=true,scope=id=='equipment' and 'equipped' or 'carried'};entries[id]=e
        tabs[id]=label('tab.'..id,root,LABELS[id],function() if epoch==owned then self.open(key) end end)
        e.home=api.Geyser.Container:new({name=OWNER..'.'..id..'.home',x=0,y=64,width='100%',height='100%-64'},root)
        e.root=api.Geyser.Container:new({name=OWNER..'.'..id,x=0,y=0,width='100%',height='100%'},e.home)
        local surface=label(id..'.background',e.root,'');surface:resize('100%','100%')
        e.input=api.Geyser.CommandLine:new({name=OWNER..'.'..id..'.search',x=4,y=0,width='100%-8',height=32},e.root)
        ui.apply(e.input);e.input:setAction(function(text)
          if epoch~=owned then return end
          if type(text)~='string' or #text>256 or text:find('[%z\1-\31\127]') then message(e,'Search up to 256 characters.');return end
          e.search=text;e.page=1;render(e)
        end);e.input:print('')
        local function click(fn) return function() if epoch==owned then fn() end end end
        e.refresh=label(id..'.refresh',e.root,'Refresh',click(function() request(e) end))
        e.inspect=label(id..'.inspect',e.root,id=='abilities' and 'Catalog' or 'Inspect',click(function()
          if id=='abilities' then openSettings('abilities') else request(e,'details') end
        end))
        e.contents=label(id..'.contents',e.root,id=='abilities' and 'Buttons' or 'Contents',click(function()
          if id=='abilities' then openSettings('actions') else request(e,'container') end
        end))
        e.homeButton=label(id..'.homeButton',e.root,'Reset',click(function()
          e.scope=id=='equipment' and 'equipped' or 'carried';e.search='';e.input:print('');e.page=1;resetSelection(e);render(e)
        end))
        e.view=label(id..'.view',e.root,'View',click(function() views.menu(id) end))
        if id~='abilities' then
          e.actions=label(id..'.actions',e.root,'Item actions',click(function() itemMenu(e,false) end))
          e.compare=label(id..'.compare',e.root,'Compare',click(function() itemMenu(e,true) end))
          e.actions:setToolTip('Preview wear/remove or a single container transfer. Select a row first.')
          e.compare:setToolTip('Compare recorded values with another equipped item. Never changes equipment.')
        end
        e.list=api.Geyser.ScrollBox:new({name=OWNER..'.'..id..'.list',x=0,y=64,width='100%',height=250},e.root)
        e.details=api.Geyser.ScrollBox:new({name=OWNER..'.'..id..'.details',x=0,y=314,width='100%',height=180},e.root)
        e.detail=label(id..'.detail',e.details,'Select a row for details.')
        e.feedback=label(id..'.feedback',e.root,'Open to read stored observations.')
        e.previous=label(id..'.previous',e.root,'‹ Previous',click(function() e.page=math.max(1,e.page-1);render(e) end))
        e.pageLabel=label(id..'.page',e.root,'1 / 1')
        e.next=label(id..'.next',e.root,'Next ›',click(function() e.page=math.min(e.pages or 1,e.page+1);render(e) end))
        e.root:hide()
        assert(views.register(id,{root=e.root,home=e.home,homeLabel='workspace',settings=function() openSettings('browser') end,select=function() selectView(key) end,placement={feature='browser',key=id}}))
        e.mode=views.mode(id)
      end
      root:hide()
      for _,event in ipairs({'sysWindowResizeEvent','sysUserWindowResizeEvent','sysDisconnectionEvent','AardwolfToolbox.gmcp.cleared','AardwolfToolbox.ui.changed','AardwolfToolbox.views.changed','AardwolfToolbox.inventory.updated','AardwolfToolbox.abilities.updated','AardwolfToolbox.abilities.reset'}) do
        handlers[#handlers+1]=event
        assert(api.registerNamedEventHandler(OWNER,event,event,function()
          if epoch~=owned then return end
          if event~='AardwolfToolbox.abilities.updated' then self.closeMenu() end
          if event=='sysWindowResizeEvent' or event=='sysUserWindowResizeEvent' or event=='AardwolfToolbox.ui.changed' or event=='AardwolfToolbox.views.changed' then layout()
          else for id,e in pairs(entries) do
            if (id=='abilities')==(event~='AardwolfToolbox.inventory.updated') and (id=='abilities' or e.dataRevision~=inventory.status().revision) then e.dirty=true;if visible(id) then render(e) end end
          end end
        end))
      end
      building=false;layout();self.last='Workspace ready'
    end)
    if not ok then self.stop();self.last=tostring(why);return false,self.last end
    return true
  end
  return self
end
return Browser
