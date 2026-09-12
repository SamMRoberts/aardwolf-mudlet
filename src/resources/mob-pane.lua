-- Dedicated roster: stable scan order, separate selection and combat evidence.
local Pane={}
local OWNER='AardwolfToolbox.mobs'
function Pane.new(api,ui,borders,refresh,settings,selectMob,clearSelection)
  local self={}; local root,body,heading,status,button,optionsButton,summary,hint,clearButton
  local labels={}; local options={}; local latest={rows={}}
  local message='Waiting for room data'; local phase=false; local generation=0
  local function label(name,parent)
    return api.Geyser.Label:new({name=OWNER..'.'..name,x=0,y=0,width=1,height=1},parent)
  end
  local function styled(widget,text,color,role)
    ui.apply(widget,role)
    widget:setStyleSheet('QLabel { background: transparent; color: '..color..'; padding: 6px; qproperty-wordWrap: true; }')
    widget:echo(text)
  end
  local function render()
    if not root then return end
    local width=math.max(1,root:get_width()); local m=ui.metrics(); local small=ui.metrics('secondary'); local h=m.height
    local present,killed=0,0; local selected
    for _,r in ipairs(latest.rows) do present=present+r.alive; killed=killed+r.killed; if r.selected then selected=r end end
    styled(heading,'<b>ROOM MOBS</b>','#edf3fa'); heading:move(4,4); heading:resize(width-8,h)
    styled(summary,ui.escape(present..' present  ·  '..killed..' killed'),'#aebfce','secondary')
    summary:move(4,h+2); summary:resize(width-8,small.height)
    local controlsY=h+small.height+4
    ui.style(button,true); button:echo('<center>Refresh</center>'); button:move(8,controlsY); button:resize((width-24)/2,h)
    ui.style(optionsButton,true); optionsButton:echo('<center>Settings</center>'); optionsButton:move(width/2+4,controlsY); optionsButton:resize((width-24)/2,h)
    local text=message
    if latest.fresh and latest.updated and message=='Visible mobs · current visit' then text='Updated '..math.max(0,math.floor(api.getEpoch()-latest.updated))..'s ago · current room' end
    styled(status,ui.escape(text),latest.fresh and '#9fbcad' or '#d6bb88','secondary')
    local sh=math.max(small.height,math.ceil(ui.measure(text,'secondary')/math.max(60,width-24))*small.line+12)
    status:move(4,controlsY+h); status:resize(width-8,sh)
    local footer=selected and 'Selected: '..selected.name or 'Double-click a mob to select'
    local footerWidth=selected and width-76 or width-16
    local fh=math.max(h,math.ceil(ui.measure(footer,'secondary')/math.max(60,footerWidth-12))*small.line+12)
    styled(hint,ui.escape(footer),selected and '#80cfff' or '#b9c8d6','secondary')
    hint:move(8,math.max(0,root:get_height()-fh-4)); hint:resize(footerWidth,fh)
    ui.style(clearButton,true); clearButton:echo('<center>Clear</center>')
    clearButton:move(width-64,math.max(0,root:get_height()-fh-4)); clearButton:resize(60,fh)
    if selected then clearButton:show() else clearButton:hide() end
    local bodyY=controlsY+h+sh+4
    body:move(0,bodyY); body:resize(width,math.max(1,root:get_height()-bodyY-fh-8))
    local entries={}
    for _,r in ipairs(latest.rows) do
      if r.alive>0 or options.show_killed and r.killed>0 or options.show_missing and r.missing>0 then
        local badges={}; local symbol=''; local color='#7592a6'
        if r.selected then badges[#badges+1]='Selected'; color=options.target_color; symbol='› ' end
        if r.target and options.target then badges[#badges+1]='Fighting'..(r.health and ' · '..r.health..'%' or ''); color=options.target_color; symbol=symbol..'◎ ' end
        if r.possibleTarget and options.target then badges[#badges+1]='Possible opponent'; symbol=symbol..'◎? ' end
        if r.attacking and options.attackers then badges[#badges+1]='Attacking you'; color=options.attacker_color; symbol=symbol..'⚔ ' end
        if r.possibleAttacker and options.attackers then badges[#badges+1]='Possible attacker'; symbol=symbol..'⚔? ' end
        if r.killed>0 then badges[#badges+1]=r.uncertainDeath and 'Killed · duplicate identity unknown' or 'Killed'; color=options.killed_color; symbol='† ' end
        if r.missing>0 then badges[#badges+1]='No longer seen'; color='#93a4b4'; symbol='? ' end
        if r.unclassified then badges[#badges+1]='Opponent · type unknown' end
        if #badges==0 then badges[1]='In room' end
        local name=r.name..(r.duplicates and r.duplicates>1 and '  #'..r.ordinal or '')
        local title=(options.symbols and symbol or '')..name
        entries[#entries+1]={row=r,title=title,detail=table.concat(badges,' · '),color=options.colors and color or '#bac8d5'}
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

      local lines={entry.title,entry.detail}; local html='<b>'..ui.escape(entry.title)..'</b><br><span style="color:'..entry.color..'">'..ui.escape(entry.detail)..'</span>'
      if r and options.flags and r.flags~='' then lines[#lines+1]=r.flags; html=html..'<br><span style="color:#b8c7d5">'..ui.escape(r.flags)..'</span>' end
      local signature=table.concat({width,m.font,m.size,bg,entry.color,html},'|')
      if card.signature~=signature then
        ui.apply(card)
      card:setStyleSheet('QLabel { background: '..bg..'; color: #e8eff5; border: 1px solid #2b3d4b; border-left: 3px solid '..entry.color..'; border-radius: 5px; padding: 8px; qproperty-wordWrap: true; } QLabel:hover { border-color: #7a9db8; background: #263a4a; }')
        local count=0; for _,line in ipairs(lines) do count=count+math.max(1,math.ceil(ui.measure(line)/math.max(40,width-52))) end
        card.rowHeight=math.max(h,count*m.line+20)
        card:resize(math.max(1,width-30),card.rowHeight); card:echo(html); card.signature=signature
      end
      card:move(8,y); card:show(); y=y+card.rowHeight+6
      card.entry=r and r.alive>0 and not r.unclassified and {id=r.id,revision=latest.revision} or nil
    end
    for i=#entries+1,#labels do labels[i].entry=nil; labels[i].press=nil; labels[i]:hide() end
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
      button=label('refresh',root); button:setClickCallback(refresh)
      optionsButton=label('settings',root); optionsButton:setClickCallback(settings)
      clearButton=label('clear',root); clearButton:setClickCallback(clearSelection)
      body=api.Geyser.ScrollBox:new({name=OWNER..'.body',x=0,y=100,width='100%',height='-100px'},root)
    end
    self.layout()
  end
  function self.destroy()
    generation=generation+1
    if root then root:delete(); root=nil end
    labels={}; borders.release(OWNER)
  end
  return self
end
return Pane
