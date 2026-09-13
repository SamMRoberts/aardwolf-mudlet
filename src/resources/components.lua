-- Explicit dependency order, with best-effort cleanup even after partial startup.
local Components={}
function Components.new()
  local self,entries,order,errors={},{},{},{}
  function self.register(id,value,dependencies,method)
    assert(type(id)=='string' and type(value)=='table','Invalid component')
    assert(not entries[id],'Duplicate component: '..id)
    for _,dependency in ipairs(dependencies or {}) do
      assert(entries[dependency],'Missing component dependency: '..dependency)
    end
    entries[id]={value=value,dependencies=dependencies or {},method=method or 'stop'}
    order[#order+1]=id
    return value
  end
  function self.stop()
    errors={}
    for i=#order,1,-1 do
      local id=order[i]; local entry=entries[id]
      local fn=entry.value[entry.method] or entry.value.destroy
      if fn then
        local ok,result,message=pcall(fn)
        if not ok or result==false then errors[id]=tostring(message or result) end
      end
    end
    return next(errors)==nil,self.snapshot()
  end
  function self.snapshot()
    local result={}
    for _,id in ipairs(order) do
      local entry=entries[id]
      result[#result+1]={id=id,enabled=entry.value.enabled,last=entry.value.last,error=errors[id]}
    end
    return result
  end
  return self
end
return Components
