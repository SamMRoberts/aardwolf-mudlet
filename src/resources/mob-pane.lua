-- Dedicated roster: stable scan order, separate selection and combat evidence.
local Pane={}
local OWNER='AardwolfToolbox.mobs'
local scanColors={North='#80dfff',South='#9fe3a8',East='#ffda85',West='#d4b0ff',Up='#9bbcff',Down='#ffad99'}
function Pane.new(api,ui,borders,refresh,settings,selectMob,clearSelection,refreshNearby,rateRoom,actions)
  local self={}; local root,body,heading,button,optionsButton,summary,hint,clearButton
  local scanHeading,scanBody,scanRefresh,rateButton; local scanLabels={}; local scanExpanded=false
  local labels={}; local cardSerial=0; local options={}; local latest={rows={}}
  local menu,menuToken; local menuKeys={};local menuGeneration=0
  local message='Waiting for room data'; local phase=false; local generation=0
  local function label(name,parent)
    return api.Geyser.Label:new({name=OWNER..'.'..name,x=0,y=0,width=1,height=1},parent)
  end
  local fonts={}
  local function geometry(widget,x,y,w,h)
    if widget.px~=x or widget.py~=y then widget:move(x,y); widget.px=x; widget.py=y end
    if widget.pw~=w or widget.ph~=h then widget:resize(w,h); widget.pw=w; widget.ph=h end
  end
  local function visible(widget,show)
    if widget.shown==show then return end
    if show then widget:show() else widget:hide() end; widget.shown=show
  end
  local function tip(widget,text)
    if widget.tip~=text then widget:setToolTip(text); widget.tip=text end
  end
  local function paint(widget,text,color,role,css)
    local m=fonts[role or 'ui']; local font=m.font..'|'..m.size
    if widget.fontKey~=font then ui.apply(widget,role); widget.fontKey=font; widget.html=nil end
    local style=css or 'QLabel { background: transparent; color: '..color..'; padding: 4px; qproperty-wordWrap: true; }'
    if widget.css~=style then widget:setStyleSheet(style); widget.css=style end
    -- Explicit foreground also survives Geyser's inline rich-text formatting.
    local html='<span style="color:'..color..'">'..text..'</span>'
    if widget.html~=html then widget:echo(html); widget.html=html end
  end
  local function control(widget,text,selected)
    paint(widget,text,'#e0eaf3',nil,'QLabel { background: '..(selected and '#263c4d' or '#192732')..'; border: 1px solid #304555; border-radius: 4px; padding: 4px; } QLabel:hover { background: #304b60; border-color: #80b8dc; }')
  end
  function self.closeMenu()
    menuGeneration=menuGeneration+1
    for _,id in ipairs(menuKeys) do api.killKey(id) end;menuKeys={}
    local opened=menu~=nil
    if menu then menu:delete();menu=nil end
    menuToken=nil
    if opened and actions then actions.visibility(false) end
  end
  function self.validateMenu()
    if menu and not actions.resolve(menuToken) then self.closeMenu() end
  end
  local function openMenu(token,card)
    self.closeMenu()
    if not actions or not options.context_menu then return end
    local content,reason=actions.menu(token)
    if not content then actions.feedback(reason);return end
    local ok,err=pcall(function()
      local w,h=api.getMainWindowSize();local metrics=ui.metrics()
      local ch=math.max(32,metrics.height);local width=math.min(360,w)
      local header=content.name..' · '..content.target
      local hh=math.max(ch,math.ceil(ui.measure(header)/math.max(1,width-20))*metrics.line+12)
      local height=math.min(h,math.max(ch*3,math.min(h*0.7,hh+(#content.items+2)*(ch+4)+12)))
      -- ScrollBox child coordinates omit its viewport offset. Anchor at the
      -- actual click position so scrolling the roster cannot misplace the menu.
      local mx,my
      if api.getMousePosition then mx,my=api.getMousePosition() end
      local x=math.max(0,math.min(w-width,mx or root:get_x()+root:get_width()))
      local y=math.max(0,math.min(h-height,my or root:get_y()))
      menu=api.Geyser.ScrollBox:new({name=OWNER..'.menu',x=x,y=y,width=width,height=height})
      menuToken=token;local epoch=menuGeneration;local buttons={}
      local title=label('menuTitle',menu);ui.apply(title);title:move(4,4);title:resize(width-12,hh)
      title:setStyleSheet('QLabel { background:#0e1720; color:#edf3fa; border:1px solid #607c90; padding:5px; qproperty-wordWrap:true; }')
      title:echo(ui.escape(header));local top=hh+8
      local function style()
        for _,item in ipairs(buttons) do
          item.widget:setStyleSheet('QLabel { background:#192732; color:#edf3fa; border:1px solid #415366; padding:4px; qproperty-wordWrap:true; } QLabel:hover, QLabel:focus { background:#304b60; border-color:#a4d8ff; }')
        end
      end
      local function add(text,tooltip,fn)
        local widget=label('menuItem'..(#buttons+1),menu);ui.apply(widget)
        local rowHeight=math.max(ch,math.ceil(ui.measure(text)/math.max(1,width-28))*metrics.line+10)
        widget:move(4,top);widget:resize(width-12,rowHeight);top=top+rowHeight+4
        widget:echo(ui.escape(text));widget:setToolTip(ui.escape(tooltip))
        local item={widget=widget,run=function()
          if not menu or epoch~=menuGeneration then return end
          self.closeMenu();fn()
        end};buttons[#buttons+1]=item
        widget:setClickCallback(function(event)
          if type(event)=='table' and event.button and event.button~='LeftButton' then return end
          item.run()
        end)
      end
      for _,item in ipairs(content.items) do
        local id=item.id
        add(item.label,item.mode..': '..item.command,function() actions.activate(id,token) end)
      end
      add('Configure actions','Edit Room mob actions',settings)
      add('Close','Close this menu',function() end)
      local function bind(key,fn)
        local code=assert(api.mudlet and api.mudlet.key[key],'Menu key unavailable: '..key)
        local id=api.tempKey(0,code,function() if menu and epoch==menuGeneration then fn() end end)
        assert(id and id~=-1,'Cannot register menu key');menuKeys[#menuKeys+1]=id
      end
      bind('Escape',self.closeMenu)
      style();menu:show();menu:raiseAll();actions.visibility(true)
    end)
    if not ok then self.closeMenu();actions.feedback('Mob menu unavailable: '..tostring(err)) end
  end
  local function render()
    if not root then return end
    local width=math.max(1,root:get_width()); local m=ui.metrics(); local small=ui.metrics('secondary'); local h=m.height
    fonts={ui=m,secondary=small}
    local present,killed,attacking=0,0,0; local selected
    for _,r in ipairs(latest.rows) do
      present=present+r.alive; killed=killed+r.killed
      if r.attacking and options.attackers then attacking=attacking+1 end
      if r.selected then selected=r end
    end
    local ch=math.max(32,h)
    paint(heading,'<b>Room mobs</b>','#edf3fa')
    geometry(heading,4,4,width-3*ch-20,ch)
    if rateButton then control(rateButton,'<center>≋</center>'); geometry(rateButton,width-3*ch-12,4,ch,ch);tip(rateButton,'Rate room: consider all. '..(latest.ratings and latest.ratings.last or 'Verifies the completion marker for automatic ratings this session')) end
    control(button,'<center>↻</center>'); geometry(button,width-2*ch-8,4,ch,ch)
    control(optionsButton,'<center>⚙</center>'); geometry(optionsButton,width-ch-4,4,ch,ch)
    local age=latest.updated and math.max(0,math.floor((api.getEpoch()-latest.updated)/10)*10)
    local freshness=latest.fresh and (age and (age<10 and 'fresh' or age..'s ago') or 'fresh') or 'waiting'
    local counts=present..' here'..(killed>0 and ' · '..killed..' killed' or '')..(attacking>0 and ' · '..attacking..' attacking' or '')
    local caption=counts..' · '..freshness
    paint(summary,ui.escape(caption),'#b8cbd9','secondary')
    tip(summary,ui.escape(message))
    local summaryKey=caption..'|'..width..'|'..small.size..small.font
    if summary.key~=summaryKey then summary.rows=math.max(1,math.ceil(ui.measure(caption,'secondary')/math.max(60,width-24))); summary.key=summaryKey end
    local summaryHeight=summary.rows*small.line+8
    geometry(summary,4,ch+6,width-8,summaryHeight)
    local bodyY=ch+summaryHeight+14
    local footer=selected and ('Selected #'..(selected.ordinal or 1)..' · '..selected.name:match('%S+$')) or (actions and actions.describe() or 'Double-click to attack')
    local footerWidth=selected and width-76 or width-16
    local footerKey=footer..'|'..footerWidth..'|'..small.size..small.font
    if hint.key~=footerKey then hint.fitText=ui.fit(footer,footerWidth-8,'secondary'); hint.key=footerKey end
    local fh=ch
    paint(hint,ui.escape(hint.fitText),selected and '#80cfff' or '#aabfce','secondary')
    tip(hint,ui.escape((selected and ('Selected: '..selected.name..'. ') or '')..(actions and actions.describe() or 'Double-click to attack')..'. Right-click for mob actions. Clear only clears selection. Nearby entries are read-only.'))
    geometry(hint,8,math.max(0,root:get_height()-fh-4),footerWidth,fh)
    control(clearButton,'<center>Clear</center>'); geometry(clearButton,width-64,math.max(0,root:get_height()-fh-4),60,fh)
    visible(clearButton,selected~=nil)
    local available=math.max(1,root:get_height()-bodyY-fh-8)
    local scanContent=0
    if options.nearby then
      local scan=latest.nearby or {fresh=false,sections={}}; local count=0
      for _,section in ipairs(scan.sections) do count=count+#section.entries end
      visible(scanHeading,true)
      control(scanHeading,ui.escape((scanExpanded and '▾ ' or '▸ ')..'Nearby · '..(scan.fresh and count or scan.updated and 'stale' or '--')),true)
      tip(scanHeading,scan.updated and ((not scan.fresh and 'Stale. ' or '')..'Last scan '..math.max(0,math.floor((api.getEpoch()-scan.updated)/10)*10)..' seconds ago. Nearby entries cannot be attacked from this list.') or 'Refresh to scan nearby rooms. Click to collapse or expand.')
      local lines={}
      if scanExpanded then
        for _,section in ipairs(scan.sections) do
          lines[#lines+1]={text=section.direction..(section.distance and ' · '..section.distance..' away' or ''),header=true,direction=section.direction,tooltip=section.heading}
          for _,entry in ipairs(section.entries) do lines[#lines+1]={text=entry.name} end
          if #section.entries==0 then lines[#lines+1]={text='No visible occupants'} end
        end
        if #lines==0 then lines[1]={text=scan.fresh and 'No nearby mobs reported' or 'Waiting for scan'} end
        local y=0
        for i,line in ipairs(lines) do
          local widget=scanLabels[i]
          if not widget then widget=label('scanRow'..i,scanBody); scanLabels[i]=widget end
          local color=line.header and (options.colors and scanColors[line.direction] or '#d8e3eb') or '#d8e3eb'
          local signature=table.concat({width,small.font,small.size,tostring(line.header),line.text,color},'|')
          if widget.signature~=signature then
            local padding=line.header and 10 or 6
            widget.rowHeight=math.max(small.line+padding,math.ceil(ui.measure(line.text,'secondary')/math.max(40,width-48))*small.line+padding)
            local surface=line.header and 'background: #213343; border-top: 1px solid #496274; border-left: 3px solid '..color..'; padding: 4px;' or 'background: #111c25; padding: 3px;'
            paint(widget,line.header and '<b>'..ui.escape(line.text)..'</b>' or ui.escape(line.text),color,'secondary','QLabel { '..surface..' color: '..color..'; qproperty-wordWrap: true; }')
            widget.signature=signature
          end
          tip(widget,ui.escape(line.tooltip or line.text))
          if line.header and i>1 then y=y+6 end
          geometry(widget,8,y,width-30,widget.rowHeight); visible(widget,true); y=y+widget.rowHeight
        end
        for i=#scanLabels,#lines+1,-1 do scanLabels[i]:delete(); scanLabels[i]=nil end
        scanContent=y+4
      end
    else visible(scanHeading,false); visible(scanBody,false); if scanRefresh then visible(scanRefresh,false) end end
    local entries={}
    for _,r in ipairs(latest.rows) do
      if r.alive>0 or options.show_killed and r.killed>0 or options.show_missing and r.missing>0 then
        local badges={}; local symbol=''; local color='#7592a6'
        local rating=options.consider and r.consider
        if rating then color=rating.color end
        if r.requested and not r.target then badges[#badges+1]='Attack requested'; symbol='› ' end
        if r.selected then badges[#badges+1]='Selected'; color=options.target_color; symbol='› ' end
        if r.target and options.target then badges[#badges+1]='Fighting'..(r.health and ' · '..r.health..'%' or ''); color=options.target_color; symbol=symbol..'◎ ' end
        if r.attacking and options.attackers then badges[#badges+1]='Attacking you'; color=options.attacker_color; symbol=symbol..'⚔ ' end
        if r.killed>0 then badges[#badges+1]=r.uncertainDeath and 'Killed · duplicate identity unknown' or 'Killed'; color=options.killed_color; symbol='† ' end
        if r.missing>0 then badges[#badges+1]='No longer seen'; color='#93a4b4'; symbol='? ' end
        if r.unclassified then badges[#badges+1]='Opponent · type unknown' end
        if options.quest_hints and r.objective then badges[#badges+1]='Quest?' end
        local seen={}
        for _,hint in ipairs(r.objectives or {}) do
          if hint.source~='quest' and not seen[hint.source] then
            badges[#badges+1]=hint.source=='campaign' and 'CP?' or 'GQ?';seen[hint.source]=true
          end
        end
        local name=r.name..(r.duplicates and r.duplicates>1 and '  #'..r.ordinal or '')
        local title=(options.symbols and symbol or '')..name
        entries[#entries+1]={row=r,title=title,detail=table.concat(badges,' · '),rating=rating,color=options.colors and color or '#bac8d5'}
      end
    end
    if #entries==0 then entries[1]={title=latest.fresh and 'No visible mobs' or 'Waiting for room scan',detail=latest.fresh and 'Refresh to check this room again.' or 'The list appears after a complete scan.',color='#9dafbf'} end
    local y=4; local used={}
    for i,entry in ipairs(entries) do
      local key=entry.row and entry.row.id or 'empty'
      used[key]=true
      local card=labels[key]
      if not card then
        cardSerial=cardSerial+1; card=label('row'..cardSerial,body); labels[key]=card
        local widget=card; local epoch=generation
        widget:setClickCallback(function(event)
          if not root or epoch~=generation then return end
          local current=widget.entry
          local token=current and (actions and actions.capture(current.id,current.revision) or {id=current.id,revision=current.revision})
          if type(event)=='table' and event.button=='RightButton' then
            widget.press=nil;self.closeMenu()
            if token then openMenu(token,widget) end
            return
          end
          if type(event)=='table' and event.button and event.button~='LeftButton' then return end
          self.closeMenu();widget.press=token
        end)
        widget:setDoubleClickCallback(function(event)
          if not root or epoch~=generation then return end
          if type(event)=='table' and event.button and event.button~='LeftButton' then return end
          local current,press=widget.entry,widget.press; widget.press=nil
          if not current or not press or current.id~=press.id or current.revision~=press.revision then return end
          if actions then actions.doubleClick(press) else selectMob(current.id,current.revision) end
        end)
      end
      local r=entry.row
      local bg=r and r.selected and '#20384b' or i%2==0 and '#18232d' or '#121d27'
      if r and r.attacking and options.attackers and options.blink and phase then bg='#463322' end

      local lines={entry.title}; local html='<b>'..ui.escape(entry.title)..'</b>'
      if entry.rating then
        local text=entry.rating.label..' · '..entry.rating.range
        lines[#lines+1]=text
        html=html..'<br><span style="color:'..(options.colors and entry.rating.color or '#bac8d5')..'">'..ui.escape(text)..'</span>'
      end
      if entry.detail~='' then lines[#lines+1]=entry.detail; html=html..'<br><span style="color:'..entry.color..'">'..ui.escape(entry.detail)..'</span>' end
      if r and options.flags and r.flags~='' then
        local flagsKey=r.flags..'|'..width..'|'..m.font..m.size
        if card.flagsKey~=flagsKey then card.flagsText=ui.fit(r.flags,width-48); card.flagsKey=flagsKey end
        lines[#lines+1]=card.flagsText; html=html..'<br><span style="color:#aebfce">'..ui.escape(card.flagsText)..'</span>'
      end
      local layoutKey=table.concat({width,m.font,m.size,table.concat(lines,'\n')},'|')
      if card.layoutKey~=layoutKey then
        local count=0; for _,line in ipairs(lines) do count=count+math.max(1,math.ceil(ui.measure(line)/math.max(40,width-48))) end
        card.rowHeight=math.max(ch,count*m.line+12); card.layoutKey=layoutKey
      end
      paint(card,html,r and r.killed>0 and '#acbac6' or '#edf3f8',nil,'QLabel { background: '..bg..'; color: #edf3f8; border: 1px solid #2b3d4b; border-left: 3px solid '..entry.color..'; border-radius: 4px; padding: 5px; qproperty-wordWrap: true; } QLabel:hover { border-color: #7a9db8; background: #263a4a; }')
      if r then
        local objective=''
        if options.quest_hints and r.objective then
          local q=r.objective
          objective='\nQuest candidate: exact name match only; identity is unverified.'..
            '\nTarget: '..q.target..(q.room and '\nRoom: '..q.room or '')..(q.area and '\nArea: '..q.area or '')..
            ((q.matches or 0)>1 and '\n'..q.matches..' matching mobs; none is confirmed as the quest target.' or '')
        end
        for _,hint in ipairs(r.objectives or {}) do
          if hint.source~='quest' then
            objective=objective..'\n'..(hint.source=='campaign' and 'Campaign' or 'Global Quest')..' candidate: exact name match only; identity is unverified.'..
              (hint.room and '\nRoom: '..hint.room or '')..(hint.area and '\nArea: '..hint.area or '')
          end
        end
        tip(card,ui.escape(r.name..objective..(r.flags~='' and '\n'..r.flags or '')..(entry.rating and '\nConsider: '..entry.rating.label..' · '..entry.rating.range..' relative to you' or '')..(r.alive>0 and not r.unclassified and '\n'..(actions and actions.describe() or 'Double-click: kill')..' · '..(r.ordinal or 1)..'.'..r.name:match('%S+$')..(options.context_menu and '\nRight-click for actions' or '') or '\n'..entry.detail)))
      end
      geometry(card,8,y,math.max(1,width-30),card.rowHeight); visible(card,true); y=y+card.rowHeight+4
      card.entry=r and r.alive>0 and not r.unclassified and {id=r.id,revision=latest.revision} or nil
    end
    for key,card in pairs(labels) do
      if not used[key] then card.entry=nil; card.press=nil; card:delete(); labels[key]=nil end
    end
    local roomHeight=available
    if options.nearby then
      local scanMinimum=ch+8+(scanExpanded and math.min(scanContent,math.max(small.line+6,available*0.4-ch)) or 0)
      roomHeight=math.min(y+4,math.max(ch,available-scanMinimum))
      if not scanExpanded then roomHeight=math.min(y+4,available-ch-8) end
      roomHeight=math.max(1,roomHeight)
      local scanY=bodyY+roomHeight+4
      geometry(scanHeading,8,scanY,width-ch-20,ch)
      if scanRefresh then control(scanRefresh,'<center>↻</center>');geometry(scanRefresh,width-ch-8,scanY,ch,ch);visible(scanRefresh,true) end
      local scanHeight=math.max(1,available-roomHeight-ch-8)
      geometry(scanBody,0,scanY+ch+4,width,scanHeight)
      visible(scanBody,scanExpanded and scanHeight>1)
    end
    geometry(body,0,bodyY,width,roomHeight)
  end
  function self.layout()
    self.closeMenu()
    if not root then return end
    local w=select(1,api.getMainWindowSize())
    local width=math.min(options.width or 260,math.max(160,w*0.25))
    borders.reserve(OWNER,'left',math.floor(width),20,function()
      if root then local x,y,bw,bh=borders.box(OWNER); root:move(x,y); root:resize(bw,bh); render() end
    end)
    local x,y,bw,bh=borders.box(OWNER); root:move(x,y); root:resize(bw,bh); root:show(); render()
  end
  function self.update(snapshot,text,tick) self.validateMenu();latest=snapshot; message=text; if tick then phase=not phase end; render() end
  function self.configure(values)
    self.closeMenu()
    options=values
    if not root then
      generation=generation+1
      root=api.Geyser.Container:new({name=OWNER..'.pane',x=0,y=0,width=260,height=400})
      local background=label('background',root); background:resize('100%','100%'); background:setStyleSheet('background: #0e1720;')
      heading=label('heading',root); summary=label('summary',root); hint=label('hint',root)
      button=label('refresh',root); button:setClickCallback(refresh); button:setToolTip('Refresh room mobs')
      optionsButton=label('settings',root); optionsButton:setClickCallback(settings); optionsButton:setToolTip('Room mob settings')
      if rateRoom then rateButton=label('rate',root);rateButton:setClickCallback(rateRoom);rateButton:setToolTip('Rate room: consider all (also verifies completion for automatic ratings this session)') end
      if refreshNearby then scanRefresh=label('scanRefresh',root);scanRefresh:setClickCallback(refreshNearby);scanRefresh:setToolTip('Refresh nearby rooms') end
      clearButton=label('clear',root); clearButton:setClickCallback(clearSelection)
      scanHeading=label('scanHeading',root)
      local epoch=generation
      scanHeading:setClickCallback(function(event)
        if not root or generation~=epoch then return end
        if type(event)=='table' and event.button and event.button~='LeftButton' then return end
        scanExpanded=not scanExpanded; render()
        if scanExpanded and refreshNearby and not (latest.nearby and latest.nearby.fresh) then refreshNearby() end
      end)
      scanBody=api.Geyser.ScrollBox:new({name=OWNER..'.scanBody',x=0,y=0,width='100%',height=1},root)
      body=api.Geyser.ScrollBox:new({name=OWNER..'.body',x=0,y=100,width='100%',height='-100px'},root)
    end
    self.layout()
  end
  function self.destroy()
    self.closeMenu()
    generation=generation+1
    if root then root:delete(); root=nil end
    labels={}; scanLabels={}; scanExpanded=false;cardSerial=0; borders.release(OWNER)
  end
  return self
end
return Pane
