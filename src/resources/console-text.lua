-- Render server text literally. Only ANSI SGR sequences change native colors.
local Text={}
local palette={{0,0,0},{170,0,0},{0,170,0},{170,85,0},{0,0,170},{170,0,170},{0,170,170},{170,170,170},
  {85,85,85},{255,85,85},{85,255,85},{255,255,85},{85,85,255},{255,85,255},{85,255,255},{255,255,255}}
local function color(n)
  if n<16 then return palette[n+1] end
  if n<232 then
    local levels={0,95,135,175,215,255};n=n-16
    return {levels[math.floor(n/36)+1],levels[math.floor(n/6)%6+1],levels[n%6+1]}
  end
  local v=8+(n-232)*10;return {v,v,v}
end
function Text.write(api,console,text)
  assert(type(text)=='string' and #text<=65536,'Invalid console message')
  local fg,bg={224,230,236},{0,0,0}
  local function emit(value)
    if value=='' then return end
    api.setFgColor(console.name,unpack(fg));api.setBgColor(console.name,unpack(bg));console:echo(value)
  end
  local at=1
  while true do
    local first,last,sequence=text:find('\27%[([%d;]*)m',at)
    if not first then emit(text:sub(at));break end
    emit(text:sub(at,first-1))
    local codes={};for part in (sequence..';'):gmatch('(.-);') do codes[#codes+1]=tonumber(part) or 0 end
    local i=1
    while i<=#codes do
      local n=codes[i]
      if n==0 then fg,bg={224,230,236},{0,0,0}
      elseif n==39 then fg={224,230,236}
      elseif n==49 then bg={0,0,0}
      elseif n>=30 and n<=37 then fg=color(n-30)
      elseif n>=40 and n<=47 then bg=color(n-40)
      elseif n>=90 and n<=97 then fg=color(n-90+8)
      elseif n>=100 and n<=107 then bg=color(n-100+8)
      elseif n==38 or n==48 then
        local nextColor
        if codes[i+1]==5 and codes[i+2] and codes[i+2]<=255 then nextColor=color(codes[i+2]);i=i+2
        elseif codes[i+1]==2 and codes[i+4] and codes[i+2]<=255 and codes[i+3]<=255 and codes[i+4]<=255 then
          nextColor={codes[i+2],codes[i+3],codes[i+4]};i=i+4
        end
        if nextColor then if n==38 then fg=nextColor else bg=nextColor end end
      end
      i=i+1
    end
    at=last+1
  end
  api.setFgColor(console.name,224,230,236);api.setBgColor(console.name,0,0,0)
end
return Text
