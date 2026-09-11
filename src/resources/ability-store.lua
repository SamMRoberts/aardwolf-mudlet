-- Profile-local SQLite storage. Rows are decoded only for explicit queries.
local Store={}
local function quote(value)
  assert(type(value)=='string' and not value:find('%z'),'Invalid database text')
  return "'"..value:gsub("'","''").."'"
end
function Store.new(api)
  local self={path=api.getMudletHomeDir()..'/AardwolfToolbox-abilities.sqlite3'}
  local env,connection,character,owners=nil,nil,nil,{}
  local function execute(sql)
    local result,err=connection:execute(sql)
    assert(result,err or 'Ability database operation failed')
    return result
  end
  local function query(sql,fn)
    local cursor=execute(sql)
    local ok,result=pcall(function()
      local rows={}
      while true do
        local row=cursor:fetch({},'a'); if not row then break end
        rows[#rows+1]=fn and fn(row) or row
      end
      return rows
    end)
    cursor:close()
    assert(ok,result); return result
  end
  function self.open(owner)
    if not connection then
      local ok,err=pcall(function()
        assert(api.luasql and api.luasql.sqlite3,'SQLite support unavailable')
        env=assert(api.luasql.sqlite3()); connection=assert(env:connect(self.path))
        local version=query('PRAGMA user_version')[1]
        local n=tonumber(version and version.user_version) or 0
        assert(n==0 or n==1,'Unsupported ability database version; file preserved')
        execute('CREATE TABLE IF NOT EXISTS ability_records (character TEXT NOT NULL, bucket TEXT NOT NULL, id INTEGER NOT NULL, name TEXT, data TEXT NOT NULL, PRIMARY KEY(character,bucket,id))')
        execute('CREATE INDEX IF NOT EXISTS ability_names ON ability_records(character,bucket,name)')
        execute('CREATE TABLE IF NOT EXISTS ability_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)')
        execute('PRAGMA user_version=1')
        local row=query("SELECT value FROM ability_meta WHERE key='last_character'")[1]
        character=row and row.value or nil
      end)
      if not ok then
        if connection then pcall(function() connection:close() end); connection=nil end
        if env then pcall(function() env:close() end); env=nil end
        return nil,tostring(err)
      end
    end
    owners[owner]=true; return true
  end
  function self.close(owner)
    owners[owner]=nil
    if next(owners) then return end
    if connection then connection:close(); connection=nil end
    if env then env:close(); env=nil end
  end
  function self.character() return character end
  function self.select(name)
    assert(connection,'Ability database is closed')
    assert(type(name)=='string' and #name>0 and #name<=128 and not name:find('[%c]'),'Invalid character identity')
    name=name:lower()
    if character~=name then
      execute("INSERT OR REPLACE INTO ability_meta(key,value) VALUES('last_character',"..quote(name)..')')
      character=name
    end
  end
  local function where(bucket)
    assert(connection and character,'No saved character catalog available')
    return 'character='..quote(character)..' AND bucket='..quote(bucket)
  end
  function self.get(bucket,id)
    if not connection or not character then return nil end
    assert(type(id)=='number' and id>=0 and id%1==0 and id<=2147483647,'Invalid ability number')
    local row=query('SELECT data FROM ability_records WHERE '..where(bucket)..' AND id='..id)[1]
    return row and api.yajl.to_value(row.data) or nil
  end
  function self.rows(bucket,name)
    if not connection or not character then return {} end
    return query('SELECT data FROM ability_records WHERE '..where(bucket)..(name and ' AND name='..quote(name) or '')..' ORDER BY id',function(r) return api.yajl.to_value(r.data) end)
  end
  function self.replace(buckets)
    assert(connection and character,'No character selected')
    execute('BEGIN IMMEDIATE')
    local ok,err=pcall(function()
      for bucket,rows in pairs(buckets) do
        execute('DELETE FROM ability_records WHERE '..where(bucket))
        local count,bytes=0,0
        for id,row in pairs(rows) do
          assert(type(id)=='number' and id>=0 and id%1==0 and id<=2147483647,'Invalid ability number')
          local data=api.yajl.to_string(row); count=count+1; bytes=bytes+#data
          assert(count<=4096 and bytes<=1048576,'Ability snapshot exceeds storage limit')
          execute('INSERT INTO ability_records(character,bucket,id,name,data) VALUES('..quote(character)..','..quote(bucket)..','..id..','..quote(row.name or '')..','..quote(data)..')')
        end
      end
    end)
    if not ok then execute('ROLLBACK'); error(err,0) end
    local committed,err=connection:execute('COMMIT')
    if not committed then pcall(execute,'ROLLBACK'); error(err or 'Ability commit failed',0) end
    return true
  end
  function self.destroy()
    owners={}; self.close('shutdown')
  end
  return self
end
return Store
