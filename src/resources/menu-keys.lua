-- Contextual keys never replace typing, completion, or the main input buffer.
local Menus={}
function Menus.new(api,blocked)
  local self={};local stack,keys={},{};local generation=0
  local function clearKeys()
    generation=generation+1
    for _,id in ipairs(keys) do pcall(api.killKey,id) end
    keys={}
  end
  local function bind()
    if #keys>0 or #stack==0 then return end
    local current=generation
    local function add(mod,key,action)
      local code=assert(api.mudlet.key[key],'Menu key unavailable: '..key)
      local id=api.tempKey(mod,code,function()
        if current~=generation or (blocked and blocked()) then return end
        local entry=stack[#stack]
        if entry and entry.actions[action] then entry.actions[action]() end
      end)
      assert(type(id)=='number' and id>0,'Cannot register menu key: '..key)
      keys[#keys+1]=id
    end
    local mods=assert(api.mudlet and api.mudlet.keymodifier,'Menu modifiers unavailable')
    local ok,why=pcall(function()
      add(0,'Escape','close')
      -- Mudlet 5.0.1 consumes plain Escape in TCommandLine before Lua keys.
      add(mods.Shift,'Escape','close')
      add(mods.Alt,'J','next');add(mods.Alt,'K','previous')
      add(mods.Alt,'Return','activate')
    end)
    if not ok then clearKeys();error(why) end
  end
  function self.push(owner,actions)
    assert(type(owner)=='string' and type(actions)=='table' and type(actions.close)=='function','Invalid menu scope')
    for i=#stack,1,-1 do if stack[i].owner==owner then table.remove(stack,i) end end
    assert(#stack<16,'Too many open Toolbox menus')
    local entry={owner=owner,actions=actions};stack[#stack+1]=entry
    local ok,why=pcall(bind)
    if not ok then table.remove(stack);return nil,tostring(why) end
    local handle={}
    function handle.release()
      for i=#stack,1,-1 do if stack[i]==entry then table.remove(stack,i);break end end
      if #stack==0 then clearKeys() end
    end
    function handle.raise()
      for i=#stack,1,-1 do if stack[i]==entry then table.remove(stack,i);stack[#stack+1]=entry;return end end
    end
    return handle
  end
  function self.active() return #stack>0 end
  function self.stop() stack={};clearKeys() end
  self.destroy=self.stop
  return self
end
return Menus
