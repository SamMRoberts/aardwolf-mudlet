-- Policies share fresh cache data; manual actions are never queued here.
local Readiness={}
local MANUAL={[3]=true,[4]=true,[8]=true,[9]=true,[11]=true}
local REASONS={[1]='At login',[2]='Login incomplete',[4]='AFK',[5]='Writing a note',
  [6]='Editing',[7]='Paged output',[8]='In combat',[9]='Sleeping',[11]='Resting',[12]='Running'}
function Readiness.new(api,cache)
  local self={}
  function self.check(policy)
    assert(policy=='manual' or policy=='information' or policy=='spellup','Unknown readiness policy')
    if not cache.enabled or not select(3,api.getConnectionInfo()) then return false,'Disconnected or GMCP disabled' end
    local state=cache.get('char.status.state')
    if state==nil then return false,'Waiting for fresh character state' end
    if policy=='manual' then
      return MANUAL[state]==true,MANUAL[state] and nil or (REASONS[state] or 'Character not ready')
    end
    if state~=3 then return false,REASONS[state] or 'Character not ready' end
    if policy=='spellup' and cache.get('char.status.pos')~='Standing' then return false,'Not standing' end
    return true
  end
  function self.send(transport,line)
    assert(transport=='command' or transport=='gmcp' or transport=='alias','Unknown transport')
    if type(line)~='string' or not line:match('%S') or line:find('[%z\1-\31\127]') then return false,'Invalid single-line command' end
    local fn=transport=='gmcp' and api.sendGMCP or transport=='alias' and api.expandAlias or api.send
    if type(fn)~='function' then return false,'Transport unavailable' end
    local ok,result,message
    if transport=='gmcp' then ok,result,message=pcall(fn,line)
    else ok,result,message=pcall(fn,line,false) end
    if not ok or result==false or (result==nil and message) then return false,tostring(message or result) end
    return true
  end
  cache.checkReadiness=self.check
  cache.sendChecked=self.send
  return self
end
return Readiness
