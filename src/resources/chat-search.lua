-- On-demand reads of the existing native buffer; no capture or retained history.
local Search={}
function Search.new(api,ui)
  local self={}
  local root,input,status,results,closeButton,escapeKey,console
  local rows={};local generation=0;local layoutKey
  function self.isEditing() return root~=nil end
  function self.close()
    generation=generation+1
    if escapeKey then api.killKey(escapeKey);escapeKey=nil end
    if root then root:delete() end
    root,input,status,results,closeButton,console=nil,nil,nil,nil,nil,nil
    rows={};layoutKey=nil
  end
  self.stop=self.close
  local function message(text) status:echo(ui.escape(text)) end
  function self.layout()
    if not root then return end
    local metrics=ui.metrics();local h=metrics.height
    local key=table.concat({root:get_width(),root:get_height(),metrics.font,metrics.size,generation},'|')
    if key==layoutKey then return end
    layoutKey=key
    ui.apply(input);ui.style(status);ui.style(closeButton,true)
    input:move(0,0);input:resize('100%-'..h,h)
    closeButton:move('-'..h..'px',0);closeButton:resize(h,h)
    status:move(0,h);status:resize('100%',h*2)
    results:move(0,h*3);results:resize('100%','100%-'..h*3)
    for index,row in ipairs(rows) do
      ui.style(row,true);row:move(0,(index-1)*h);row:resize('100%',h)
      row:echo(ui.escape(ui.fit(row.preview,math.max(1,root:get_width()-16))))
    end
  end
  function self.find(value)
    if not root then return false,'Search is closed' end
    generation=generation+1;local token=generation
    for _,row in ipairs(rows) do row:delete() end;rows={}
    if type(value)~='string' or #value>256 or value:find('[%z\1-\31\127]') then message('Enter up to 256 characters.');return false end
    if value=='' then message('Type text and press Enter. Literal, case-sensitive search.');return true end
    local ok,err=pcall(function()
      local count=assert(api.getLineCount(console.name),'Chat buffer unavailable')
      assert(type(count)=='number' and count>=0,'Chat buffer unavailable')
      local first=math.max(0,count-10000)
      local bytes,found,limited=0,0,first>0
      -- Scan newest first so bounded results remain useful in busy channels.
      for finish=count,first+1,-128 do
        local start=math.max(first,finish-128)
        local lines=assert(api.getLines(console.name,start,finish),'Cannot read chat buffer')
        for i=#lines,1,-1 do
          local line=lines[i]
          if type(line)=='string' then
            bytes=bytes+#line
            if bytes>1048576 or found>=100 then limited=true;break end
            if line:find(value,1,true) then
              found=found+1
              local number=start+i-1
              local row=api.Geyser.Label:new({name='AardwolfToolbox.chatSearch.result.'..found,x=0,y=0,width='100%',height=32},results)
              rows[#rows+1]=row;row.preview=line
              row:setToolTip('Jump to this line in the original chat buffer')
              row:setClickCallback(function()
                if token~=generation or not console then return end
                local current=api.getLines(console.name,number,number+1)
                if not current or current[1]~=line then message('Buffer changed. Press Enter to search again.');return end
                local target=console;self.close();target:scrollTo(number)
              end)
            end
          end
        end
        if bytes>1048576 or found>=100 then break end
      end
      message(found..' match'..(found==1 and '' or 'es')..((limited or found>=100) and ' · recent buffer limit reached' or '')..'. Click to jump.')
    end)
    if not ok then message('Search unavailable: '..tostring(err));return false,tostring(err) end
    self.layout();return true
  end
  function self.open(host,target)
    self.close();console=target
    local ok,err=pcall(function()
      root=api.Geyser.Container:new({name='AardwolfToolbox.chatSearch',x=0,y=0,width='100%',height='100%'},host)
      local ownedRoot=root
      local background=api.Geyser.Label:new({name='AardwolfToolbox.chatSearch.background',x=0,y=0,width='100%',height='100%'},root)
      background:setStyleSheet('QLabel { background: #101820; border: none; }')
      input=api.Geyser.CommandLine:new({name='AardwolfToolbox.chatSearch.input',x=0,y=0,width='100%',height=32},root)
      ui.apply(input);input:setStyleSheet('QPlainTextEdit { background: #151c23; color: #e0e6ec; border: 1px solid #83bde8; }')
      input:setAction(function(value) if root==ownedRoot then self.find(value) end end)
      input:print('')
      closeButton=api.Geyser.Label:new({name='AardwolfToolbox.chatSearch.close',x=0,y=0,width=32,height=32},root)
      ui.style(closeButton,true);closeButton:echo('×');closeButton:setToolTip('Close search (Escape)')
      closeButton:setClickCallback(function() if root==ownedRoot then self.close() end end)
      status=api.Geyser.Label:new({name='AardwolfToolbox.chatSearch.status',x=0,y=32,width='100%',height=64},root)
      results=api.Geyser.ScrollBox:new({name='AardwolfToolbox.chatSearch.results',x=0,y=96,width='100%',height='100%-96'},root)
      self.layout();message('Type text and press Enter. Literal, case-sensitive search.')
      escapeKey=assert(api.tempKey(api.mudlet.key.Escape,self.close),'Cannot register search dismissal')
      root:raiseAll()
    end)
    if not ok then self.close();return false,tostring(err) end
    return true
  end
  return self
end
return Search
