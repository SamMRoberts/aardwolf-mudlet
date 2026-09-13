-- One retained inbox, moved between the profile and the shared external host.
local Pane={}
local OWNER,VIEW='AardwolfToolbox.notificationPane','notifications'
local COLORS={info='#B6C9DB',warning='#FFCC66',combat='#FF8899'}
local LABELS={info='Info',warning='Warning',combat='Combat'}
function Pane.new(api,ui,views,bar,notices,openSettings)
  local self={enabled=false,last='Disabled',renderCount=0}
  local root,home,content,header,closeButton,list,empty,pageLabel,previous,nextButton
  local controls,rows,handlers={}, {}, {}
  local options,placement={},nil
  local building,epoch,page,filter=false,0,1,'all'
  local timer,pulseTimer,pulseUntil,phase,indicator=nil,nil,nil,false,nil
  local render,layout,queue
  local function label(name,parent,text,callback)
    local w=api.Geyser.Label:new({name=OWNER..'.'..name,x=0,y=0,width='100%',height=32},parent)
    ui.style(w,callback~=nil);w:echo(ui.escape(text))
    if callback then w:setClickCallback(callback) end
    return w
  end
  local function visible() return self.enabled and not building and views.visible(VIEW) end
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
    for _,row in pairs(rows) do row.widget:delete() end;rows={}
  end
  render=function()
    indicatorUpdate()
    if not visible() then return end
    self.renderCount=self.renderCount+1
    local category=filter~='all' and filter~='unread' and filter or nil
    local entries=notices.list(category,filter=='unread')
    local pages=math.max(1,math.ceil(#entries/20));page=math.min(page,pages)
    local m=ui.metrics();local height=m.line*3+14
    local width=math.max(1,list:get_width()-24);local retained={}
    local owned=epoch
    for i=(page-1)*20+1,math.min(#entries,page*20) do
      local entry=entries[i];local id=entry.id;local row=rows[id]
      if not row then
        row={widget=label('row.'..id,list,'',function()
          if owned==epoch and visible() and notices.get(id) then notices.markRead(id) end
        end)};rows[id]=row
      end
      retained[id]=true
      local color=options.colors and COLORS[entry.category] or '#EEEEEE'
      local title=(entry.read and '' or '● ')..LABELS[entry.category]..' · '..entry.title
      local stamp=api.os.date('%H:%M:%S',math.floor(entry.updated))
      local footer=entry.source..' · '..stamp..(entry.count>1 and ' · ×'..entry.count or '')..(entry.read and ' · Read' or ' · Click to mark read')
      local html='<span style="color:'..color..'">'..ui.escape(ui.fit(title,width))..'</span><br>'..
        ui.escape(ui.fit(entry.message,width))..'<br>'..ui.escape(ui.fit(footer,width))
      local signature=html..'\0'..m.font..m.size
      if signature~=row.signature then
        ui.style(row.widget,true);row.widget:echo(html)
        row.widget:setToolTip(ui.escape(title)..'<br>'..ui.escape(entry.message)..'<br>'..ui.escape(footer));row.signature=signature
      end
      local y=(i-(page-1)*20-1)*height
      if row.y~=y or row.height~=height then row.widget:move(0,y);row.widget:resize('100%',height);row.y=y;row.height=height end
    end
    for id,row in pairs(rows) do if not retained[id] then row.widget:delete();rows[id]=nil end end
    if #entries==0 then empty:show();empty:echo('No notifications in this filter.') else empty:hide() end
    local s=notices.status();local title='Notifications · '..s.unread..' unread'
    if header.text~=title then header:echo(ui.escape(title));header.text=title end
    local pageText=page..' / '..pages
    if pageLabel.text~=pageText then pageLabel:echo(pageText);pageLabel.text=pageText end
    for _,c in ipairs(controls) do
      local selected=c.filter==filter
      if c.selected~=selected then ui.style(c.widget,true,selected);c.selected=selected end
    end
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
    local cw=content:get_width();local y,x=0,0
    for _,c in ipairs(controls) do
      local bw=math.min(cw,math.max(70,ui.measure(c.text)+24))
      if x>0 and x+bw>cw then x=0;y=y+row end
      ui.style(c.widget,true,c.filter==filter);c.widget:move(x,y);c.widget:resize(bw,row);x=x+bw
    end
    y=y+row
    list:move(0,y);list:resize('100%',math.max(row,content:get_height()-y-row))
    for i,b in ipairs({previous,pageLabel,nextButton}) do
      ui.style(b,i~=2);b:move((i-1)*cw/3,math.max(y+row,content:get_height()-row));b:resize(cw/3,row)
    end
    ui.style(empty);empty:resize('100%',row*2)
    if views.mode(VIEW)=='floating' then
      root:hide()
    end
    render()
  end
  function self.close()
    if root then root:hide() end
    if content then content:hide() end
    if timer then api.killTimer(timer);timer=nil end
  end
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
      local function control(id,title,fn,kind) controls[#controls+1]={widget=label(id,content,title,click(fn)),text=title,filter=kind} end
      for _,kind in ipairs({'all','unread','info','warning','combat'}) do
        local key=kind;control(key,LABELS[key] or key:gsub('^%l',string.upper),function() filter=key;page=1;render() end,key)
      end
      control('read','Mark all read',function() notices.markRead() end)
      control('clear','Clear',function() notices.clear() end)
      control('settings','Settings',openSettings)
      control('view','View',function() views.menu(VIEW) end)
      list=api.Geyser.ScrollBox:new({name=OWNER..'.list',x=0,y=64,width='100%',height='100%-96'},content)
      empty=label('empty',list,'No notifications yet.')
      previous=label('previous',content,'‹ Previous',click(function() page=math.max(1,page-1);render() end))
      pageLabel=label('page',content,'1 / 1')
      nextButton=label('next',content,'Next ›',click(function() page=page+1;render() end))
      content:hide();root:hide()
      assert(views.register(VIEW,{root=content,home=home,homeLabel='profile window',placement={feature='notifications',key='placement'},settings=openSettings,
        unread=function() return notices.status().unread end,select=function()
          root:show();content:show();root:raiseAll()
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
