local Pane={}
local OWNER,VIEW='AardwolfToolbox.mapWorkspacePane','atlas'
function Pane.new(api,config,ui,views,map,openSettings)
  local self={enabled=false,last='Disabled'}
  local root,home,content,body,search,list,details,detail,labelInput,noteInput,feedback
  local rows,controls,handlers={}, {}, {}
  local title,closeButton,previous,pageLabel,nextButton,saveButton,removeButton
  local building,epoch,revision=false,0,0
  local page,pages,query,mode=1,1,'','rooms'
  local selected,source,editRevision,escapeKey
  local placement
  local render,layout,choose
  local function say(message) if feedback then feedback:echo(ui.escape(message or 'Unavailable')) end end
  local function label(name,parent,text,callback)
    local w=api.Geyser.Label:new({name=OWNER..'.'..name,x=0,y=0,width='100%',height=32},parent)
    ui.style(w,callback~=nil);w:echo(ui.escape(text))
    if callback then w:setClickCallback(callback) end
    return w
  end
  local function clearRows()
    revision=revision+1
    for _,r in ipairs(rows) do r:delete() end;rows={}
  end
  local function showText(lines)
    local width=math.max(80,details:get_width()-20);local output={}
    for _,line in ipairs(lines) do
      local current=''
      for word in tostring(line):gmatch('%S+') do
        local nextLine=current=='' and word or current..' '..word
        if current~='' and ui.measure(nextLine)>width then output[#output+1]=ui.escape(current);current=word else current=nextLine end
      end
      output[#output+1]=ui.escape(current)
    end
    ui.style(detail);detail:resize('100%',math.max(32,#output*ui.metrics().line+12));detail:echo(table.concat(output,'<br>'))
  end
  -- Keep all editor text local. Saving reads the native editor, not its last Enter event.
  choose=function(id,identity)
    local r,why=map.get(id)
    if not r or (identity and r.identity~=identity) then say(why or 'Room identity changed; search again');return end
    selected=r;editRevision=config.revision
    local saved
    for _,b in ipairs(config.get('map_workspace','bookmarks')) do if b.room==id and b.identity==r.identity then saved=b;break end end
    labelInput:print(saved and saved.label or (r.name~='' and r.name:sub(1,160) or 'Room '..id))
    noteInput:print(saved and saved.note or '')
    local lines={r.name~='' and r.name or 'Unexplored room',
      'Room '..id..' · '..(r.zone or 'Unknown area')..' · Coordinates '..tostring(r.x)..', '..tostring(r.y)..', '..tostring(r.z),
      r.verified and ('Verified game ID '..r.gameId..' · '..(r.discovery=='unexplored' and 'Provisional destination' or 'Observed room')) or 'Unverified / foreign map identity'}
    local exits={};for dir,to in pairs(r.exits) do exits[#exits+1]=dir..' → '..to end
    for command,to in pairs(r.special) do exits[#exits+1]=command..' → '..to..' (special)' end
    table.sort(exits);lines[#lines+1]=#exits>0 and table.concat(exits,' · ') or 'No saved exits'
    if saved and saved.note~='' then lines[#lines+1]='Note: '..saved.note end
    showText(lines);say('Selected #'..id..' · Local inspection; no movement')
  end
  local function bookmarks()
    local records,why=map.bookmarks();if not records then return nil,why end
    local matches={}
    for _,b in ipairs(records) do if (b.label..' '..b.note..' '..b.room):lower():find(query:lower(),1,true) then matches[#matches+1]=b end end
    return matches
  end
  render=function()
    if not self.enabled or building or not views.visible(VIEW) then return end
    clearRows();local token=revision;local items,total={},0
    if mode=='bookmarks' then
      local matches,why=bookmarks();if not matches then say(why);return end
      total=#matches;pages=math.max(1,math.ceil(total/24));page=math.min(page,pages)
      for i=(page-1)*24+1,math.min(total,page*24) do
        local b=matches[i];items[#items+1]={id=b.room,identity=b.identity,name=b.label,subtitle=b.available and ('#'..b.room..' · '..b.note) or ('#'..b.room..' · Missing or changed identity'),available=b.available}
      end
    else
      local result,why=map.search(query,mode,page);if not result then say(why);return end
      if page>result.pages then page=result.pages;return render() end
      total=result.total;pages=result.pages
      for _,r in ipairs(result.rows) do items[#items+1]={id=r.id,identity=r.identity,name=r.name~='' and r.name or 'Unexplored',subtitle='#'..r.id..' · '..(r.zone or 'Unknown area'),available=true} end
    end
    local height=ui.metrics().line*2+12
    for i,item in ipairs(items) do
      local w=label('row.'..i,list,'',function()
        if token==revision and self.enabled and views.visible(VIEW) then
          if item.available then choose(item.id,item.identity) else say('Bookmark identity changed or room missing; review it in Settings') end
        end
      end)
      rows[#rows+1]=w;w:move(0,(i-1)*height);w:resize('100%',height)
      w:echo(ui.escape(ui.fit(item.name,math.max(1,list:get_width()-24)))..'<br>'..ui.escape(ui.fit(item.subtitle,math.max(1,list:get_width()-24))))
      w:setToolTip(ui.escape(item.name)..'<br>'..ui.escape(item.subtitle))
    end
    for _,c in ipairs(controls) do ui.style(c.widget,true,c.mode==mode) end
    pageLabel:echo(page..' / '..pages);say(total..' matching rooms · '..mode..' · Enter searches locally')
  end
  local function preview()
    if not selected then say('Select a destination first');return end
    local from,why=source,nil
    if not from then from,why=map.current() end
    if not from then say(why);return end
    local result,err=map.preview(from.id,selected.id,from.identity,selected.identity)
    if not result then say(err);return end
    local lines={'Route #'..from.id..' → #'..selected.id..' · '..#result.steps..' steps · Cost '..tostring(result.cost or '?'),
      'Preview only. Saved topology may be incomplete. Doors and special exits need manual review.'}
    for i,step in ipairs(result.steps) do
      lines[#lines+1]=i..'. '..step.direction..' → #'..step.to..(step.special and ' · Special exit' or '')..(step.unexplored and ' · Unexplored' or '')..(not step.verified and ' · Unverified identity' or '')
    end
    showText(lines);say(source and ('Start: selected room #'..source.id) or ('Start: fresh GMCP room #'..from.id))
  end
  local function save(remove)
    if not selected then say('Select a room first');return end
    local ok,why=map.save(selected.id,selected.identity,labelInput:getText(),noteInput:getText(),editRevision,remove)
    if not ok then say(why);return end
    editRevision=config.revision;render();say(remove and 'Bookmark removed; native map unchanged' or 'Bookmark and note saved')
  end
  layout=function()
    if not root or building then return end
    local w,h=api.getMainWindowSize();local row=ui.metrics().height
    local width,height=math.min(800,math.max(260,w-32)),math.min(760,math.max(240,h-40))
    root:move(math.max(0,(w-width)/2),math.max(0,(h-height)/2));root:resize(width,height)
    ui.style(title);title:resize('100%-96',row);ui.style(closeButton,true);closeButton:move(width-96,0);closeButton:resize(96,row)
    home:move(0,row);home:resize('100%',height-row)
    local cw=content:get_width();body:resize('100%','100%')
    local y=4;ui.apply(search);search:move(4,y);search:resize('100%-8',row);y=y+row
    local widest=0;for _,c in ipairs(controls) do widest=math.max(widest,ui.measure(c.label)+20) end
    local cols=math.max(1,math.min(4,math.floor(cw/math.max(1,widest))))
    for i,c in ipairs(controls) do
      ui.style(c.widget,true,c.mode==mode);c.widget:move((i-1)%cols*cw/cols,y+math.floor((i-1)/cols)*row);c.widget:resize(cw/cols,row)
    end
    y=y+math.ceil(#controls/cols)*row
    list:move(4,y);list:resize('100%-8',row*5);y=y+row*5
    for i,b in ipairs({previous,pageLabel,nextButton}) do ui.style(b,i~=2);b:move((i-1)*cw/3,y);b:resize(cw/3,row) end;y=y+row
    details:move(4,y);details:resize('100%-8',row*5);y=y+row*5
    for _,input in ipairs({labelInput,noteInput}) do ui.apply(input);input:move(4,y);input:resize('100%-8',row);y=y+row end
    for i,b in ipairs({saveButton,removeButton}) do ui.style(b,true);b:move((i-1)*cw/2,y);b:resize(cw/2,row) end;y=y+row
    ui.style(feedback);feedback:move(4,y);feedback:resize('100%-8',row*2)
    if views.mode(VIEW)=='floating' then
      root:hide()
      if escapeKey then api.killKey(escapeKey);escapeKey=nil end
    end
    render()
  end
  function self.close()
    clearRows()
    if root then root:hide() end
    if content then content:hide() end
    if escapeKey then api.killKey(escapeKey);escapeKey=nil end
  end
  function self.isEditing() return self.enabled and not building and views.visible(VIEW) end
  function self.open() if not self.enabled then return false,'Map workspace disabled' end;return views.open(VIEW) end
  function self.stop()
    self.enabled=false;epoch=epoch+1;self.close()
    for _,event in ipairs(handlers) do api.deleteNamedEventHandler(OWNER,event) end;handlers={}
    views.unregister(VIEW)
    if root then root:delete() end
    root,content,home=nil,nil,nil;selected,source=nil,nil;controls={};building=false;self.last='Disabled'
  end
  self.destroy=self.stop
  function self.configure(values)
    if not values.enabled then self.stop();return true end
    if not map.enabled then self.stop();return false,map.last end
    if self.enabled then
      local previousPlacement=placement;placement=values.placement
      local ok,why=views.configure()
      if ok and placement=='tabbed' and previousPlacement=='floating' then self.open() end
      layout();return ok,why
    end
    local ok,why=pcall(function()
      building=true;placement=values.placement;epoch=epoch+1;local owned=epoch
      root=api.Geyser.Container:new({name=OWNER,x=20,y=40,width=800,height=720})
      local bg=label('background',root,'');bg:resize('100%','100%');bg:setStyleSheet('QLabel { background: #151c23; border: 1px solid #83bde8; }')
      local function click(fn) return function() if self.enabled and epoch==owned and self.isEditing() then fn() end end end
      title=label('title',root,'Local map workspace')
      closeButton=label('close',root,'Close',click(self.close))
      home=api.Geyser.Container:new({name=OWNER..'.home',x=0,y=32,width='100%',height='100%-32'},root)
      content=api.Geyser.Container:new({name=OWNER..'.content',x=0,y=0,width='100%',height='100%'},home)
      body=api.Geyser.ScrollBox:new({name=OWNER..'.body',x=0,y=0,width='100%',height='100%'},content)
      local function input(name,initial,action)
        local w=api.Geyser.CommandLine:new({name=OWNER..'.'..name,x=0,y=0,width='100%',height=32},body)
        ui.apply(w);w:print(initial);w:setAction(click(action));return w
      end
      search=input('search','',function()
        local value=search:getText()
        if #value>256 or value:find('[%z\1-\31\127]') then say('Search up to 256 single-line characters');return end
        query=value;page=1;render()
      end)
      local function control(id,text,fn,selectedMode)
        controls[#controls+1]={widget=label(id,body,text,click(fn)),label=text,mode=selectedMode}
      end
      for _,kind in ipairs({'rooms','areas','bookmarks'}) do
        local key=kind;control(kind,kind:gsub('^%l',string.upper),function() mode=key;page=1;render() end,kind)
      end
      control('health','Map health',function()
        local report,err=map.health();if not report then say(err);return end
        local lines={report.rooms..' rooms · '..report.owned..' Toolbox-owned · '..report.unexplored..' unexplored',report.issueCount..' observations for review; no repairs performed'}
        for _,issue in ipairs(report.issues) do lines[#lines+1]='#'..issue.id..' · '..issue.kind..': '..issue.detail end
        if report.truncated then lines[#lines+1]='First 200 observations shown. Public health API includes category counts.' end
        showText(lines);say('Read-only snapshot; coordinate overlaps may be intentional')
      end)
      control('start','Set route start',function() if selected then source=selected;say('Route start set to #'..source.id..'; select a destination') else say('Select a start room first') end end)
      control('preview','Preview route',preview)
      control('current','Use current room',function() source=nil;local r,err=map.current();say(r and ('Route start follows fresh room #'..r.id) or err) end)
      control('view','View / Settings',function() views.menu(VIEW) end)
      list=api.Geyser.ScrollBox:new({name=OWNER..'.list',x=0,y=0,width='100%',height=200},body)
      details=api.Geyser.ScrollBox:new({name=OWNER..'.details',x=0,y=0,width='100%',height=200},body)
      detail=label('detail',details,'Select a room. Search Rooms by name/ID or Areas by zone/area ID.')
      labelInput=input('bookmarkLabel','Bookmark label',function() say('Edit the bookmark label and note, then choose Save bookmark') end)
      noteInput=input('note','',function() say('Note held locally; choose Save bookmark to persist it') end)
      saveButton=label('save',body,'Save bookmark',click(function() save(false) end))
      removeButton=label('remove',body,'Remove bookmark',click(function() save(true) end))
      feedback=label('feedback',body,'Local map data only')
      previous=label('previous',body,'‹ Previous',click(function() page=math.max(1,page-1);render() end))
      pageLabel=label('page',body,'1 / 1')
      nextButton=label('next',body,'Next ›',click(function() page=math.min(pages,page+1);render() end))
      content:hide();root:hide()
      assert(views.register(VIEW,{root=content,home=home,homeLabel='workspace',placement={feature='map_workspace',key='placement'},settings=openSettings,select=function()
        root:show();content:show();root:raiseAll()
        if not escapeKey and api.tempKey and api.mudlet and api.mudlet.key then escapeKey=api.tempKey(api.mudlet.key.Escape,self.close) end
        layout()
      end}))
      for _,event in ipairs({'sysWindowResizeEvent','sysUserWindowResizeEvent','AardwolfToolbox.ui.changed','AardwolfToolbox.views.changed','sysDisconnectionEvent','AardwolfToolbox.gmcp.cleared'}) do
        handlers[#handlers+1]=event
        assert(api.registerNamedEventHandler(OWNER,event,event,function()
          if owned~=epoch or building then return end
          if event=='sysDisconnectionEvent' or event=='AardwolfToolbox.gmcp.cleared' then source=nil;return end
          layout()
        end))
      end
      building=false;self.enabled=true;layout();self.last='Map workspace ready'
    end)
    if not ok then self.stop();self.last=tostring(why);return false,self.last end
    return true
  end
  return self
end
return Pane
