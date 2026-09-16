-- Bounded local preference transfers. Never overwrites an existing export/backup.
local Files={}
local LIMIT=1048576
function Files.definition(apply)
  return {id='preferences',label='Import and export',description='Export saved preferences locally or import a JSON file into this settings draft. Review all changes before Apply: preferences can enable monitoring or automatic spellups. Maps, catalogs, history and layout-ownership metadata are not transferred.',settings={
    {key='enabled',type='boolean',default=true,label='Enable preference import/export'},
  },apply=apply}
end
function Files.new(api)
  local self={enabled=true,last='Ready'}
  local function guard(fn,...)
    if not self.enabled then return nil,'Preference import/export is disabled' end
    local ok,result,why=pcall(fn,...)
    if not ok then return nil,'Preference file operation failed: '..tostring(result) end
    return result,why
  end
  local function read(path)
    if type(path)~='string' or path=='' or #path>4096 or path:find('[%z\1-\31\127]') then return nil,'Invalid file path' end
    local f,err,code=api.io.open(path,'rb')
    if not f then return nil,err,code end
    local ok,bytes=pcall(f.read,f,LIMIT+1)
    local closed,result=pcall(f.close,f)
    if not ok or not closed or not result or type(bytes)~='string' then return nil,'Cannot read and close preference file' end
    if #bytes>LIMIT then return nil,'Preference file exceeds 1 MiB' end
    return bytes
  end
  function self.read(path) return guard(read,path) end
  local function writeNew(kind,bytes)
    if kind~='export' and kind~='before-import' then return nil,'Invalid preference file kind' end
    if type(bytes)~='string' or #bytes>LIMIT then return nil,'Preference file exceeds 1 MiB' end
    local destination
    for i=1,999 do
      local path=api.getMudletHomeDir()..'/AardwolfToolbox-preferences-'..kind..'-'..string.format('%03d',i)..'.json'
      local old,err,code=read(path)
      if not old and code==2 then destination=path;break end
      if not old then return nil,'Cannot inspect preference destination: '..tostring(err) end
    end
    if not destination then return nil,'All 999 preference filenames are occupied; archive older files first' end
    local temporary=destination..'.tmp'
    local out,why=api.io.open(temporary,'wb');if not out then return nil,'Cannot create preference file: '..tostring(why) end
    local wrote,result=pcall(out.write,out,bytes)
    local flushed,flushResult=true,true
    if out.flush then flushed,flushResult=pcall(out.flush,out) end
    local closed,closeResult=pcall(out.close,out)
    if not wrote or not result or not flushed or not flushResult or not closed or not closeResult then
      api.os.remove(temporary);return nil,'Cannot finish preference file'
    end
    local checked=read(temporary)
    if checked~=bytes then api.os.remove(temporary);return nil,'Preference file readback failed' end
    local renameOK,renamed,err=pcall(api.os.rename,temporary,destination)
    if not renameOK or not renamed then
      api.os.remove(temporary);return nil,'Cannot finalize preference file: '..tostring(renameOK and err or renamed)
    end
    self.last=destination;return destination
  end
  function self.writeNew(kind,bytes) return guard(writeNew,kind,bytes) end
  function self.backup(path,fallback)
    return guard(function()
      local bytes,why,code=read(path)
      if not bytes and code~=2 then return nil,'Cannot read preferences for backup: '..tostring(why) end
      return writeNew('before-import',bytes or fallback)
    end)
  end
  function self.configure(values) self.enabled=values.enabled;self.last=self.enabled and 'Ready' or 'Disabled';return true end
  function self.stop() self.enabled=false end
  self.destroy=self.stop
  return self
end
return Files
