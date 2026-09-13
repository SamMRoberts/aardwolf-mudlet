-- Observe fresh progression only; no queries, gameplay commands or inferred gains.
local History={}
local OWNER='AardwolfToolbox.history'
local FIELDS={'level','tier','remorts','redos','pups','totpups'}
local function copy(value) local result={};for k,v in pairs(value) do result[k]=type(v)=='table' and copy(v) or v end;return result end
local function number(value) return type(value)=='number' and value>=0 and value<=2147483647 and value%1==0 end
function History.definition(apply)
  return {id='history',label='Local history',description='Optional per-character progression observations stored only on this computer. Quest, kill and chat history are not recorded. Retention limits apply across this profile; expired/oldest records are removed on access or new writes.',settings={
    {key='progression',type='boolean',default=false,label='Record progression history'},
    {key='days',type='number',integer=true,min=1,max=3650,default=30,label='Retain days'},
    {key='max_entries',type='number',integer=true,min=100,max=10000,default=1000,label='Maximum stored observations'},
    {key='max_kib',type='number',integer=true,min=64,max=16384,default=2048,label='Maximum retained text (KiB)'},
    {key='placement',type='choice',default='tabbed',label='History placement',options={{value='tabbed',label='Profile window'},{value='floating',label='External window'}}},
  },apply=apply}
end
function History.new(api,cache,store)
  local self={enabled=false,last='Recording off',revision=0}
  local known,previous,character,statusLevel={},nil,nil,false
  local handlers,epoch={},0
  local paused=false
  local function updated() self.revision=self.revision+1;api.raiseEvent('AardwolfToolbox.history.updated') end
  local function reset()
    known,previous,character,statusLevel={},nil,nil,false
    self.last=self.enabled and 'Waiting for fresh character data' or 'Recording off';updated()
  end
  local function record(path)
    if not self.enabled or paused or not cache.enabled then return end
    local value=cache.get(path);if type(value)~='table' then return end
    local base=path=='char' and value.base or path=='char.base' and value
    local status=path=='char' and value.status or path=='char.status' and value
    if type(base)=='table' and type(base.name)=='string' and base.name~='' and #base.name<=128 and not base.name:find('[%c]') then
      local identity=base.name:lower()
      if character and character~=identity then known,previous,statusLevel={},nil,false end
      character=identity
    end
    if type(base)=='table' then for _,key in ipairs(FIELDS) do
      if number(base[key]) and (key~='level' or not statusLevel) then known[key]=base[key] end
    end end
    if type(status)=='table' and number(status.level) then known.level=status.level;statusLevel=true end
    if not character or not next(known) then return end
    local changes={}
    for _,key in ipairs(FIELDS) do
      if known[key]~=nil and (not previous or known[key]~=previous[key]) then changes[#changes+1]={field=key,before=previous and previous[key],after=known[key]} end
    end
    if #changes==0 then return end
    local entry={observed=math.floor(api.getEpoch()),kind=previous and 'change' or 'snapshot',values=copy(known),changes=changes}
    local ok,why=store.append(character,entry)
    if not ok then
      paused=true;self.last='History recording paused: '..tostring(why);api.echo('Aardwolf '..self.last..'\n');updated();return
    end
    previous=copy(known);self.last='Recording observed progression';updated()
  end
  function self.status() return {enabled=self.enabled,paused=paused,last=self.last,revision=self.revision} end
  function self.list(character,page)
    local result,why=store.read(character,page)
    if not result then self.last='History unavailable: '..tostring(why);return nil,self.last end
    result.revision=self.revision;return result
  end
  function self.clear(character,revision)
    if revision~=self.revision then return nil,'History changed; review before clearing' end
    local ok,why=store.clear(character)
    if ok then updated();return true end
    return nil,why
  end
  function self.export(character)
    local result,why=store.read(character,1,true);if not result then return nil,why end
    local data=api.yajl.to_string({version=1,category='progression',character=result.character,observations=result.rows})
    if #data>16777216 then return nil,'History export exceeds 16 MiB' end
    local destination
    for i=1,999 do
      local path=api.getMudletHomeDir()..'/AardwolfToolbox-progression-export-'..string.format('%03d',i)..'.json'
      local f,err,code=api.io.open(path,'rb')
      if f then if not f:close() then return nil,'Cannot inspect export destination' end
      elseif code==2 then destination=path;break
      else return nil,'Cannot inspect export destination: '..tostring(err) end
    end
    if not destination then return nil,'All 999 export filenames are occupied' end
    local temporary=destination..'.tmp';local f,err=api.io.open(temporary,'wb');if not f then return nil,err end
    local ok,wrote=pcall(f.write,f,data);local flushed,flushResult=pcall(f.flush,f);local closed,closeResult=pcall(f.close,f)
    if not ok or not wrote or not flushed or not flushResult or not closed or not closeResult then api.os.remove(temporary);return nil,'Cannot write history export' end
    local input=api.io.open(temporary,'rb');if not input then api.os.remove(temporary);return nil,'Cannot verify history export' end
    local read,bytes=pcall(input.read,input,#data+1);local shut,done=pcall(input.close,input)
    if not read or bytes~=data or not shut or not done then api.os.remove(temporary);return nil,'History export readback failed' end
    local renamed,message=api.os.rename(temporary,destination)
    if not renamed then api.os.remove(temporary);return nil,message end
    return destination
  end
  function self.stop()
    self.enabled=false;epoch=epoch+1;paused=false
    for _,id in ipairs(handlers) do api.deleteNamedEventHandler(OWNER,id) end;handlers={}
    store.close();reset()
  end
  self.destroy=self.stop
  function self.configure(values)
    store.configure(values)
    if not values.progression then if self.enabled then self.stop() end;return true end
    if self.enabled and not paused then return true end
    self.stop();self.enabled=true;local owned=epoch
    local ok,why=pcall(function()
      for _,id in ipairs({'update','reset'}) do
        handlers[#handlers+1]=id
        assert(api.registerNamedEventHandler(OWNER,id,id=='update' and 'AardwolfToolbox.gmcp.updated' or 'AardwolfToolbox.gmcp.cleared',function(_,path)
          if not self.enabled or epoch~=owned then return end
          if id=='reset' then reset() elseif path=='char' or path=='char.base' or path=='char.status' then record(path) end
        end))
      end
    end)
    if not ok then self.stop();self.last=tostring(why);return nil,self.last end
    reset();return true
  end
  return self
end
return History
