-- Shared typography. Geyser's inline rich-text font must agree with its QFont.
local UI={}
local OWNER="AardwolfToolbox.ui"
function UI.new(api,config)
  local self={enabled=false,last="Disabled"}
  local options={ui_font="Arial",mono_font="Menlo",ui_size=12,reading_size=13,preset="comfortable"}
  local original,written,probe
  local function copy(t) local r={}; for k,v in pairs(t or {}) do r[k]=v end; return r end
  function self.escape(text)
    return (tostring(text):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"):gsub('"',"&quot;"):gsub("'","&#39;"))
  end
  local function family(requested,mono)
    local fonts=api.getAvailableFonts and api.getAvailableFonts() or {}
    if fonts[requested] or next(fonts)==nil then return requested end
    for _,name in ipairs(mono and {"Menlo","Consolas","DejaVu Sans Mono","Monospace"} or {"Arial","Helvetica","DejaVu Sans","Sans Serif"}) do
      if fonts[name] then return name end
    end
    return mono and "Monospace" or "Sans Serif"
  end
  function self.metrics(role)
    local mono=role=="reading"
    local size=mono and options.reading_size or role=="secondary" and math.max(11,options.ui_size-1) or options.ui_size
    if options.preset=="large" then size=math.max(size,mono and 15 or 14) end
    local font=family(mono and options.mono_font or options.ui_font,mono)
    local _,height=api.calcFontSize(size,font)
    return {font=font,size=size,height=math.max(32,math.ceil(height+12)),line=math.ceil(height+6)}
  end
  function self.apply(widget,role)
    local m=self.metrics(role)
    widget:setFont(m.font); widget:setFontSize(m.size)
    return m
  end
  function self.measure(text,role)
    if not probe then
      probe=api.Geyser.Label:new({name=OWNER..".measure",x=0,y=0,width=10000,height=100,hidden=true})
      probe:hide(); probe:setStyleSheet("QLabel { border: none; padding: 0; }")
    end
    self.apply(probe,role); probe:echo(self.escape(text))
    local width,height=probe:getSizeHint()
    return width,height
  end
  function self.fit(text,width,role)
    if self.measure(text,role)<=width then return text end
    local chars={}; for char in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do chars[#chars+1]=char end
    while #chars>0 do
      chars[#chars]=nil
      local value=table.concat(chars).."…"
      if self.measure(value,role)<=width then return value end
    end
    return ""
  end
  function self.style(widget,button,selected)
    self.apply(widget)
    widget:setStyleSheet("QLabel { background-color: "..(selected and "#293e50" or "#151c23")..
      "; color: #e0e6ec; border: 0; padding: 5px; }"..
      (button and " QLabel:hover { background-color: #344b60; } QLabel:focus { border: 1px solid #83bde8; }" or ""))
  end
  function self.chrome(root)
    local m=self.metrics()
    self.apply(root.adjLabel); self.apply(root.exitLabel)
    root.exitLabel:resize(m.height,m.height)
    root.Inside:move(0,m.height); root.Inside:resize("100%","100%-"..m.height)
    for _,item in pairs((root.adjLabel.rightClickMenu or {}).MenuLabels or {}) do
      self.apply(item); item:resize(item.width,m.height)
    end
  end
  function self.stop()
    if original and written then
      if api.getFont("main")==written.font then api.setFont("main",original.font) end
      if api.getFontSize("main")==written.size then api.setFontSize("main",original.size) end
      if api.getCmdLineStyleSheet()==written.command then api.setCmdLineStyleSheet(original.command) end
    end
    if probe then probe:delete(); probe=nil end
    self.enabled=false; self.last="Disabled"; original,written=nil,nil
  end
  self.destroy=self.stop
  function self.configure(values)
    options=copy(values)
    if not values.enabled then self.stop(); api.raiseEvent(OWNER..".changed"); return true end
    local ok,err=pcall(function()
      local current={font=api.getFont("main"),size=api.getFontSize("main"),command=api.getCmdLineStyleSheet()}
      if not original then
        local saved=config.getMetadata("appearanceProvenance")
        if type(saved)=="table" and type(saved.original)=="table" and type(saved.written)=="table"
            and saved.written.font==current.font and saved.written.size==current.size and saved.written.command==current.command then
          original=saved.original
        else original=current end
      elseif written then
        for key,value in pairs(current) do if value~=written[key] then original[key]=value end end
      end
      local m=self.metrics("reading")
      local size=math.max(m.size,original.size or 0)
      -- Preserve a larger user-selected input size; otherwise match the console.
      local existing=tonumber((original.command or ""):match("font%-size:%s*([%d.]+)pt")) or original.size or 0
      local command=(original.command or "").."\nQPlainTextEdit { font-family: '"..m.font:gsub("['\\]","")..
        "'; font-size: "..math.max(size,existing).."pt; padding: 3px; }"
      assert(config.setMetadata("appearanceProvenance",{original=original,written={font=m.font,size=size,command=command}}))
      api.setFont("main",m.font); api.setFontSize("main",size); api.setCmdLineStyleSheet(command)
      written={font=api.getFont("main"),size=size,command=command}
      self.enabled=true; self.last="Readable fonts active"
      api.raiseEvent(OWNER..".changed")
    end)
    if not ok then self.last=tostring(err); return false,self.last end
    return true
  end
  return self
end
return UI
