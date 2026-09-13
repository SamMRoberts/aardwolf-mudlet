-- Render server text literally; raw Aardwolf colors require an explicit mode.
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
local rawColors={b=4,B=12,c=6,C=14,r=1,R=9,m=5,M=13,g=2,G=10,w=7,W=15,y=3,Y=11,D=8}
local function render(text,mode,emit)
  assert(type(text)=='string' and #text<=65536,'Invalid console message')
  local fg,bg={224,230,236},{0,0,0}
  local at,start=1,1
  local function flush(last)
    if last>=start then emit(text:sub(start,last),fg,bg) end
  end
  while at<=#text do
    local first,last,sequence=text:find('^\27%[([%d;]*)m',at)
    local raw=mode=='raw' and text:sub(at,at)=='@' and text:sub(at+1,at+1)
    local digits=raw=='x' and text:sub(at+2,at+4):match('^%d+')
    if first then
      flush(at-1)
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
      at=last+1;start=at
    elseif raw and (rawColors[raw] or raw=='@' or raw=='-' or digits and tonumber(digits)<=255) then
      flush(at-1)
      if rawColors[raw] then fg=color(rawColors[raw]);at=at+2
      elseif digits then fg=color(tonumber(digits));at=at+2+#digits
      else emit(raw=='@' and '@' or '~',fg,bg);at=at+2 end
      start=at
    else at=at+1 end
  end
  flush(#text)
end
function Text.plain(text,mode)
  local parts={};render(text,mode,function(value) parts[#parts+1]=value end);return table.concat(parts)
end
function Text.write(api,console,text,mode)
  render(text,mode,function(value,fg,bg)
    api.setFgColor(console.name,unpack(fg));api.setBgColor(console.name,unpack(bg));console:echo(value)
  end)
  api.setFgColor(console.name,224,230,236);api.setBgColor(console.name,0,0,0)
end
return Text
