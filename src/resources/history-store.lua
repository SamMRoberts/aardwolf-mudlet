-- Bounded categorized history. Connections and cursors never outlive an operation.
local Store={}
local function normalize(value) return (value:gsub('[A-Z]',function(c) return string.char(c:byte()+32) end)) end
local function quote(value)
  assert(type(value)=='string' and #value<=128 and value~='' and not value:find('[%z\1-\31\127]'),'Invalid history character')
  return "'"..normalize(value):gsub("'","''").."'"
end
local function category(value)
  value=value or 'progression'
  assert(value=='progression' or value=='quests','Invalid history category')
  return value
end
function Store.new(api)
  local self={identity=normalize,path=api.getMudletHomeDir()..'/AardwolfToolbox-history.sqlite3'}
  local env,connection
  local limits={days=30,max_entries=1000,max_kib=2048}
  local function query(sql)
    local cursor,why=connection:execute(sql);assert(cursor,why)
    local ok,rows=pcall(function()
      local result={}
      while true do local row=cursor:fetch({},'a');if not row then break end;result[#result+1]=row end
      return result
    end)
    local closed,err=cursor:close();assert(ok,rows);assert(closed,err)
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
      assert(version==0 or version==1 or version==2,'Unsupported history database version; file preserved')
      if version==0 then
        assert(#query("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")==0,'Unrecognized history database; file preserved')
        execute('PRAGMA auto_vacuum=FULL')
        transaction(function()
          execute('CREATE TABLE observations (id INTEGER PRIMARY KEY AUTOINCREMENT, character TEXT NOT NULL, observed INTEGER NOT NULL, data TEXT NOT NULL, bytes INTEGER NOT NULL, category TEXT NOT NULL)')
          execute('CREATE INDEX history_category_character ON observations(category,character,id)')
          execute('PRAGMA user_version=2')
        end)
      end
      if version==1 then
        transaction(function()
          execute('ALTER TABLE progression RENAME TO observations')
          execute("ALTER TABLE observations ADD COLUMN category TEXT NOT NULL DEFAULT 'progression'")
          execute('CREATE INDEX history_category_character ON observations(category,character,id)')
          execute('PRAGMA user_version=2')
        end)
      end
      return fn()
    end)
    local closed,err=pcall(self.close)
    if not ok then return nil,tostring(result) end
    if not closed then return nil,tostring(err) end
    return result
  end
  local function prune()
    local cutoff=math.floor(api.getEpoch())-limits.days*86400
    execute('DELETE FROM observations WHERE observed<'..cutoff)
    execute('DELETE FROM observations WHERE id NOT IN (SELECT id FROM observations ORDER BY id DESC LIMIT '..limits.max_entries..')')
    local bytes=0
    for _,row in ipairs(query('SELECT id,bytes FROM observations ORDER BY id DESC')) do
      bytes=bytes+tonumber(row.bytes)
      if bytes>limits.max_kib*1024 then execute('DELETE FROM observations WHERE id<='..tonumber(row.id));break end
    end
  end
  function self.configure(values)
    for key,bounds in pairs({days={1,3650},max_entries={100,10000},max_kib={64,16384}}) do
      local n=values[key];assert(type(n)=='number' and n%1==0 and n>=bounds[1] and n<=bounds[2],'Invalid history retention')
      limits[key]=n
    end
  end
  function self.append(character,entry,kind)
    kind=category(kind)
    local identity=quote(character)
    local observed=entry.observed
    assert(type(observed)=='number' and observed%1==0 and observed>=0 and observed<=9007199254740991,'Invalid history timestamp')
    local data=api.yajl.to_string(entry);assert(#data<=8192 and not data:find('%z'),'History record too large')
    return run(function() return transaction(function()
      execute('INSERT INTO observations(character,observed,data,bytes,category) VALUES('..identity..','..observed..",'"..data:gsub("'","''").."',"..#data..",'"..kind.."')")
      prune();return true
    end) end)
  end
  function self.read(character,page,all,kind)
    kind=category(kind)
    local filter="category='"..kind.."'"
    local identity=character and quote(character)
    page=page or 1;assert(type(page)=='number' and page%1==0 and page>=1 and page<=10000,'Invalid history page')
    return run(function() return transaction(function()
      prune()
      local characters=query('SELECT character,COUNT(*) AS count FROM observations WHERE '..filter..' GROUP BY character ORDER BY character')
      local chosen=character and normalize(character) or (characters[1] and characters[1].character)
      if not chosen then return {category=kind,characters=characters,rows={},total=0,page=1,pages=1} end
      identity=identity or quote(chosen)
      local total=tonumber(query('SELECT COUNT(*) AS count FROM observations WHERE '..filter..' AND character='..identity)[1].count)
      local pages=math.max(1,math.ceil(total/25));page=math.min(page,pages)
      local result={category=kind,character=chosen,characters=characters,total=total,page=page,pages=pages,rows={}}
      for _,row in ipairs(query('SELECT id,data FROM observations WHERE '..filter..' AND character='..identity..' ORDER BY id DESC'..(all and '' or ' LIMIT 25 OFFSET '..((page-1)*25)))) do
        local entry=api.yajl.to_value(row.data)
        assert(type(entry)=='table' and type(entry.observed)=='number'
          and entry.observed>=0 and entry.observed%1==0,'Invalid saved history record')
        if kind=='quests' then
          assert(entry.kind=='quest_reward' and type(entry.rewards)=='table' and type(entry.quest)=='table','Invalid saved quest history record')
          local allowed={qp=true,tierqp=true,pracs=true,hardcore=true,opk=true,trains=true,tp=true,lucky=true,double=true,daily=true,totqp=true,gold=true}
          for key,value in pairs(entry.rewards) do
            assert(allowed[key] and type(value)=='number' and value>=0 and value%1==0 and value<=9007199254740991,'Invalid saved quest reward')
          end
          assert(entry.completed==nil or type(entry.completed)=='number' and entry.completed>=0 and entry.completed%1==0 and entry.completed<=9007199254740991,'Invalid saved quest count')
          for key,value in pairs(entry.quest) do
            assert((key=='target' or key=='room' or key=='area') and type(value)=='string' and #value<=1024 and not value:find('[%z\1-\31\127]'),'Invalid saved quest details')
          end
        else
          assert(type(entry)=='table' and (entry.kind=='snapshot' or entry.kind=='change') and type(entry.observed)=='number'
            and entry.observed>=0 and entry.observed%1==0 and type(entry.values)=='table' and type(entry.changes)=='table','Invalid saved history record')
          assert(#entry.changes<=6,'Invalid saved history changes')
          for _,change in ipairs(entry.changes) do
            assert(type(change)=='table' and type(change.field)=='string' and #change.field<=16
              and type(change.after)=='number' and change.after>=0 and change.after%1==0
              and (change.before==nil or type(change.before)=='number' and change.before>=0 and change.before%1==0),'Invalid saved history change')
          end
        end
        entry.id=tonumber(row.id)
        result.rows[#result.rows+1]=entry
      end
      return result
    end) end)
  end
  function self.clear(character,kind)
    kind=category(kind)
    local filter="category='"..kind.."'"
    local identity=quote(character)
    return run(function() return transaction(function() execute('DELETE FROM observations WHERE '..filter..' AND character='..identity);return true end) end)
  end
  self.destroy=self.close
  return self
end
return Store
