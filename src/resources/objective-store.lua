-- Latest observations only; history preferences and retention are independent.
local Store={}
function Store.new(api,State)
  local self={path=api.getMudletHomeDir()..'/AardwolfToolbox-objectives.sqlite3'}
  local env,connection
  local function quote(v)
    assert(type(v)=='string' and #v>0 and #v<=128 and not v:find('[%z\1-\31\127]'),'Invalid character')
    return "'"..v:gsub("'","''").."'"
  end
  function self.identity(v) return (v:gsub('[A-Z]',function(c) return string.char(c:byte()+32) end)) end
  local function kind(v) assert(v=='campaign' or v=='globalQuest','Invalid tracker');return "'"..v.."'" end
  local function query(sql)
    local cursor,why=connection:execute(sql);assert(cursor,why)
    local ok,rows=pcall(function()
      local result={}
      while true do
        local row,err=cursor:fetch({},'a')
        if not row then assert(not err,err);break end
        result[#result+1]=row
      end
      return result
    end)
    local closed,err=cursor:close();assert(ok,rows)
    -- LuaSQL SQLite auto-closes exhausted cursors; a second close returns false.
    assert(closed or closed==false and err==nil,err or 'Cannot close history cursor')
    return rows
  end
  local function execute(sql)
    local result,why=connection:execute(sql);assert(result,why)
    if type(result)~='number' then assert(result:close()) end
  end
  function self.close()
    local ok,why=true,nil
    if connection then ok,why=connection:close();connection=nil end
    if env then local closed,err=env:close();env=nil;if not closed then ok,why=closed,err end end
    assert(ok,why or 'Cannot close history database')
  end
  local function transaction(fn)
    execute('BEGIN IMMEDIATE')
    local ok,result=pcall(fn)
    if ok then ok,result=pcall(function() execute('COMMIT');return result end) end
    if not ok then pcall(execute,'ROLLBACK');error(result,0) end
    return result
  end

  local function run(fn)
    local ok,result=pcall(function()
      assert(api.luasql and api.luasql.sqlite3,'SQLite support unavailable')
      env=assert(api.luasql.sqlite3());connection=assert(env:connect(self.path))
      local version=tonumber(query('PRAGMA user_version')[1].user_version)
      assert(version==0 or version==1,'Unsupported objective database; file preserved')
      if version==0 then
        assert(#query("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")==0,'Unrecognized objective database; file preserved')
        transaction(function()
          execute('CREATE TABLE latest (character TEXT NOT NULL, tracker TEXT NOT NULL, data TEXT NOT NULL, PRIMARY KEY(character,tracker))')
          execute('PRAGMA user_version=1')
        end)
      end
      return fn()
    end)
    local closed,err=pcall(self.close)
    if not ok then return nil,tostring(result) end
    if not closed then return nil,tostring(err) end
    return result
  end
  function self.save(character,tracker,value)
    State.validate(value)
    local who,which=quote(self.identity(character)),kind(tracker)
    local encoded=api.yajl.to_string(State.restore(value))
    assert(#encoded<=1048576 and not encoded:find('%z'),'Observation too large')
    return run(function() return transaction(function()
      execute("INSERT OR REPLACE INTO latest(character,tracker,data) VALUES("..who..","..which..",'"..encoded:gsub("'","''").."')")
      return true
    end) end)
  end
  function self.read(character,tracker)
    local who,which=quote(self.identity(character)),kind(tracker)
    return run(function()
      local rows=query('SELECT data FROM latest WHERE character='..who..' AND tracker='..which)
      if #rows==0 then return State.empty() end
      assert(#rows[1].data<=1048576,'Saved observation too large')
      return State.restore(api.yajl.to_value(rows[1].data))
    end)
  end
  self.destroy=self.close
  return self
end
return Store
