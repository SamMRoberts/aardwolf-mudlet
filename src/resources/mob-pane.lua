-- Dedicated roster: stable scan order, separate selection and combat evidence.
local Pane={}
local OWNER='AardwolfToolbox.mobs'
local scanColors={North='#80dfff',South='#9fe3a8',East='#ffda85',West='#d4b0ff',Up='#9bbcff',Down='#ffad99'}
function Pane.new(api,ui,borders,refresh,settings,selectMob,clearSelection)
  local self={}; local root,body,heading,status,button,optionsButton,summary,hint,clearButton
  local scanHeading,scanBody; local scanLabels={}; local scanExpanded=true
  local labels={}; local options={}; local latest={rows={}}
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
    geometry(heading,4,4,width-2*ch-16,ch)
    control(button,'<center>↻</center>'); geometry(button,width-2*ch-8,4,ch,ch)
    control(optionsButton,'<center>⚙</center>'); geometry(optionsButton,width-ch-4,4,ch,ch)
    local age=latest.updated and math.max(0,math.floor((api.getEpoch()-latest.updated)/10)*10)
    local freshness=latest.fresh and (age and (age<10 and 'fresh' or age..'s ago') or 'fresh') or 'waiting'
    local counts=present..' here'..(killed>0 and ' · '..killed..' killed' or '')..(attacking>0 and ' · '..attacking..' attacking' or '')
    local caption=counts..' · '..freshness
    paint(summary,ui.escape(caption),'#b8cbd9','secondary')
    local summaryKey=caption..'|'..width..'|'..small.size..small.font
    if summary.key~=summaryKey then summary.rows=math.max(1,math.ceil(ui.measure(caption,'secondary')/math.max(60,width-24))); summary.key=summaryKey end
    local summaryHeight=summary.rows*small.line+8
    geometry(summary,4,ch+6,width-8,summaryHeight)
    local bodyY=ch+summaryHeight+14
    local normal=message=='Visible mobs · current visit'
    local sh=0
    if not normal then
      local statusKey=message..'|'..width..'|'..small.size..small.font
      if status.key~=statusKey then status.fitText=ui.fit(message,width-24,'secondary'); status.key=statusKey end
      paint(status,ui.escape(status.fitText),'#ddc292','secondary'); sh=small.line+8
      geometry(status,4,bodyY,width-8,sh); tip(status,ui.escape(message)); visible(status,true)
      bodyY=bodyY+sh+4
    else visible(status,false) end
    local footer=selected and ('Selected #'..(selected.ordinal or 1)..' · '..selected.name:match('%S+$')) or 'Double-click to attack'
    local footerWidth=selected and width-76 or width-16
    local footerKey=footer..'|'..footerWidth..'|'..small.size..small.font
    if hint.key~=footerKey then hint.fitText=ui.fit(footer,footerWidth-8,'secondary'); hint.key=footerKey end
    local fh=ch
    paint(hint,ui.escape(hint.fitText),selected and '#80cfff' or '#aabfce','secondary')
    tip(hint,ui.escape(selected and ('Selected: '..selected.name..'. Double-click attacks; Clear only clears selection.') or 'Double-click a current-room mob to attack. Nearby scan entries are read-only.'))
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
    else visible(scanHeading,false); visible(scanBody,false) end
    local entries={}
    for _,r in ipairs(latest.rows) do
      if r.alive>0 or options.show_killed and r.killed>0 or options.show_missing and r.missing>0 then
        local badges={}; local symbol=''; local color='#7592a6'
        local rating=options.consider and r.consider
        if rating then color=rating.color end
        if r.selected then badges[#badges+1]='Selected'; color=options.target_color; symbol='› ' end
        if r.target and options.target then badges[#badges+1]='Fighting'..(r.health and ' · '..r.health..'%' or ''); color=options.target_color; symbol=symbol..'◎ ' end
        if r.attacking and options.attackers then badges[#badges+1]='Attacking you'; color=options.attacker_color; symbol=symbol..'⚔ ' end
        if r.killed>0 then badges[#badges+1]=r.uncertainDeath and 'Killed · duplicate identity unknown' or 'Killed'; color=options.killed_color; symbol='† ' end
        if r.missing>0 then badges[#badges+1]='No longer seen'; color='#93a4b4'; symbol='? ' end
        if r.unclassified then badges[#badges+1]='Opponent · type unknown' end
        local name=r.name..(r.duplicates and r.duplicates>1 and '  #'..r.ordinal or '')
        local title=(options.symbols and symbol or '')..name
        entries[#entries+1]={row=r,title=title,detail=table.concat(badges,' · '),rating=rating,color=options.colors and color or '#bac8d5'}
      end
    end
    if #entries==0 then entries[1]={title=latest.fresh and 'No visible mobs' or 'Waiting for room scan',detail=latest.fresh and 'Refresh to check this room again.' or 'The list appears after a complete scan.',color='#9dafbf'} end
    local y=4
    for i,entry in ipairs(entries) do
      local card=labels[i]
      if not card then
        card=label('row'..i,body); labels[i]=card
        local widget=card; local epoch=generation
        widget:setClickCallback(function(event)
          if type(event)=='table' and event.button~='LeftButton' then return end
          local current=widget.entry
          widget.press=current and {id=current.id,revision=current.revision} or nil
        end)
        widget:setDoubleClickCallback(function(event)
          if not root or epoch~=generation then return end
          if type(event)=='table' and event.button and event.button~='LeftButton' then return end
          local current,press=widget.entry,widget.press; widget.press=nil
          if not current or not press or current.id~=press.id or current.revision~=press.revision then return end
          selectMob(current.id,current.revision)
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
        tip(card,ui.escape(r.name..(r.flags~='' and '\n'..r.flags or '')..(entry.rating and '\nConsider: '..entry.rating.label..' · '..entry.rating.range..' relative to you' or '')..(r.alive>0 and not r.unclassified and '\nDouble-click: kill '..(r.ordinal or 1)..'.'..r.name:match('%S+$') or '\n'..entry.detail)))
      end
      geometry(card,8,y,math.max(1,width-30),card.rowHeight); visible(card,true); y=y+card.rowHeight+4
      card.entry=r and r.alive>0 and not r.unclassified and {id=r.id,revision=latest.revision} or nil
    end
    for i=#labels,#entries+1,-1 do labels[i].entry=nil; labels[i].press=nil; labels[i]:delete(); labels[i]=nil end
    local roomHeight=available
    if options.nearby then
      local scanMinimum=ch+8+(scanExpanded and math.min(scanContent,math.max(small.line+6,available*0.4-ch)) or 0)
      roomHeight=math.min(y+4,math.max(ch,available-scanMinimum))
      if not scanExpanded then roomHeight=math.min(y+4,available-ch-8) end
      roomHeight=math.max(1,roomHeight)
      local scanY=bodyY+roomHeight+4
      geometry(scanHeading,8,scanY,width-16,ch)
      local scanHeight=math.max(1,available-roomHeight-ch-8)
      geometry(scanBody,0,scanY+ch+4,width,scanHeight)
      visible(scanBody,scanExpanded and scanHeight>1)
    end
    geometry(body,0,bodyY,width,roomHeight)
  end
  function self.layout()
    if not root then return end
    local w=select(1,api.getMainWindowSize())
    local width=math.min(options.width or 260,math.max(160,w*0.25))
    borders.reserve(OWNER,'left',math.floor(width),20,function()
      if root then local x,y,bw,bh=borders.box(OWNER); root:move(x,y); root:resize(bw,bh); render() end
    end)
    local x,y,bw,bh=borders.box(OWNER); root:move(x,y); root:resize(bw,bh); root:show(); render()
  end
  function self.update(snapshot,text,tick) latest=snapshot; message=text; if tick then phase=not phase end; render() end
  function self.configure(values)
    options=values
    if not root then
      generation=generation+1
      root=api.Geyser.Container:new({name=OWNER..'.pane',x=0,y=0,width=260,height=400})
      local background=label('background',root); background:resize('100%','100%'); background:setStyleSheet('background: #0e1720;')
      heading=label('heading',root); summary=label('summary',root); status=label('status',root); hint=label('hint',root)
      button=label('refresh',root); button:setClickCallback(refresh); button:setToolTip('Refresh room mobs')
      optionsButton=label('settings',root); optionsButton:setClickCallback(settings); optionsButton:setToolTip('Room mob settings')
      clearButton=label('clear',root); clearButton:setClickCallback(clearSelection)
      scanHeading=label('scanHeading',root)
      local epoch=generation
      scanHeading:setClickCallback(function(event)
        if not root or generation~=epoch then return end
        if type(event)=='table' and event.button and event.button~='LeftButton' then return end
        scanExpanded=not scanExpanded; render()
      end)
      scanBody=api.Geyser.ScrollBox:new({name=OWNER..'.scanBody',x=0,y=0,width='100%',height=1},root)
      body=api.Geyser.ScrollBox:new({name=OWNER..'.body',x=0,y=100,width='100%',height='-100px'},root)
    end
    self.layout()
  end
  function self.destroy()
    generation=generation+1
    if root then root:delete(); root=nil end
    labels={}; scanLabels={}; scanExpanded=true; borders.release(OWNER)
  end
  return self
end
return Pane
