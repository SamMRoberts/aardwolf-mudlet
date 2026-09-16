-- One retained inbox, moved between the profile and the shared external host.
local Pane={}
local OWNER,VIEW='AardwolfToolbox.notificationPane','notifications'
local COLORS={info='#B6C9DB',warning='#FFCC66',combat='#FF8899',chat='#99DDCC'}
local LABELS={info='Info',warning='Warning',combat='Combat',chat='Chat'}
function Pane.new(api,ui,views,bar,notices,openSettings)
  local self={enabled=false,last='Disabled',renderCount=0}
  local root,home,content,body,header,closeButton,list,empty,pageLabel,previous,nextButton,reader,detail
  local controls,rows,handlers={}, {}, {}
  local options,placement={},nil
  local building,epoch,page,filter=false,0,1,'all'
  local entries,pages,pageSize,selected,keyScope={},1,1,nil,nil
  local timer,pulseTimer,pulseUntil,phase,indicator=nil,nil,nil,false,nil
  local render,layout,queue
  local function label(name,parent,text,callback)
    local w=api.Geyser.Label:new({name=OWNER..'.'..name,x=0,y=0,width='100%',height=32},parent)
    ui.style(w,callback~=nil);w:echo(ui.escape(text))
    if callback then w:setClickCallback(callback) end
    return w
  end
  local function visible() return self.enabled and not building and content and not content.hidden and not content.auto_hidden and views.visible(VIEW) end
  local function cancelPulse()
    if pulseTimer then api.killTimer(pulseTimer);pulseTimer=nil end
    pulseUntil=nil;phase=false
  end
  local function indicatorUpdate()
    if not self.enabled then return end
    local s=notices.status();local color=options.colors and COLORS[s.category] or '#EEEEEE'
    if phase then color='#FFFFFF' end
    local signature=s.unread..':'..color
    if signature==indicator then return end;indicator=signature
    bar.updateItem('notifications',{text=tostring(s.unread),compactText=tostring(s.unread),color=color,
      tooltip=s.unread..' unread notifications · Open session inbox',badge=s.unread>0 and '●' or '',badgeColor=color})
  end
  local function pulse()
    pulseTimer=nil
    if not self.enabled or not options.blink or not bar.enabled or notices.status().unread==0 or api.getEpoch()>=pulseUntil then
      cancelPulse();indicatorUpdate();return
    end
    phase=not phase;indicatorUpdate();pulseTimer=api.tempTimer(0.75,pulse)
  end
  local function clearRows()
    for _,row in pairs(rows) do row.widget:delete() end;rows={};entries={};selected=nil
  end
  local function indexOf(id)
    for i,entry in ipairs(entries) do if entry.id==id then return i end end
  end
  local function showDetail()
    local entry=selected and rows[selected] and rows[selected].entry
    local text=entry and (entry.title..'\n'..entry.message..'\n'..LABELS[entry.category]..' · '..entry.source..
      ' · '..api.os.date('%H:%M:%S',math.floor(entry.updated))..' · ×'..entry.count..
      (entry.read and ' · Read' or ' · Unread; Alt+Enter marks read')) or
      'Alt+J/K selects · Alt+H/L pages · Alt+Enter marks read · Shift+Escape closes'
    local m=ui.metrics();local width=math.max(80,reader:get_width()-24)
    local signature=text..'\0'..width..'|'..m.font..m.size
    if detail.signature==signature then return end
    -- Wrap complete literal text, retaining long words through horizontal scrolling.
    local lines={};local widest=width
    for line in (text..'\n'):gmatch('(.-)\n') do
      local current=''
      for word in line:gmatch('%S+') do
        local nextLine=current=='' and word or current..' '..word
        if current~='' and ui.measure(nextLine)>width then lines[#lines+1]=current;current=word
        else current=nextLine end
        local wordWidth=ui.measure(word);widest=math.max(widest,wordWidth)
      end
      lines[#lines+1]=current
    end
    for i,line in ipairs(lines) do lines[i]=ui.escape(line) end
    ui.style(detail);detail:resize(widest+12,math.max(m.height,#lines*m.line+12))
    detail:echo(table.concat(lines,'<br>'));detail.signature=signature
  end
  local function highlight(id)
    if selected==id then return end
    if selected and rows[selected] then ui.style(rows[selected].widget,true,false);rows[selected].selected=false end
    selected=id
    if id and rows[id] then ui.style(rows[id].widget,true,true);rows[id].selected=true end
    showDetail()
  end
  local function markRead(id)
    local row=rows[id];local current=notices.get(id)
    local observed=row and row.entry
    -- A repeat arriving before the queued repaint must not be marked read unseen.
    if not observed or not current or current.session~=observed.session or
        current.count~=observed.count or current.updated~=observed.updated then
      render();return
    end
    notices.markRead(id)
  end
  local function changePage(delta)
    local target=math.max(1,math.min(pages,page+delta))
    if target==page then return end
    page=target;selected=nil;render(true)
  end
  local function selectNext(delta)
    if #entries==0 then return end
    local index=indexOf(selected)
    index=index and index+delta or (delta>0 and (page-1)*pageSize+1 or math.min(#entries,page*pageSize))
    if index<1 or index>#entries then return end
    local id=entries[index].id
    local target=math.floor((index-1)/pageSize)+1
    if target~=page then selected=id;page=target;render(true)
    else highlight(id) end
  end
  render=function(resetPage)
    indicatorUpdate()
    if not visible() then return end
    self.renderCount=self.renderCount+1
    local anchor=not resetPage and page>1 and entries[(page-1)*pageSize+1]
    local category=filter~='all' and filter~='unread' and filter or nil
    entries=notices.list(category,filter=='unread')
    local m=ui.metrics();local height=m.line*3+14
    pageSize=math.max(1,math.min(20,math.floor(list:get_height()/height)))
    pages=math.max(1,math.ceil(#entries/pageSize))
    local index=indexOf(selected)
    if selected and not index then selected=nil end
    index=index or (anchor and indexOf(anchor.id))
    if index then page=math.floor((index-1)/pageSize)+1 end
    page=math.min(page,pages)
    local width=math.max(1,list:get_width()-24);local retained={}
    local owned=epoch
    for i=(page-1)*pageSize+1,math.min(#entries,page*pageSize) do
      local entry=entries[i];local id=entry.id;local row=rows[id]
      if not row then
        row={};rows[id]=row
        row.widget=label('row.'..id,list,'',function(event)
          if type(event)=='table' and event.button and event.button~='LeftButton' then return end
          if owned==epoch and visible() and rows[id]==row then highlight(id);markRead(id) end
        end)
      end
      row.entry=entry;retained[id]=true
      local color=options.colors and COLORS[entry.category] or '#EEEEEE'
      local title=(entry.read and '' or '● ')..LABELS[entry.category]..' · '..entry.title
      local stamp=api.os.date('%H:%M:%S',math.floor(entry.updated))
      local footer=entry.source..' · '..stamp..(entry.count>1 and ' · ×'..entry.count or '')..(entry.read and ' · Read' or ' · Click to mark read')
      local html='<span style="color:'..color..'">'..ui.escape(ui.fit(title,width))..'</span><br>'..
        ui.escape(ui.fit(entry.message,width))..'<br>'..ui.escape(ui.fit(footer,width))
      local signature=html..'\0'..m.font..m.size
      if signature~=row.signature or row.selected~=(id==selected) then
        ui.style(row.widget,true,id==selected);row.selected=id==selected
      end
      if signature~=row.signature then
        row.widget:echo(html)
        row.widget:setToolTip(ui.escape(title)..'<br>'..ui.escape(entry.message)..'<br>'..ui.escape(footer));row.signature=signature
      end
      local y=(i-(page-1)*pageSize-1)*height
      if row.y~=y or row.height~=height then row.widget:move(0,y);row.widget:resize('100%',height);row.y=y;row.height=height end
    end
    for id,row in pairs(rows) do if not retained[id] then row.widget:delete();rows[id]=nil end end
    if #entries==0 then empty:show();empty:echo('No notifications in this filter.') else empty:hide() end
    local status=notices.status();local title='Notifications · '..status.unread..' unread'
    if header.text~=title then header:echo(ui.escape(title));header.text=title end
    local pageText=page..' / '..pages
    if pageLabel.text~=pageText then pageLabel:echo(pageText);pageLabel.text=pageText end
    for _,c in ipairs(controls) do
      local active=c.filter==filter
      if c.selected~=active then ui.style(c.widget,true,active);c.selected=active end
    end
    showDetail()
  end
  queue=function()
    if not self.enabled then return end
    if notices.status().unread==0 then cancelPulse() end
    indicatorUpdate()
    if not visible() or timer then return end
    timer=api.tempTimer(0.05,function() timer=nil;render() end)
  end
  layout=function()
    if not root or building then return end
    local w,h=api.getMainWindowSize();local row=ui.metrics().height
    local width,height=math.min(720,math.max(240,w-32)),math.min(640,math.max(200,h-40))
    root:move(math.max(0,(w-width)/2),math.max(0,(h-height)/2));root:resize(width,height)
    ui.style(header);header:resize('100%-80',row);ui.style(closeButton,true);closeButton:move(width-80,0);closeButton:resize(80,row)
    home:move(0,row);home:resize('100%',height-row)
    body:resize('100%','100%')
    local cw=content:get_width();local y,x=0,0
    for _,c in ipairs(controls) do
      local bw=math.min(cw,math.max(70,ui.measure(c.text)+24))
      if x>0 and x+bw>cw then x=0;y=y+row end
      ui.style(c.widget,true,c.filter==filter);c.widget:move(x,y);c.widget:resize(bw,row);x=x+bw
    end
    y=y+row
    local entryHeight=ui.metrics().line*3+14
    local detailHeight=math.max(row*2,ui.metrics().line*4+12)
    local listHeight=math.max(entryHeight,content:get_height()-y-row-detailHeight)
    list:move(0,y);list:resize('100%',listHeight)
    reader:move(0,y+listHeight+row);reader:resize('100%',detailHeight)
    for i,b in ipairs({previous,pageLabel,nextButton}) do
      ui.style(b,i~=2);b:move((i-1)*cw/3,y+listHeight);b:resize(cw/3,row)
    end
    ui.style(empty);empty:resize('100%',row*2)
    if views.mode(VIEW)=='floating' then
      root:hide()
      if keyScope then keyScope.release();keyScope=nil end
    end
    render()
  end
  function self.close()
    if root then root:hide() end
    if content then content:hide() end
    if timer then api.killTimer(timer);timer=nil end
    if keyScope then keyScope.release();keyScope=nil end
    clearRows()
  end
  function self.isEditing() return visible() end
  function self.open() if not self.enabled then return false,'Notifications disabled' end;return views.open(VIEW) end
  function self.stop()
    self.enabled=false;epoch=epoch+1;self.close();cancelPulse()
    for _,event in ipairs(handlers) do api.deleteNamedEventHandler(OWNER,event) end;handlers={}
    views.unregister(VIEW);bar.unregisterItem('notifications');clearRows()
    if root then root:delete() end
    root,home,content=nil,nil,nil;controls={};indicator=nil;building=false;self.last='Disabled'
  end
  self.destroy=self.stop
  function self.configure(values)
    options=values
    if not values.enabled then self.stop();return true end
    if not notices.enabled then self.stop();return false,notices.last end
    if not options.blink then cancelPulse() end
    if self.enabled then
      local before=placement;placement=values.placement
      local ok,why=views.configure()
      if ok and placement=='tabbed' and before=='floating' then self.open() end
      indicator=nil;layout();return ok,why
    end
    local ok,why=pcall(function()
      building=true;epoch=epoch+1;local owned=epoch;placement=values.placement
      root=api.Geyser.Container:new({name=OWNER,x=20,y=40,width=720,height=640})
      local bg=label('background',root,'');bg:resize('100%','100%');bg:setStyleSheet('QLabel { background: #151c23; border: 1px solid #83bde8; }')
      local function click(fn) return function() if self.enabled and owned==epoch and visible() then fn() end end end
      header=label('title',root,'Notifications');closeButton=label('close',root,'Close',click(self.close))
      home=api.Geyser.Container:new({name=OWNER..'.home',x=0,y=32,width='100%',height='100%-32'},root)
      content=api.Geyser.Container:new({name=OWNER..'.content',x=0,y=0,width='100%',height='100%'},home)
      body=api.Geyser.ScrollBox:new({name=OWNER..'.body',x=0,y=0,width='100%',height='100%'},content)
      local function control(id,title,fn,kind) controls[#controls+1]={widget=label(id,body,title,click(fn)),text=title,filter=kind} end
      for _,kind in ipairs({'all','unread','info','warning','combat','chat'}) do
        local key=kind;control(key,LABELS[key] or key:gsub('^%l',string.upper),function() filter=key;page=1;selected=nil;render(true) end,key)
      end
      control('read','Mark all read',function() notices.markRead() end)
      control('clear','Clear',function() notices.clear() end)
      control('settings','Settings',openSettings)
      control('view','View',function() views.menu(VIEW) end)
      list=api.Geyser.ScrollBox:new({name=OWNER..'.list',x=0,y=64,width='100%',height='100%-96'},body)
      empty=label('empty',list,'No notifications yet.')
      reader=api.Geyser.ScrollBox:new({name=OWNER..'.reader',x=0,y=0,width='100%',height=100},body)
      detail=label('detail',reader,'')
      previous=label('previous',body,'‹ Previous',click(function() changePage(-1) end))
      pageLabel=label('page',body,'1 / 1')
      nextButton=label('next',body,'Next ›',click(function() changePage(1) end))
      content:hide();root:hide()
      assert(views.register(VIEW,{root=content,home=home,homeLabel='profile window',placement={feature='notifications',key='placement'},settings=openSettings,
        unread=function() return notices.status().unread end,select=function()
          root:show();content:show();root:raiseAll()
          if views.mode(VIEW)=='tabbed' and not keyScope and api.tempKey and api.mudlet and api.mudlet.key then
            local function current() return visible() and views.mode(VIEW)=='tabbed' end
            keyScope=assert(ui.menuKeys.push(OWNER,{close=function() if current() then self.close() end end,
              next=function() if current() then selectNext(1) end end,
              previous=function() if current() then selectNext(-1) end end,
              pageNext=function() if current() then changePage(1) end end,
              pagePrevious=function() if current() then changePage(-1) end end,
              activate=function() if current() and selected then markRead(selected) end end}))
          end
          if keyScope then keyScope.raise() end
          layout()
        end}))
      bar.registerItem({id='notifications',label='Notices',order=94,overflowPriority=10,callback=self.open})
      local function on(event,fn)
        handlers[#handlers+1]=event
        assert(api.registerNamedEventHandler(OWNER,event,event,function(...)
          if self.enabled and epoch==owned and not building then fn(...) end
        end))
      end
      on('AardwolfToolbox.notifications.updated',function(_,id,alert)
        if alert and options.blink and bar.enabled and not pulseTimer then pulseUntil=api.getEpoch()+6;pulse() end
        queue()
      end)
      for _,event in ipairs({'sysWindowResizeEvent','sysUserWindowResizeEvent','AardwolfToolbox.ui.changed','AardwolfToolbox.views.changed'}) do on(event,layout) end
      self.enabled=true;building=false;layout();self.last='Notification view ready'
    end)
    if not ok then self.stop();self.last=tostring(why);return false,self.last end
    return true
  end
  return self
end
return Pane
