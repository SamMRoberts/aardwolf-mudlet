-- Paged on-demand disk reads; closed views do no history queries.
local Pane={}
local OWNER,VIEW='AardwolfToolbox.historyPane','history'
local CATEGORIES={progression='Progression',quests='Quest rewards',kills='Kills'}
local REWARDS={{'totqp','Total QP'},{'gold','Gold'},{'pracs','Practices'},{'trains','Trains'},{'tp','TP'},{'qp','Base QP'},{'tierqp','Tier QP'},{'hardcore','Hardcore'},{'opk','OPK'},{'lucky','Lucky'},{'double','Double'},{'daily','Daily'}}
local LABELS={level='Level',tier='Tier',remorts='Remorts',redos='Redos',pups='Powerups',totpups='Total powerups'}
function Pane.new(api,ui,views,history,openSettings)
  local self={enabled=false,last='Disabled'}
  local root,home,content,toolbar,list,title,closeButton,feedback,previous,nextButton,pageLabel
  local rows,controls,handlers={},{},{}
  local selected,page,result,confirm=nil,1,nil,nil
  local category='progression'
  local building,epoch,timer=false,0,nil
  local layout,render
  local function visible() return self.enabled and not building and views.visible(VIEW) end
  local function say(text) feedback:echo(ui.escape(ui.fit(text,math.max(1,content:get_width()-16))));feedback:setToolTip(ui.escape(text)) end
  local function clearRows() for _,w in pairs(rows) do w:delete() end;rows={} end
  local function label(id,parent,text,fn)
    local w=api.Geyser.Label:new({name=OWNER..'.'..id,x=0,y=0,width='100%',height=32},parent)
    ui.style(w,fn~=nil);w:echo(ui.escape(text))
    if fn then local owned=epoch;w:setClickCallback(function() if epoch==owned and visible() then fn() end end) end
    return w
  end
  render=function(read)
    if not visible() then return end
    if read or not result then
      local why;result,why=history.list(selected,page,category)
      if not result then clearRows();say(why);return end
      page,selected=result.page,result.character
    end
    confirm=nil
    local retained={}
    for _,c in ipairs(controls) do
      if c.id=='clear' then c.widget:echo('Clear…') end
      if CATEGORIES[c.id] then ui.style(c.widget,true,c.id==category) end
    end
    local rowHeight=ui.metrics().line*3+12
    for i,entry in ipairs(result.rows) do
      local changes={}
      for _,change in ipairs(entry.changes or {}) do
        changes[#changes+1]=(LABELS[change.field] or change.field)..' '..tostring(change.before or '--')..' → '..tostring(change.after)
      end
      local summary=table.concat(changes,' · ')
      local stamp=api.os.date('%Y-%m-%d %H:%M:%S',entry.observed)
      local text=stamp..' · '..(entry.kind=='snapshot' and 'Observed state' or 'Changed observation')
      local detail,tooltip='',''
      if category=='kills' then
        text=stamp..' · Death observed'
        summary=entry.name
        detail=(entry.room.name or 'Room #'..entry.room.num)..' · '..(entry.room.area or 'Area unavailable')
        tooltip='Room #'..entry.room.num..' · '..entry.flags..' · Kill credit unknown'
          ..(entry.uncertain and ' · Duplicate identity uncertain' or ' · Identity is a local observation')
      elseif category=='quests' then
        changes={}
        for _,field in ipairs(REWARDS) do
          if entry.rewards[field[1]]~=nil then changes[#changes+1]=field[2]..' '..tostring(entry.rewards[field[1]]) end
        end
        summary=#changes>0 and table.concat(changes,' · ') or 'Rewards unavailable'
        text=stamp..' · Quest completed'..(entry.completed and ' · Count '..entry.completed or '')
        detail=(entry.quest.target or 'Target unavailable')..' · '..(entry.quest.area or 'Area unavailable')
        tooltip=detail..' · '..(entry.quest.room or 'Room unavailable')
      end
      local id=tostring(entry.id);local w=rows[id]
      if not w then w=label('row.'..id,list,'');rows[id]=w end;retained[id]=true
      local y=(i-1)*rowHeight
      if w.historyY~=y or w.historyHeight~=rowHeight then w:move(0,y);w:resize('100%',rowHeight);w.historyY=y;w.historyHeight=rowHeight end
      local width=math.max(1,list:get_width()-24)
      local html=ui.escape(ui.fit(text,width))..'<br><span style="color:#A8D7E8">'..ui.escape(ui.fit(summary,width))..'</span>'
      if detail~='' then html=html..'<br>'..ui.escape(ui.fit(detail,width)) end
      local signature=html..ui.metrics().font..ui.metrics().size
      if w.historyText~=signature then ui.style(w);w:echo(html);w:setToolTip(ui.escape(text)..'<br>'..ui.escape(summary)..(tooltip~='' and '<br>'..ui.escape(tooltip) or ''));w.historyText=signature end
    end
    if #result.rows==0 then
      if not rows.empty then rows.empty=label('empty',list,'No saved '..CATEGORIES[category]:lower()..' observations.') end;retained.empty=true
    end
    for id,w in pairs(rows) do if not retained[id] then w:delete();rows[id]=nil end end
    local heading=CATEGORIES[category]..' history · '..(selected or 'No character')
    title:echo(ui.escape(ui.fit(heading,math.max(1,title:get_width()))));title:setToolTip(ui.escape(heading))
    pageLabel:echo(page..' / '..result.pages)
    local status=history.status()
    say((selected or 'No saved character')..' · '..result.total..' observations · '..status.last)
  end
  local function character(step)
    if not result or #result.characters==0 then return end
    local index=1;for i,v in ipairs(result.characters) do if v.character==selected then index=i;break end end
    selected=result.characters[(index-1+step)%#result.characters+1].character;page=1;render(true)
  end
  layout=function()
    if not root or building then return end
    local w,h=api.getMainWindowSize();local row=ui.metrics().height
    local width,height=math.min(760,math.max(240,w-32)),math.min(640,math.max(220,h-40))
    root:move(math.max(0,(w-width)/2),math.max(0,(h-height)/2));root:resize(width,height)
    ui.style(title);title:resize('100%-80',row);ui.style(closeButton,true);closeButton:move(width-80,0);closeButton:resize(80,row)
    home:move(0,row);home:resize('100%',height-row)
    local cw=content:get_width();local x,y=0,0
    for _,c in ipairs(controls) do
      local bw=math.min(cw,math.max(80,ui.measure(c.id=='clear' and 'Confirm clear' or c.text)+24))
      if x>0 and x+bw>cw then x=0;y=y+row end
      ui.style(c.widget,true);c.widget:move(x,y);c.widget:resize(bw,row);x=x+bw
    end
    local toolbarHeight=math.max(row,math.min(y+row,content:get_height()-5*row))
    toolbar:move(0,0);toolbar:resize('100%',toolbarHeight)
    y=toolbarHeight;ui.style(feedback);feedback:move(0,y);feedback:resize('100%',row*2);y=y+row*2
    list:move(0,y);list:resize('100%',math.max(row,content:get_height()-y-row))
    for i,b in ipairs({previous,pageLabel,nextButton}) do ui.style(b,i~=2);b:move((i-1)*cw/3,math.max(y+row,content:get_height()-row));b:resize(cw/3,row) end
    if views.mode(VIEW)=='floating' then root:hide() end
    render(false)
  end
  function self.close()
    if root then root:hide();content:hide() end
    if timer then api.killTimer(timer);timer=nil end
    clearRows();result=nil;confirm=nil
  end
  local function choose(value)
    if not CATEGORIES[value] then return nil,'Unknown history category' end
    if category~=value then category=value;selected=nil;page=1;result=nil;confirm=nil;clearRows() end
    return true
  end
  function self.open(value)
    if not self.enabled then return nil,'History view unavailable' end
    if value then local ok,why=choose(value);if not ok then return nil,why end end
    return views.open(VIEW)
  end
  function self.stop()
    self.enabled=false;epoch=epoch+1;self.close()
    for _,id in ipairs(handlers) do api.deleteNamedEventHandler(OWNER,id) end;handlers={}
    views.unregister(VIEW);if root then root:delete() end
    root,home,content=nil,nil,nil;controls={};self.last='Stopped'
  end
  self.destroy=self.stop
  function self.configure()
    if self.enabled then result=nil;local ok,why=views.configure();layout();return ok,why end
    local ok,why=pcall(function()
      building=true;epoch=epoch+1;local owned=epoch
      root=api.Geyser.Container:new({name=OWNER,x=20,y=40,width=760,height=640})
      local bg=label('background',root,'');bg:resize('100%','100%');bg:setStyleSheet('QLabel { background: #151c23; border: 1px solid #83bde8; }')
      title=label('title',root,'Local history');closeButton=label('close',root,'Close',self.close)
      home=api.Geyser.Container:new({name=OWNER..'.home',x=0,y=32,width='100%',height='100%-32'},root)
      content=api.Geyser.Container:new({name=OWNER..'.content',x=0,y=0,width='100%',height='100%'},home)
      toolbar=api.Geyser.ScrollBox:new({name=OWNER..'.toolbar',x=0,y=0,width='100%',height=64},content)
      local function button(id,text,fn) controls[#controls+1]={id=id,text=text,widget=label(id,toolbar,text,fn)} end
      for _,id in ipairs({'progression','quests','kills'}) do local value=id;button(value,CATEGORIES[value],function() choose(value);render(true) end) end
      button('characterPrevious','‹ Character',function() character(-1) end)
      button('characterNext','Character ›',function() character(1) end)
      button('refresh','Refresh',function() render(true) end)
      button('export','Export JSON',function()
        if not selected then say('Select a saved character first');return end
        local path,err=history.export(selected,category);say(path and 'Exported: '..path or err)
      end)
      button('clear','Clear…',function()
        if not selected then say('Select a saved character first');return end
        if confirm and confirm.character==selected and confirm.category==category and confirm.revision==history.revision then
          local done,err=history.clear(selected,confirm.revision,category);confirm=nil;render(true);if not done then say(err) end
        else
          confirm={category=category,character=selected,revision=history.revision}
          for _,c in ipairs(controls) do if c.id=='clear' then c.widget:echo('Confirm clear') end end
          say('Clear saved '..CATEGORIES[category]:lower()..' for '..selected..'? Click Confirm clear again; Refresh cancels.')
        end
      end)
      button('settings','Settings',openSettings);button('view','View',function() views.menu(VIEW) end)
      feedback=label('feedback',content,'Recording is off by default. Enable in Local history settings.')
      list=api.Geyser.ScrollBox:new({name=OWNER..'.list',x=0,y=96,width='100%',height='100%-128'},content)
      previous=label('previous',content,'‹ Previous',function() page=math.max(1,page-1);render(true) end)
      pageLabel=label('page',content,'1 / 1');nextButton=label('next',content,'Next ›',function() page=page+1;render(true) end)
      root:hide();content:hide()
      assert(views.register(VIEW,{root=content,home=home,homeLabel='profile window',placement={feature='history',key='placement'},settings=openSettings,
        select=function() root:show();content:show();root:raiseAll();result=nil;layout() end}))
      local function on(id,event,fn)
        handlers[#handlers+1]=id
        assert(api.registerNamedEventHandler(OWNER,id,event,function(...) if self.enabled and owned==epoch and not building then fn(...) end end))
      end
      on('data','AardwolfToolbox.history.updated',function()
        result=nil;confirm=nil
        if visible() and not timer then timer=api.tempTimer(0.05,function() timer=nil;render(true) end) end
      end)
      for _,event in ipairs({'sysWindowResizeEvent','sysUserWindowResizeEvent','AardwolfToolbox.ui.changed','AardwolfToolbox.views.changed'}) do on(event,event,layout) end
      self.enabled=true;building=false;layout();self.last='History view ready'
    end)
    if not ok then self.stop();self.last=tostring(why);return nil,self.last end
    return true
  end
  return self
end
return Pane
